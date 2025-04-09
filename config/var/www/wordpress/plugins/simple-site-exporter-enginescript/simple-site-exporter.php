<?php
/*
Plugin Name: EngineScript: Simple Site Exporter
Description: Exports the site files and database as a zip archive.
Version: 1.1.6
Author: EngineScript
License: GPL v2 or later
*/

if ( ! defined( 'ABSPATH' ) ) {
    exit; // Exit if accessed directly.
}

// --- Admin Menu ---
function sse_admin_menu() {
    add_management_page(
        __( 'Simple Site Exporter', 'simple-site-exporter' ),
        __( 'Site Exporter', 'simple-site-exporter' ),
        'manage_options', // Capability required
        'simple-site-exporter',
        'sse_exporter_page_html'
    );
}
add_action( 'admin_menu', 'sse_admin_menu' );

// --- Exporter Page HTML ---
function sse_exporter_page_html() {
    if ( ! current_user_can( 'manage_options' ) ) {
        return;
    }

    // Determine the export directory path for display
    $upload_dir = wp_upload_dir();
    $export_dir_name = 'site-exports'; // Consistent name
    $export_dir_path = $upload_dir['basedir'] . '/' . $export_dir_name;
    // Make the path relative to the WordPress root for display, if possible
    $display_path = str_replace( ABSPATH, '', $export_dir_path );

    ?>
    <div class="wrap">
        <h1><?php echo esc_html( get_admin_page_title() ); ?></h1>
        <p><?php _e( 'Click the button below to generate a zip archive containing your WordPress files and a database dump (.sql file).', 'simple-site-exporter' ); ?></p>
        <p><strong><?php _e( 'Warning:', 'simple-site-exporter' ); ?></strong> <?php _e( 'This can take a long time and consume significant server resources, especially on large sites. Ensure your server has sufficient disk space and execution time.', 'simple-site-exporter' ); ?></p>

        <p style="margin-top: 15px;">
            <?php printf(
                __( 'Exported .zip files will be saved in the following directory on the server: %s', 'simple-site-exporter' ),
                '<code>' . esc_html( $display_path ) . '</code>'
            ); ?>
        </p>

        <form method="post" action="" style="margin-top: 15px;">
            <?php wp_nonce_field( 'sse_export_action', 'sse_export_nonce' ); ?>
            <input type="hidden" name="action" value="sse_export_site">
            <?php submit_button( __( 'Export Site', 'simple-site-exporter' ) ); ?>
        </form>

        <hr>
        <p>
            <?php _e( 'This plugin is part of the EngineScript project.', 'simple-site-exporter' ); ?>
            <a href="https://github.com/EngineScript/EngineScript" target="_blank" rel="noopener noreferrer">
                <?php _e( 'Visit the EngineScript GitHub page', 'simple-site-exporter' ); ?>
            </a>
        </p>
    </div>
    <?php
}

// --- Handle Export Action ---
function sse_handle_export() {
    if ( ! isset( $_POST['action'] ) || $_POST['action'] !== 'sse_export_site' ) {
        return;
    }

    if ( ! isset( $_POST['sse_export_nonce'] ) || ! wp_verify_nonce( $_POST['sse_export_nonce'], 'sse_export_action' ) ) {
        wp_die( __( 'Nonce verification failed!', 'simple-site-exporter' ) );
    }

    if ( ! current_user_can( 'manage_options' ) ) {
        wp_die( __( 'You do not have permission to perform this action.', 'simple-site-exporter' ) );
    }

    // Increase execution time limit (may not work on all servers)
    @set_time_limit( 0 );

    $upload_dir = wp_upload_dir();
    $export_dir_name = 'site-exports';
    $export_dir = $upload_dir['basedir'] . '/' . $export_dir_name;
    $export_url = $upload_dir['baseurl'] . '/' . $export_dir_name; // Base URL for the export dir
    wp_mkdir_p( $export_dir ); // Ensure the directory exists

    // Add an index.php file to prevent directory listing
    if ( ! file_exists( $export_dir . '/index.php' ) ) {
        @file_put_contents( $export_dir . '/index.php', '<?php // Silence is golden.' );
    }

    $site_name = sanitize_file_name( get_bloginfo( 'name' ) ); // Gets the site name
    $timestamp = date( 'Y-m-d_H-i-s' );
    $db_filename = "db_dump_{$site_name}_{$timestamp}.sql"; // Uses the site name
    // Modify the zip filename prefix here:
    $zip_filename = "site_export_sse_{$site_name}_{$timestamp}.zip"; // Changed prefix
    $db_filepath = $export_dir . '/' . $db_filename;
    $zip_filepath = $export_dir . '/' . $zip_filename;
    $zip_fileurl = $export_url . '/' . $zip_filename; // Full URL to the zip file

    // --- 1. Database Export (WP-CLI recommended) ---
    $db_exported = false;
    $db_error = ''; // Variable to store potential DB error messages
    if ( function_exists('shell_exec') ) {
        $wp_cli_path = trim(shell_exec('which wp')); // Basic check for wp path
        if (!empty($wp_cli_path)) {
            $command = sprintf(
                '%s db export %s --path=%s --allow-root',
                escapeshellarg($wp_cli_path),
                escapeshellarg( $db_filepath ),
                escapeshellarg( ABSPATH )
            );
            $output = shell_exec( $command . ' 2>&1' ); // Capture stderr
            if ( file_exists( $db_filepath ) && filesize( $db_filepath ) > 0 ) {
                $db_exported = true;
            } else {
                 $db_error = !empty($output) ? trim($output) : 'WP-CLI command failed silently.';
            }
        } else {
             $db_error = 'WP-CLI command not found in PATH.';
        }
    } else {
         $db_error = 'shell_exec function is disabled.';
    }

    // Handle DB Export Failure - Show notice and stop
    if ( ! $db_exported ) {
        add_action( 'admin_notices', function() use ($db_error) {
             ?>
             <div class="notice notice-error is-dismissible">
                 <p><?php printf( __( 'Database export failed: %s. Export process halted.', 'simple-site-exporter' ), '<strong>' . esc_html( $db_error ) . '</strong>' ); ?></p>
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
                 <p><?php _e( 'ZipArchive class is not available on your server. Cannot create zip file.', 'simple-site-exporter' ); ?></p>
             </div>
             <?php
         });
         @unlink( $db_filepath ); // Clean up DB dump
         return; // Stop
    }

    $zip = new ZipArchive();
    if ( $zip->open( $zip_filepath, ZipArchive::CREATE | ZipArchive::OVERWRITE ) !== TRUE ) {
        add_action( 'admin_notices', function() use ($zip_filepath) {
             ?>
             <div class="notice notice-error is-dismissible">
                 <p><?php printf( __( 'Could not create zip file at %s', 'simple-site-exporter' ), '<code>' . esc_html($zip_filepath) . '</code>' ); ?></p>
             </div>
             <?php
         });
         @unlink( $db_filepath ); // Clean up DB dump
         return; // Stop
    }

    // Add Database Dump to Zip
    if ( $db_exported && file_exists( $db_filepath ) ) {
        $zip->addFile( $db_filepath, $db_filename );
    }

    // Add WordPress Files
    $source_path = realpath( ABSPATH );
    try {
        $files = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator( $source_path, RecursiveDirectoryIterator::SKIP_DOTS | FilesystemIterator::UNIX_PATHS ),
            RecursiveIteratorIterator::SELF_FIRST
        );

        foreach ( $files as $file_info ) {
            $file = $file_info->getRealPath();
            $relativePath = ltrim( substr( $file_info->getPathname(), strlen( $source_path ) ), '/' );

            if ( $file === false || empty($relativePath) ) continue; // Skip if path is invalid

            // --- Exclusions ---
            if ( strpos( $file, $export_dir ) === 0 ) continue; // Skip export dir
            if ( preg_match( '#^wp-content/(cache|upgrade|temp)/#', $relativePath ) ) continue; // Skip common cache/temp
            if ( preg_match( '#/\.(git|svn|hg|DS_Store)$#', $file ) ) continue; // Skip VCS files

            if ( $file_info->isDir() ) {
                $zip->addEmptyDir( $relativePath );
            } elseif ( $file_info->isFile() ) {
                $zip->addFile( $file, $relativePath );
            }
        }
    } catch ( Exception $e ) {
        $zip->close(); // Attempt close
        @unlink( $zip_filepath ); // Attempt cleanup
        @unlink( $db_filepath ); // Attempt cleanup
        add_action( 'admin_notices', function() use ($e) {
             ?>
             <div class="notice notice-error is-dismissible">
                 <p><?php printf( __( 'Error during file processing: %s', 'simple-site-exporter' ), '<strong>' . esc_html( $e->getMessage() ) . '</strong>' ); ?></p>
             </div>
             <?php
         });
         error_log("Simple Site Exporter: Exception during file iteration - " . $e->getMessage());
         return; // Stop
    }

    $zip_close_status = $zip->close();

    // --- 3. Cleanup temporary DB file ---
    if ( $db_exported && file_exists( $db_filepath ) ) {
        @unlink( $db_filepath );
    }

    // --- 4. Report Success or Failure ---
    if ( $zip_close_status && file_exists( $zip_filepath ) ) {
        // Display success message with download link
        // Add $zip_filepath to the use clause here:
        add_action( 'admin_notices', function() use ( $zip_fileurl, $zip_filename, $zip_filepath ) {
            ?>
            <div class="notice notice-success is-dismissible">
                <p>
                    <?php _e( 'Site export successfully created!', 'simple-site-exporter' ); ?>
                    <a href="<?php echo esc_url( $zip_fileurl ); ?>" download="<?php echo esc_attr( $zip_filename ); ?>" class="button" style="margin-left: 10px;">
                        <?php _e( 'Download Export File', 'simple-site-exporter' ); ?>
                    </a>
                </p>
                 <p><small><?php printf(
                    __( 'File location: %s', 'simple-site-exporter' ),
                    // This should now work correctly:
                    '<code>' . esc_html( str_replace( ABSPATH, '', $zip_filepath ) ) . '</code>'
                 ); ?></small></p>
            </div>
            <?php
        });
        error_log("Simple Site Exporter: Export successful. File saved to " . $zip_filepath); // Log success
    } else {
        // ... (error handling) ...
    }
    // No exit; let the page reload to show the notice.
}
add_action( 'admin_init', 'sse_handle_export' );

?>