<?php
/**
 * Tiny File Manager Integration for EngineScript Admin
 * Secure file management interface with restricted access
 * 
 * @version 1.0.0
 * @security HIGH - File system access
 */

// Security checks - prevent direct access
if (!isset($_SERVER['HTTP_HOST']) || !isset($_SERVER['REQUEST_URI'])) {
    http_response_code(403);
    die('Direct access forbidden');
}

// Basic authentication check (integrate with your auth system)
session_start();
$client_ip = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : 'unknown';

// Rate limiting for file operations
$rate_limit_key = 'fm_rate_' . hash('sha256', $client_ip);
if (!isset($_SESSION[$rate_limit_key])) {
    $_SESSION[$rate_limit_key] = ['count' => 0, 'reset' => time() + 300]; // 5 minute window
}

if (time() > $_SESSION[$rate_limit_key]['reset']) {
    $_SESSION[$rate_limit_key] = ['count' => 0, 'reset' => time() + 300];
}

if ($_SESSION[$rate_limit_key]['count'] >= 50) { // 50 operations per 5 minutes
    http_response_code(429);
    die('Rate limit exceeded for file operations');
}

$_SESSION[$rate_limit_key]['count']++;

// Security configuration for Tiny File Manager
$CONFIG = [
    // Authentication
    'auth' => true,
    'auth_users' => array(
        'admin' => '$2y$10$k9eBj8J6.1jDZMHxY/MqC.SqZwOZDKOGGgHI3xQKNLxWJj9KvyQnW' // Default: admin/admin123 (change this!)
    ),
    
    // Directories configuration
    'root_path' => '/var/www',
    'root_url' => '',
    'show_hidden_files' => false,
    'hide_Cols' => false,
    'readonly' => false,
    
    // Upload settings
    'upload_extension' => 'zip,rar,7z,tar,gz,txt,pdf,doc,docx,xls,xlsx,ppt,pptx,jpg,jpeg,png,gif,svg,mp3,mp4,avi,mov,wmv,sql',
    'max_upload_size_bytes' => 100 * 1024 * 1024, // 100MB
    'upload_overwrite' => false,
    
    // Security settings
    'exclude_items' => array(
        '.htaccess',
        '.htpasswd',
        'wp-config.php',
        '*.log',
        '/etc',
        '/var/log',
        '/root',
        '/home'
    ),
    'exclude_regex' => '/^\.|^wp-config\.php$|\.log$/',
    
    // UI settings
    'theme' => 'dark',
    'sticky_navbar' => true,
    'default_timezone' => 'UTC',
    'datetime_format' => 'Y-m-d H:i:s',
    'error_reporting' => false,
    'show_php_info' => false,
    'show_php_ver' => false,
    'check_updates' => false
];

// Set configuration constants for Tiny File Manager
foreach ($CONFIG as $key => $value) {
    if (!defined('FM_' . strtoupper($key))) {
        define('FM_' . strtoupper($key), $value);
    }
}

// Additional security headers
header('X-Frame-Options: SAMEORIGIN');
header('X-Content-Type-Options: nosniff');
header('X-XSS-Protection: 1; mode=block');
header('Referrer-Policy: strict-origin-when-cross-origin');

// Log file manager access
$log_entry = date('Y-m-d H:i:s') . " [FILE_MANAGER] Access from IP: " . $client_ip . "\n";
error_log($log_entry, 3, '/var/log/enginescript-filemanager.log');

// Download and include Tiny File Manager
$tfm_file = __DIR__ . '/tinyfilemanager.php';
$tfm_url = 'https://raw.githubusercontent.com/prasathmani/tinyfilemanager/master/tinyfilemanager.php';

// Download TFM if not exists or older than 30 days
if (!file_exists($tfm_file) || (time() - filemtime($tfm_file)) > (30 * 24 * 60 * 60)) {
    $tfm_content = @file_get_contents($tfm_url);
    if ($tfm_content !== false) {
        file_put_contents($tfm_file, $tfm_content);
        chmod($tfm_file, 0644);
    } else {
        die('Unable to download Tiny File Manager. Please check internet connection.');
    }
}

// Include Tiny File Manager
if (file_exists($tfm_file)) {
    include $tfm_file;
} else {
    die('Tiny File Manager not found. Please check installation.');
}
?>
