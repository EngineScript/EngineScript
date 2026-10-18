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

// Load core classes
// @codacy suppress [require_once statement detected] Secure class loading with __DIR__ constant - no user input
require_once __DIR__ . '/classes/SystemCommand.php';
require_once __DIR__ . '/classes/ApiResponder.php';
require_once __DIR__ . '/classes/Request.php';
require_once __DIR__ . '/classes/Router.php';
require_once __DIR__ . '/classes/SecurityLogger.php';
require_once __DIR__ . '/classes/Session.php';
require_once __DIR__ . '/controllers/BaseController.php';
require_once __DIR__ . '/controllers/BatchController.php';
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

// Prevent direct access if not from proper context
if (!$request->hasServer('REQUEST_URI') || !$request->hasServer('HTTP_HOST')) {
    http_response_code(403);
    die('Direct access forbidden'); // codacy:ignore - die() required for security termination
}

// Security headers - header() function required for standalone API security
header('Content-Type: application/json; charset=UTF-8'); // codacy:ignore - Required for API response type
header('X-Content-Type-Options: nosniff'); // codacy:ignore - Security header required
header('X-Frame-Options: DENY'); // codacy:ignore - Security header required
header('Referrer-Policy: strict-origin-when-cross-origin'); // codacy:ignore - Security header required
header('Content-Security-Policy: default-src \'none\'; frame-ancestors \'none\';'); // codacy:ignore - Security header required

// Check if client accepts gzip and zlib extension is available
$zlib_output_compression = ini_get('zlib.output_compression');
if (extension_loaded('zlib') && in_array($zlib_output_compression, [false, '', '0'], true)) {
    // Check Accept-Encoding header for gzip support
    $accept_encoding = $request->header('Accept-Encoding') ?? '';
    if (str_contains($accept_encoding, 'gzip')) {
        // Enable gzip compression with level 6 (good balance of speed/compression)
        ini_set('zlib.output_compression', 'On'); // codacy:ignore - ini_set() required for compression
        ini_set('zlib.output_compression_level', '6'); // codacy:ignore - ini_set() required for compression
    }
}

// Secure CORS - only echo a validated same-origin Origin header.
$request_host_header = $request->hostHeader();
$request_port = null;
if (preg_match('/^\[([^\]]+)\](?::(\d+))?$/', $request_host_header, $host_matches)) {
    $request_host = $host_matches[1];
    $request_port = isset($host_matches[2]) ? (int) $host_matches[2] : null;
} elseif (preg_match('/^([^:]+)(?::(\d+))?$/', $request_host_header, $host_matches)) {
    $request_host = $host_matches[1];
    $request_port = isset($host_matches[2]) ? (int) $host_matches[2] : null;
} else {
    $request_host = trim($request_host_header, '[]');
}
$request_scheme = $request->scheme();
$request_effective_port = $request_port ?? ($request_scheme === 'https' ? 443 : 80);
$is_local_request_host = in_array($request_host, ['localhost', '127.0.0.1', '::1'], true);
$cors_origin_allowed = false;

$origin = $request->header('Origin');
if (is_string($origin) && $origin !== '') {
    $origin_parts = parse_url($origin); // codacy:ignore - parse_url() required for URL validation
    if (!is_array($origin_parts)) {
        $origin_parts = [];
    }

    $origin_scheme = strtolower($origin_parts['scheme'] ?? '');
    $origin_host = strtolower($origin_parts['host'] ?? '');
    $origin_host_for_compare = trim($origin_host, '[]');
    $origin_port = isset($origin_parts['port']) ? ':' . $origin_parts['port'] : '';
    $origin_effective_port = $origin_parts['port']
        ?? ($origin_scheme === 'https' ? 443 : 80);
    $scheme_matches = hash_equals($request_scheme, $origin_scheme)
        || ($is_local_request_host && in_array($origin_scheme, ['http', 'https'], true));
    $port_matches = $request_effective_port === $origin_effective_port || $is_local_request_host;

    $is_allowed_origin = $scheme_matches && $port_matches && hash_equals($request_host, $origin_host_for_compare);

    if ($is_allowed_origin) {
        $origin_host_header = str_contains($origin_host, ':') && !str_starts_with($origin_host, '[')
            ? '[' . $origin_host . ']'
            : $origin_host;
        header('Access-Control-Allow-Origin: ' . $origin_scheme . '://' . $origin_host_header . $origin_port); // codacy:ignore - CORS header required for API
        $cors_origin_allowed = true;
    }
}

if ($cors_origin_allowed) {
    header('Access-Control-Allow-Methods: GET, POST, OPTIONS'); // codacy:ignore - CORS header required
    header('Access-Control-Allow-Headers: Content-Type, X-Requested-With, X-CSRF-Token'); // codacy:ignore - CORS header required
    header('Access-Control-Allow-Credentials: true'); // codacy:ignore - CORS header required for same-origin API credentials
    header('Access-Control-Max-Age: 86400'); // codacy:ignore - CORS header required
}

// Rate limiting (basic implementation) - session functions required for API rate limiting
if (session_status() === PHP_SESSION_NONE) { // codacy:ignore - session_status() required for session management in standalone API
    // Configure secure session cookie parameters before starting session
    // codacy:ignore-start - ini_set() required for secure session configuration in standalone API
    ini_set('session.cookie_secure', '1');     // Only send cookie over HTTPS
    ini_set('session.cookie_httponly', '1');   // Prevent JavaScript access to session cookie
    ini_set('session.cookie_samesite', 'Strict'); // Prevent CSRF via cookie
    ini_set('session.use_strict_mode', '1');   // Reject uninitialized session IDs
    ini_set('session.use_only_cookies', '1');  // Only use cookies for session ID
    // codacy:ignore-end

    session_start(); // codacy:ignore - session_start() required for rate limiting functionality

    if (!$session->has('_initialized')) {
        session_regenerate_id(true); // codacy:ignore - Security hardening for session fixation
        $session->set('_initialized', true);
    }
}

// Initialize CSRF token if not exists
if (!$session->has('csrf_token')) {
    try {
        $session->set('csrf_token', bin2hex(random_bytes(32))); // codacy:ignore - random_bytes() required for cryptographic token generation
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

// Handle preflight requests
if ($request->method() === 'OPTIONS') {
    http_response_code(200);
    die(); // codacy:ignore - die() required for CORS termination
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
    if ($client_token === null || $client_token === '' || $client_token === '0' || !is_string($session_token) || $session_token === '') {
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

// Get the request URI first
$request_uri = $request->uri();

// Check if endpoint is passed as a query parameter
$endpoint_param = $request->query('endpoint') ?? '';
// Sanitize endpoint parameter to prevent injection attacks
$endpoint_param = preg_replace('/[^a-zA-Z0-9\/\-_]/', '', $endpoint_param);
$endpoint_param = is_string($endpoint_param) ? $endpoint_param : '';
$path = '';
if (!empty($endpoint_param)) {
    $path = '/' . ltrim($endpoint_param, '/');
    $path = rtrim($path, '/'); // Remove trailing slashes
} else {
    $parsed_path = parse_url($request_uri, PHP_URL_PATH); // codacy:ignore - parse_url() required for URL parsing
    if (is_string($parsed_path)) {
        if (str_starts_with($parsed_path, '/api/')) {
            $parsed_path = '/' . ltrim(substr($parsed_path, 5), '/');
        } elseif ($parsed_path === '/api') {
            $parsed_path = '/';
        }
        $path = rtrim($parsed_path, '/'); // Remove trailing slashes
    }
}

$path = $path === '' ? '/' : $path;

// Path was already extracted and validated above, validate again for security
if (strlen($path) > 100 || !preg_match('/^\/[a-zA-Z0-9\/_-]*$/', $path)) {
    $securityLogger->write('Suspicious path', $path);
    $response->badRequest('Invalid path');
    die();
}

// ============ Router-Based Request Dispatch ============
// Initialize router and register all routes
$router = new Router($response, $request, $securityLogger, $session);

// CSRF Token endpoint
$router->register('/csrf-token', CsrfController::class, 'getToken');

// System information endpoint
$router->register('/system/info', SystemController::class, 'getInfo');

// Service status endpoint
$router->register('/services/status', ServiceController::class, 'getStatus');

// Sites endpoints
$router->register('/sites', SiteController::class, 'getSites');
$router->register('/sites/count', SiteController::class, 'getSitesCount');
$router->alias('/sites/', '/sites'); // Handle trailing slash

// File manager endpoint
$router->register('/tools/filemanager/status', FileManagerController::class, 'getStatus');

// Uptime monitoring endpoints
$router->register('/monitoring/uptime', UptimeController::class, 'getStatus');
$router->register('/monitoring/uptime/monitors', UptimeController::class, 'getMonitors');

// Cache management endpoint
$router->register('/cache/clear', CacheController::class, 'clear', ['POST']);
$router->register('/cache/status', CacheController::class, 'getStatus');

// Legacy batch endpoint (kept for backward compatibility)
$router->register('/batch', BatchController::class, 'handle', ['POST']);

// Dispatch request through router
try {
    $router->dispatch($path, $request->method());
} catch (Throwable $e) {
    $securityLogger->write('Unhandled API error', $e->getMessage());
    $response->serverError('Internal server error');
}
