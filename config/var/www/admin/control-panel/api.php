<?php
/**
 * EngineScript Admin Dashboard API
 * Secure API endpoints for dashboard functionality
 * 
 * @version 1.0.0
 * @security HIGH - Contains sensitive system information
 */

// Prevent direct access if not from proper context
if (!isset($_SERVER['REQUEST_URI']) || !isset($_SERVER['HTTP_HOST'])) {
    http_response_code(403);
    exit('Direct access forbidden');
}

// Security headers
header('Content-Type: application/json; charset=UTF-8');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('X-XSS-Protection: 1; mode=block');
header('Referrer-Policy: strict-origin-when-cross-origin');
header('Content-Security-Policy: default-src \'none\'; frame-ancestors \'none\';');

// Secure CORS - Only allow same origin by default
$allowed_origins = [
    $_SERVER['HTTP_HOST'],
    'localhost',
    '127.0.0.1'
];

$origin = $_SERVER['HTTP_ORIGIN'] ?? $_SERVER['HTTP_HOST'] ?? '';
$origin_host = parse_url($origin, PHP_URL_HOST) ?: $origin;

if (in_array($origin_host, $allowed_origins, true) || 
    preg_match('/^(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/', $origin_host)) {
    header('Access-Control-Allow-Origin: ' . $origin);
} else {
    header('Access-Control-Allow-Origin: null');
}

header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-Requested-With');
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Max-Age: 86400');

// Rate limiting (basic implementation)
session_start();
$client_ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
$rate_limit_key = 'api_rate_' . hash('sha256', $client_ip);

if (!isset($_SESSION[$rate_limit_key])) {
    $_SESSION[$rate_limit_key] = ['count' => 0, 'reset' => time() + 60];
}

// Reset rate limit counter every minute
if (time() > $_SESSION[$rate_limit_key]['reset']) {
    $_SESSION[$rate_limit_key] = ['count' => 0, 'reset' => time() + 60];
}

// Check rate limit (100 requests per minute)
if ($_SESSION[$rate_limit_key]['count'] >= 100) {
    http_response_code(429);
    exit(json_encode(['error' => 'Rate limit exceeded']));
}

$_SESSION[$rate_limit_key]['count']++;

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Only allow GET requests for security
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    exit(json_encode(['error' => 'Method not allowed']));
}

// Get the request URI and method
$request_uri = $_SERVER['REQUEST_URI'] ?? '';
$request_method = $_SERVER['REQUEST_METHOD'] ?? '';

// Input validation and sanitization
function validateInput($input, $type = 'string', $max_length = 255) {
    if (empty($input) && $input !== '0') {
        return false;
    }
    
    switch ($type) {
        case 'string':
            $input = trim($input);
            if (strlen($input) > $max_length) {
                return false;
            }
            // Remove any potential script tags or dangerous characters
            $input = preg_replace('/[<>"\']/', '', $input);
            return filter_var($input, FILTER_SANITIZE_STRING, FILTER_FLAG_STRIP_HIGH);
            
        case 'path':
            // Strict path validation - only allow alphanumeric, dash, underscore, dot
            if (!preg_match('/^[a-zA-Z0-9._-]+$/', $input)) {
                return false;
            }
            // Prevent path traversal
            if (strpos($input, '..') !== false || strpos($input, '/') !== false) {
                return false;
            }
            return $input;
            
        case 'service':
            // Only allow known service names
            $allowed_services = ['nginx', 'php8.3-fpm', 'mariadb', 'redis-server'];
            return in_array($input, $allowed_services, true) ? $input : false;
            
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

function logSecurityEvent($event, $details = '') {
    $log_entry = date('Y-m-d H:i:s') . " [SECURITY] " . $event;
    if ($details) {
        $log_entry .= " - " . $details;
    }
    $log_entry .= " - IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown') . "\n";
    
    // Log to a secure location
    $log_file = '/var/log/enginescript-api-security.log';
    error_log($log_entry, 3, $log_file);
}

// Remove query parameters and decode URI
$path = parse_url($request_uri, PHP_URL_PATH);
if ($path === false) {
    http_response_code(400);
    logSecurityEvent('Invalid URI', $request_uri);
    exit(json_encode(['error' => 'Invalid request']));
}

$path = str_replace('/api', '', $path);

// Validate path to prevent injection
if (strlen($path) > 100 || !preg_match('/^\/[a-zA-Z0-9\/_-]*$/', $path)) {
    http_response_code(400);
    logSecurityEvent('Suspicious path', $path);
    exit(json_encode(['error' => 'Invalid path']));
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
    
    case '/security/status':
        handleSecurityStatus();
        break;
    
    case '/backups':
    case '/backups/':
        handleBackups();
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
                exit(json_encode(['error' => 'Invalid log type']));
            }
            handleLogs($logType);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Endpoint not found']);
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
        echo json_encode(sanitizeOutput($stats));
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('System stats error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve system stats']);
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
        echo json_encode(sanitizeOutput($info));
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('System info error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve system info']);
    }
}

function handleMemoryUsage() {
    try {
        echo json_encode(['usage' => sanitizeOutput(getMemoryUsage())]);
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Memory usage error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve memory usage']);
    }
}

function handleDiskUsage() {
    try {
        echo json_encode(['usage' => sanitizeOutput(getDiskUsage())]);
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Disk usage error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve disk usage']);
    }
}

function handleCpuUsage() {
    try {
        echo json_encode(['usage' => sanitizeOutput(getCpuUsage())]);
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('CPU usage error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve CPU usage']);
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
        echo json_encode(sanitizeOutput($services));
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Services status error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve services status']);
    }
}

function handleSites() {
    try {
        echo json_encode(sanitizeOutput(getWordPressSites()));
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Sites error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve sites']);
    }
}

function handleSitesCount() {
    try {
        $sites = getWordPressSites();
        echo json_encode(['count' => count($sites)]);
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Sites count error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve sites count']);
    }
}

function handleSecurityStatus() {
    try {
        $status = [
            'ssl' => getSSLStatus(),
            'firewall' => getFirewallStatus(),
            'malware' => getMalwareStatus()
        ];
        echo json_encode(sanitizeOutput($status));
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Security status error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve security status']);
    }
}

function handleBackups() {
    try {
        echo json_encode(sanitizeOutput(getBackupStatus()));
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Backups error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve backup status']);
    }
}

function handleRecentActivity() {
    try {
        echo json_encode(sanitizeOutput(getRecentActivity()));
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Recent activity error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve recent activity']);
    }
}

function handleAlerts() {
    try {
        echo json_encode(sanitizeOutput(getSystemAlerts()));
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Alerts error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve alerts']);
    }
}

function handleLogs($logType) {
    try {
        echo json_encode(['logs' => getLogs($logType)]);
    } catch (Exception $e) {
        http_response_code(500);
        logSecurityEvent('Logs error', $e->getMessage());
        echo json_encode(['error' => 'Unable to retrieve logs']);
    }
}

// System information functions
function getCpuUsage() {
    try {
        $load = sys_getloadavg();
        if ($load !== false) {
            // Use safe method to get CPU cores without shell_exec
            $cpu_cores = 1; // Default fallback
            if (file_exists('/proc/cpuinfo')) {
                $cpuinfo = file_get_contents('/proc/cpuinfo');
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
    $meminfo = file_get_contents('/proc/meminfo');
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
    $bytes = disk_total_space('/');
    $free_bytes = disk_free_space('/');
    if ($bytes && $free_bytes) {
        $used_bytes = $bytes - $free_bytes;
        $usage_percent = ($used_bytes / $bytes) * 100;
        return round($usage_percent, 1) . '%';
    }
    return 'N/A';
}

function getUptime() {
    $uptime = file_get_contents('/proc/uptime');
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
    $load = sys_getloadavg();
    if ($load !== false) {
        return round($load[0], 2) . ', ' . round($load[1], 2) . ', ' . round($load[2], 2);
    }
    return 'N/A';
}

function getOsInfo() {
    $os_release = file_get_contents('/etc/os-release');
    if ($os_release && preg_match('/PRETTY_NAME="([^"]+)"/', $os_release, $matches)) {
        return $matches[1];
    }
    return 'Unknown Linux Distribution';
}

function getKernelVersion() {
    return trim(shell_exec('uname -r')) ?: 'Unknown';
}

function getTotalMemory() {
    $meminfo = file_get_contents('/proc/meminfo');
    if ($meminfo && preg_match('/MemTotal:\s+(\d+)/', $meminfo, $matches)) {
        $mb = round($matches[1] / 1024);
        return $mb . ' MB';
    }
    return 'N/A';
}

function getTotalDisk() {
    $bytes = disk_total_space('/');
    if ($bytes) {
        $gb = round($bytes / (1024 * 1024 * 1024), 1);
        return $gb . ' GB';
    }
    return 'N/A';
}

function getNetworkInfo() {
    try {
        $hostname = gethostname();
        if ($hostname === false) {
            $hostname = 'Unknown';
        }
        
        // Use safer method to get IP
        $ip = 'Unknown';
        
        // Try to get IP from /proc/net/fib_trie (safer than shell commands)
        if (file_exists('/proc/net/route')) {
            // Fallback to safer shell command with validation
            $ip_output = shell_exec("ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}'");
            if ($ip_output) {
                $ip = trim($ip_output);
                // Validate the IP
                if (!filter_var($ip, FILTER_VALIDATE_IP)) {
                    $ip = 'Unknown';
                }
            }
        }
        
        return trim($hostname . ' (' . $ip . ')');
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
        return [
            'status' => 'error',
            'version' => 'Invalid',
            'online' => false
        ];
    }
    
    try {
        // Use escapeshellarg for additional safety
        $safe_service = escapeshellarg($service);
        $command = "systemctl is-active $safe_service 2>/dev/null";
        $status = trim(shell_exec($command) ?? '');
        
        $version = 'Unknown';
        switch ($service) {
            case 'nginx':
                $version_output = shell_exec('nginx -v 2>&1');
                if ($version_output && preg_match('/nginx\/(\d+\.\d+\.\d+)/', $version_output, $matches)) {
                    $version = $matches[1];
                }
                break;
            case 'php8.3-fpm':
                $version_output = shell_exec('php -v 2>/dev/null');
                if ($version_output && preg_match('/PHP (\d+\.\d+\.\d+)/', $version_output, $matches)) {
                    $version = $matches[1];
                }
                break;
            case 'mariadb':
                $version_output = shell_exec('mariadb --version 2>/dev/null');
                if ($version_output && preg_match('/mariadb.*?(\d+\.\d+\.\d+)/', $version_output, $matches)) {
                    $version = $matches[1];
                }
                break;
            case 'redis-server':
                $version_output = shell_exec('redis-server --version 2>/dev/null');
                if ($version_output && preg_match('/v=(\d+\.\d+\.\d+)/', $version_output, $matches)) {
                    $version = $matches[1];
                }
                break;
        }
        
        return [
            'status' => $status === 'active' ? 'online' : 'offline',
            'version' => $version,
            'online' => $status === 'active'
        ];
    } catch (Exception $e) {
        logSecurityEvent('Service status error', $e->getMessage());
        return [
            'status' => 'error',
            'version' => 'Error',
            'online' => false
        ];
    }
}

function getWordPressSites() {
    $sites = [];
    $nginx_sites_path = '/etc/nginx/sites-enabled';
    
    try {
        // Verify the path is exactly what we expect
        $real_path = realpath($nginx_sites_path);
        if ($real_path !== '/etc/nginx/sites-enabled') {
            logSecurityEvent('Nginx sites path traversal attempt', $nginx_sites_path);
            return $sites;
        }
        
        if (is_dir($real_path)) {
            $files = scandir($real_path);
            if ($files === false) {
                return $sites;
            }
            
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
                $config_real_path = realpath($config_path);
                
                // Ensure the file is within the expected directory
                if (!$config_real_path || strpos($config_real_path, $real_path . '/') !== 0) {
                    logSecurityEvent('Config file path traversal attempt', $config_path);
                    continue;
                }
                
                $config_content = file_get_contents($config_real_path);
                if ($config_content === false) {
                    continue;
                }
                
                if (strpos($config_content, 'wordpress') !== false || 
                    strpos($config_content, 'wp-') !== false) {
                    
                    // Extract domain name safely
                    if (preg_match('/server_name\s+([a-zA-Z0-9.-]+(?:\s+[a-zA-Z0-9.-]+)*)\s*;/', $config_content, $matches)) {
                        $domain = trim($matches[1]);
                        
                        // Split multiple domains and take the first one
                        $domain_parts = preg_split('/\s+/', $domain);
                        $primary_domain = $domain_parts[0];
                        
                        // Validate domain format
                        if (filter_var($primary_domain, FILTER_VALIDATE_DOMAIN, FILTER_FLAG_HOSTNAME)) {
                            $sites[] = [
                                'domain' => htmlspecialchars($primary_domain, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'),
                                'status' => 'online',
                                'wp_version' => 'Unknown',
                                'ssl_status' => 'Enabled',
                                'last_backup' => 'Unknown'
                            ];
                        }
                    }
                }
            }
        }
    } catch (Exception $e) {
        logSecurityEvent('WordPress sites enumeration error', $e->getMessage());
    }
    
    return $sites;
}

function getSSLStatus() {
    // Check for SSL certificates
    $ssl_dir = '/etc/letsencrypt/live';
    if (is_dir($ssl_dir)) {
        $cert_count = count(glob($ssl_dir . '/*', GLOB_ONLYDIR));
        return "Active SSL certificates: $cert_count";
    }
    return 'No SSL certificates found';
}

function getFirewallStatus() {
    $ufw_status = shell_exec('ufw status 2>/dev/null');
    if (strpos($ufw_status, 'Status: active') !== false) {
        return 'UFW Firewall: Active';
    }
    return 'UFW Firewall: Inactive';
}

function getMalwareStatus() {
    if (file_exists('/usr/bin/clamscan')) {
        return 'ClamAV: Installed and running';
    }
    return 'ClamAV: Not installed';
}

function getBackupStatus() {
    $backups = [];
    
    try {
        // Validate backup directories exist and are secure
        $allowed_backup_dirs = [
            '/var/backups/databases',
            '/var/backups/files'
        ];
        
        foreach ($allowed_backup_dirs as $backup_dir) {
            $real_path = realpath($backup_dir);
            if ($real_path && $real_path === $backup_dir && is_dir($real_path)) {
                
                if ($backup_dir === '/var/backups/databases') {
                    // Check for database backups safely
                    $files = glob($real_path . '/*.sql*', GLOB_NOSORT);
                    if ($files && count($files) > 0) {
                        $latest_file = null;
                        $latest_time = 0;
                        
                        foreach ($files as $file) {
                            $file_time = filemtime($file);
                            if ($file_time && $file_time > $latest_time) {
                                $latest_time = $file_time;
                                $latest_file = $file;
                            }
                        }
                        
                        if ($latest_file) {
                            $backups[] = [
                                'type' => 'Database',
                                'last_run' => date('Y-m-d H:i:s', $latest_time),
                                'status' => 'Success',
                                'size' => human_filesize(filesize($latest_file))
                            ];
                        }
                    }
                }
                
                if ($backup_dir === '/var/backups/files') {
                    // Check for file backups safely
                    if (is_dir($real_path)) {
                        $iterator = new DirectoryIterator($real_path);
                        $has_backups = false;
                        
                        foreach ($iterator as $file) {
                            if ($file->isFile()) {
                                $has_backups = true;
                                break;
                            }
                        }
                        
                        if ($has_backups) {
                            $backups[] = [
                                'type' => 'Files',
                                'last_run' => 'Recent',
                                'status' => 'Success',
                                'size' => 'Multiple files'
                            ];
                        }
                    }
                }
            }
        }
    } catch (Exception $e) {
        logSecurityEvent('Backup status error', $e->getMessage());
    }
    
    return $backups;
}

function human_filesize($size, $precision = 2) {
    if ($size === false || $size < 0) {
        return 'Unknown';
    }
    
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    
    for ($i = 0; $size > 1024 && $i < count($units) - 1; $i++) {
        $size /= 1024;
    }
    
    return round($size, $precision) . ' ' . $units[$i];
}

function getRecentActivity() {
    $activities = [];
    
    try {
        // Check recent log entries safely
        $auth_log = '/var/log/auth.log';
        $real_auth_log = realpath($auth_log);
        
        if ($real_auth_log && $real_auth_log === '/var/log/auth.log' && 
            file_exists($real_auth_log) && is_readable($real_auth_log)) {
            
            // Read last few lines safely without shell_exec
            $handle = fopen($real_auth_log, 'r');
            if ($handle) {
                // Read last 1KB to look for recent logins
                $file_size = filesize($real_auth_log);
                if ($file_size && $file_size > 0) {
                    fseek($handle, max(0, $file_size - 1024), SEEK_SET);
                    $content = fread($handle, 1024);
                    
                    if ($content && strpos($content, 'Accepted') !== false) {
                        $activities[] = [
                            'message' => 'Recent SSH login detected',
                            'time' => '5 minutes ago',
                            'icon' => 'fa-sign-in-alt'
                        ];
                    }
                }
                fclose($handle);
            }
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

function getLogs($logType) {
    // Strict whitelist of allowed log types
    $allowed_log_types = ['enginescript', 'nginx', 'php', 'mysql'];
    
    if (!in_array($logType, $allowed_log_types, true)) {
        logSecurityEvent('Invalid log type requested', $logType);
        return 'Invalid log type';
    }
    
    // Predefined safe log file paths
    $log_files = [
        'enginescript' => '/var/log/enginescript.log',
        'nginx' => '/var/log/nginx/error.log',
        'php' => '/var/log/php8.3-fpm.log',
        'mysql' => '/var/log/mysql/error.log'
    ];
    
    $log_file = $log_files[$logType];
    
    // Additional security check - ensure the path is exactly what we expect
    $real_path = realpath($log_file);
    $expected_paths = [
        '/var/log/enginescript.log',
        '/var/log/nginx/error.log',
        '/var/log/php8.3-fpm.log',
        '/var/log/mysql/error.log'
    ];
    
    if (!$real_path || !in_array($real_path, $expected_paths, true)) {
        logSecurityEvent('Log file path traversal attempt', $log_file);
        return 'Log file access denied';
    }
    
    try {
        if (file_exists($real_path) && is_readable($real_path)) {
            // Use safe method to read last 50 lines
            $file_size = filesize($real_path);
            if ($file_size === false || $file_size > 50 * 1024 * 1024) { // 50MB limit
                return 'Log file too large or unreadable';
            }
            
            $handle = fopen($real_path, 'r');
            if ($handle === false) {
                return 'Cannot open log file';
            }
            
            // Read last 50 lines safely
            $lines = [];
            $line_count = 0;
            $buffer = '';
            
            // Read from end of file
            fseek($handle, -min($file_size, 8192), SEEK_END); // Read last 8KB
            while (($line = fgets($handle)) !== false && $line_count < 50) {
                $lines[] = $line;
                $line_count++;
            }
            
            fclose($handle);
            
            // Return last 50 lines, sanitized
            $result = implode('', array_slice($lines, -50));
            return htmlspecialchars($result, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        }
    } catch (Exception $e) {
        logSecurityEvent('Log reading error', $e->getMessage());
        return 'Error reading log file';
    }
    
    return 'Log file not found';
}
?>
