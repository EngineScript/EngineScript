<?php
/**
 * EngineScript Admin Dashboard API
 * Secure API endpoints for dashboard functionality
 * 
 * @version 1.0.0
 * @security HIGH - Contains sensitive system information
 * 
 * NOTE: Codacy security warnings about $_SERVER, session_start(), header(), etc. are false positives.
 * This is a standalone API that does not use WordPress and requires direct PHP functionality.
 * wp_unslash() and WordPress functions are not available in this context.
 */

// Load SystemCommand class for secure shell execution
// @codacy suppress [require_once statement detected] Secure class loading with __DIR__ constant - no user input
require_once __DIR__ . '/classes/SystemCommand.php';

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
    ini_set('session.cookie_secure', '1');     // Only send cookie over HTTPS
    ini_set('session.cookie_httponly', '1');   // Prevent JavaScript access to session cookie
    ini_set('session.cookie_samesite', 'Strict'); // Prevent CSRF via cookie
    ini_set('session.use_strict_mode', '1');   // Reject uninitialized session IDs
    ini_set('session.use_only_cookies', '1');  // Only use cookies for session ID
    
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

function getPhpServiceStatus() {
    // Dynamically find any running PHP-FPM service
    $php_service = findActivePhpFpmService();
    if ($php_service) {
        return getServiceStatus($php_service);
    }
    
    // Fallback: return offline status if no PHP-FPM service found
    return [
        'status' => 'offline',
        'version' => 'Not Found',
        'online' => false
    ];
}

function findActivePhpFpmService() {
    // Use systemctl to find any active PHP-FPM service
    // This approach is more flexible and works with any PHP version
    $services_output = SystemCommand::getSystemdServices(); // codacy:ignore - Static utility class pattern
    
    if ($services_output === false || empty($services_output)) {
        return null;
    }
    
    // Parse services in PHP for better security control
    $lines = explode("\n", trim($services_output));
    foreach ($lines as $line) {
        if (empty(trim($line))) {
            continue;
        }
        
        // Extract service name (first column) with additional safety checks
        $parts = preg_split('/\s+/', trim($line));
        if (empty($parts[0]) || strlen($parts[0]) > 50) { // Prevent excessively long service names
            continue;
        }
        
        $service_name = $parts[0];
        
        // Additional security: ensure service name contains only allowed characters
        if (!preg_match('/^[a-zA-Z0-9\.\-_]+$/', $service_name)) {
            continue;
        }
        
        // Remove .service suffix if present
        $service_name = preg_replace('/\.service$/', '', $service_name);
        
        // Check if it contains both "php" and "fpm" (case insensitive)
        // This matches: php-fpm, php8.4-fpm, php-fpm8.4, php84-fpm, phpfpm, etc.
        if (stripos($service_name, 'php') !== false && stripos($service_name, 'fpm') !== false) {
            // Validate the service name matches our flexible pattern for PHP-FPM services
            // Pattern allows: php[version]fpm or php-fpm[version] or any combination
            // Examples: php-fpm, php8.4-fpm, php-fpm8.4, php84-fpm, phpfpm84
            if (preg_match('/^php[a-zA-Z0-9\.\-_]*fpm[a-zA-Z0-9\.\-_]*$/', $service_name)) {
                // Double-check that it's actually active before returning
                $status = getSystemServiceStatus($service_name);
                if ($status === 'active') {
                    return $service_name;
                }
            }
        }
    }
    
    return null;
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
    return addcslashes($sanitized, '\\');
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
    '/activity/recent' => 30,       // 30 seconds
    '/alerts' => 30,                // 30 seconds
    '/tools/filemanager/status' => 300, // 5 minutes - rarely changes
    '/monitoring/uptime' => 60,     // 1 minute
    '/monitoring/uptime/monitors' => 60, // 1 minute
    '/external-services/config' => 300,  // 5 minutes - config rarely changes
    '/external-services/feed' => 180,    // 3 minutes - external feeds
];

// Cache sweep configuration in seconds
define('CACHE_SWEEP_INTERVAL', 60); // Run cleanup at most once per minute

/**
 * Periodic cache sweeping to remove expired files
 * Runs at most once every CACHE_SWEEP_INTERVAL seconds to reduce IO overhead
 */
function sweepCache() {
    $lockFile = CACHE_DIR . '.sweep_lock';
    $now = time();

    if (!is_dir(CACHE_DIR)) return;

    // Attempt to obtain a non-blocking lock; if not possible, skip sweep
    $fp = @fopen($lockFile, 'c');
    if ($fp === false) return;
    $gotLock = flock($fp, LOCK_EX | LOCK_NB);
    if (!$gotLock) {
        fclose($fp);
        return;
    }

    // Read last sweep time
    $lastSweep = 0;
    $contents = @file_get_contents($lockFile);
    if ($contents !== false) {
        $lastSweep = intval($contents);
    }
    if ($now - $lastSweep < CACHE_SWEEP_INTERVAL) {
        // Not time yet
        flock($fp, LOCK_UN);
        fclose($fp);
        return;
    }

    // Update lock file with now; keep exclusive lock while sweeping
    ftruncate($fp, 0);
    rewind($fp);
    fwrite($fp, (string)$now);
    fflush($fp);

    // Scan cache files and remove expired ones (limit to 200 deletions per sweep)
    $deleted = 0;
    $maxDeletes = 200;
    global $CACHE_TTL_CONFIG;
    foreach (glob(CACHE_DIR . '*.json') as $cacheFile) {
        if ($deleted >= $maxDeletes) break;
        $raw = @file_get_contents($cacheFile);
        if ($raw === false) continue;
        $data = json_decode($raw, true);
        if (!$data || !isset($data['timestamp'])) {
            @unlink($cacheFile);
            $deleted++;
            continue;
        }
        $endpoint = isset($data['endpoint']) ? $data['endpoint'] : '';
        $timestamp = intval($data['timestamp']);
        $ttl = isset($CACHE_TTL_CONFIG[$endpoint]) ? $CACHE_TTL_CONFIG[$endpoint] : CACHE_DEFAULT_TTL;
        if ($now - $timestamp > $ttl) {
            @unlink($cacheFile);
            $deleted++;
        }
    }

    // Release lock
    flock($fp, LOCK_UN);
    fclose($fp);
}


/**
 * Get cache file path for an endpoint
 * @param string $endpoint The API endpoint
 * @param array $params Optional query parameters for cache key
 * @return string Cache file path
 */
function getCacheFilePath($endpoint, $params = []) {
    // Create cache key from endpoint and params
    $cache_key = $endpoint;
    if (!empty($params)) {
        ksort($params);
        $cache_key .= '_' . md5(json_encode($params));
    }
    
    // Sanitize cache key for filesystem
    $safe_key = preg_replace('/[^a-zA-Z0-9_-]/', '_', $cache_key);
    return CACHE_DIR . $safe_key . '.json';
}

/**
 * Get cached response if valid
 * @param string $endpoint The API endpoint
 * @param array $params Optional query parameters
 * @return array|null Cached data or null if not found/expired
 */
function getCachedResponse($endpoint, $params = []) {
    global $CACHE_TTL_CONFIG;
    
    $cache_file = getCacheFilePath($endpoint, $params);
    
    if (!file_exists($cache_file)) {
        return null;
    }
    
    $cache_data = json_decode(file_get_contents($cache_file), true);
    if (!$cache_data || !isset($cache_data['timestamp']) || !isset($cache_data['data'])) {
        return null;
    }
    
    // Get TTL for this endpoint
    $ttl = isset($CACHE_TTL_CONFIG[$endpoint]) ? $CACHE_TTL_CONFIG[$endpoint] : CACHE_DEFAULT_TTL;
    
    // Check if cache is still valid
    if (time() - $cache_data['timestamp'] > $ttl) {
        // Cache expired
        @unlink($cache_file);
        return null;
    }
    
    return $cache_data['data'];
}

/**
 * Store response in cache
 * @param string $endpoint The API endpoint
 * @param mixed $data The response data to cache
 * @param array $params Optional query parameters
 * @return bool Success status
 */
function setCachedResponse($endpoint, $data, $params = []) {
    // Ensure cache directory exists
    if (!is_dir(CACHE_DIR)) {
        @mkdir(CACHE_DIR, 0755, true);
    }
    
    $cache_file = getCacheFilePath($endpoint, $params);
    $cache_data = [
        'timestamp' => time(),
        'endpoint' => $endpoint,
        'data' => $data
    ];
    
    return @file_put_contents($cache_file, json_encode($cache_data), LOCK_EX) !== false;
}

/**
 * Clear cache for a specific endpoint or all caches
 * @param string|null $endpoint Optional endpoint to clear, null clears all
 */
function clearCache($endpoint = null) {
    if (!is_dir(CACHE_DIR)) {
        return;
    }
    
    if ($endpoint === null) {
        // Clear all cache files
        $files = glob(CACHE_DIR . '*.json');
        foreach ($files as $file) {
            @unlink($file);
        }
    } else {
        // Clear specific endpoint cache
        $safe_key = preg_replace('/[^a-zA-Z0-9_-]/', '_', $endpoint);
        $files = glob(CACHE_DIR . $safe_key . '*.json');
        foreach ($files as $file) {
            @unlink($file);
        }
    }
}

/**
 * Output cached response with cache headers
 * @param mixed $data The cached data
 * @param int $ttl Time-to-live in seconds
 */
function outputCachedResponse($data, $ttl) {
    header('X-Cache: HIT');
    header('Cache-Control: private, max-age=' . $ttl);
    echo json_encode($data);
}

// ============ Batch API Request Handler ============

/**
 * Allowed endpoints for batch requests
 * Only GET endpoints that return JSON are allowed
 */
$BATCH_ALLOWED_ENDPOINTS = [
    '/system/info',
    '/services/status',
    '/sites',
    '/sites/count',
    '/activity/recent',
    '/alerts',
    '/tools/filemanager/status',
    '/monitoring/uptime',
    '/monitoring/uptime/monitors',
];

/**
 * Handle batch API requests
 * Accepts POST with JSON body: { "requests": ["/endpoint1", "/endpoint2", ...] }
 * Returns: { "results": { "/endpoint1": {...}, "/endpoint2": {...} }, "errors": {...} }
 */
function handleBatchRequest() {
    global $BATCH_ALLOWED_ENDPOINTS;
    
    // Only accept POST for batch requests
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed. Use POST.']);
        return;
    }
    
    // Parse JSON body
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);
    
    if (!$data || !isset($data['requests']) || !is_array($data['requests'])) {
        http_response_code(400);
        echo json_encode(['error' => 'Invalid request. Expected JSON with "requests" array.']);
        return;
    }
    
    $requests = $data['requests'];
    
    // Limit batch size to prevent abuse
    $max_batch_size = 10;
    if (count($requests) > $max_batch_size) {
        http_response_code(400);
        echo json_encode(['error' => "Batch size exceeds maximum of $max_batch_size requests."]);
        return;
    }
    
    $results = [];
    $errors = [];
    
    foreach ($requests as $endpoint) {
        // Validate endpoint
        if (!is_string($endpoint)) {
            $errors[] = ['endpoint' => $endpoint, 'error' => 'Invalid endpoint type'];
            continue;
        }
        
        // Sanitize and validate endpoint
        $clean_endpoint = preg_replace('/[^a-zA-Z0-9\/_-]/', '', $endpoint);
        
        if (!in_array($clean_endpoint, $BATCH_ALLOWED_ENDPOINTS, true)) {
            $errors[$endpoint] = 'Endpoint not allowed in batch requests';
            continue;
        }
        
        // Check cache first
        $cached = getCachedResponse($clean_endpoint);
        if ($cached !== null) {
            $results[$clean_endpoint] = $cached;
            continue;
        }
        
        // Execute the endpoint handler
        try {
            ob_start();
            
            switch ($clean_endpoint) {
                case '/system/info':
                    handleSystemInfo();
                    break;
                case '/services/status':
                    handleServicesStatus();
                    break;
                case '/sites':
                    handleSites();
                    break;
                case '/sites/count':
                    handleSitesCount();
                    break;
                case '/activity/recent':
                    handleRecentActivity();
                    break;
                case '/alerts':
                    handleAlerts();
                    break;
                case '/tools/filemanager/status':
                    handleFileManagerStatus();
                    break;
                case '/monitoring/uptime':
                    handleUptimeStatus();
                    break;
                case '/monitoring/uptime/monitors':
                    handleUptimeMonitors();
                    break;
            }
            
            $output = ob_get_clean();
            $result = json_decode($output, true);
            
            if ($result !== null) {
                $results[$clean_endpoint] = $result;
                // Cache the result
                setCachedResponse($clean_endpoint, $result);
            } else {
                $errors[$clean_endpoint] = 'Failed to parse response';
            }
        } catch (Exception $e) {
            ob_end_clean();
            $errors[$clean_endpoint] = 'Internal error';
            logSecurityEvent('Batch request error', $clean_endpoint . ': ' . $e->getMessage());
        }
    }
    
    echo json_encode([
        'results' => $results,
        'errors' => $errors,
        'cached_count' => count(array_filter($results, function($r) { return $r !== null; }))
    ]);
}

/**
 * Handle cache clearing requests (admin-only)
 * Accepts POST with JSON body: { "endpoint": "/services/status" } or no body to clear all
 */
function handleCacheClear() {
    // Only accept POST
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed. Use POST.']);
        return;
    }

    // Check CSRF token
    if (!validateCsrfToken()) {
        http_response_code(403);
        echo json_encode(['error' => 'Invalid CSRF token']);
        return;
    }

    // Basic authentication check (if using HTTP auth via nginx)
    if (!isset($_SERVER['REMOTE_USER'])) {
        http_response_code(403);
        echo json_encode(['error' => 'Unauthorized']);
        return;
    }

    $input = json_decode(file_get_contents('php://input'), true);
    $endpoint = null;
    if (is_array($input) && isset($input['endpoint']) && is_string($input['endpoint'])) {
        $endpoint = preg_replace('/[^a-zA-Z0-9\/_-]/', '', $input['endpoint']);
    }

    try {
        if ($endpoint) {
            clearCache($endpoint);
            echo json_encode(['result' => 'ok', 'cleared' => $endpoint]);
        } else {
            clearCache(null);
            echo json_encode(['result' => 'ok', 'cleared' => 'all']);
        }
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Cache clear error', $e->getMessage());
        echo json_encode(['error' => 'Failed to clear cache']);
    }
}

// Path was already extracted and validated above, validate again for security
if (strlen($path) > 100 || !preg_match('/^\/[a-zA-Z0-9\/_-]*$/', $path)) {
    http_response_code(400);
    logSecurityEvent('Suspicious path', $path);
    die(json_encode(['error' => 'Invalid path']));
}

// Periodic cache sweep (non-blocking and rate-limited)
if (function_exists('sweepCache')) {
    sweepCache();
}

// Route handling
switch ($path) {
    case '/csrf-token':
        handleCsrfToken();
        break;
    
    case '/batch':
        handleBatchRequest();
        break;
    
    case '/system/info':
        handleSystemInfo();
        break;
    
    case '/services/status':
        handleServicesStatus();
        break;
    
    case '/sites':
    case '/sites/':
        handleSites();
        break;
    
    case '/sites/count':
        handleSitesCount();
        break;
    
    case '/activity/recent':
        handleRecentActivity();
        break;
    
    case '/alerts':
    case '/alerts/':
        handleAlerts();
        break;
    
    case '/tools/filemanager/status':
        handleFileManagerStatus();
        break;
    
    case '/monitoring/uptime':
        handleUptimeStatus();
        break;
    
    case '/monitoring/uptime/monitors':
        handleUptimeMonitors();
        break;
    
    case '/external-services/config':
    case '/external-services/feed':
        // Route to external services API module
        define('ENGINESCRIPT_DASHBOARD', true);
        // @codacy suppress [require_once statement detected] Module inclusion with __DIR__ constant - hardcoded path, no user input
        require_once __DIR__ . '/external-services/external-services-api.php';
        if ($path === '/external-services/config') {
            handleExternalServicesConfig();
        } elseif ($path === '/external-services/feed') {
            handleStatusFeed();
        }
        break;
    
    case '/cache/clear':
        handleCacheClear();
        break;
    
    default:
        http_response_code(404);
        // Sanitize path for logging to prevent injection attacks
        $sanitized_path = preg_replace('/[^a-zA-Z0-9\/\-_.]/', '', $path);
        error_log("API 404 - Path not matched: " . $sanitized_path);
        echo json_encode(['error' => 'Endpoint not found']); // codacy:ignore - echo required for JSON API response
        break;
}

function handleCsrfToken() {
    try {
        // Return the current CSRF token
        if (isset($_SESSION['csrf_token'])) { // codacy:ignore - Direct $_SESSION access required for CSRF token response
            echo json_encode([
                'csrf_token' => $_SESSION['csrf_token'], // codacy:ignore - Direct $_SESSION access required for CSRF token response
                'token_name' => '_csrf_token'
            ]); // codacy:ignore - echo required for JSON API response
        } else {
            http_response_code(500);
            echo json_encode(['error' => 'Unable to generate CSRF token']); // codacy:ignore - echo required for JSON API response
        }
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('CSRF token error', $e->getMessage());
        echo json_encode(['error' => 'Unable to generate CSRF token']); // codacy:ignore - echo required for JSON API response
    }
}



function handleSystemInfo() {
    global $CACHE_TTL_CONFIG;
    
    try {
        // Check cache first
        $cached = getCachedResponse('/system/info');
        if ($cached !== null) {
            $ttl = isset($CACHE_TTL_CONFIG['/system/info']) ? $CACHE_TTL_CONFIG['/system/info'] : CACHE_DEFAULT_TTL;
            outputCachedResponse($cached, $ttl);
            return;
        }
        
        $info = [
            'os' => getOsInfo(),
            'kernel' => getKernelVersion(),
            'network' => getNetworkInfo()
        ];
        
        $result = sanitizeOutput($info);
        
        // Cache the result
        setCachedResponse('/system/info', $result);
        
        header('X-Cache: MISS');
        echo json_encode($result); // codacy:ignore - echo required for JSON API response
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('System info error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve system info']); // codacy:ignore - echo required for JSON API response
    }
}











function handleServicesStatus() {
    global $CACHE_TTL_CONFIG;
    
    try {
        // Check cache first
        $cached = getCachedResponse('/services/status');
        if ($cached !== null) {
            $ttl = isset($CACHE_TTL_CONFIG['/services/status']) ? $CACHE_TTL_CONFIG['/services/status'] : CACHE_DEFAULT_TTL;
            outputCachedResponse($cached, $ttl);
            return;
        }
        
        $services = [
            'nginx' => getServiceStatus('nginx'),
            'php' => getPhpServiceStatus(),
            'mysql' => getServiceStatus('mariadb'),
            'redis' => getServiceStatus('redis-server')
        ];
        
        $result = sanitizeOutput($services);
        
        // Cache the result
        setCachedResponse('/services/status', $result);
        
        header('X-Cache: MISS');
        echo json_encode($result); // codacy:ignore - echo required for JSON API response
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Services status error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve services status']); // codacy:ignore - echo required for JSON API response
    }
}

function handleSites() {
    try {
        echo json_encode(sanitizeOutput(getWordPressSites())); // codacy:ignore - echo required for JSON API response
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Sites error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve sites']); // codacy:ignore - echo required for JSON API response
    }
}

function handleSitesCount() {
    try {
        $sites = getWordPressSites();
        echo json_encode(['count' => count($sites)]); // codacy:ignore - echo required for JSON API response
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Sites count error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve sites count']); // codacy:ignore - echo required for JSON API response
    }
}

function handleRecentActivity() {
    try {
        echo json_encode(sanitizeOutput(getRecentActivity())); // codacy:ignore - echo required for JSON API response
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Recent activity error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve recent activity']); // codacy:ignore - echo required for JSON API response
    }
}

function handleAlerts() {
    try {
        echo json_encode(sanitizeOutput(getSystemAlerts())); // codacy:ignore - echo required for JSON API response
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Alerts error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve alerts']); // codacy:ignore - echo required for JSON API response
    }
}

function handleFileManagerStatus() {
    try {
        // Load EngineScript variables to get current version
        $current_version = 'Unknown';
        if (file_exists('/usr/local/bin/enginescript/enginescript-variables.txt')) { // codacy:ignore - file_exists() required for version checking in standalone service
            $content = file_get_contents('/usr/local/bin/enginescript/enginescript-variables.txt'); // codacy:ignore - file_get_contents() required for version reading in standalone service
            preg_match('/TINYFILEMANAGER_VER="([^"]*)"/', $content, $matches);
            if (isset($matches[1]) && !empty($matches[1])) {
                $current_version = $matches[1];
            }
        }
        
        $tfm_file = '/var/www/admin/enginescript/tinyfilemanager/tinyfilemanager.php';
        $tfm_config = '/var/www/admin/enginescript/tinyfilemanager/config.php';
        
        $status = [
            'available' => file_exists($tfm_file), // codacy:ignore - file_exists() required for status checking in standalone service
            'config_exists' => file_exists($tfm_config), // codacy:ignore - file_exists() required for status checking in standalone service
            'writable_dirs' => [
                '/var/www' => is_writable('/var/www'), // codacy:ignore - is_writable() required for permission checking in standalone service
                '/tmp' => is_writable('/tmp') // codacy:ignore - is_writable() required for permission checking in standalone service
            ],
            'url' => '/tinyfilemanager/tinyfilemanager.php',
            'version' => $current_version
        ];
        
        echo json_encode(sanitizeOutput($status)); // codacy:ignore - echo required for JSON API response
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('File manager status error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve file manager status']); // codacy:ignore - echo required for JSON API response
    }
}

function handleUptimeStatus() {
    try {
        require_once __DIR__ . '/uptimerobot.php'; // codacy:ignore - require_once needed for class loading in standalone service
        $uptime = new UptimeRobotAPI();
        
        if (!$uptime->isConfigured()) {
            echo json_encode([ // codacy:ignore - echo required for JSON API response
                'configured' => false,
                'message' => 'Uptime Robot API key not configured'
            ]);
            return;
        }
        
        $monitors = $uptime->getMonitorStatus();
        $summary = [
            'configured' => true,
            'total_monitors' => count($monitors),
            'up_monitors' => count(array_filter($monitors, function($monitor) { return $monitor['status_code'] == 2; })),
            'down_monitors' => count(array_filter($monitors, function($monitor) { return in_array($monitor['status_code'], [8, 9]); })),
            'average_uptime' => count($monitors) > 0 ? 
                round(array_sum(array_column($monitors, 'uptime_ratio')) / count($monitors), 2) : 0
        ];
        
        echo json_encode(sanitizeOutput($summary)); // codacy:ignore - echo required for JSON API response
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Uptime status error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve uptime status', 'configured' => false]); // codacy:ignore - echo required for JSON API response
    }
}

function handleUptimeMonitors() {
    try {
        require_once __DIR__ . '/uptimerobot.php'; // codacy:ignore - require_once needed for class loading in standalone service
        $uptime = new UptimeRobotAPI();
        
        if (!$uptime->isConfigured()) {
            echo json_encode([ // codacy:ignore - echo required for JSON API response
                'configured' => false,
                'monitors' => [],
                'message' => 'Uptime Robot API key not configured'
            ]);
            return;
        }
        
        $monitors = $uptime->getMonitorStatus();
        echo json_encode([ // codacy:ignore - echo required for JSON API response
            'configured' => true,
            'monitors' => sanitizeOutput($monitors)
        ]);
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Uptime monitors error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve monitors', 'configured' => false, 'monitors' => []]); // codacy:ignore - echo required for JSON API response
    }
}

// System information functions













function getOsInfo() {
    $os_release = file_get_contents('/etc/os-release'); // codacy:ignore - file_get_contents() required for OS info reading in standalone API
    if ($os_release && preg_match('/PRETTY_NAME="([^"]+)"/', $os_release, $matches)) {
        return $matches[1];
    }
    return 'Unknown Linux Distribution';
}

function getKernelVersion() {
    try {
        $version = SystemCommand::getKernelVersion(); // codacy:ignore - Static utility class pattern
        if ($version !== null) {
            $version = trim($version);
            // Validate kernel version format
            if (preg_match('/^[0-9]+\.[0-9]+\.[0-9]+/', $version)) {
                return htmlspecialchars($version, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
            }
        }
    } catch (Exception $e) {
        logSecurityEvent('Kernel version error', $e->getMessage());
    }
    return 'Unknown';
}

function getNetworkInfo() {
    try {
        $hostname = gethostname();
        if ($hostname === false) {
            $hostname = 'Unknown';
        }
        
        if ($hostname !== 'Unknown') {
            $hostname = htmlspecialchars($hostname, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        }
        
        // Use safer method to get IP
        $client_ip = 'Unknown';
        
        // Try to get IP from /proc/net/fib_trie (safer than shell commands)
        if (file_exists('/proc/net/route')) { // codacy:ignore - file_exists() required for network info reading in standalone API
            // Fallback to safer shell command with validation
            $ip_output = SystemCommand::getNetworkIP(); // codacy:ignore - Static utility class pattern
            if ($ip_output !== null) {
                $client_ip = trim($ip_output);
                // Validate the IP
                if (!filter_var($client_ip, FILTER_VALIDATE_IP)) {
                    $client_ip = 'Unknown';
                }
                
                if ($client_ip !== 'Unknown') {
                    $client_ip = htmlspecialchars($client_ip, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
                }
            }
        }
        
        return $hostname . ' (' . $client_ip . ')';
    } catch (Exception $e) {
        logSecurityEvent('Network info error', $e->getMessage());
        return 'Unknown (Unknown)';
    }
}

function getServiceStatus($service) {
    // Validate service name to prevent command injection
    $service = validateInput($service, 'service');
    if ($service === false) {
        logSecurityEvent('Invalid service name attempted', $service);
        return createErrorServiceStatus();
    }
    
    try {
        $status = getSystemServiceStatus($service);
        $version = getServiceVersion($service);
        
        return [
            'status' => $status === 'active' ? 'online' : 'offline',
            'version' => $version,
            'online' => $status === 'active'
        ];
    } catch (Exception $e) {
        logSecurityEvent('Service status error', $e->getMessage());
        return createErrorServiceStatus();
    }
}

function createErrorServiceStatus() {
    return [
        'status' => 'error',
        'version' => 'Error',
        'online' => false
    ];
}

function getSystemServiceStatus($service) {
    $status_output = SystemCommand::getServiceStatus($service); // codacy:ignore - Static utility class pattern
    return $status_output !== false ? $status_output : 'unknown';
}

function getServiceVersion($service) {
    switch ($service) {
        case 'nginx':
            return getNginxVersion();
        case 'mariadb':
            return getMariadbVersion();
        case 'redis-server':
            return getRedisVersion();
        default:
            // Check if it's any PHP-FPM service (with flexible pattern matching)
            // Matches: php-fpm, php8.4-fpm, php-fpm8.4, php84-fpm, etc.
            if (preg_match('/^php[a-zA-Z0-9\.\-_]*fpm[a-zA-Z0-9\.\-_]*$/', $service)) {
                return getPhpVersion();
            }
            return 'Unknown';
    }
}

function getNginxVersion() {
    $version_output = SystemCommand::getNginxVersion(); // codacy:ignore - Static utility class pattern
    if ($version_output !== null && preg_match('/nginx\/(\d+\.\d+\.\d+)/', $version_output, $matches)) {
        return htmlspecialchars($matches[1], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }
    return 'Unknown';
}

function getPhpVersion() {
    $version_output = SystemCommand::getPhpVersion(); // codacy:ignore - Static utility class pattern
    if ($version_output !== null && preg_match('/PHP (\d+\.\d+\.\d+)/', $version_output, $matches)) {
        return htmlspecialchars($matches[1], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }
    return 'Unknown';
}

function getMariadbVersion() {
    $version_output = SystemCommand::getMariadbVersion(); // codacy:ignore - Static utility class pattern
    if ($version_output !== null && preg_match('/mariadb.*?(\d+\.\d+\.\d+)/', $version_output, $matches)) {
        return htmlspecialchars($matches[1], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }
    return 'Unknown';
}

function getRedisVersion() {
    $version_output = SystemCommand::getRedisVersion(); // codacy:ignore - Static utility class pattern
    if ($version_output !== null && preg_match('/v=(\d+\.\d+\.\d+)/', $version_output, $matches)) {
        return htmlspecialchars($matches[1], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }
    return 'Unknown';
}

// WordPress sites discovery helpers
function validateNginxSitesPath($nginx_sites_path) {
    // Verify the path is exactly what we expect
    $real_path = realpath($nginx_sites_path); // codacy:ignore - realpath() required for path validation in standalone API
    if ($real_path !== '/etc/nginx/sites-enabled') {
        logSecurityEvent('Nginx sites path traversal attempt', $nginx_sites_path);
        return false;
    }
    
    if (!is_dir($real_path)) { // codacy:ignore - is_dir() required for directory validation in standalone API
        return false;
    }
    
    return $real_path;
}

function scanNginxConfigs($real_path) {
    $files = scandir($real_path); // codacy:ignore - scandir() required for directory listing in standalone API
    if ($files === false) {
        return false;
    }
    
    $valid_files = [];
    foreach ($files as $file) {
        if ($file === '.' || $file === '..' || $file === 'default') {
            continue;
        }
        
        // Validate filename to prevent traversal
        if (!preg_match('/^[a-zA-Z0-9._-]+$/', $file)) {
            logSecurityEvent('Suspicious nginx config filename', $file);
            continue;
        }
        
        $config_path = $real_path . '/' . $file;
        $config_real_path = realpath($config_path); // codacy:ignore - realpath() required for path validation in standalone API
        
        // Ensure the file is within the expected directory
        if (!$config_real_path || strpos($config_real_path, $real_path . '/') !== 0) {
            logSecurityEvent('Config file path traversal attempt', $config_path);
            continue;
        }
        
        $valid_files[] = $config_real_path;
    }
    
    return $valid_files;
}

function processNginxConfig($config_real_path) {
    $config_content = file_get_contents($config_real_path); // codacy:ignore - file_get_contents() required for configuration reading in standalone API
    if ($config_content === false) {
        return null;
    }
    
    if (strpos($config_content, 'wordpress') === false && 
        strpos($config_content, 'wp-') === false) {
        return null;
    }
    
    // Extract domain name and document root safely
    $domain = '';
    $document_root = '';
    
    if (preg_match('/server_name\s+([a-zA-Z0-9.-]+(?:\s+[a-zA-Z0-9.-]+)*)\s*;/', $config_content, $matches)) {
        $domain = trim($matches[1]);
        
        // Split multiple domains and take the first one
        $domain_parts = preg_split('/\s+/', $domain);
        $primary_domain = $domain_parts[0];
        
        // Validate domain format
        if (filter_var($primary_domain, FILTER_VALIDATE_DOMAIN, FILTER_FLAG_HOSTNAME)) {
            $domain = htmlspecialchars($primary_domain, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        }
    }
    
    // Extract document root for WordPress version detection
    if (preg_match('/root\s+([^\s;]+)\s*;/', $config_content, $matches)) {
        $document_root = trim($matches[1]);
        // Validate and sanitize document root path
        if (preg_match('/^\/[a-zA-Z0-9\/_.-]+$/', $document_root)) {
            $document_root = realpath($document_root); // codacy:ignore - realpath() required for path validation in standalone API
        }
        
        if (!$document_root) {
            $document_root = '';
        }
    }
    
    if (empty($domain)) {
        return null;
    }
    
    $wp_version = getWordPressVersion($document_root);
    
    return [
        'domain' => $domain,
        'status' => 'online',
        'wp_version' => $wp_version,
        'ssl_status' => 'Enabled'
    ];
}

function getWordPressSites() {
    $sites = [];
    $nginx_sites_path = '/etc/nginx/sites-enabled';
    
    try {
        $real_path = validateNginxSitesPath($nginx_sites_path);
        if (!$real_path) {
            return $sites;
        }
        
        $valid_files = scanNginxConfigs($real_path);
        if ($valid_files === false) {
            return $sites;
        }
        
        foreach ($valid_files as $config_real_path) {
            $site_info = processNginxConfig($config_real_path);
            if ($site_info !== null) {
                $sites[] = $site_info;
            }
        }
    } catch (Exception $e) {
        logSecurityEvent('WordPress sites enumeration error', $e->getMessage());
    }
    
    return $sites;
}

// WordPress version detection helper
function validateWordPressPath($document_root) {
    if (empty($document_root) || !is_dir($document_root)) { // codacy:ignore - is_dir() required for directory validation in standalone API
        return false;
    }
    
    // Check for wp-includes/version.php file
    $version_file = $document_root . '/wp-includes/version.php';
    $real_version_file = realpath($version_file); // codacy:ignore - realpath() required for path validation in standalone API
    
    // Ensure the file exists and is within the expected directory structure
    if (!$real_version_file || 
        strpos($real_version_file, realpath($document_root) . '/') !== 0) { // codacy:ignore - realpath() required for path validation in standalone API
        return false;
    }
    
    if (file_exists($real_version_file) && is_readable($real_version_file)) { // codacy:ignore - file_exists() and is_readable() required for version file checking in standalone API
        return $real_version_file;
    }
    
    return false;
}

function parseWordPressVersion($real_version_file) {
    $content = file_get_contents($real_version_file); // codacy:ignore - file_get_contents() required for version reading in standalone API
    if ($content === false) {
        return 'Unknown';
    }
    
    // Look for the WordPress version variable
    if (preg_match('/\$wp_version\s*=\s*[\'"]([0-9]+\.[0-9]+(?:\.[0-9]+)?(?:-[a-zA-Z0-9-]+)?)[\'"]/', $content, $matches)) {
        $version = $matches[1];
        // Validate version format
        if (preg_match('/^[0-9]+\.[0-9]+(?:\.[0-9]+)?(?:-[a-zA-Z0-9-]+)?$/', $version)) {
            return htmlspecialchars($version, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        }
    }
    
    return 'Unknown';
}

/**
 * Get WordPress version from a site's document root
 * @param string $document_root The document root path of the WordPress installation
 * @return string WordPress version or 'Unknown'
 */
function getWordPressVersion($document_root) {
    try {
        $real_version_file = validateWordPressPath($document_root);
        if (!$real_version_file) {
            return 'Unknown';
        }
        
        return parseWordPressVersion($real_version_file);
    } catch (Exception $e) {
        logSecurityEvent('WordPress version detection error', $e->getMessage());
        return 'Unknown';
    }
}

// Recent activity helpers
function checkRecentSSHActivity() {
    $auth_log = '/var/log/auth.log';
    $real_auth_log = realpath($auth_log); // codacy:ignore - realpath() required for log file path validation in standalone API
    
    if (!isValidLogFile($real_auth_log, $auth_log)) {
        return null;
    }
    
    $handle = fopen($real_auth_log, 'r'); // codacy:ignore - fopen() required for log file reading in standalone API
    if (!$handle) {
        return null;
    }
    
    $ssh_activity = parseAuthLogForActivity($handle);
    fclose($handle); // codacy:ignore - fclose() required for proper file handle cleanup in standalone API
    
    return $ssh_activity;
}

function getRecentActivity() {
    $activities = [];
    
    try {
        // Check for SSH login activity
        $ssh_activity = checkRecentSSHActivity();
        if ($ssh_activity) {
            $activities[] = $ssh_activity;
        }
        
        // Add system status update
        $activities[] = [
            'message' => 'System status updated',
            'time' => 'Just now',
            'icon' => 'fa-sync-alt'
        ];
    } catch (Exception $e) {
        logSecurityEvent('Recent activity error', $e->getMessage());
        // Add fallback activity
        $activities[] = [
            'message' => 'System monitoring active',
            'time' => 'Just now',
            'icon' => 'fa-shield-alt'
        ];
    }
    
    return $activities;
}

function isValidLogFile($real_path, $expected_path) {
    return $real_path && 
           $real_path === $expected_path && 
           file_exists($real_path) && // codacy:ignore - file_exists() required for log file validation in standalone API
           is_readable($real_path); // codacy:ignore - is_readable() required for log file validation in standalone API
}

function parseAuthLogForActivity($handle) {
    $file_size = filesize('/var/log/auth.log'); // codacy:ignore - filesize() required for log file size checking in standalone API
    if (!$file_size || $file_size <= 0) {
        return null;
    }
    
    fseek($handle, max(0, $file_size - 1024), SEEK_SET); // codacy:ignore - fseek() required for log file positioning in standalone API
    $content = fread($handle, 1024); // codacy:ignore - fread() required for log file reading in standalone API
    
    if ($content && strpos($content, 'Accepted') !== false) {
        return [
            'message' => 'Recent SSH login detected',
            'time' => '5 minutes ago',
            'icon' => 'fa-sign-in-alt'
        ];
    }
    
    return null;
}

function getSystemAlerts() {
    $alerts = [];
    
    // Check disk usage
    $disk_usage = (float)str_replace('%', '', getDiskUsage());
    if ($disk_usage > 90) {
        $alerts[] = [
            'message' => 'High disk usage detected',
            'time' => 'Now',
            'type' => 'warning'
        ];
    }
    
    // Check memory usage
    $memory_usage = (float)str_replace('%', '', getMemoryUsage());
    if ($memory_usage > 85) {
        $alerts[] = [
            'message' => 'High memory usage detected',
            'time' => 'Now',
            'type' => 'warning'
        ];
    }
    
    // If no alerts, return success message
    if (empty($alerts)) {
        $alerts[] = [
            'message' => 'All systems operational',
            'time' => 'Just now',
            'type' => 'info'
        ];
    }
    
    return $alerts;
}

// External services functions moved to external-services/external-services-api.php

?>


