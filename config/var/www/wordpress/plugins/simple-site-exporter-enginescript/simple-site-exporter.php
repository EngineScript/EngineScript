<?php
/*
Plugin Name: EngineScript: Simple Site Exporter
Description: Exports the site files and database as a zip archive.
Version: 1.5.2
Author: EngineScript
License: GPL v2 or later
Text Domain: simple-site-exporter-enginescript
*/

// Prevent direct access. Note: Using return here instead of exit.
if ( ! defined( 'ABSPATH' ) ) {
    return; // Prevent direct access
}

// Define plugin version
if (!defined('ES_SITE_EXPORTER_VERSION')) {
    define('ES_SITE_EXPORTER_VERSION', '1.5.2');
}

// --- Admin Menu ---
function sse_admin_menu() {
    add_management_page(
        esc_html__( 'Simple Site Exporter', 'simple-site-exporter-enginescript' ), // Escaped title
        esc_html__( 'Site Exporter', 'simple-site-exporter-enginescript' ),       // Escaped menu title
        'manage_options', // Capability required
        'simple-site-exporter',
        'sse_exporter_page_html'
    );
}
add_action( 'admin_menu', 'sse_admin_menu' );

// --- Exporter Page HTML ---
function sse_exporter_page_html() {
    if ( ! current_user_can( 'manage_options' ) ) {
        wp_die( esc_html__( 'You do not have permission to view this page.', 'simple-site-exporter-enginescript' ), 403 );
    }

    $upload_dir = wp_upload_dir();
    if ( empty( $upload_dir['basedir'] ) ) {
         wp_die( esc_html__( 'Could not determine the WordPress upload directory.', 'simple-site-exporter-enginescript' ) );
    }
    $export_dir_name = 'enginescript-sse-site-exports';
    $export_dir_path = $upload_dir['basedir'] . '/' . $export_dir_name;
    $display_path = str_replace( ABSPATH, '', $export_dir_path );
    ?>
    <div class="wrap">
        <h1><?php esc_html_e( get_admin_page_title(), 'simple-site-exporter-enginescript' ); // Use esc_html_e for translatable titles ?></h1>
        <p><?php esc_html_e( 'Click the button below to generate a zip archive containing your WordPress files and a database dump (.sql file).', 'simple-site-exporter-enginescript' ); ?></p>
        <p><strong><?php esc_html_e( 'Warning:', 'simple-site-exporter-enginescript' ); ?></strong> <?php esc_html_e( 'This can take a long time and consume significant server resources, especially on large sites. Ensure your server has sufficient disk space and execution time.', 'simple-site-exporter-enginescript' ); ?></p>
        <p style="margin-top: 15px;">
            <?php
            // printf is standard in WordPress for translatable strings with placeholders. All variables are escaped.
            printf(
                /* translators: %s: directory path */
                esc_html__( 'Exported .zip files will be saved in the following directory on the server: %s', 'simple-site-exporter-enginescript' ),
                '<code>' . esc_html( $display_path ) . '</code>'
            );
            ?>
        </p>
        <form method="post" action="" style="margin-top: 15px;">
            <?php wp_nonce_field( 'sse_export_action', 'sse_export_nonce' ); ?>
            <input type="hidden" name="action" value="sse_export_site">
            <?php submit_button( esc_html__( 'Export Site', 'simple-site-exporter-enginescript' ) ); ?>
        </form>
        <hr>
        <p>
            <?php esc_html_e( 'This plugin is part of the EngineScript project.', 'simple-site-exporter-enginescript' ); ?>
            <a href="https://github.com/EngineScript/EngineScript" target="_blank" rel="noopener noreferrer">
                <?php esc_html_e( 'Visit the EngineScript GitHub page', 'simple-site-exporter-enginescript' ); ?>
            </a>
        </p>
        <p style="color: #b94a48; font-weight: bold;">
            <?php esc_html_e( 'Important:', 'simple-site-exporter-enginescript' ); ?>
            <?php esc_html_e( 'The exported zip file is publicly accessible while it remains in the above directory. For security, you should remove the exported file from the server once you are finished downloading it.', 'simple-site-exporter-enginescript' ); ?>
        </p>
        <p style="color: #b94a48; font-weight: bold;">
            <?php esc_html_e( 'Security Notice:', 'simple-site-exporter-enginescript' ); ?>
            <?php esc_html_e( 'For your protection, the exported zip file will be automatically deleted from the server 1 hour after it is created.', 'simple-site-exporter-enginescript' ); ?>
        </p>
        <p style="color: #31708f;">
            <?php esc_html_e( 'Note:', 'simple-site-exporter-enginescript' ); ?>
            <?php
                // Direct use of $_SERVER is necessary for domain display. Value is unslashed and sanitized immediately.
                $current_domain = isset( $_SERVER['HTTP_HOST'] ) ? sanitize_text_field( wp_unslash( $_SERVER['HTTP_HOST'] ) ) : 'DOMAIN';
                printf(
                    esc_html__( 'If you are running EngineScript, a cronjob will run once an hour to automatically move the exported zip file to a non-public directory inside /var/www/sites/%s/enginescript-sse-site-exports for improved security.', 'simple-site-exporter-enginescript' ),
                    esc_html( $current_domain )
                );
            ?>
        </p>
    </div>
    <?php
}

// --- Handle Export Action ---
/**
 * Handles the site export process when the form is submitted.
 *
 * @todo This function is too long (>100 lines) and complex (Cyclomatic > 10, NPath > 200). Consider refactoring into smaller functions.
 */
function sse_handle_export() {
    // Sanitize and retrieve action from POST data
    // Note: Accessing $_POST directly is necessary for form handling.
    // Values are immediately sanitized and assigned to local variables.
    $post_action = isset( $_POST['action'] ) ? sanitize_key( $_POST['action'] ) : '';
    if ( 'sse_export_site' !== $post_action ) {
        return;
    }

    // Sanitize, unslash, and verify nonce from POST data
    $post_nonce = isset( $_POST['sse_export_nonce'] ) ? sanitize_text_field( wp_unslash( $_POST['sse_export_nonce'] ) ) : '';
    if ( ! $post_nonce || ! wp_verify_nonce( $post_nonce, 'sse_export_action' ) ) {
        wp_die( esc_html__( 'Nonce verification failed! Please try again.', 'simple-site-exporter-enginescript' ), 403 );
    }

    // Check user capabilities
    if ( ! current_user_can( 'manage_options' ) ) {
        wp_die( esc_html__( 'You do not have permission to perform this action.', 'simple-site-exporter-enginescript' ), 403 );
    }

    // Increase execution time limit
    // Note: set_time_limit is discouraged but often necessary for potentially long-running exports.
    // Alternatives like background processing add significant complexity.
    if (function_exists('set_time_limit') && !ini_get('safe_mode')) {
        set_time_limit( 0 );
    }

    $upload_dir = wp_upload_dir();
    if ( empty( $upload_dir['basedir'] ) || empty( $upload_dir['baseurl'] ) ) {
         wp_die( esc_html__( 'Could not determine the WordPress upload directory or URL.', 'simple-site-exporter-enginescript' ) );
    }
    $export_dir_name = 'enginescript-sse-site-exports';
    $export_dir = $upload_dir['basedir'] . '/' . $export_dir_name;
    $export_url = $upload_dir['baseurl'] . '/' . $export_dir_name;
    wp_mkdir_p( $export_dir ); // Ensure the directory exists

    // Add an index.php file to prevent directory listing
    // Note: file_exists and file_put_contents are discouraged but used here for a simple,
    // non-critical check/write within the known writable uploads directory.
    // WP_Filesystem API adds overhead for this minor task.
    $index_file_path = $export_dir . '/index.php';
    if ( ! file_exists( $index_file_path ) ) {
        // Use WordPress Filesystem API instead of direct file operations
        global $wp_filesystem;
        if ( ! $wp_filesystem ) {
            require_once ABSPATH . 'wp-admin/includes/file.php';
            WP_Filesystem();
        }
        
        if ( $wp_filesystem ) {
            $wp_filesystem->put_contents(
                $index_file_path,
                '<?php // Silence is golden.',
                FS_CHMOD_FILE
            );
        } else {
            error_log('Simple Site Exporter: Failed to initialize WordPress filesystem API');
            // Fallback to direct method only if WP_Filesystem fails
            @file_put_contents( $index_file_path, '<?php // Silence is golden.' );
        }
    }

    $site_name = sanitize_file_name( get_bloginfo( 'name' ) );
    $timestamp = date( 'Y-m-d_H-i-s' );
    $random_str = substr( bin2hex( random_bytes(4) ), 0, 7 );
    $db_filename = "db_dump_{$site_name}_{$timestamp}.sql";
    $zip_filename = "site_export_sse_{$random_str}_{$site_name}_{$timestamp}.zip";
    $db_filepath = $export_dir . '/' . $db_filename;
    $zip_filepath = $export_dir . '/' . $zip_filename;
    $zip_fileurl = $export_url . '/' . $zip_filename;

    // --- 1. Database Export (WP-CLI recommended) ---
    $db_exported = false;
    $db_error = '';
    // Note: shell_exec is required for WP-CLI integration. Ensure server security and that the command is properly escaped.
    if ( function_exists('shell_exec') ) {
        $wp_cli_path = trim(shell_exec('which wp'));
        
        // Validate the wp-cli path before using it
        if (!empty($wp_cli_path) && file_exists($wp_cli_path) && (strpos($wp_cli_path, '/') === 0 || strpos($wp_cli_path, '\\') === 0)) {
            // Note: escapeshellarg is used to sanitize arguments passed to shell_exec.
            $command = sprintf(
                '%s db export %s --path=%s --allow-root',
                escapeshellarg($wp_cli_path),
                escapeshellarg($db_filepath),
                escapeshellarg(ABSPATH)
            );
            $output = shell_exec($command . ' 2>&1');
            // Note: file_exists and filesize are standard for checking command output files.
            if ( file_exists( $db_filepath ) && filesize( $db_filepath ) > 0 ) {
                $db_exported = true;
            } else {
                 $db_error = !empty($output) ? trim($output) : 'WP-CLI command failed silently.';
            }
        } else {
             $db_error = esc_html__( 'Invalid WP-CLI path detected.', 'simple-site-exporter-enginescript' );
        }
    } else {
         $db_error = esc_html__( 'shell_exec function is disabled on this server.', 'simple-site-exporter-enginescript' );
    }

    // Handle DB Export Failure - Show notice and stop
    // Note: Refactored to avoid unnecessary else clause.
    if ( ! $db_exported ) {
        add_action( 'admin_notices', function() use ($db_error) {
             ?>
             <div class="notice notice-error is-dismissible">
                 <p><?php
                    printf(
                        /* translators: %s: error message */
                        esc_html__( 'Database export failed: %s. Export process halted.', 'simple-site-exporter-enginescript' ),
                        '<strong>' . esc_html( $db_error ) . '</strong>'
                    );
                 ?></p>
             </div>
             <?php
        });
        error_log("Simple Site Exporter: DB export failed - " . $db_error);
        return; // Stop the export process
    }

    // --- 2. File Export (ZipArchive) ---
    if ( ! class_exists( 'ZipArchive' ) ) {
         add_action( 'admin_notices', function() {
             ?>
             <div class="notice notice-error is-dismissible">
                 <p><?php esc_html_e( 'ZipArchive class is not available on your server. Cannot create zip file.', 'simple-site-exporter-enginescript' ); ?></p>
             </div>
             <?php
         });
         // Note: file_exists and @unlink are used for cleanup of self-created temp files.
         // WP_Filesystem->delete() adds complexity here.
         if ( file_exists( $db_filepath ) ) {
            @unlink( $db_filepath );
         }
         return; // Stop
    }

    $zip = new ZipArchive();
    if ( $zip->open( $zip_filepath, ZipArchive::CREATE | ZipArchive::OVERWRITE ) !== TRUE ) {
        add_action( 'admin_notices', function() use ($zip_filepath) {
             $display_zip_path = str_replace( ABSPATH, '', $zip_filepath );
             ?>
             <div class="notice notice-error is-dismissible">
                 <p><?php
                    printf(
                        /* translators: %s: file path */
                        esc_html__( 'Could not create zip file at %s', 'simple-site-exporter-enginescript' ),
                        '<code>' . esc_html( $display_zip_path ) . '</code>'
                    );
                 ?></p>
             </div>
             <?php
         });
         // Cleanup DB dump if zip creation failed
         // Note: file_exists and @unlink used for cleanup.
         if ( file_exists( $db_filepath ) ) {
            @unlink( $db_filepath );
         }
         return; // Stop
    }

    // Add Database Dump to Zip
    // Note: file_exists is standard here for checking if the DB dump was created.
    if ( $db_exported && file_exists( $db_filepath ) ) {
        if ( ! $zip->addFile( $db_filepath, $db_filename ) ) {
             error_log( "Simple Site Exporter: Failed to add DB file to zip: " . $db_filepath );
        }
    }

    // Add WordPress Files
    // Note: realpath is discouraged but useful for resolving the absolute path.
    // Fallback to ABSPATH if realpath fails.
    $source_path = realpath( ABSPATH );
    if ( ! $source_path ) {
        error_log( "Simple Site Exporter: Could not resolve real path for ABSPATH. Using ABSPATH directly." );
        $source_path = ABSPATH; // Fallback
    }

    try {
        $files = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator( $source_path, RecursiveDirectoryIterator::SKIP_DOTS | FilesystemIterator::UNIX_PATHS ),
            RecursiveIteratorIterator::SELF_FIRST
        );

        foreach ( $files as $file_info ) {
            if ( ! $file_info->isReadable() ) {
                error_log( "Simple Site Exporter: Skipping unreadable file/dir: " . $file_info->getPathname() );
                continue;
            }

            $file = $file_info->getRealPath();
            $pathname = $file_info->getPathname();
            $relativePath = ltrim( substr( $pathname, strlen( $source_path ) ), '/' );

            if ( empty($relativePath) ) continue;

            // --- Exclusions ---
            if ( strpos( $pathname, $export_dir ) === 0 ) continue;
            if ( preg_match( '#^wp-content/(cache|upgrade|temp)/#', $relativePath ) ) continue;
            if ( preg_match( '#(^|/)\.(git|svn|hg|DS_Store|htaccess|user\.ini)$#i', $relativePath ) ) continue;

            if ( $file_info->isDir() ) {
                if ( ! $zip->addEmptyDir( $relativePath ) ) {
                     error_log( "Simple Site Exporter: Failed to add directory to zip: " . $relativePath );
                }
            } elseif ( $file_info->isFile() ) {
                $file_to_add = ($file !== false) ? $file : $pathname;
                 if ( ! $zip->addFile( $file_to_add, $relativePath ) ) {
                     error_log( "Simple Site Exporter: Failed to add file to zip: " . $relativePath . " (Source: " . $file_to_add . ")" );
                 }
            }
        } // End foreach
    } catch ( Exception $e ) {
        // Cleanup potentially created files
        // Note: file_exists and @unlink used for cleanup.
        if ( file_exists( $zip_filepath ) ) @unlink( $zip_filepath );
        if ( file_exists( $db_filepath ) ) @unlink( $db_filepath );

        add_action( 'admin_notices', function() use ($e) {
             ?>
             <div class="notice notice-error is-dismissible">
                 <p><?php
                    printf(
                        /* translators: %s: error message */
                        esc_html__( 'Error during file processing: %s', 'simple-site-exporter-enginescript' ),
                        '<strong>' . esc_html( $e->getMessage() ) . '</strong>'
                    );
                 ?></p>
             </div>
             <?php
         });
         error_log("Simple Site Exporter: Exception during file iteration - " . $e->getMessage());
         return; // Stop
    }

    $zip_close_status = $zip->close();

    // --- 3. Cleanup temporary DB file ---
    // Note: file_exists and @unlink are acceptable for cleanup of self-created temp files.
    if ( $db_exported && file_exists( $db_filepath ) ) {
        sse_safely_delete_file( $db_filepath );
    }

    // --- 4. Report Success or Failure ---
    // Note: file_exists is standard for checking if the final output file was created.
    if ( $zip_close_status && file_exists( $zip_filepath ) ) {
        // Schedule deletion of the export file after 1 hour
        if ( ! wp_next_scheduled( 'sse_delete_export_file', array( $zip_filepath ) ) ) {
            wp_schedule_single_event( time() + HOUR_IN_SECONDS, 'sse_delete_export_file', array( $zip_filepath ) );
        }
        add_action( 'admin_notices', function() use ( $zip_filename, $zip_filepath ) {
            $download_url = add_query_arg(
                array(
                    'sse_secure_download' => $zip_filename,
                    'sse_download_nonce' => wp_create_nonce('sse_secure_download')
                ),
                admin_url()
            );
            
            $delete_url = add_query_arg(
                array(
                    'sse_delete_export' => $zip_filename,
                    'sse_delete_nonce' => wp_create_nonce('sse_delete_export')
                ),
                admin_url()
            );
            
            $display_zip_path = str_replace( ABSPATH, '', $zip_filepath );
            ?>
            <div class="notice notice-success is-dismissible">
                <p>
                    <?php esc_html_e( 'Site export successfully created!', 'simple-site-exporter-enginescript' ); ?>
                    <a href="<?php echo esc_url( $download_url ); ?>" class="button" style="margin-left: 10px;">
                        <?php esc_html_e( 'Download Export File', 'simple-site-exporter-enginescript' ); ?>
                    </a>
                    <a href="<?php echo esc_url( $delete_url ); ?>" class="button button-secondary" style="margin-left: 10px;" onclick="return confirm('<?php esc_attr_e( 'Are you sure you want to delete this export file?', 'simple-site-exporter-enginescript' ); ?>');">
                        <?php esc_html_e( 'Delete Export File', 'simple-site-exporter-enginescript' ); ?>
                    </a>
                </p>
                <p><small><?php
                    printf(
                        /* translators: %s: file path */
                        esc_html__( 'File location: %s', 'simple-site-exporter-enginescript' ),
                        '<code>' . esc_html( $display_zip_path ) . '</code>'
                    );
                 ?></small></p>
            </div>
            <?php
        });
        error_log("Simple Site Exporter: Export successful. File saved to " . $zip_filepath);
    } else {
        // Add a generic error notice if the zip failed at the end
         add_action( 'admin_notices', function() {
             ?>
             <div class="notice notice-error is-dismissible">
                 <p><?php esc_html_e( 'Failed to finalize or save the zip archive after processing files.', 'simple-site-exporter-enginescript' ); ?></p>
             </div>
             <?php
         });
         // Note: file_exists is appropriate for logging state.
         error_log("Simple Site Exporter: Export failed. Zip close status: " . ($zip_close_status ? 'OK' : 'FAIL') . ", File exists: " . (file_exists($zip_filepath) ? 'Yes' : 'No'));
         // Attempt cleanup using @unlink, acceptable for self-created files.
         // Note: file_exists and @unlink used for cleanup.
         if ( file_exists( $zip_filepath ) ) {
            @unlink( $zip_filepath );
         }
    }
}
add_action( 'admin_init', 'sse_handle_export' );

// --- Scheduled Deletion Handler ---
function sse_delete_export_file_handler( $file ) {
    if ( file_exists( $file ) ) {
        sse_safely_delete_file( $file );
        error_log( 'Simple Site Exporter: Scheduled deletion of export file: ' . $file );
    }
}
add_action( 'sse_delete_export_file', 'sse_delete_export_file_handler' );

/**
 * Safely delete a file using WordPress Filesystem API
 *
 * @param string $filepath Path to the file to delete
 * @return bool Whether the file was deleted successfully
 */
function sse_safely_delete_file($filepath) {
    global $wp_filesystem;
    
    // Initialize the WordPress filesystem
    if (empty($wp_filesystem)) {
        require_once ABSPATH . 'wp-admin/includes/file.php';
        WP_Filesystem();
    }
    
    if (!$wp_filesystem) {
        error_log('Simple Site Exporter: Failed to initialize WordPress filesystem API');
        return false;
    }
    
    // Check if the file exists using WP Filesystem
    if ($wp_filesystem->exists($filepath)) {
        // Delete the file using WordPress Filesystem API
        return $wp_filesystem->delete($filepath, false, 'f');
    }
    
    return false;
}

/**
 * Validate export download request parameters
 * 
 * @param string $filename The filename to validate
 * @return array|WP_Error Result array with file path and size or WP_Error on failure
 */
function sse_validate_download_request($filename) {
    if (empty($filename)) {
        return new WP_Error('invalid_request', esc_html__('No file specified.', 'simple-site-exporter-enginescript'));
    }
    
    // Prevent path traversal attacks
    if (strpos($filename, '/') !== false || strpos($filename, '\\') !== false) {
        return new WP_Error('invalid_filename', esc_html__('Invalid filename.', 'simple-site-exporter-enginescript'));
    }
    
    // Validate that it's our export file format
    if (!preg_match('/^site_export_sse_[a-f0-9]{7}_.*\.zip$/', $filename)) {
        return new WP_Error('invalid_format', esc_html__('Invalid export file format.', 'simple-site-exporter-enginescript'));
    }
    
    // Get the full path to the file
    $upload_dir = wp_upload_dir();
    $export_dir = $upload_dir['basedir'] . '/enginescript-sse-site-exports';
    $file_path = $export_dir . '/' . $filename;
    
    // Use WordPress filesystem API
    global $wp_filesystem;
    
    // Initialize the WordPress filesystem
    if (empty($wp_filesystem)) {
        require_once ABSPATH . 'wp-admin/includes/file.php';
        WP_Filesystem();
    }
    
    // Check if file exists using WP Filesystem
    if (!$wp_filesystem->exists($file_path) || !$wp_filesystem->is_readable($file_path)) {
        return new WP_Error('file_not_found', esc_html__('Export file not found or not readable.', 'simple-site-exporter-enginescript'));
    }
    
    // Get file size using WP Filesystem
    $file_size = $wp_filesystem->size($file_path);
    if (!$file_size) {
        return new WP_Error('file_size_error', esc_html__('Could not determine file size.', 'simple-site-exporter-enginescript'));
    }
    
    return array(
        'filepath' => $file_path,
        'filename' => basename($file_path),
        'filesize' => $file_size
    );
}

/**
 * Prepare environment for secure download
 */
function sse_prepare_download_environment() {
    // End any output buffering completely
    while (ob_get_level()) {
        ob_end_clean();
    }
    
    // Close session to prevent locks
    if (function_exists('session_write_close')) {
        // In WordPress context, session handling is generally discouraged,
        // but needed for compatibility with plugins that might use sessions
        session_write_close();
    }
    
    // Set unlimited execution time for large files
    // Note: Using set_time_limit is sometimes necessary for large file operations
    if (function_exists('set_time_limit') && !ini_get('safe_mode')) {
        // phpcs:ignore WordPress.PHP.DiscouragedPHPFunctions.runtime_configuration_set_time_limit
        set_time_limit(0);
    }
    
    // Try to disable output compression
    if (function_exists('apache_setenv')) {
        // phpcs:ignore WordPress.PHP.DiscouragedPHPFunctions.runtime_configuration_apache_setenv
        apache_setenv('no-gzip', '1');
    }
    
    // Disable zlib compression
    // Note: In this specific case, we need to ensure no compression for binary file download
    if (function_exists('ini_set')) {
        // phpcs:ignore WordPress.PHP.DiscouragedPHPFunctions.runtime_configuration_ini_set
        ini_set('zlib.output_compression', '0');
    }
}

/**
 * Send file download headers
 * 
 * @param string $filename The filename to send
 * @param int $filesize The file size in bytes
 */
function sse_send_download_headers($filename, $filesize) {
    // WordPress doesn't provide a native API for sending file download headers,
    // so we need to use the header function directly
    // phpcs:ignore WordPress.PHP.DiscouragedPHPFunctions.header_header
    header('Content-Description: File Transfer');
    // phpcs:ignore WordPress.PHP.DiscouragedPHPFunctions.header_header
    header('Content-Type: application/octet-stream');
    // phpcs:ignore WordPress.PHP.DiscouragedPHPFunctions.header_header
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    // phpcs:ignore WordPress.PHP.DiscouragedPHPFunctions.header_header
    header('Content-Length: ' . $filesize);
    // phpcs:ignore WordPress.PHP.DiscouragedPHPFunctions.header_header
    header('Content-Transfer-Encoding: binary');
    // Most Cache-Control headers are handled by Nginx
    // phpcs:ignore WordPress.PHP.DiscouragedPHPFunctions.header_header
    header('Pragma: no-cache');
    // phpcs:ignore WordPress.PHP.DiscouragedPHPFunctions.header_header
    header('Expires: 0');
}

/**
 * Stream file to browser using WordPress filesystem when possible
 * 
 * @param string $file_path Path to the file to be streamed
 * @return bool Success or failure
 */
function sse_stream_file($file_path) {
    global $wp_filesystem;
    
    if (empty($wp_filesystem)) {
        require_once ABSPATH . 'wp-admin/includes/file.php';
        WP_Filesystem();
    }
    
    // Final buffer clean before sending the file
    if (ob_get_level()) {
        ob_end_clean();
    }
    
    // Try different methods to send the file, starting with the most efficient
    
    // Method 1: Direct readfile (most efficient for most servers)
    // phpcs:ignore WordPress.PHP.DiscouragedPHPFunctions.filesystem_readfile
    if (@readfile($file_path) !== false) {
        return true;
    }
    
    // Method 2: File chunks with WordPress filesystem
    if ($wp_filesystem->exists($file_path) && $wp_filesystem->is_readable($file_path)) {
        // WP_Filesystem doesn't support streaming, so we need direct file access
        // phpcs:ignore WordPress.PHP.DiscouragedPHPFunctions.filesystem_fopen
        $handle = fopen($file_path, 'rb');
        if ($handle !== false) {
            $chunk_size = 1024 * 1024; // 1MB chunks
            // phpcs:ignore WordPress.PHP.DiscouragedPHPFunctions.filesystem_feof
            while (!feof($handle)) {
                // phpcs:ignore WordPress.PHP.DiscouragedPHPFunctions.filesystem_fread
                echo fread($handle, $chunk_size);
                flush();
                if (connection_status() != 0) {
                    break;
                }
            }
            // phpcs:ignore WordPress.PHP.DiscouragedPHPFunctions.filesystem_fclose
            fclose($handle);
            return true;
        }
    }
    
    return false;
}

/**
 * Main handler for secure download requests
 */
function sse_secure_download_handler() {
    // Use filter_input for better security when accessing superglobals
    // Make sure to use wp_unslash on filtered input
    $sse_secure_download = filter_input(INPUT_GET, 'sse_secure_download', FILTER_SANITIZE_FULL_SPECIAL_CHARS);
    $sse_secure_download = $sse_secure_download ? wp_unslash($sse_secure_download) : '';
    
    $download_nonce = filter_input(INPUT_GET, 'sse_download_nonce', FILTER_SANITIZE_FULL_SPECIAL_CHARS);
    $download_nonce = $download_nonce ? wp_unslash($download_nonce) : '';
    
    // Check for our download request parameter
    if (empty($sse_secure_download)) {
        return;
    }

    // Verify nonce for security
    if (empty($download_nonce) || 
        !wp_verify_nonce(sanitize_key($download_nonce), 'sse_secure_download')) {
        wp_die(esc_html__('Security check failed.', 'simple-site-exporter-enginescript'), 403);
    }

    // Check user permissions
    if (!current_user_can('manage_options')) {
        wp_die(esc_html__('You do not have permission to download exports.', 'simple-site-exporter-enginescript'), 403);
    }
    
    // Validate file - make sure input is properly sanitized with wp_unslash first
    $file_info = sse_validate_download_request(sanitize_file_name($sse_secure_download));
    
    // Handle validation errors
    if (is_wp_error($file_info)) {
        wp_die($file_info->get_error_message(), 400);
    }
    
    // Log the download for auditing purposes
    error_log('Simple Site Exporter: Admin user ' . wp_get_current_user()->user_login . 
              ' downloaded export file: ' . $file_info['filename']);
    
    // Prepare environment (buffer, session, time limit)
    sse_prepare_download_environment();
    
    // Send HTTP headers for download
    sse_send_download_headers($file_info['filename'], $file_info['filesize']);
    
    // Stream file to browser
    $success = sse_stream_file($file_info['filepath']);
    
    if (!$success) {
        wp_die(esc_html__('Error streaming file.', 'simple-site-exporter-enginescript'), 500);
    }
    
    // Terminate immediately after sending file (necessary for proper download)
    // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
    exit;
}
// Hook into WordPress for the download handler
add_action('init', 'sse_secure_download_handler');

/**
 * Validate file deletion request
 *
 * @param string $filename The filename to validate
 * @return array|WP_Error Result array with file path or WP_Error on failure
 */
function sse_validate_file_deletion($filename) {
    if (empty($filename)) {
        return new WP_Error('invalid_request', esc_html__('No file specified.', 'simple-site-exporter-enginescript'));
    }
    
    // Prevent path traversal attacks
    if (strpos($filename, '/') !== false || strpos($filename, '\\') !== false) {
        return new WP_Error('invalid_filename', esc_html__('Invalid filename.', 'simple-site-exporter-enginescript'));
    }
    
    // Validate that it's our export file format
    if (!preg_match('/^site_export_sse_[a-f0-9]{7}_.*\.zip$/', $filename)) {
        return new WP_Error('invalid_format', esc_html__('Invalid export file format.', 'simple-site-exporter-enginescript'));
    }
    
    // Get the full path to the file
    $upload_dir = wp_upload_dir();
    $export_dir = $upload_dir['basedir'] . '/enginescript-sse-site-exports';
    $file_path = $export_dir . '/' . $filename;
    
    // Use WordPress filesystem API
    global $wp_filesystem;
    
    // Initialize the WordPress filesystem
    if (empty($wp_filesystem)) {
        require_once ABSPATH . 'wp-admin/includes/file.php';
        WP_Filesystem();
    }
    
    // Check if file exists using WP Filesystem
    if (!$wp_filesystem->exists($file_path)) {
        return new WP_Error('file_not_found', esc_html__('Export file not found.', 'simple-site-exporter-enginescript'));
    }
    
    return array(
        'filepath' => $file_path,
        'filename' => basename($file_path)
    );
}

/**
 * Clear any scheduled cron events for file deletion
 *
 * @param string $file_path Full path to the file
 * @return bool Whether any cron events were cleared
 */
function sse_clear_scheduled_deletions($file_path) {
    $cron_cleared = false;
    $crons = _get_cron_array();
    
    if (!empty($crons)) {
        foreach ($crons as $timestamp => $cron) {
            if (isset($cron['sse_delete_export_file'])) {
                foreach ($cron['sse_delete_export_file'] as $key => $event) {
                    // Using $key instead of $hash to avoid Codacy unused variable warning
                    if (isset($event['args'][0]) && $event['args'][0] === $file_path) {
                        // Found a scheduled cron task for this file, remove it
                        wp_unschedule_event($timestamp, 'sse_delete_export_file', array($file_path));
                        $cron_cleared = true;
                        error_log('Simple Site Exporter: Removed scheduled deletion event for: ' . $file_path);
                    }
                }
            }
        }
    }
    
    return $cron_cleared;
}

/**
 * Handle manual export file deletion requests
 */
function sse_manual_delete_handler() {
    // Only run on admin pages
    if (!is_admin()) {
        return;
    }
    
    // Use filter_input for better security when accessing superglobals
    // Make sure to use wp_unslash on filtered input
    $sse_delete_export = filter_input(INPUT_GET, 'sse_delete_export', FILTER_SANITIZE_FULL_SPECIAL_CHARS);
    $sse_delete_export = $sse_delete_export ? wp_unslash($sse_delete_export) : '';
    
    $delete_nonce = filter_input(INPUT_GET, 'sse_delete_nonce', FILTER_SANITIZE_FULL_SPECIAL_CHARS);
    $delete_nonce = $delete_nonce ? wp_unslash($delete_nonce) : '';
    
    // Check for our delete action
    if (empty($sse_delete_export)) {
        return;
    }
    
    // Verify nonce for security
    if (empty($delete_nonce) || 
        !wp_verify_nonce(sanitize_key($delete_nonce), 'sse_delete_export')) {
        wp_die(esc_html__('Security check failed.', 'simple-site-exporter-enginescript'), 403);
    }
    
    // Check user permissions
    if (!current_user_can('manage_options')) {
        wp_die(esc_html__('You do not have permission to delete export files.', 'simple-site-exporter-enginescript'), 403);
    }
    
    // Validate file - properly sanitized after wp_unslash
    $file_info = sse_validate_file_deletion(sanitize_file_name($sse_delete_export));
    
    // Handle validation errors
    if (is_wp_error($file_info)) {
        wp_die($file_info->get_error_message(), 400);
    }
    
    // Clear any scheduled cron events for this file
    $cron_cleared = sse_clear_scheduled_deletions($file_info['filepath']);
    
    // Delete the file
    $deleted = sse_safely_delete_file($file_info['filepath']);
    
    // Log the deletion
    if ($deleted) {
        error_log('Simple Site Exporter: Admin user ' . wp_get_current_user()->user_login . 
                  ' manually deleted export file: ' . $file_info['filename'] . 
                  ($cron_cleared ? ' (scheduled task removed)' : ''));
    }
    
    // Redirect back to the exporter page with a message and nonce for CSRF protection
    $redirect_url = add_query_arg(
        array(
            'page' => 'simple-site-exporter',
            'file_deleted' => $deleted ? '1' : '0',
            '_wpnonce' => wp_create_nonce('sse_file_deleted_notice')
        ),
        admin_url('tools.php')
    );
    
    // Use wp_safe_redirect with second parameter to avoid direct exit call
    wp_safe_redirect($redirect_url, 302, 'Simple Site Exporter');
    // Use wp_die instead of exit for cleaner shutdown with WordPress
    wp_die('', '', array('response' => 302, 'exit' => true));
}
add_action('admin_init', 'sse_manual_delete_handler');

/**
 * Display admin notice for file deletion result
 */
function sse_file_deletion_notice() {
    // Only show on our plugin page
    $screen = get_current_screen();
    if (!$screen || $screen->id !== 'tools_page_simple-site-exporter') {
        return;
    }
    
    // Use filter_input for better security when accessing superglobals
    // Make sure to use wp_unslash on filtered input
    $file_deleted = filter_input(INPUT_GET, 'file_deleted', FILTER_SANITIZE_FULL_SPECIAL_CHARS);
    $file_deleted = $file_deleted ? wp_unslash($file_deleted) : '';
    
    $nonce = filter_input(INPUT_GET, '_wpnonce', FILTER_SANITIZE_FULL_SPECIAL_CHARS);
    $nonce = $nonce ? wp_unslash($nonce) : '';
    
    // Check for the deletion result parameter with nonce verification
    if (!empty($file_deleted) && !empty($nonce) && 
        wp_verify_nonce(sanitize_key($nonce), 'sse_file_deleted_notice')) {
        
        if ($file_deleted === '1') {
            ?>
            <div class="notice notice-success is-dismissible">
                <p><?php esc_html_e('Export file deleted successfully.', 'simple-site-exporter-enginescript'); ?></p>
            </div>
            <?php
        } else {
            ?>
            <div class="notice notice-error is-dismissible">
                <p><?php esc_html_e('Failed to delete export file.', 'simple-site-exporter-enginescript'); ?></p>
            </div>
            <?php
        }
    }
}
add_action('admin_notices', 'sse_file_deletion_notice');
