<?php
/**
 * EngineScript TinyFileManager Configuration
 * Basic configuration for official TinyFileManager
 */

// Basic authentication - users can modify this file directly
$auth_users = array(
    'admin' => '$2y$10$3F7VnbFpPHIyFODrUQOgXKvGLgKfBgHZQT7xU8xvQ9qLpG3Rn7bCy' // password: admin
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
