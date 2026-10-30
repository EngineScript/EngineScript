<?php

/**
 * EngineScript TinyFileManager Configuration
 * Dynamic configuration using EngineScript credentials
 */

declare(strict_types=1);

// The login: JSON written by update-config-files.sh (which es.update runs) from
// FILEMANAGER_USERNAME and FILEMANAGER_PASSWORD in the install options. It holds a hash of the
// password, so the web server never reads the install options file.
$es_fm_login_file = '/var/lib/enginescript/admin/tinyfilemanager-auth.json';
$es_fm_login_json = is_readable($es_fm_login_file) ? file_get_contents($es_fm_login_file) : false;
$es_fm_login = is_string($es_fm_login_json) ? json_decode($es_fm_login_json, true) : null;

// Security check - fail if credentials are not properly configured
if (
    !is_array($es_fm_login)
    || !isset($es_fm_login['username'], $es_fm_login['password_hash'])
    || !is_string($es_fm_login['username'])
    || !is_string($es_fm_login['password_hash'])
    || $es_fm_login['username'] === ''
    || $es_fm_login['password_hash'] === ''
) {
    http_response_code(503);
    die('File Manager Error: Credentials not configured. Set FILEMANAGER_USERNAME and FILEMANAGER_PASSWORD with "es.config", then run "es.update".');
}

// Authentication array: username => password hash
$auth_users = [
    $es_fm_login['username'] => $es_fm_login['password_hash'],
];

// Set as non-global auth
$use_auth = true;
$readonly_users = [];

// Root path for file browsing - restrict to web directories
$root_path = '/var/www';

// Root URL for links (leave blank for auto-detection)
$root_url = '';

// Max upload size in bytes (100MB)
$max_upload_size_bytes = 104857600;

// Exclude specific files/folders from listing
$exclude_items = [
    '.git',
    '.github',
    '.gitignore',
    '.htaccess',
    'config.php',
];

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
