<?php
/*
Plugin Name: EngineScript: Simple Site Exporter
Description: Exports the site files and database as a zip archive.
Version: 1.1.8
Author: EngineScript
License: GPL v2 or later
*/

// Prevent direct access. Note: Using exit here is standard practice for plugins.
if ( ! defined( 'ABSPATH' ) ) {
    exit;
}

// --- Admin Menu ---
function sse_admin_menu() {
    add_management_page(
        esc_html__( 'Simple Site Exporter', 'simple-site-exporter' ), // Escaped title
        esc_html__( 'Site Exporter', 'simple-site-exporter' ),       // Escaped menu title
        'manage_options', // Capability required
        'simple-site-exporter',
        'sse_exporter_page_html'
    );
}
add_action( 'admin_menu', 'sse_admin_menu' );

// --- Exporter Page HTML ---
function sse_exporter_page_html() {
    if ( ! current_user_can( 'manage_options' ) ) {
        // Use wp_die for permission errors within admin pages
        wp_die( esc_html__( 'You do not have permission to view this page.', 'simple-site-exporter' ), 403 );
    }

    // Determine the export directory path for display
    $upload_dir = wp_upload_dir();
    $export_dir_name = 'site-exports'; // Consistent name
    $export_dir_path = $upload_dir['basedir'] . '/' . $export_dir_name;
    // Make the path relative to the WordPress root for display, if possible
    $display_path = str_replace( ABSPATH, '', $export_dir_path );

    ?>
    <div class="wrap">
        <h1><?php echo esc_html( get_admin_page_title() ); ?></h1> <?php // esc_html is correct here ?>
        <p><?php esc_html_e( 'Click the button below to generate a zip archive containing your WordPress files and a database dump (.sql file).', 'simple-site-exporter' ); ?></p>
        <p><strong><?php esc_html_e( 'Warning:', 'simple-site-exporter' ); ?></strong> <?php esc_html_e( 'This can take a long time and consume significant server resources, especially on large sites. Ensure your server has sufficient disk space and execution time.', 'simple-site-exporter' ); ?></p>

        <p style="margin-top: 15px;">
            <?php
            printf(
                /* translators: %s: directory path */
                esc_html__( 'Exported .zip files will be saved in the following directory on the server: %s', 'simple-site-exporter' ),
                '<code>' . esc_html( $display_path ) . '</code>' // Path is generated internally, esc_html is safe
            );
            ?>
        </p>

        <form method="post" action="" style="margin-top: 15px;">
            <?php wp_nonce_field( 'sse_export_action', 'sse_export_nonce' ); ?>
            <input type="hidden" name="action" value="sse_export_site">
            <?php submit_button( esc_html__( 'Export Site', 'simple-site-exporter' ) ); // Escape button text ?>
        </form>

        <hr>
        <p>
            <?php esc_html_e( 'This plugin is part of the EngineScript project.', 'simple-site-exporter' ); ?>
            <a href="https://github.com/EngineScript/EngineScript" target="_blank" rel="noopener noreferrer">
                <?php esc_html_e( 'Visit the EngineScript GitHub page', 'simple-site-exporter' ); ?>
            </a>
        </p>
    </div>
    <?php
}

// --- Handle Export Action ---
function sse_handle_export() {
    // Check if the form was submitted with the correct action
    // Sanitize the input before comparing
    $action = isset( $_POST['action'] ) ? sanitize_key( $_POST['action'] ) : '';
    if ( 'sse_export_site' !== $action ) {
        return;
    }

    // Verify nonce. wp_verify_nonce handles unslashing and validation.
    // Check nonce existence first.
    if ( ! isset( $_POST['sse_export_nonce'] ) || ! wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['sse_export_nonce'] ) ), 'sse_export_action' ) ) {
        // Nonce is invalid or missing
        wp_die( esc_html__( 'Nonce verification failed! Please try again.', 'simple-site-exporter' ), 403 );
    }

    // Check user capabilities
    if ( ! current_user_can( 'manage_options' ) ) {
        wp_die( esc_html__( 'You do not have permission to perform this action.', 'simple-site-exporter' ), 403 );
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

    $site_name = sanitize_file_name( get_bloginfo( 'name' ) );
    $timestamp = date( 'Y-m-d_H-i-s' );
    $db_filename = "db_dump_{$site_name}_{$timestamp}.sql";
    $zip_filename = "site_export_sse_{$site_name}_{$timestamp}.zip";
    $db_filepath = $export_dir . '/' . $db_filename;
    $zip_filepath = $export_dir . '/' . $zip_filename;
    $zip_fileurl = $export_url . '/' . $zip_filename;

    // --- 1. Database Export (WP-CLI recommended) ---
    $db_exported = false;
    $db_error = '';
    if ( function_exists('shell_exec') ) {
        $wp_cli_path = trim(shell_exec('which wp'));
        if (!empty($wp_cli_path)) {
            $command = sprintf(
                '%s db export %s --path=%s --allow-root',
                escapeshellarg($wp_cli_path),
                escapeshellarg( $db_filepath ),
                escapeshellarg( ABSPATH )
            );
            $output = shell_exec( $command . ' 2>&1' );
            if ( file_exists( $db_filepath ) && filesize( $db_filepath ) > 0 ) {
                $db_exported = true;
            } else {
                 $db_error = !empty($output) ? trim($output) : 'WP-CLI command failed silently.';
            }
        } else {
             $db_error = esc_html__( 'WP-CLI command not found in PATH.', 'simple-site-exporter' );
        }
    } else {
         $db_error = esc_html__( 'shell_exec function is disabled on this server.', 'simple-site-exporter' );
    }

    // Handle DB Export Failure - Show notice and stop
    if ( ! $db_exported ) {
        add_action( 'admin_notices', function() use ($db_error) {
             ?>
             <div class="notice notice-error is-dismissible">
                 <p><?php
                    printf(
                        /* translators: %s: error message */
                        esc_html__( 'Database export failed: %s. Export process halted.', 'simple-site-exporter' ),
                        '<strong>' . esc_html( $db_error ) . '</strong>' // $db_error is escaped above or is internal message
                    );
                 ?></p>
             </div>
             <?php
        });
        error_log("Simple Site Exporter: DB export failed - " . $db_error); // $db_error is safe for logging
        return; // Stop the export process
    }


    // --- 2. File Export (ZipArchive) ---
    if ( ! class_exists( 'ZipArchive' ) ) {
         add_action( 'admin_notices', function() {
             ?>
             <div class="notice notice-error is-dismissible">
                 <p><?php esc_html_e( 'ZipArchive class is not available on your server. Cannot create zip file.', 'simple-site-exporter' ); ?></p>
             </div>
             <?php
         });
         @unlink( $db_filepath ); // Clean up DB dump
         return; // Stop
    }

    $zip = new ZipArchive();
    if ( $zip->open( $zip_filepath, ZipArchive::CREATE | ZipArchive::OVERWRITE ) !== TRUE ) {
        add_action( 'admin_notices', function() use ($zip_filepath) {
             $display_zip_path = str_replace( ABSPATH, '', $zip_filepath ); // Make path relative for display
             ?>
             <div class="notice notice-error is-dismissible">
                 <p><?php
                    printf(
                        /* translators: %s: file path */
                        esc_html__( 'Could not create zip file at %s', 'simple-site-exporter' ),
                        '<code>' . esc_html( $display_zip_path ) . '</code>' // Display path is generated, esc_html is safe
                    );
                 ?></p>
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

            if ( $file === false || empty($relativePath) ) continue;

            // --- Exclusions ---
            if ( strpos( $file, $export_dir ) === 0 ) continue;
            if ( preg_match( '#^wp-content/(cache|upgrade|temp)/#', $relativePath ) ) continue;
            if ( preg_match( '#/\.(git|svn|hg|DS_Store)$#', $file ) ) continue;

            if ( $file_info->isDir() ) {
                $zip->addEmptyDir( $relativePath );
            } elseif ( $file_info->isFile() ) {
                $zip->addFile( $file, $relativePath );
            }
        }
    } catch ( Exception $e ) {
        $zip->close();
        @unlink( $zip_filepath );
        @unlink( $db_filepath );
        add_action( 'admin_notices', function() use ($e) {
             ?>
             <div class="notice notice-error is-dismissible">
                 <p><?php
                    printf(
                        /* translators: %s: error message */
                        esc_html__( 'Error during file processing: %s', 'simple-site-exporter' ),
                        '<strong>' . esc_html( $e->getMessage() ) . '</strong>' // Exception message escaped
                    );
                 ?></p>
             </div>
             <?php
         });
         error_log("Simple Site Exporter: Exception during file iteration - " . $e->getMessage()); // Raw message ok for log
         return; // Stop
    }

    $zip_close_status = $zip->close();

    // --- 3. Cleanup temporary DB file ---
    if ( $db_exported && file_exists( $db_filepath ) ) {
        @unlink( $db_filepath );
    }

    // --- 4. Report Success or Failure ---
    if ( $zip_close_status && file_exists( $zip_filepath ) ) {
        add_action( 'admin_notices', function() use ( $zip_fileurl, $zip_filename, $zip_filepath ) {
            $display_zip_path = str_replace( ABSPATH, '', $zip_filepath ); // Make path relative for display
            ?>
            <div class="notice notice-success is-dismissible">
                <p>
                    <?php esc_html_e( 'Site export successfully created!', 'simple-site-exporter' ); ?>
                    <?php // Using esc_url and esc_attr is correct for attributes ?>
                    <a href="<?php echo esc_url( $zip_fileurl ); ?>" download="<?php echo esc_attr( $zip_filename ); ?>" class="button" style="margin-left: 10px;">
                        <?php esc_html_e( 'Download Export File', 'simple-site-exporter' ); ?>
                    </a>
                </p>
                 <p><small><?php
                    printf(
                        /* translators: %s: file path */
                        esc_html__( 'File location: %s', 'simple-site-exporter' ),
                        '<code>' . esc_html( $display_zip_path ) . '</code>' // Display path generated internally, esc_html safe
                    );
                 ?></small></p>
            </div>
            <?php
        });
        error_log("Simple Site Exporter: Export successful. File saved to " . $zip_filepath); // Path is safe for logging
    } else {
        // Add a generic error notice if the zip failed at the end
         add_action( 'admin_notices', function() {
             ?>
             <div class="notice notice-error is-dismissible">
                 <p><?php esc_html_e( 'Failed to finalize or save the zip archive after processing files.', 'simple-site-exporter' ); ?></p>
             </div>
             <?php
         });
         error_log("Simple Site Exporter: Export failed. Zip close status: " . ($zip_close_status ? 'OK' : 'FAIL') . ", File exists: " . (file_exists($zip_filepath) ? 'Yes' : 'No'));
         @unlink( $zip_filepath ); // Attempt cleanup
    }
}
add_action( 'admin_init', 'sse_handle_export' );

?>