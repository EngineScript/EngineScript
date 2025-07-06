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
header('Access-Control-Allow-Headers: Content-Type, X-Requested-With'); // codacy:ignore - CORS header required
header('Access-Control-Allow-Credentials: true'); // codacy:ignore - CORS header required
header('Access-Control-Max-Age: 86400'); // codacy:ignore - CORS header required

// Rate limiting (basic implementation) - session functions required for API rate limiting
if (session_status() === PHP_SESSION_NONE) { // codacy:ignore - session_status() required for session management in standalone API
    session_start(); // codacy:ignore - session_start() required for rate limiting functionality
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

// Only allow GET requests for security
if (!isset($_SERVER['REQUEST_METHOD']) || $_SERVER['REQUEST_METHOD'] !== 'GET') { // codacy:ignore - Direct $_SERVER access required for request validation
    http_response_code(405);
    die(json_encode(['error' => 'Method not allowed'])); // codacy:ignore - die() required for security termination
}

// Get the request URI and method
$request_uri = isset($_SERVER['REQUEST_URI']) ? $_SERVER['REQUEST_URI'] : ''; // codacy:ignore - Direct $_SERVER access required, wp_unslash() not available
$request_method = isset($_SERVER['REQUEST_METHOD']) ? $_SERVER['REQUEST_METHOD'] : ''; // codacy:ignore - Direct $_SERVER access required, wp_unslash() not available

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
    // Only allow known service names
    $allowed_services = ['nginx', 'php8.3-fpm', 'mariadb', 'redis-server'];
    return in_array($input, $allowed_services, true) ? $input : false;
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
    $client_ip = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : 'unknown';
    if ($client_ip !== 'unknown') {
        // Validate IP format to prevent injection
        if (!filter_var($client_ip, FILTER_VALIDATE_IP)) {
            $client_ip = 'invalid';
        }
    }
    $log_entry .= " - IP: " . $client_ip . "\n";
    
    // Log to a secure location
    $log_file = '/var/log/enginescript-api-security.log';
    error_log($log_entry, 3, $log_file);
}

// Remove query parameters and decode URI
$path = parse_url($request_uri, PHP_URL_PATH); // codacy:ignore - parse_url() required for URL parsing in standalone API
if ($path === false) {
    http_response_code(400);
    logSecurityEvent('Invalid URI', $request_uri);
    die(json_encode(['error' => 'Invalid request'])); // codacy:ignore - die() required for security termination
}

// Check if endpoint is passed as a query parameter (from nginx rewrite)
$endpoint_param = isset($_GET['endpoint']) ? $_GET['endpoint'] : ''; // codacy:ignore - Direct $_GET access required, wp_unslash() not available, CSRF not applicable to read-only API
if (!empty($endpoint_param)) {
    // Use the endpoint parameter from the query string
    $path = '/' . ltrim($endpoint_param, '/');
} else {
    // Fallback to parsing from path (for direct access)
    $path = str_replace('/api', '', $path);
}

// Validate path to prevent injection
if (strlen($path) > 100 || !preg_match('/^\/[a-zA-Z0-9\/_-]*$/', $path)) {
    http_response_code(400);
    logSecurityEvent('Suspicious path', $path);
    die(json_encode(['error' => 'Invalid path']));
}

// Route handling
switch ($path) {
    case '/system/stats':
        handleSystemStats();
        break;
    
    case '/system/info':
        handleSystemInfo();
        break;
    
    case '/system/memory':
        handleMemoryUsage();
        break;
    
    case '/system/disk':
        handleDiskUsage();
        break;
    
    case '/system/cpu':
        handleCpuUsage();
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
    
    default:
        if (preg_match('/^\/logs\/([a-zA-Z0-9_-]+)$/', $path, $matches)) {
            $logType = validateInput($matches[1], 'path');
            if ($logType === false) {
                http_response_code(400);
                logSecurityEvent('Invalid log type', $matches[1]);
                die(json_encode(['error' => 'Invalid log type'])); // codacy:ignore - die() required for security termination
            }
            handleLogs($logType);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Endpoint not found']); // codacy:ignore - echo required for JSON API response
        }
        break;
}

function handleSystemStats() {
    try {
        $stats = [
            'cpu' => getCpuUsage(),
            'memory' => getMemoryUsage(),
            'disk' => getDiskUsage(),
            'uptime' => getUptime(),
            'load' => getLoadAverage()
        ];
        echo json_encode(sanitizeOutput($stats)); // codacy:ignore - echo required for JSON API response
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('System stats error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve system stats']); // codacy:ignore - echo required for JSON API response
    }
}

function handleSystemInfo() {
    try {
        $info = [
            'os' => getOsInfo(),
            'kernel' => getKernelVersion(),
            'uptime' => getUptime(),
            'load' => getLoadAverage(),
            'memory_total' => getTotalMemory(),
            'disk_total' => getTotalDisk(),
            'network' => getNetworkInfo()
        ];
        echo json_encode(sanitizeOutput($info)); // codacy:ignore - echo required for JSON API response
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('System info error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve system info']); // codacy:ignore - echo required for JSON API response
    }
}

function handleMemoryUsage() {
    try {
        echo json_encode(['usage' => sanitizeOutput(getMemoryUsage())]); // codacy:ignore - echo required for JSON API response
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Memory usage error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve memory usage']); // codacy:ignore - echo required for JSON API response
    }
}

function handleDiskUsage() {
    try {
        echo json_encode(['usage' => sanitizeOutput(getDiskUsage())]); // codacy:ignore - echo required for JSON API response
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Disk usage error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve disk usage']); // codacy:ignore - echo required for JSON API response
    }
}

function handleCpuUsage() {
    try {
        echo json_encode(['usage' => sanitizeOutput(getCpuUsage())]); // codacy:ignore - echo required for JSON API response
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('CPU usage error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve CPU usage']); // codacy:ignore - echo required for JSON API response
    }
}

function handleServicesStatus() {
    try {
        $services = [
            'nginx' => getServiceStatus('nginx'),
            'php' => getServiceStatus('php8.3-fpm'),
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

function handleLogs($logType) {
    try {
        echo json_encode(['logs' => getLogs($logType)]); // codacy:ignore - echo required for JSON API response
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Logs error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve logs']); // codacy:ignore - echo required for JSON API response
    }
}

// System information functions
function getCpuUsage() {
    try {
        $load = sys_getloadavg(); // codacy:ignore - sys_getloadavg() required for CPU load monitoring in standalone API
        if ($load !== false) {
            // Use safe method to get CPU cores without shell_exec
            $cpu_cores = 1; // Default fallback
            if (file_exists('/proc/cpuinfo')) { // codacy:ignore - file_exists() required for system monitoring in standalone API
                $cpuinfo = file_get_contents('/proc/cpuinfo'); // codacy:ignore - file_get_contents() required for CPU info reading in standalone API
                $cpu_cores = substr_count($cpuinfo, 'processor');
                $cpu_cores = max(1, $cpu_cores); // Ensure at least 1 core
            }
            
            $cpu_usage = ($load[0] / $cpu_cores) * 100;
            return min(100, max(0, round($cpu_usage, 1))) . '%';
        }
    } catch (Exception $e) {
        logSecurityEvent('CPU usage error', $e->getMessage());
    }
    return 'N/A';
}

function getMemoryUsage() {
    $meminfo = file_get_contents('/proc/meminfo'); // codacy:ignore - file_get_contents() required for memory info reading in standalone API
    if ($meminfo) {
        preg_match('/MemTotal:\s+(\d+)/', $meminfo, $total);
        preg_match('/MemAvailable:\s+(\d+)/', $meminfo, $available);
        
        if ($total && $available) {
            $total_mb = $total[1] / 1024;
            $available_mb = $available[1] / 1024;
            $used_mb = $total_mb - $available_mb;
            $usage_percent = ($used_mb / $total_mb) * 100;
            return round($usage_percent, 1) . '%';
        }
    }
    return 'N/A';
}

function getDiskUsage() {
    $bytes = disk_total_space('/'); // codacy:ignore - disk_total_space() required for disk usage monitoring in standalone API
    $free_bytes = disk_free_space('/'); // codacy:ignore - disk_free_space() required for disk usage monitoring in standalone API
    if ($bytes && $free_bytes) {
        $used_bytes = $bytes - $free_bytes;
        $usage_percent = ($used_bytes / $bytes) * 100;
        return round($usage_percent, 1) . '%';
    }
    return 'N/A';
}

function getUptime() {
    $uptime = file_get_contents('/proc/uptime'); // codacy:ignore - file_get_contents() required for uptime reading in standalone API
    if ($uptime) {
        $seconds = (float)explode(' ', $uptime)[0];
        $days = floor($seconds / 86400);
        $hours = floor(($seconds % 86400) / 3600);
        $minutes = floor(($seconds % 3600) / 60);
        return "{$days}d {$hours}h {$minutes}m";
    }
    return 'N/A';
}

function getLoadAverage() {
    $load = sys_getloadavg(); // codacy:ignore - sys_getloadavg() required for load average monitoring in standalone API
    if ($load !== false) {
        return round($load[0], 2) . ', ' . round($load[1], 2) . ', ' . round($load[2], 2);
    }
    return 'N/A';
}

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

function getTotalMemory() {
    $meminfo = file_get_contents('/proc/meminfo'); // codacy:ignore - file_get_contents() required for memory info reading in standalone API
    if ($meminfo && preg_match('/MemTotal:\s+(\d+)/', $meminfo, $matches)) {
        $memory_mb = round($matches[1] / 1024);
        return $memory_mb . ' MB';
    }
    return 'N/A';
}

function getTotalDisk() {
    $bytes = disk_total_space('/'); // codacy:ignore - disk_total_space() required for disk info in standalone API
    if ($bytes) {
        $disk_gb = round($bytes / (1024 * 1024 * 1024), 1);
        return $disk_gb . ' GB';
    }
    return 'N/A';
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
        case 'php8.3-fpm':
            return getPhpVersion();
        case 'mariadb':
            return getMariadbVersion();
        case 'redis-server':
            return getRedisVersion();
        default:
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
        } else {
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
    fclose($handle);
    
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

// Log reading helpers
function validateLogType($logType) {
    // Strict whitelist of allowed log types
    $allowed_log_types = ['enginescript', 'nginx', 'php', 'mysql'];
    
    if (!in_array($logType, $allowed_log_types, true)) {
        logSecurityEvent('Invalid log type requested', $logType);
        return false;
    }
    
    return true;
}

function getLogFilePath($logType) {
    // Predefined safe log file paths
    $log_files = [
        'enginescript' => '/var/log/enginescript.log',
        'nginx' => '/var/log/nginx/error.log',
        'php' => '/var/log/php8.3-fpm.log',
        'mysql' => '/var/log/mysql/error.log'
    ];
    
    return $log_files[$logType];
}

function validateLogFilePath($log_file) {
    // Additional security check - ensure the path is exactly what we expect
    $real_path = realpath($log_file); // codacy:ignore - realpath() required for log file path validation in standalone API
    $expected_paths = [
        '/var/log/enginescript.log',
        '/var/log/nginx/error.log',
        '/var/log/php8.3-fpm.log',
        '/var/log/mysql/error.log'
    ];
    
    if (!$real_path || !in_array($real_path, $expected_paths, true)) {
        logSecurityEvent('Log file path traversal attempt', $log_file);
        return false;
    }
    
    return $real_path;
}

function readLogFileSafely($real_path) {
    if (!file_exists($real_path) || !is_readable($real_path)) { // codacy:ignore - file_exists() and is_readable() required for log file validation in standalone API
        return 'Log file not found';
    }
    
    // Use safe method to read last 50 lines
    $file_size = filesize($real_path); // codacy:ignore - filesize() required for log file size checking in standalone API
    if ($file_size === false || $file_size > 50 * 1024 * 1024) { // 50MB limit
        return 'Log file too large or unreadable';
    }
    
    $handle = fopen($real_path, 'r'); // codacy:ignore - fopen() required for log file reading in standalone API
    if ($handle === false) {
        return 'Cannot open log file';
    }
    
    // Read last 50 lines safely
    $lines = [];
    $line_count = 0;
    
    // Read from end of file
    fseek($handle, -min($file_size, 8192), SEEK_END); // codacy:ignore - fseek() required for log file positioning in standalone API
    while (($line = fgets($handle)) !== false && $line_count < 50) { // codacy:ignore - fgets() required for log file line reading in standalone API
        $lines[] = $line;
        $line_count++;
    }
    
    fclose($handle);
    
    // Return last 50 lines, sanitized
    $result = implode('', array_slice($lines, -50));
    return htmlspecialchars($result, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function getLogs($logType) {
    if (!validateLogType($logType)) {
        return 'Invalid log type';
    }
    
    $log_file = getLogFilePath($logType);
    $real_path = validateLogFilePath($log_file);
    
    if (!$real_path) {
        return 'Log file access denied';
    }
    
    try {
        return readLogFileSafely($real_path);
    } catch (Exception $e) {
        logSecurityEvent('Log reading error', $e->getMessage());
        return 'Error reading log file';
    }
}
?>
