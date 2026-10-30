<?php

/**
 * EngineScript Admin Dashboard API
 * Secure API endpoints for dashboard functionality
 *
 * Refactored to use Router/Controller pattern for maintainability.
 *
 * @version 2.0.0
 * @security HIGH - Contains sensitive system information
 */

declare(strict_types=1);

// Load core classes
require_once __DIR__ . '/classes/SystemCommand.php';
require_once __DIR__ . '/classes/ApiResponder.php';
require_once __DIR__ . '/classes/Request.php';
require_once __DIR__ . '/classes/Router.php';
require_once __DIR__ . '/classes/SecurityLogger.php';
require_once __DIR__ . '/classes/Session.php';
require_once __DIR__ . '/controllers/BaseController.php';
require_once __DIR__ . '/controllers/CacheController.php';
require_once __DIR__ . '/controllers/CsrfController.php';
require_once __DIR__ . '/controllers/FileManagerController.php';
require_once __DIR__ . '/controllers/ServiceController.php';
require_once __DIR__ . '/controllers/SiteController.php';
require_once __DIR__ . '/controllers/SystemController.php';
require_once __DIR__ . '/controllers/UptimeController.php';

$request = new Request();
$response = new ApiResponder();
$session = new Session();
$securityLogger = new SecurityLogger($request);

// Cover early exits as well as JSON responses.
header('Cache-Control: no-store');

// Prevent direct access if not from proper context
if (!$request->hasServer('REQUEST_URI') || !$request->hasServer('HTTP_HOST')) {
    http_response_code(403);
    die('Direct access forbidden');
}

// Security headers - header() function required for standalone API security
// (X-Content-Type-Options comes from the admin site's nginx configuration, on every response)
header('Content-Type: application/json; charset=UTF-8');
header('Content-Security-Policy: default-src \'none\'; frame-ancestors \'none\';');

// No CORS headers: the dashboard calls the API from its own origin.

// Rate limiting (basic implementation) - session functions required for API rate limiting
if (session_status() === PHP_SESSION_NONE) {
    session_name('__Host-esp_session');
    // Keep the API's no-store policy instead of PHP's session cache headers.
    session_cache_limiter('');
    // Configure secure session cookie parameters before starting session
    ini_set('session.cookie_secure', '1');     // Only send cookie over HTTPS
    ini_set('session.cookie_httponly', '1');   // Prevent JavaScript access to session cookie
    ini_set('session.cookie_samesite', 'Strict'); // Prevent CSRF via cookie
    ini_set('session.cookie_path', '/');
    ini_set('session.cookie_domain', '');
    ini_set('session.use_strict_mode', '1');   // Reject uninitialized session IDs
    ini_set('session.use_only_cookies', '1');  // Only use cookies for session ID

    session_start();

    if (!$session->has('_initialized')) {
        session_regenerate_id(true);
        $session->set('_initialized', true);
    }
}

// Initialize CSRF token if not exists
if (!$session->has('csrf_token')) {
    try {
        $session->set('csrf_token', bin2hex(random_bytes(32)));
    } catch (Throwable $e) {
        $securityLogger->write('CSRF token generation failed', $e->getMessage());
        $response->serverError('Unable to initialize request security');
        die();
    }
}
$client_ip = $request->remoteAddress();
$rate_limit_key = 'api_rate_' . hash('sha256', $client_ip);
$rate_limit = rateLimitState($session->get($rate_limit_key));

// Reset rate limit counter every minute
if (isset($rate_limit['reset']) && is_int($rate_limit['reset']) && time() > $rate_limit['reset']) {
    $rate_limit = ['count' => 0, 'reset' => time() + 60];
}

// Check rate limit (100 requests per minute)
if (isset($rate_limit['count']) && is_int($rate_limit['count']) && $rate_limit['count'] >= 100) {
    // Rejected requests intentionally preserve the current over-limit count.
    // This keeps the lockout stable until the reset time without extending it.
    $session->set($rate_limit_key, $rate_limit);
    $response->rateLimited();
    die();
}

$rate_limit['count'] = nextRateLimitCount($rate_limit);
$session->set($rate_limit_key, $rate_limit);

/**
 * The stored rate-limit state, or a fresh window when nothing usable is stored.
 *
 * @return array<mixed>
 */
function rateLimitState(mixed $stored): array
{
    return is_array($stored) ? $stored : ['count' => 0, 'reset' => time() + 60];
}

/**
 * The request count after this request.
 *
 * @param array<mixed> $rate_limit
 */
function nextRateLimitCount(array $rate_limit): int
{
    return isset($rate_limit['count']) && is_int($rate_limit['count']) ? $rate_limit['count'] + 1 : 1;
}

/**
 * Validates CSRF token for state-changing requests (POST, PUT, DELETE, PATCH)
 * Token can be sent via X-CSRF-Token header or _csrf_token body parameter
 *
 * @return bool True if valid or not required (GET/HEAD/OPTIONS), false if invalid
 */
function validateCsrfToken(Request $request, Session $session, SecurityLogger $securityLogger): bool
{
    $method = $request->method();

    if (isCsrfSafeMethod($method)) {
        return true;
    }

    $client_token = csrfTokenFromRequest($request, $securityLogger);
    if ($client_token === false) {
        return false;
    }

    return csrfTokenIsValid($method, $client_token, $session->get('csrf_token'), $securityLogger);
}

function isCsrfSafeMethod(string $method): bool
{
    return in_array($method, ['GET', 'HEAD', 'OPTIONS'], true);
}

function csrfTokenFromRequest(Request $request, SecurityLogger $securityLogger): string|false|null
{
    $headerToken = $request->header('X-CSRF-Token');
    if ($headerToken !== null) {
        return $headerToken;
    }

    $postToken = $request->post('_csrf_token');
    if ($postToken !== null) {
        return $postToken;
    }

    if (!str_contains(strtolower($request->header('Content-Type') ?? ''), 'application/json')) {
        return null;
    }

    return csrfTokenFromJsonBody($request, $securityLogger);
}

function csrfTokenFromJsonBody(Request $request, SecurityLogger $securityLogger): string|false|null
{
    $input = $request->body();
    if (trim($input) === '') {
        return null;
    }

    try {
        return csrfTokenFromDecodedBody(json_decode($input, true, 512, JSON_THROW_ON_ERROR));
    } catch (JsonException) {
        $securityLogger->write('CSRF token JSON parse failed', 'Invalid JSON body');
        return false;
    }
}

function csrfTokenFromDecodedBody(mixed $body): ?string
{
    if (!is_array($body) || !isset($body['_csrf_token']) || !is_string($body['_csrf_token'])) {
        return null;
    }

    return $body['_csrf_token'];
}

function csrfTokenIsValid(
    string $method,
    ?string $client_token,
    mixed $session_token,
    SecurityLogger $securityLogger
): bool {
    if (in_array($client_token, [null, '', '0'], true) || !is_string($session_token) || $session_token === '') {
        $securityLogger->write('CSRF token missing', $method . ' request without token');
        return false;
    }

    if (!hash_equals($session_token, $client_token)) {
        $securityLogger->write('CSRF token mismatch', 'Invalid token submitted');
        return false;
    }

    return true;
}

// Validate CSRF token for state-changing requests
if (!validateCsrfToken($request, $session, $securityLogger)) {
    $response->forbidden('Invalid or missing CSRF token');
    die();
}

// Dispatch only reads session data; release the lock before slow controller work.
if (session_status() === PHP_SESSION_ACTIVE) {
    session_write_close();
}

// The endpoint comes from nginx's rewrite (endpoint=...), or else from an /api/ path.
$endpoint = $request->query('endpoint');
if ($endpoint !== null) {
    $path = '/' . ltrim($endpoint, '/');
} else {
    $path = parse_url($request->uri(), PHP_URL_PATH);
    $path = is_string($path) ? $path : '';
    if (str_starts_with($path, '/api/')) {
        $path = '/' . ltrim(substr($path, 5), '/');
    } elseif ($path === '/api') {
        $path = '/';
    }
}

$path = rtrim($path, '/');
$path = $path === '' ? '/' : $path;

// One check, anchored at the end; anything else is refused, never cleaned up.
if (preg_match('/^\/[A-Za-z0-9\/_-]{0,99}\z/', $path) !== 1) {
    $securityLogger->write('Suspicious path', $path);
    $response->badRequest('Invalid path');
    die();
}

try {
    (new Router($response, $request, $securityLogger, $session))->dispatch($path);
} catch (Throwable $e) {
    $securityLogger->write('Unhandled API error', $e->getMessage());
    $response->serverError('Internal server error');
}
