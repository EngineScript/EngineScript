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

// Load file manager configuration
$fm_config_file = '/etc/enginescript/filemanager.conf';
$fm_config = [];

if (file_exists($fm_config_file)) {
    $config_content = file_get_contents($fm_config_file);
    $config_lines = explode("\n", $config_content);
    
    foreach ($config_lines as $line) {
        $line = trim($line);
        if (empty($line) || strpos($line, '#') === 0) {
            continue; // Skip empty lines and comments
        }
        
        if (strpos($line, '=') !== false) {
            list($key, $value) = explode('=', $line, 2);
            $fm_config[trim($key)] = trim($value);
        }
    }
}

// Set values from configuration file only - no defaults
$fm_username = isset($fm_config['fm_username']) && !empty($fm_config['fm_username']) ? $fm_config['fm_username'] : null;
$fm_password_hash = isset($fm_config['fm_password_hash']) && !empty($fm_config['fm_password_hash']) ? $fm_config['fm_password_hash'] : null;

// Check if credentials are properly configured
if (empty($fm_username) || empty($fm_password_hash)) {
    // Check if main credentials file exists and has been configured
    if (file_exists('/home/EngineScript/enginescript-install-options.txt')) {
        $credentials_content = file_get_contents('/home/EngineScript/enginescript-install-options.txt');
        
        // Check if credentials are still PLACEHOLDER values
        if (strpos($credentials_content, 'FILEMANAGER_USERNAME="PLACEHOLDER"') !== false ||
            strpos($credentials_content, 'FILEMANAGER_PASSWORD="PLACEHOLDER"') !== false) {
            
            die('File Manager credentials not configured. Please edit your credentials file with command: es.config');
        } else {
            // Credentials configured but config file not updated
            die('File Manager configuration needs to be updated. Please run: sudo /usr/local/bin/enginescript/scripts/functions/shared/update-config-files.sh');
        }
    } else {
        die('EngineScript credentials file not found. Please ensure EngineScript is properly installed.');
    }
}

$fm_root_path = isset($fm_config['fm_root_path']) && !empty($fm_config['fm_root_path']) ? $fm_config['fm_root_path'] : '/var/www';
$fm_max_upload = isset($fm_config['fm_max_upload_size']) && !empty($fm_config['fm_max_upload_size']) ? (int)$fm_config['fm_max_upload_size'] : 104857600;
$fm_readonly = isset($fm_config['fm_readonly']) && $fm_config['fm_readonly'] === 'true' ? true : false;

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

// Modify TFM file to use our credentials
if (file_exists($tfm_file)) {
    $tfm_content = file_get_contents($tfm_file);
    
    // Replace the hardcoded auth_users array with our credentials
    $new_auth_array = '$auth_users = array(\'' . $fm_username . '\' => \'' . $fm_password_hash . '\');';
    
    // Pattern to match the existing $auth_users array (handles multi-line arrays)
    $pattern = '/\$auth_users\s*=\s*array\s*\([^;]*\);/s';
    
    if (preg_match($pattern, $tfm_content)) {
        $tfm_content = preg_replace($pattern, $new_auth_array, $tfm_content);
        file_put_contents($tfm_file, $tfm_content);
    }
    
    include $tfm_file;
} else {
    die('Tiny File Manager not found. Please check installation.');
}
?>
