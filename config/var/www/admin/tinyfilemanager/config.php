<?php
/**
 * EngineScript TinyFileManager Configuration
 * Dynamic configuration using EngineScript credentials
 */

// Load credentials from EngineScript install options
$credentials_file = '/home/EngineScript/enginescript-install-options.txt';
$fm_username = null;
$fm_password = null;

if (file_exists($credentials_file)) { // codacy:ignore - file_exists() required for configuration file checking in standalone service
    $content = file_get_contents($credentials_file); // codacy:ignore - file_get_contents() required for configuration reading in standalone service
    
    // Extract FILEMANAGER_USERNAME
    if (preg_match('/FILEMANAGER_USERNAME="([^"]*)"/', $content, $matches)) {
        $extracted_username = trim($matches[1]);
        if (!empty($extracted_username) && $extracted_username !== 'PLACEHOLDER') {
            $fm_username = $extracted_username;
        }
    }
    
    // Extract FILEMANAGER_PASSWORD
    if (preg_match('/FILEMANAGER_PASSWORD="([^"]*)"/', $content, $matches)) {
        $extracted_password = trim($matches[1]);
        if (!empty($extracted_password) && $extracted_password !== 'PLACEHOLDER') {
            $fm_password = $extracted_password;
        }
    }
}

// Security check - fail if credentials are not properly configured
if (empty($fm_username) || empty($fm_password)) {
    http_response_code(503);
    die('File Manager Error: Credentials not configured. Please run "es.config" to set FILEMANAGER_USERNAME and FILEMANAGER_PASSWORD.'); // codacy:ignore - die() required for secure failure in standalone service
}

// Generate authentication array with hashed password
$auth_users = array(
    $fm_username => password_hash($fm_password, PASSWORD_DEFAULT)
);

// Set as non-global auth
$use_auth = true;
$readonly_users = array();

// Root path for file browsing - restrict to web directories
$root_path = '/var/www';

// Root URL for links (leave blank for auto-detection)
$root_url = '';

// Max upload size in bytes (100MB)
$max_upload_size_bytes = 104857600;

// Exclude specific files/folders from listing
$exclude_items = array(
    '.git',
    '.github',
    '.gitignore',
    '.htaccess',
    'config.php'
);

// Theme (light, dark)
$theme = 'light';

// Default timezone
date_default_timezone_set('UTC');

// Edit files in popup or same window
$edit_files = true;

// Enable/disable file and folder management
$readonly = false;

// Session name for authentication
$session_name = 'filemanager';

// Show directory size
$show_dirs_size = false;

// Check for updates
$check_for_updates = false;

// Online office viewer
$online_viewer = false;

// Sticky navbar
$sticky_navbar = true;
?>
