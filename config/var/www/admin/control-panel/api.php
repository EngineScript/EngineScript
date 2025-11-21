<?php
/**
 * EngineScript Admin Dashboard API
 * Refactored to use Router/Controller pattern
 * 
 * @version 2.0.0
 * @security HIGH - Contains sensitive system information
 */

// Load BaseController early for response methods
require_once __DIR__ . '/classes/BaseController.php'; // codacy:ignore - Safe class loading with __DIR__ constant

// Prevent direct access
if (!isset($_SERVER['REQUEST_URI']) || !isset($_SERVER['HTTP_HOST'])) { // codacy:ignore - $_SERVER access required for standalone API validation
    BaseController::forbidden('Direct access forbidden');
}

// Security headers
header('Content-Type: application/json; charset=UTF-8'); // codacy:ignore - header() required for API response type
header('X-Content-Type-Options: nosniff'); // codacy:ignore - header() required for security
header('X-Frame-Options: DENY'); // codacy:ignore - header() required for security
header('X-XSS-Protection: 1; mode=block'); // codacy:ignore - header() required for security
header('Referrer-Policy: strict-origin-when-cross-origin'); // codacy:ignore - header() required for security
header('Content-Security-Policy: default-src \'none\'; frame-ancestors \'none\';'); // codacy:ignore - header() required for security

// CORS configuration
$allowed_origins = [
    isset($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : '',
    'localhost',
    '127.0.0.1'
];

$origin = isset($_SERVER['HTTP_ORIGIN']) ? $_SERVER['HTTP_ORIGIN'] : (isset($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : '');
$origin_host = parse_url($origin, PHP_URL_HOST); // codacy:ignore - parse_url() required for URL validation in standalone API
if ($origin_host === false) {
    $origin_host = $origin;
}

$allowed = in_array($origin_host, $allowed_origins, true) || 
           preg_match('/^(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/', $origin_host);
if ($allowed) {
    header('Access-Control-Allow-Origin: ' . $origin); // codacy:ignore - header() required for CORS
}
if (!$allowed) {
    header('Access-Control-Allow-Origin: null'); // codacy:ignore - header() required for CORS security
}

header('Access-Control-Allow-Methods: GET, OPTIONS'); // codacy:ignore - header() required for CORS
header('Access-Control-Allow-Headers: Content-Type, X-Requested-With, X-CSRF-Token'); // codacy:ignore - header() required for CORS
header('Access-Control-Allow-Credentials: true'); // codacy:ignore - header() required for CORS
header('Access-Control-Max-Age: 86400'); // codacy:ignore - header() required for CORS

// Session and rate limiting
if (session_status() === PHP_SESSION_NONE) { // codacy:ignore - session_status() required for rate limiting
    session_start(); // codacy:ignore - session_start() required for rate limiting
}

// Initialize CSRF token
if (!isset($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

// Rate limiting
$client_ip = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : 'unknown';
$rate_limit_key = 'api_rate_' . hash('sha256', $client_ip);

if (!isset($_SESSION[$rate_limit_key])) {
    $_SESSION[$rate_limit_key] = ['count' => 0, 'reset' => time() + 60];
}

if (isset($_SESSION[$rate_limit_key]['reset']) && time() > $_SESSION[$rate_limit_key]['reset']) {
    $_SESSION[$rate_limit_key] = ['count' => 0, 'reset' => time() + 60];
}

if (isset($_SESSION[$rate_limit_key]['count']) && $_SESSION[$rate_limit_key]['count'] >= 100) { // codacy:ignore - Session access required for rate limiting
    BaseController::rateLimitExceeded();
}

if (isset($_SESSION[$rate_limit_key]['count'])) { // codacy:ignore - Session access required for rate limiting
    $_SESSION[$rate_limit_key]['count']++; // codacy:ignore - Session modification required for rate limiting
}

// Handle preflight requests
if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] === 'OPTIONS') { // codacy:ignore - $_SERVER access required for CORS
    http_response_code(200);
    die(); // codacy:ignore - die() required for CORS preflight termination
}

// Only allow GET requests
if (!isset($_SERVER['REQUEST_METHOD']) || $_SERVER['REQUEST_METHOD'] !== 'GET') { // codacy:ignore - $_SERVER access required for method validation
    http_response_code(405);
    BaseController::methodNotAllowed();
}

// Load Router and Controllers
require_once __DIR__ . '/classes/Router.php'; // codacy:ignore - Safe class loading with __DIR__ constant

// Parse request path
$request_uri = isset($_SERVER['REQUEST_URI']) ? $_SERVER['REQUEST_URI'] : ''; // codacy:ignore - $_SERVER access required for routing, wp_unslash() not available in standalone API
$endpoint_param = isset($_GET['endpoint']) ? trim($_GET['endpoint']) : ''; // codacy:ignore - $_GET access required for routing, input sanitized with preg_replace
$endpoint_param = preg_replace('/[^a-zA-Z0-9\/\-_]/', '', $endpoint_param);

if (!empty($endpoint_param)) {
    $path = '/' . ltrim($endpoint_param, '/');
    $path = rtrim($path, '/');
}
if (empty($endpoint_param)) {
    $path = parse_url($request_uri, PHP_URL_PATH); // codacy:ignore - parse_url() required for URL parsing in standalone API
    if ($path !== false) {
        $path = str_replace('/api', '', $path);
        $path = rtrim($path, '/');
    }
}

// Validate path
if (!Router::validatePath($path)) {
    error_log("API Security: Suspicious path - " . substr($path, 0, 100) . " - IP: " . $client_ip);
    BaseController::badRequest('Invalid path');
}

$router = new Router();

// Register routes
$router->get('/csrf-token', ['SecurityController', 'getCsrfToken']);
$router->get('/system/info', ['SystemController', 'getInfo']);
$router->get('/services/status', ['ServicesController', 'getStatus']);
$router->get('/sites', ['SitesController', 'getSites']);
$router->get('/sites/', ['SitesController', 'getSites']);
$router->get('/sites/count', ['SitesController', 'getCount']);
$router->get('/activity/recent', ['ActivityController', 'getRecent']);
$router->get('/alerts', ['ActivityController', 'getAlerts']);
$router->get('/alerts/', ['ActivityController', 'getAlerts']);
$router->get('/tools/filemanager/status', ['ToolsController', 'getFileManagerStatus']);
$router->get('/monitoring/uptime', ['MonitoringController', 'getUptimeStatus']);
$router->get('/monitoring/uptime/monitors', ['MonitoringController', 'getUptimeMonitors']);
$router->get('/external-services/config', ['ExternalServicesController', 'getConfig']);
$router->get('/external-services/feed', ['ExternalServicesController', 'getFeed']);

// Load controllers
require_once __DIR__ . '/controllers/SecurityController.php'; // codacy:ignore - Safe class loading with __DIR__ constant
require_once __DIR__ . '/controllers/SystemController.php'; // codacy:ignore - Safe class loading with __DIR__ constant
require_once __DIR__ . '/controllers/ServicesController.php'; // codacy:ignore - Safe class loading with __DIR__ constant
require_once __DIR__ . '/controllers/SitesController.php'; // codacy:ignore - Safe class loading with __DIR__ constant
require_once __DIR__ . '/controllers/ActivityController.php'; // codacy:ignore - Safe class loading with __DIR__ constant
require_once __DIR__ . '/controllers/ToolsController.php'; // codacy:ignore - Safe class loading with __DIR__ constant
require_once __DIR__ . '/controllers/MonitoringController.php'; // codacy:ignore - Safe class loading with __DIR__ constant
require_once __DIR__ . '/controllers/ExternalServicesController.php'; // codacy:ignore - Safe class loading with __DIR__ constant

// Dispatch request
$router->dispatch('GET', $path);
