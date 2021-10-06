<?php
// wp-config.php
// Created automatically with Enginescript
// https://EngineScript.com

/* MySQL settings - You can get this info from your web host */
define('DB_NAME',	'SEDWPDB');
define('DB_USER',	'SEDWPUSER');
define('DB_PASSWORD',	'SEDWPPASS');
define('DB_CHARSET',	'utf8mb4');
define('DB_HOST',	'localhost');
define('DB_COLLATE',	'');

/* MySQL database table prefix. */
$table_prefix = 'SEDPREFIX_';

/* Site Details */
define('WP_HOME', 'https://SEDURL');
define('WP_SITEURL', 'https://SEDURL');
define('WP_CONTENT_URL', 'https://SEDURL/wp-content');
define('WP_PLUGIN_URL', 'https://SEDURL/wp-content/plugins');
define('UPLOADS', 'wp-content/uploads');

/* Salt Keys */
// Generate new keys at https://api.wordpress.org/secret-key/1.1/salt/
// You can change these at any point in time to invalidate all existing cookies.
// Changing these keys will force all users to log in again next time they visit.
define('AUTH_KEY',         'put your unique phrase here');
define('SECURE_AUTH_KEY',  'put your unique phrase here');
define('LOGGED_IN_KEY',    'put your unique phrase here');
define('NONCE_KEY',        'put your unique phrase here');
define('AUTH_SALT',        'put your unique phrase here');
define('SECURE_AUTH_SALT', 'put your unique phrase here');
define('LOGGED_IN_SALT',   'put your unique phrase here');
define('NONCE_SALT',       'put your unique phrase here');

/* SSL */
define('FORCE_SSL_ADMIN', true);
define('FORCE_SSL_LOGIN', true);

/* Multisite */
define('WP_ALLOW_MULTISITE', false);

/* Redis Object Cache	*/
define('WP_CACHE_KEY_SALT',	'SEDURL');
define('WP_REDIS_DISABLE_BANNERS',	'true');
define('WP_REDIS_IGBINARY',	'true');
define('WP_REDIS_MAXTTL',	'300');
//define('WP_REDIS_PATH',	'/run/redis/redis-server.sock');
define('WP_REDIS_PREFIX',	'SEDURL');
//define('WP_REDIS_SCHEME', 'unix');
define('WP_REDIS_SELECTIVE_FLUSH', 'true');

/* Nginx Helper FastCGI Cache Path	*/
define('RT_WP_NGINX_HELPER_CACHE_PATH','/var/cache/nginx/');

/* Performance */
define('WP_MAX_MEMORY_LIMIT', '300M');
define('WP_MEMORY_LIMIT', '256M');

/* WP-Cron */
define( 'WP_CRON_LOCK_TIMEOUT', 60 );

/* Cloudflare Plugin HTTP2 Server Push */
define('CLOUDFLARE_HTTP2_SERVER_PUSH_ACTIVE', true);

/* Updates */
define('WP_AUTO_UPDATE_CORE', 'minor');

/* Editing */
define('DISALLOW_FILE_EDIT', true);
define('DISALLOW_FILE_MODS', false);

/* File Permissions */
define('FS_CHMOD_DIR', 0755);
define('FS_CHMOD_FILE', 0644);

/* Content */
define('AUTOSAVE_INTERVAL', 60);	// Time in seconds
define('EMPTY_TRASH_DAYS', 14);	// Setting to 0 causes all deletions skip the trash folder and are permanent.
define('IMAGE_EDIT_OVERWRITE', true);
define('MEDIA_TRASH', true);
define('WP_POST_REVISIONS', 2);	// Can also be set to false
define('ALLOW_UNFILTERED_UPLOADS', false);	// Allows admins to upload files that would normally be filtered by WordPress by default.

/* Disable Nag Notices */
// https://codex.wordpress.org/Plugin_API/Action_Reference/admin_notices
define('DISABLE_NAG_NOTICES', true);

/* WP-CLI 10Up Vulnerability Scanner */
// Register for an account at https://wpscan.com/api
define('VULN_API_TOKEN', 'SEDWPSCANAPI');
define('WP_CLI_BIN_DIR', '/tmp/wp-cli-phar');
define('WP_CLI_CONFIG_PATH', '/tmp/wp-cli-phar/config.yml');

/* Debug */
define('WP_DEBUG', false);	// Set to true if you want to debug
define('CONCATENATE_SCRIPTS', true);	// Setting to false may fix java issues in dashboard only
define('SAVEQUERIES', false);	// https://codex.wordpress.org/Editing_wp-config.php#Save_queries_for_analysis
define('SCRIPT_DEBUG', false);	// Use dev versions of core JS and CSS files (only needed if you are modifying these core files)
define('WP_ALLOW_REPAIR', false);	// https://SEDURL/wp-admin/maint/repair.php - Make sure to disable this once you're done. Anyone can trigger this.
define('WP_DEBUG_DISPLAY', false);	// Displays logs within browser on site. Not for production environments.
define('WP_DEBUG_LOG', '/var/log/domains/SEDURL/SEDURL-wp-error.log' ); // Only writes log if WP_DEBUG is set to true.

/* Compression */
// Leave these disabled unless you absolutely need them for whatever reason. This is done with Nginx and Cloudflare.
//define('COMPRESS_CSS',	true);
//define('COMPRESS_SCRIPTS',	true);
//define('ENFORCE_GZIP',	true);

/* Security Headers */
// Leave these disabled unless you absolutely need them for whatever reason. This is done with Nginx and Cloudflare.
//header('X-Frame-Options: SAMEORIGIN');
//header('X-XSS-Protection: 1; mode=block');
//header('X-Content-Type-Options: nosniff');
//header('Referrer-Policy: no-referrer');
//header('Expect-CT enforce; max-age=3600');

// Don't change things below this line
/* Absolute path to the WordPress directory. */
if ( !defined('ABSPATH') )
	define('ABSPATH', dirname(__FILE__) . '/');

/* Sets up WordPress vars and included files. */
require_once(ABSPATH . 'wp-settings.php');
