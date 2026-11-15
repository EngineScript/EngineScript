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

use EngineScript\Dashboard\Classes\ApiResponder;
use EngineScript\Dashboard\Classes\Request;
use EngineScript\Dashboard\Classes\RequestGuard;
use EngineScript\Dashboard\Classes\Router;
use EngineScript\Dashboard\Classes\SecurityLogger;
use EngineScript\Dashboard\Classes\Session;

// Load every class here, in dependency order: the class files do not load each other
require_once __DIR__ . '/classes/CommandRunner.php';
require_once __DIR__ . '/classes/SystemProcessRunner.php';
require_once __DIR__ . '/classes/SystemCommand.php';
require_once __DIR__ . '/classes/ApiResponder.php';
require_once __DIR__ . '/classes/Request.php';
require_once __DIR__ . '/classes/SecurityLogger.php';
require_once __DIR__ . '/classes/Session.php';
require_once __DIR__ . '/classes/RequestGuard.php';
require_once __DIR__ . '/classes/UptimeRobotAPI.php';
require_once __DIR__ . '/classes/Router.php';
require_once __DIR__ . '/controllers/BaseController.php';
require_once __DIR__ . '/controllers/CacheController.php';
require_once __DIR__ . '/controllers/CsrfController.php';
require_once __DIR__ . '/controllers/FileManagerController.php';
require_once __DIR__ . '/controllers/ServiceController.php';
require_once __DIR__ . '/controllers/SiteController.php';
require_once __DIR__ . '/controllers/SystemController.php';
require_once __DIR__ . '/controllers/ToolsController.php';
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

// The session holds the CSRF token and the rate-limit count.
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

// Without a session there is no rate limit and no CSRF token, so stop here.
if (session_status() !== PHP_SESSION_ACTIVE) {
    $securityLogger->write('Session start failed', 'API request refused with 503');
    $response->error('Session storage unavailable', 503);
    die();
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
$rate_limit = RequestGuard::rateLimitState($session->get($rate_limit_key));

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

$rate_limit['count'] = RequestGuard::nextRateLimitCount($rate_limit);
$session->set($rate_limit_key, $rate_limit);

// Validate CSRF token for state-changing requests
if (!RequestGuard::validateCsrfToken($request, $session, $securityLogger)) {
    $response->forbidden('Invalid or missing CSRF token');
    die();
}

// Dispatch only reads session data; release the lock before slow controller work.
session_write_close();

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
