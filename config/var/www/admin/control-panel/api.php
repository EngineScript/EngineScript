<?php
/**
 * EngineScript Admin Dashboard API
 * Refactored to use Router/Controller pattern
 * 
 * @version 2.0.0
 * @security HIGH - Contains sensitive system information
 */

// Prevent direct access
if (!isset($_SERVER['REQUEST_URI']) || !isset($_SERVER['HTTP_HOST'])) {
    http_response_code(403);
    die('Direct access forbidden');
}

// Security headers
header('Content-Type: application/json; charset=UTF-8');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('X-XSS-Protection: 1; mode=block');
header('Referrer-Policy: strict-origin-when-cross-origin');
header('Content-Security-Policy: default-src \'none\'; frame-ancestors \'none\';');

// CORS configuration
$allowed_origins = [
    isset($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : '',
    'localhost',
    '127.0.0.1'
];

$origin = isset($_SERVER['HTTP_ORIGIN']) ? $_SERVER['HTTP_ORIGIN'] : (isset($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : '');
$origin_host = parse_url($origin, PHP_URL_HOST);
if ($origin_host === false) {
    $origin_host = $origin;
}

if (in_array($origin_host, $allowed_origins, true) || 
    preg_match('/^(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/', $origin_host)) {
    header('Access-Control-Allow-Origin: ' . $origin);
} else {
    header('Access-Control-Allow-Origin: null');
}

header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-Requested-With, X-CSRF-Token');
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Max-Age: 86400');

// Session and rate limiting
if (session_status() === PHP_SESSION_NONE) {
    session_start();
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

if (isset($_SESSION[$rate_limit_key]['count']) && $_SESSION[$rate_limit_key]['count'] >= 100) {
    http_response_code(429);
    die(json_encode(['error' => 'Rate limit exceeded']));
}

if (isset($_SESSION[$rate_limit_key]['count'])) {
    $_SESSION[$rate_limit_key]['count']++;
}

// Handle preflight requests
if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    die();
}

// Only allow GET requests
if (!isset($_SERVER['REQUEST_METHOD']) || $_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    die(json_encode(['error' => 'Method not allowed']));
}

// Load Router and Controllers
require_once __DIR__ . '/classes/Router.php';
require_once __DIR__ . '/classes/BaseController.php';
require_once __DIR__ . '/classes/SystemCommand.php';

// Parse request path
$request_uri = isset($_SERVER['REQUEST_URI']) ? $_SERVER['REQUEST_URI'] : '';
$endpoint_param = isset($_GET['endpoint']) ? trim($_GET['endpoint']) : '';
$endpoint_param = preg_replace('/[^a-zA-Z0-9\/\-_]/', '', $endpoint_param);

if (!empty($endpoint_param)) {
    $path = '/' . ltrim($endpoint_param, '/');
    $path = rtrim($path, '/');
} else {
    $path = parse_url($request_uri, PHP_URL_PATH);
    if ($path !== false) {
        $path = str_replace('/api', '', $path);
        $path = rtrim($path, '/');
    }
}

// Validate path
if (!Router::validatePath($path)) {
    http_response_code(400);
    error_log("API Security: Suspicious path - " . substr($path, 0, 100) . " - IP: " . $client_ip);
    die(json_encode(['error' => 'Invalid path']));
}

// Initialize router
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
require_once __DIR__ . '/controllers/SecurityController.php';
require_once __DIR__ . '/controllers/SystemController.php';
require_once __DIR__ . '/controllers/ServicesController.php';
require_once __DIR__ . '/controllers/SitesController.php';
require_once __DIR__ . '/controllers/ActivityController.php';
require_once __DIR__ . '/controllers/ToolsController.php';
require_once __DIR__ . '/controllers/MonitoringController.php';
require_once __DIR__ . '/controllers/ExternalServicesController.php';

// Dispatch request
$router->dispatch('GET', $path);
