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

// Get the request URI and method first
$request_uri = isset($_SERVER['REQUEST_URI']) ? $_SERVER['REQUEST_URI'] : ''; // codacy:ignore - Direct $_SERVER access required, wp_unslash() not available
$request_method = isset($_SERVER['REQUEST_METHOD']) ? $_SERVER['REQUEST_METHOD'] : ''; // codacy:ignore - Direct $_SERVER access required, wp_unslash() not available

// Check if endpoint is passed as a query parameter
$endpoint_param = isset($_GET['endpoint']) ? trim($_GET['endpoint']) : ''; // codacy:ignore - Direct $_GET access required
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

// Only allow GET requests (preferences now stored client-side)
if (!isset($_SERVER['REQUEST_METHOD']) || $_SERVER['REQUEST_METHOD'] !== 'GET') { // codacy:ignore - Direct $_SERVER access required for request validation
    http_response_code(405);
    die(json_encode(['error' => 'Method not allowed'])); // codacy:ignore - die() required for security termination
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
    // Use a safer approach: get list of active services first, then filter in PHP
    $command = "systemctl list-units --type=service --state=active --no-legend --plain 2>/dev/null";
    $services_output = shell_exec($command); // codacy:ignore - shell_exec() required for service discovery in standalone API
    
    if ($services_output === null) {
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
        
        // Check if it contains both "php" and "fpm" (case insensitive) - FIXED TYPO
        if (stripos($service_name, 'php') !== false && stripos($service_name, 'fpm') !== false) {
            // Validate the service name matches our flexible pattern for PHP-FPM services
            // Pattern: php + optional version/text + fpm + optional version/text
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
    // Sanitize all log inputs to prevent log injection attacks
    $safe_event = preg_replace('/[\r\n\t]/', ' ', $event);
    $safe_event = substr(trim($safe_event), 0, 255); // Limit length
    
    $log_entry = date('Y-m-d H:i:s') . " [SECURITY] " . $safe_event;
    
    if ($details) {
        // Sanitize details to prevent log injection
        $safe_details = preg_replace('/[\r\n\t]/', ' ', $details);
        $safe_details = substr(trim($safe_details), 0, 255); // Limit length
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

// Path was already extracted and validated above, validate again for security
if (strlen($path) > 100 || !preg_match('/^\/[a-zA-Z0-9\/_-]*$/', $path)) {
    http_response_code(400);
    logSecurityEvent('Suspicious path', $path);
    die(json_encode(['error' => 'Invalid path']));
}

// Route handling
switch ($path) {
    case '/csrf-token':
        handleCsrfToken();
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
        handleExternalServicesConfig();
        break;
    
    case '/external-services/feed':
        handleStatusFeed();
        break;
    
    default:
        http_response_code(404);
        error_log("API 404 - Path not matched: " . $path); // Debug logging
        echo json_encode(['error' => 'Endpoint not found', 'path' => $path]); // codacy:ignore - echo required for JSON API response
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
    try {
        $info = [
            'os' => getOsInfo(),
            'kernel' => getKernelVersion(),
            'network' => getNetworkInfo()
        ];
        echo json_encode(sanitizeOutput($info)); // codacy:ignore - echo required for JSON API response
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('System info error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve system info']); // codacy:ignore - echo required for JSON API response
    }
}











function handleServicesStatus() {
    try {
        $services = [
            'nginx' => getServiceStatus('nginx'),
            'php' => getPhpServiceStatus(),
            'mysql' => getServiceStatus('mariadb'),
            'redis' => getServiceStatus('redis-server')
        ];
        echo json_encode(sanitizeOutput($services)); // codacy:ignore - echo required for JSON API response
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
        if (file_exists('/usr/local/bin/enginescript/enginescript-variables.txt')) { // codacy:ignore - file_exists() required for version checking in standalone service
            $content = file_get_contents('/usr/local/bin/enginescript/enginescript-variables.txt'); // codacy:ignore - file_get_contents() required for version reading in standalone service
            preg_match('/TINYFILEMANAGER_VER="([^"]*)"/', $content, $matches);
            $current_version = isset($matches[1]) ? $matches[1] : '2.6';
        } else {
            $current_version = '2.6';
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
        $version = shell_exec('uname -r 2>/dev/null'); // codacy:ignore - shell_exec() required for kernel version retrieval in standalone API
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
            $ip_output = shell_exec("ip route get 8.8.8.8 2>/dev/null | awk '{print \$7; exit}'"); // codacy:ignore - shell_exec() required for network IP detection in standalone API
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
    $safe_service = escapeshellarg($service); // codacy:ignore - escapeshellarg() required for shell command safety in standalone API
    $command = "systemctl is-active $safe_service 2>/dev/null";
    $status_output = shell_exec($command); // codacy:ignore - shell_exec() required for service status checking in standalone API
    return $status_output !== null ? trim($status_output) : '';
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
    $version_output = shell_exec('nginx -v 2>&1'); // codacy:ignore - shell_exec() required for Nginx version retrieval in standalone API
    if ($version_output !== null && preg_match('/nginx\/(\d+\.\d+\.\d+)/', $version_output, $matches)) {
        return htmlspecialchars($matches[1], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }
    return 'Unknown';
}

function getPhpVersion() {
    $version_output = shell_exec('php -v 2>/dev/null'); // codacy:ignore - shell_exec() required for PHP version retrieval in standalone API
    if ($version_output !== null && preg_match('/PHP (\d+\.\d+\.\d+)/', $version_output, $matches)) {
        return htmlspecialchars($matches[1], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }
    return 'Unknown';
}

function getMariadbVersion() {
    $version_output = shell_exec('mariadb --version 2>/dev/null'); // codacy:ignore - shell_exec() required for MariaDB version retrieval in standalone API
    if ($version_output !== null && preg_match('/mariadb.*?(\d+\.\d+\.\d+)/', $version_output, $matches)) {
        return htmlspecialchars($matches[1], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }
    return 'Unknown';
}

function getRedisVersion() {
    $version_output = shell_exec('redis-server --version 2>/dev/null'); // codacy:ignore - shell_exec() required for Redis version retrieval in standalone API
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

/**
 * Parse RSS/Atom feed and extract status information
 * @param string $feedUrl The URL of the RSS/Atom feed
 * @return array Status information with indicator and description
 */
function parseStatusFeed($feedUrl) {
    try {
        // Set up context with timeout and user agent
        $context = stream_context_create([
            'http' => [
                'timeout' => 10,
                'user_agent' => 'EngineScript-StatusMonitor/1.0',
                'ignore_errors' => true
            ]
        ]);
        
        // Fetch feed content
        $feedContent = @file_get_contents($feedUrl, false, $context); // codacy:ignore - file_get_contents required for feed fetching
        
        if ($feedContent === false) {
            throw new Exception('Failed to fetch feed');
        }
        
        // Suppress XML errors and parse
        libxml_use_internal_errors(true);
        $xml = simplexml_load_string($feedContent);
        libxml_clear_errors();
        
        if ($xml === false) {
            throw new Exception('Failed to parse XML');
        }
        
        $status = [
            'indicator' => 'none',
            'description' => 'All Systems Operational'
        ];
        
        // Check if it's an Atom feed
        if (isset($xml->entry)) {
            $latestEntry = $xml->entry[0];
            $title = isset($latestEntry->title) ? (string)$latestEntry->title : '';
            $content = isset($latestEntry->content) ? (string)$latestEntry->content : '';
            $summary = isset($latestEntry->summary) ? (string)$latestEntry->summary : '';
            
            // Strip CDATA tags if present (e.g., Brevo feed)
            $title = preg_replace('/<!\[CDATA\[(.*?)\]\]>/s', '$1', $title);
            $content = preg_replace('/<!\[CDATA\[(.*?)\]\]>/s', '$1', $content);
            $summary = preg_replace('/<!\[CDATA\[(.*?)\]\]>/s', '$1', $summary);
            
            // Get entry timestamp
            $entryDate = null;
            if (isset($latestEntry->updated)) {
                $entryDate = strtotime((string)$latestEntry->updated);
            } elseif (isset($latestEntry->published)) {
                $entryDate = strtotime((string)$latestEntry->published);
            }
            
            // Check if entry is within 48 hours (172800 seconds)
            $isRecent = ($entryDate && (time() - $entryDate) <= 172800);
            
            // For Brevo and similar feeds, prefer title only
            $description = !empty($title) ? $title : (!empty($content) ? $content : $summary);
            
            // Only show status if entry is within 48 hours, otherwise show operational
            if (!$isRecent || preg_match('/operational|resolved|completed|fixed|normal/i', $title)) {
                $status['indicator'] = 'none';
                $status['description'] = 'All Systems Operational';
            } elseif (preg_match('/outage|down|major|critical|offline/i', $title)) {
                $status['indicator'] = 'major';
                $status['description'] = strip_tags($description);
            } elseif (preg_match('/degraded|issue|problem|investigating|identified|monitoring/i', $title)) {
                $status['indicator'] = 'minor';
                $status['description'] = strip_tags($description);
            } else {
                $status['description'] = strip_tags($title);
            }
        }
        // Check if it's an RSS feed
        elseif (isset($xml->channel->item)) {
            $latestItem = $xml->channel->item[0];
            $title = isset($latestItem->title) ? (string)$latestItem->title : '';
            $description = isset($latestItem->description) ? (string)$latestItem->description : '';
            
            // Get item timestamp
            $itemDate = null;
            if (isset($latestItem->pubDate)) {
                $itemDate = strtotime((string)$latestItem->pubDate);
            } elseif (isset($latestItem->children('http://purl.org/dc/elements/1.1/')->date)) {
                $itemDate = strtotime((string)$latestItem->children('http://purl.org/dc/elements/1.1/')->date);
            }
            
            // Check if item is within 48 hours (172800 seconds)
            $isRecent = ($itemDate && (time() - $itemDate) <= 172800);
            
            // Only show status if item is within 48 hours, otherwise show operational
            if (!$isRecent || preg_match('/operational|resolved|completed|fixed|normal/i', $title)) {
                $status['indicator'] = 'none';
                $status['description'] = 'All Systems Operational';
            } elseif (preg_match('/outage|down|major|critical|offline/i', $title)) {
                $status['indicator'] = 'major';
                $status['description'] = strip_tags(!empty($description) ? $description : $title);
            } elseif (preg_match('/degraded|issue|problem|investigating|identified|monitoring/i', $title)) {
                $status['indicator'] = 'minor';
                $status['description'] = strip_tags(!empty($description) ? $description : $title);
            } else {
                $status['description'] = strip_tags($title);
            }
        }
        
        // Truncate long descriptions
        if (strlen($status['description']) > 200) {
            $status['description'] = substr($status['description'], 0, 197) . '...';
        }
        
        return $status;
        
    } catch (Exception $e) {
        return [
            'indicator' => 'major',
            'description' => 'Unable to fetch status'
        ];
    }
}

/**
 * Parse Google Workspace incidents JSON API
 */
function parseGoogleWorkspaceIncidents($apiUrl) {
    try {
        $context = stream_context_create([
            'http' => [
                'timeout' => 10,
                'user_agent' => 'EngineScript Admin Dashboard'
            ]
        ]);
        
        $response = file_get_contents($apiUrl, false, $context);
        if ($response === false) {
            return [
                'indicator' => 'major',
                'description' => 'Unable to fetch status'
            ];
        }
        
        $data = json_decode($response, true);
        if (!$data || empty($data)) {
            return [
                'indicator' => 'none',
                'description' => 'All Systems Operational'
            ];
        }
        
        // Get the first incident (most recent)
        $latestIncident = reset($data);
        
        // Extract title from external_desc (format: **Title:**\nActual title text)
        $description = isset($latestIncident['external_desc']) ? $latestIncident['external_desc'] : '';
        
        // Parse title - extract text after **Title:** marker
        $title = '';
        if (preg_match('/\*\*Title:?\*\*\s*\n(.+?)(?:\n|$)/s', $description, $matches)) {
            $title = trim($matches[1]);
        } elseif (preg_match('/\*\*Title:?\*\*\s*(.+?)(?:\n|$)/s', $description, $matches)) {
            // Fallback: title on same line
            $title = trim($matches[1]);
        } else {
            // No title marker, use first line
            $title = strtok($description, "\n");
        }
        
        if (empty($title)) {
            return [
                'indicator' => 'none',
                'description' => 'All Systems Operational'
            ];
        }
        
        // Determine severity
        $indicator = 'minor';
        if (isset($latestIncident['severity'])) {
            $severity = strtolower($latestIncident['severity']);
            if (in_array($severity, ['high', 'critical'])) {
                $indicator = 'major';
            }
        }
        
        return [
            'indicator' => $indicator,
            'description' => strip_tags($title)
        ];
        
    } catch (Exception $e) {
        return [
            'indicator' => 'major',
            'description' => 'Unable to fetch status'
        ];
    }
}

/**
 * Parse Wistia summary JSON API
 */
function parseWistiaSummary($apiUrl) {
    try {
        $context = stream_context_create([
            'http' => [
                'timeout' => 10,
                'user_agent' => 'EngineScript Admin Dashboard'
            ]
        ]);
        
        $response = file_get_contents($apiUrl, false, $context);
        if ($response === false) {
            return [
                'indicator' => 'major',
                'description' => 'Unable to fetch status'
            ];
        }
        
        $data = json_decode($response, true);
        if (!$data || !isset($data['page'])) {
            return [
                'indicator' => 'major',
                'description' => 'Unable to fetch status'
            ];
        }
        
        // Check page status
        $pageStatus = isset($data['page']['status']) ? strtoupper($data['page']['status']) : 'UNKNOWN';
        
        // If no issues, return operational
        if ($pageStatus === 'OK' || $pageStatus === 'OPERATIONAL') {
            return [
                'indicator' => 'none',
                'description' => 'All Systems Operational'
            ];
        }
        
        // Check for active incidents
        if (isset($data['activeIncidents']) && !empty($data['activeIncidents'])) {
            $latestIncident = reset($data['activeIncidents']);
            $name = isset($latestIncident['name']) ? $latestIncident['name'] : 'Service Issue';
            
            // Determine severity from impact
            $indicator = 'minor';
            if (isset($latestIncident['impact'])) {
                $impact = strtoupper($latestIncident['impact']);
                if (in_array($impact, ['MAJOROUTAGE', 'CRITICAL'])) {
                    $indicator = 'major';
                }
            }
            
            return [
                'indicator' => $indicator,
                'description' => strip_tags($name)
            ];
        }
        
        // Has issues but no active incidents listed
        if ($pageStatus === 'HASISSUES') {
            return [
                'indicator' => 'minor',
                'description' => 'Service Experiencing Issues'
            ];
        }
        
        return [
            'indicator' => 'none',
            'description' => 'All Systems Operational'
        ];
        
    } catch (Exception $e) {
        return [
            'indicator' => 'major',
            'description' => 'Unable to fetch status'
        ];
    }
}

/**
 * Parse Vultr alerts JSON API
 */
function parseVultrAlerts($apiUrl) {
    try {
        $context = stream_context_create([
            'http' => [
                'timeout' => 10,
                'user_agent' => 'EngineScript Admin Dashboard'
            ]
        ]);
        
        $response = file_get_contents($apiUrl, false, $context);
        if ($response === false) {
            return [
                'indicator' => 'major',
                'description' => 'Unable to fetch status'
            ];
        }
        
        $data = json_decode($response, true);
        if (!$data || !isset($data['service_alerts'])) {
            return [
                'indicator' => 'none',
                'description' => 'All Systems Operational'
            ];
        }
        
        // Check for ongoing alerts only
        $ongoingAlerts = array_filter($data['service_alerts'], function($alert) {
            return isset($alert['status']) && $alert['status'] === 'ongoing';
        });
        
        if (empty($ongoingAlerts)) {
            return [
                'indicator' => 'none',
                'description' => 'All Systems Operational'
            ];
        }
        
        // Get the most recent ongoing alert
        $latestAlert = reset($ongoingAlerts);
        $subject = isset($latestAlert['subject']) ? $latestAlert['subject'] : 'Service Alert';
        
        // Determine severity from subject
        $indicator = 'minor';
        if (preg_match('/outage|down|major|critical|offline/i', $subject)) {
            $indicator = 'major';
        }
        
        return [
            'indicator' => $indicator,
            'description' => strip_tags($subject)
        ];
        
    } catch (Exception $e) {
        return [
            'indicator' => 'major',
            'description' => 'Unable to fetch status'
        ];
    }
}

/**
 * Parse Postmark notices API
 */
function parsePostmarkNotices($apiUrl) {
    try {
        $context = stream_context_create([
            'http' => [
                'timeout' => 10,
                'user_agent' => 'EngineScript Admin Dashboard'
            ]
        ]);
        
        $response = file_get_contents($apiUrl, false, $context);
        if ($response === false) {
            return [
                'indicator' => 'major',
                'description' => 'Unable to fetch status'
            ];
        }
        
        $data = json_decode($response, true);
        if (!$data || !isset($data['notices'])) {
            return [
                'indicator' => 'none',
                'description' => 'All Systems Operational'
            ];
        }
        
        // Filter for current unplanned notices
        $currentUnplanned = array_filter($data['notices'], function($notice) {
            $isUnplanned = isset($notice['type']) && $notice['type'] === 'unplanned';
            $isPresent = isset($notice['timeline_state']) && $notice['timeline_state'] === 'present';
            return $isUnplanned && $isPresent;
        });
        
        if (empty($currentUnplanned)) {
            return [
                'indicator' => 'none',
                'description' => 'All Systems Operational'
            ];
        }
        
        // Get the most recent current unplanned notice
        $latestNotice = reset($currentUnplanned);
        $title = isset($latestNotice['title']) ? $latestNotice['title'] : 'Unplanned Incident';
        
        // Determine severity from title
        $indicator = 'minor';
        if (preg_match('/outage|down|major|critical|offline/i', $title)) {
            $indicator = 'major';
        }
        
        return [
            'indicator' => $indicator,
            'description' => strip_tags($title)
        ];
        
    } catch (Exception $e) {
        return [
            'indicator' => 'major',
            'description' => 'Unable to fetch status'
        ];
    }
}

/**
 * Handle RSS/Atom feed status requests
 */
function handleStatusFeed() {
    try {
        // Validate feed parameter
        if (!isset($_GET['feed']) || empty($_GET['feed'])) { // codacy:ignore - Direct $_GET access required
            http_response_code(400);
            echo json_encode(['error' => 'Missing feed parameter']); // codacy:ignore - echo required for JSON response
            return;
        }
        
        $feedType = $_GET['feed']; // codacy:ignore - Direct $_GET access required
        
        // Handle special JSON API feeds
        if ($feedType === 'vultr') {
            $status = parseVultrAlerts('https://status.vultr.com/alerts.json');
            echo json_encode(['status' => $status]); // codacy:ignore - echo required for JSON response
            return;
        }
        
        if ($feedType === 'postmark') {
            $status = parsePostmarkNotices('https://status.postmarkapp.com/api/v1/notices?filter[timeline_state_eq]=present&filter[type_eq]=unplanned');
            echo json_encode(['status' => $status]); // codacy:ignore - echo required for JSON response
            return;
        }
        
        if ($feedType === 'googleworkspace') {
            $status = parseGoogleWorkspaceIncidents('https://www.google.com/appsstatus/dashboard/incidents.json');
            echo json_encode(['status' => $status]); // codacy:ignore - echo required for JSON response
            return;
        }
        
        if ($feedType === 'wistia') {
            $status = parseWistiaSummary('https://status.wistia.com/summary.json');
            echo json_encode(['status' => $status]); // codacy:ignore - echo required for JSON response
            return;
        }
        
        // Whitelist allowed RSS/Atom feeds for security
        $allowedFeeds = [
            'stripe' => 'https://www.stripestatus.com/history.atom',
            'letsencrypt' => 'https://letsencrypt.status.io/pages/55957a99e800baa4470002da/rss',
            'cloudflare-flare' => 'https://status.flare.io/history/rss',
            'slack' => 'https://slack-status.com/feed/atom',
            'gitlab' => 'https://status.gitlab.com/pages/5b36dc6502d06804c08349f7/rss',
            'square' => 'https://www.issquareup.com/united-states/feed.atom',
            'recurly' => 'https://status.recurly.com/statuspage/recurly/subscribe/rss',
            'googleads' => 'https://ads.google.com/status/publisher/en/feed.atom',
            'googlesearch' => 'https://status.search.google.com/en/feed.atom',
            'microsoftads' => 'https://status.ads.microsoft.com/feed?cat=27',
            'paypal' => 'https://www.paypal-status.com/feed/atom',
            'googlecloud' => 'https://status.cloud.google.com/en/feed.atom',
            'oracle' => 'https://ocistatus.oraclecloud.com/api/v2/incident-summary.rss',
            'ovh' => 'https://public-cloud.status-ovhcloud.com/history.atom',
            'brevo' => 'https://status.brevo.com/feed.atom',
            'automattic' => 'https://automatticstatus.com/rss',
            'wpvip' => 'https://wpvipstatus.com/rss'
        ];
        
        if (!isset($allowedFeeds[$feedType])) {
            http_response_code(400);
            echo json_encode(['error' => 'Invalid feed type']); // codacy:ignore - echo required for JSON response
            return;
        }
        
        $feedUrl = $allowedFeeds[$feedType];
        
        // Parse feed and return status
        $status = parseStatusFeed($feedUrl);
        
        echo json_encode(['status' => $status]); // codacy:ignore - echo required for JSON response
        
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Status feed error', $e->getMessage());
        echo json_encode(['error' => 'Unable to fetch status feed']); // codacy:ignore - echo required for JSON response
    }
}

function getExternalServicesConfig() {
    // All services available - user preferences stored client-side in cookies
    $config = [
        // Hosting & Infrastructure
        'aws' => true,
        'cloudflare' => true,
        'cloudways' => true,
        'digitalocean' => true,
        'googlecloud' => true,
        'hostinger' => true,
        'kinsta' => true,
        'linode' => true,
        'oracle' => true,
        'ovh' => true,
        'scaleway' => true,
        'upcloud' => true,
        'vercel' => true,
        'vultr' => true,
        'wpvip' => true,
        
        // Developer Tools
        'github' => true,
        'gitlab' => true,
        'notion' => true,
        'postmark' => true,
        'twilio' => true,
        
        // Payment Processing
        'coinbase' => true,
        'paypal' => true,
        'recurly' => true,
        'square' => true,
        'stripe' => true,
        
        // Communication
        'brevo' => true,
        'discord' => true,
        'mailgun' => true,
        'slack' => true,
        'zoom' => true,
        
        // E-Commerce
        'intuit' => true,
        'shopify' => true,
        
        // Media & Content
        'automattic' => true,
        'dropbox' => true,
        'reddit' => true,
        'udemy' => true,
        'vimeo' => true,
        'wistia' => true,
        
        // Gaming
        'epicgames' => true,
        
        // AI & Machine Learning
        'openai' => true,
        
        // Advertising
        'googleads' => true,
        'googlesearch' => true,
        'googleworkspace' => true,
        'microsoftads' => true,
        
        // Security
        'letsencrypt' => true,
        'cloudflareflare' => true
    ];
    
    return $config;
}

function handleExternalServicesConfig() {
    try {
        $config = getExternalServicesConfig();
        
        // Return all available services (preferences now stored client-side in cookies)
        echo json_encode($config); // codacy:ignore - echo required for JSON API response
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('External services config error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve external services config']); // codacy:ignore - echo required for JSON API response
    }
}

?>


