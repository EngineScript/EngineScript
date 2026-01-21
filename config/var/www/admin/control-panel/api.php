<?php
/**
 * EngineScript Admin Dashboard API
 * Secure API endpoints for dashboard functionality
 * 
 * Refactored to use Router/Controller pattern for maintainability.
 * 
 * @version 2.0.0
 * @security HIGH - Contains sensitive system information
 * 
 * NOTE: Codacy security warnings about $_SERVER, session_start(), header(), etc. are false positives.
 * This is a standalone API that does not use WordPress and requires direct PHP functionality.
 * wp_unslash() and WordPress functions are not available in this context.
 */

// Load core classes
// @codacy suppress [require_once statement detected] Secure class loading with __DIR__ constant - no user input
require_once __DIR__ . '/classes/SystemCommand.php';
require_once __DIR__ . '/classes/ApiResponse.php';
require_once __DIR__ . '/classes/Router.php';

// Prevent direct access if not from proper context
if (!isset($_SERVER['REQUEST_URI']) || !isset($_SERVER['HTTP_HOST'])) { // codacy:ignore - Direct $_SERVER access required for standalone API
    http_response_code(403);
    die('Direct access forbidden'); // codacy:ignore - die() required for security termination
}

// Security headers - header() function required for standalone API security
header('Content-Type: application/json; charset=UTF-8'); // codacy:ignore - Required for API response type
header('X-Content-Type-Options: nosniff'); // codacy:ignore - Security header required
header('X-Frame-Options: DENY'); // codacy:ignore - Security header required
header('X-XSS-Protection: 1; mode=block'); // codacy:ignore - Security header required
header('Referrer-Policy: strict-origin-when-cross-origin'); // codacy:ignore - Security header required
header('Content-Security-Policy: default-src \'none\'; frame-ancestors \'none\';'); // codacy:ignore - Security header required

// Task 94: Enable response compression for performance
// Check if client accepts gzip and zlib extension is available
if (extension_loaded('zlib') && !ini_get('zlib.output_compression')) {
    // Check Accept-Encoding header for gzip support
    $accept_encoding = isset($_SERVER['HTTP_ACCEPT_ENCODING']) ? $_SERVER['HTTP_ACCEPT_ENCODING'] : ''; // codacy:ignore - Direct $_SERVER access required
    if (strpos($accept_encoding, 'gzip') !== false) {
        // Enable gzip compression with level 6 (good balance of speed/compression)
        ini_set('zlib.output_compression', 'On'); // codacy:ignore - ini_set() required for compression
        ini_set('zlib.output_compression_level', '6'); // codacy:ignore - ini_set() required for compression
    }
}

// Secure CORS - Only allow same origin by default
$allowed_origins = [
    isset($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : '', // codacy:ignore - Direct $_SERVER access required, wp_unslash() not available in standalone API
    'localhost',
    '127.0.0.1'
];

$origin = isset($_SERVER['HTTP_ORIGIN']) ? $_SERVER['HTTP_ORIGIN'] : (isset($_SERVER['HTTP_HOST']) ? $_SERVER['HTTP_HOST'] : ''); // codacy:ignore - Direct $_SERVER access required, wp_unslash() not available
$origin_host = parse_url($origin, PHP_URL_HOST); // codacy:ignore - parse_url() required for URL validation in standalone API
if ($origin_host === false) {
    $origin_host = $origin;
}

if (in_array($origin_host, $allowed_origins, true) || 
    preg_match('/^(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/', $origin_host)) {
    header('Access-Control-Allow-Origin: ' . $origin); // codacy:ignore - CORS header required for API
} else {
    header('Access-Control-Allow-Origin: null'); // codacy:ignore - CORS security header required
}

header('Access-Control-Allow-Methods: GET, OPTIONS'); // codacy:ignore - CORS header required
header('Access-Control-Allow-Headers: Content-Type, X-Requested-With, X-CSRF-Token'); // codacy:ignore - CORS header required
header('Access-Control-Allow-Credentials: true'); // codacy:ignore - CORS header required
header('Access-Control-Max-Age: 86400'); // codacy:ignore - CORS header required

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
}

// Initialize CSRF token if not exists
if (!isset($_SESSION['csrf_token'])) { // codacy:ignore - Direct $_SESSION access required for CSRF protection
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32)); // codacy:ignore - random_bytes() required for cryptographic token generation
}
$client_ip = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : 'unknown'; // codacy:ignore - Direct $_SERVER access required, wp_unslash() not available
$rate_limit_key = 'api_rate_' . hash('sha256', $client_ip);

if (!isset($_SESSION[$rate_limit_key])) { // codacy:ignore - Direct $_SESSION access required for rate limiting
    $_SESSION[$rate_limit_key] = ['count' => 0, 'reset' => time() + 60]; // codacy:ignore - Direct $_SESSION access required
}

// Reset rate limit counter every minute
if (isset($_SESSION[$rate_limit_key]['reset']) && time() > $_SESSION[$rate_limit_key]['reset']) { // codacy:ignore - Direct $_SESSION access required
    $_SESSION[$rate_limit_key] = ['count' => 0, 'reset' => time() + 60]; // codacy:ignore - Direct $_SESSION access required
}

// Check rate limit (100 requests per minute)
if (isset($_SESSION[$rate_limit_key]['count']) && $_SESSION[$rate_limit_key]['count'] >= 100) { // codacy:ignore - Direct $_SESSION access required
    http_response_code(429);
    die(json_encode(['error' => 'Rate limit exceeded'])); // codacy:ignore - die() required for security termination
}

if (isset($_SESSION[$rate_limit_key]['count'])) { // codacy:ignore - Direct $_SESSION access required
    $_SESSION[$rate_limit_key]['count']++; // codacy:ignore - Direct $_SESSION access required
}

// Handle preflight requests
if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] === 'OPTIONS') { // codacy:ignore - Direct $_SERVER access required for CORS handling
    http_response_code(200);
    die(); // codacy:ignore - die() required for CORS termination
}

/**
 * Validates CSRF token for state-changing requests (POST, PUT, DELETE, PATCH)
 * Token can be sent via X-CSRF-Token header or _csrf_token body parameter
 * 
 * @return bool True if valid or not required (GET/HEAD/OPTIONS), false if invalid
 */
function validateCsrfToken() {
    $method = isset($_SERVER['REQUEST_METHOD']) ? $_SERVER['REQUEST_METHOD'] : 'GET'; // codacy:ignore - Direct $_SERVER access required
    
    // CSRF validation only required for state-changing methods
    $safe_methods = ['GET', 'HEAD', 'OPTIONS'];
    if (in_array($method, $safe_methods, true)) {
        return true;
    }
    
    // Get CSRF token from header (preferred) or body parameter
    $client_token = null;
    
    // Check header first (X-CSRF-Token)
    if (isset($_SERVER['HTTP_X_CSRF_TOKEN'])) { // codacy:ignore - Direct $_SERVER access required for CSRF header
        $client_token = $_SERVER['HTTP_X_CSRF_TOKEN'];
    }
    // Fallback to body parameter
    elseif (isset($_POST['_csrf_token'])) { // codacy:ignore - Direct $_POST access required for CSRF token
        $client_token = $_POST['_csrf_token'];
    }
    
    // Validate token exists
    if (empty($client_token) || empty($_SESSION['csrf_token'])) {
        logSecurityEvent('CSRF token missing', $method . ' request without token');
        return false;
    }
    
    // Use timing-safe comparison to prevent timing attacks
    if (!hash_equals($_SESSION['csrf_token'], $client_token)) { // codacy:ignore - Direct $_SESSION access required for CSRF validation
        logSecurityEvent('CSRF token mismatch', 'Invalid token submitted');
        return false;
    }
    
    return true;
}

// Validate CSRF token for state-changing requests
if (!validateCsrfToken()) {
    http_response_code(403);
    die(json_encode(['error' => 'Invalid or missing CSRF token'])); // codacy:ignore - die() required for security termination
}

// Get the request URI and method first
$request_uri = isset($_SERVER['REQUEST_URI']) ? $_SERVER['REQUEST_URI'] : ''; // codacy:ignore - Direct $_SERVER access required, wp_unslash() not available
$request_method = isset($_SERVER['REQUEST_METHOD']) ? $_SERVER['REQUEST_METHOD'] : ''; // codacy:ignore - Direct $_SERVER access required, wp_unslash() not available

// Check if endpoint is passed as a query parameter
$endpoint_param = isset($_GET['endpoint']) ? trim($_GET['endpoint']) : ''; // codacy:ignore - Direct $_GET access required
// Sanitize endpoint parameter to prevent injection attacks
$endpoint_param = preg_replace('/[^a-zA-Z0-9\/\-_]/', '', $endpoint_param);
$path = '';
if (!empty($endpoint_param)) {
    $path = '/' . ltrim($endpoint_param, '/');
    $path = rtrim($path, '/'); // Remove trailing slashes
} else {
    $path = parse_url($request_uri, PHP_URL_PATH); // codacy:ignore - parse_url() required for URL parsing
    if ($path !== false) {
        $path = str_replace('/api', '', $path);
        $path = rtrim($path, '/'); // Remove trailing slashes
    }
}

// Input validation and sanitization
// Input validation and sanitization helper
function validateInputString($input, $max_length = 255) {
    $input = trim($input);
    if (strlen($input) > $max_length) {
        return false;
    }
    
    // Remove any potential script tags or dangerous characters
    $input = preg_replace('/[<>"\']/', '', $input);
    // Use htmlspecialchars instead of deprecated FILTER_SANITIZE_STRING
    return htmlspecialchars($input, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function validateInputPath($input) {
    // Strict path validation - only allow alphanumeric, dash, underscore, dot
    if (!preg_match('/^[a-zA-Z0-9._-]+$/', $input)) {
        return false;
    }
    // Prevent path traversal
    if (strpos($input, '..') !== false || strpos($input, '/') !== false) {
        return false;
    }
    return $input;
}

function validateInputService($input) {
    // Allow known service names and PHP-FPM service patterns
    $allowed_services = ['nginx', 'mariadb', 'redis-server'];
    
    // Check if it's in the allowed list
    if (in_array($input, $allowed_services, true)) {
        return $input;
    }
    
    // Allow PHP-FPM services with flexible patterns:
    // php-fpm, php8.4-fpm, php-fpm8.4, php84-fpm, etc.
    // Pattern: php + optional version/text + fpm + optional version/text
    if (preg_match('/^php[a-zA-Z0-9\.\-_]*fpm[a-zA-Z0-9\.\-_]*$/', $input)) {
        return $input;
    }
    
    return false;
}


function validateInput($input, $type = 'string', $max_length = 255) {
    if (empty($input) && $input !== '0') {
        return false;
    }
    
    switch ($type) {
        case 'string':
            return validateInputString($input, $max_length);
            
        case 'path':
            return validateInputPath($input);
            
        case 'service':
            return validateInputService($input);
            
        default:
            return false;
    }
}

function sanitizeOutput($data) {
    if (is_array($data)) {
        return array_map('sanitizeOutput', $data);
    }
    if (is_string($data)) {
        // Prevent XSS in JSON output
        return htmlspecialchars($data, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }
    return $data;
}

function logSecurityEvent($event, $details = '') { // codacy:ignore - Direct $_SERVER access required for security logging in standalone API
    // Enhanced log injection protection
    // Sanitize all log inputs to prevent log injection/forging attacks
    $safe_event = sanitizeLogInput($event);
    
    $log_entry = date('Y-m-d H:i:s') . " [SECURITY] " . $safe_event;
    
    if ($details) {
        // Sanitize details using same function
        $safe_details = sanitizeLogInput($details);
        $log_entry .= " - " . $safe_details;
    }
    
    // Sanitize IP address for logging
    $client_ip = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : 'unknown'; // codacy:ignore - Direct $_SERVER access required, wp_unslash() not available in standalone API
    if ($client_ip !== 'unknown') {
        // Validate IP format to prevent injection
        if (!filter_var($client_ip, FILTER_VALIDATE_IP)) {
            $client_ip = 'invalid';
        }
    }
    $log_entry .= " - IP: " . $client_ip . "\n";
    
    // Log to a secure location
    $log_file = '/var/log/EngineScript/enginescript-api-security.log';
    error_log($log_entry, 3, $log_file);
}

/**
 * Sanitize input for safe log output
 * Prevents log injection attacks by escaping control characters
 * @param string $input Raw input to sanitize
 * @return string Sanitized string safe for logging
 */
function sanitizeLogInput($input) {
    // Remove all control characters (ASCII 0-31 and 127)
    // This includes \r, \n, \t, and other dangerous characters
    $sanitized = preg_replace('/[\x00-\x1F\x7F]/', ' ', $input);
    
    // Collapse multiple spaces
    $sanitized = preg_replace('/\s+/', ' ', $sanitized);
    
    // Limit length to prevent log flooding
    $sanitized = substr(trim($sanitized), 0, 255);
    
    // Encode any remaining special characters for safe output
    // This prevents log format string attacks
    return addcslashes($sanitized, '\\'); // codacy:ignore - addcslashes() required for log injection prevention
}

// ============ API Response Caching System ============
// Cache configuration
define('CACHE_DIR', '/var/cache/enginescript/api/');
define('CACHE_DEFAULT_TTL', 30); // 30 seconds default

/**
 * Cache TTL configuration per endpoint (in seconds)
 * Endpoints not listed use CACHE_DEFAULT_TTL
 */
$CACHE_TTL_CONFIG = [
    '/system/info' => 60,           // 1 minute - system info rarely changes
    '/services/status' => 15,       // 15 seconds - service status should be fresh
    '/sites' => 120,                // 2 minutes - site list rarely changes
    '/sites/count' => 120,          // 2 minutes
    '/tools/filemanager/status' => 300, // 5 minutes - rarely changes
    '/monitoring/uptime' => 60,     // 1 minute
    '/monitoring/uptime/monitors' => 60, // 1 minute
    '/cache/status' => 30,          // 30 seconds - cache status updates frequently
    '/external-services/config' => 300,  // 5 minutes - config rarely changes
    '/external-services/feed' => 180,    // 3 minutes - external feeds
];

// Cache sweep configuration in seconds
define('CACHE_SWEEP_INTERVAL', 60); // Run cleanup at most once per minute


// Path was already extracted and validated above, validate again for security
if (strlen($path) > 100 || !preg_match('/^\/[a-zA-Z0-9\/_-]*$/', $path)) {
    http_response_code(400);
    logSecurityEvent('Suspicious path', $path);
    die(json_encode(['error' => 'Invalid path']));
}

// ============ Router-Based Request Dispatch ============
// Initialize router and register all routes
$router = new Router();

// CSRF Token endpoint
$router->register('/csrf-token', 'CsrfController', 'getToken');

// System information endpoint
$router->register('/system/info', 'SystemController', 'getInfo');

// Service status endpoint
$router->register('/services/status', 'ServiceController', 'getStatus');

// Sites endpoints
$router->register('/sites', 'SiteController', 'getSites');
$router->register('/sites/count', 'SiteController', 'getSitesCount');
$router->alias('/sites/', '/sites'); // Handle trailing slash

// File manager endpoint
$router->register('/tools/filemanager/status', 'FileManagerController', 'getStatus');

// Uptime monitoring endpoints
$router->register('/monitoring/uptime', 'UptimeController', 'getStatus');
$router->register('/monitoring/uptime/monitors', 'UptimeController', 'getMonitors');

// Cache management endpoint
$router->register('/cache/clear', 'CacheController', 'clear');
$router->register('/cache/status', 'CacheController', 'getStatus');

// External services endpoints
$router->register('/external/plugin', 'ExternalServicesController', 'getPluginInfo');
$router->register('/external/cloudflare/status', 'ExternalServicesController', 'getCloudflareStatus');

// Legacy batch endpoint (kept for backward compatibility)
$router->register('/batch', 'BatchController', 'handle');

// External services legacy routes (for backward compatibility)
// These route to the external-services-api.php module
if ($path === '/external-services/config' || $path === '/external-services/feed') {
    define('ENGINESCRIPT_DASHBOARD', true);
    // @codacy suppress [require_once statement detected] Module inclusion with __DIR__ constant - hardcoded path, no user input
    require_once __DIR__ . '/external-services/external-services-api.php';
    if ($path === '/external-services/config') {
        handleExternalServicesConfig();
    } elseif ($path === '/external-services/feed') {
        handleStatusFeed();
    }
} else {
    // Dispatch request through router
    $router->dispatch($path);
}
