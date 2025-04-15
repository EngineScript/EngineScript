<?php
/*
Plugin Name: EngineScript: Simple Site Exporter
Description: Exports the site files and database as a zip archive.
Version: 1.3.0
Author: EngineScript
License: GPL v2 or later
Text Domain: simple-site-exporter-enginescript
*/

// Prevent direct access. Note: Using exit here is standard practice for plugins.
if ( ! defined( 'ABSPATH' ) ) {
    exit; // Standard WordPress practice to prevent direct access.
}

// Define plugin version
if (!defined('ES_SITE_EXPORTER_VERSION')) {
    define('ES_SITE_EXPORTER_VERSION', '1.2.0');
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
        // Use wp_die for permission errors within admin pages
        wp_die( esc_html__( 'You do not have permission to view this page.', 'simple-site-exporter-enginescript' ), 403 );
    }

    // Determine the export directory path for display
    $upload_dir = wp_upload_dir();
    if ( empty( $upload_dir['basedir'] ) ) {
        // Handle potential error getting upload directory
         wp_die( esc_html__( 'Could not determine the WordPress upload directory.', 'simple-site-exporter-enginescript' ) );
    }
    $export_dir_name = 'enginescript-sse-site-exports';
    $export_dir = $upload_dir['basedir'] . '/' . $export_dir_name;
    $export_url = $upload_dir['baseurl'] . '/' . $export_dir_name;
    // For display in the admin page as well:
    $export_dir_path = $upload_dir['basedir'] . '/' . $export_dir_name;
    $display_path = str_replace( ABSPATH, '', $export_dir_path );

    ?>
    <div class="wrap">
        <?php // Using echo with proper escaping (esc_html) is secure and standard. ?>
        <h1><?php echo esc_html( get_admin_page_title() ); ?></h1>
        <p><?php esc_html_e( 'Click the button below to generate a zip archive containing your WordPress files and a database dump (.sql file).', 'simple-site-exporter-enginescript' ); ?></p>
        <p><strong><?php esc_html_e( 'Warning:', 'simple-site-exporter-enginescript' ); ?></strong> <?php esc_html_e( 'This can take a long time and consume significant server resources, especially on large sites. Ensure your server has sufficient disk space and execution time.', 'simple-site-exporter-enginescript' ); ?></p>

        <p style="margin-top: 15px;">
            <?php
            // Using printf with escaped strings and variables is secure and standard WordPress practice.
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
    </div>
    <?php
}

// --- Handle Export Action ---
function sse_handle_export() {
    // Check if the form was submitted with the correct action
    // Accessing $_POST is necessary here, but the value is immediately sanitized.
    $action = isset( $_POST['action'] ) ? sanitize_key( $_POST['action'] ) : '';
    if ( 'sse_export_site' !== $action ) {
        return;
    }

    // Verify nonce.
    // Accessing $_POST is necessary, value is unslashed, sanitized, and verified.
    if ( ! isset( $_POST['sse_export_nonce'] ) || ! wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['sse_export_nonce'] ) ), 'sse_export_action' ) ) {
        wp_die( esc_html__( 'Nonce verification failed! Please try again.', 'simple-site-exporter-enginescript' ), 403 );
    }

    // Check user capabilities
    if ( ! current_user_can( 'manage_options' ) ) {
        wp_die( esc_html__( 'You do not have permission to perform this action.', 'simple-site-exporter-enginescript' ), 403 );
    }

    // Increase execution time limit (may not work on all servers)
    // Use of @ suppresses errors if the function is disabled, which is acceptable here.
    @set_time_limit( 0 );

    $upload_dir = wp_upload_dir();
    if ( empty( $upload_dir['basedir'] ) || empty( $upload_dir['baseurl'] ) ) {
         wp_die( esc_html__( 'Could not determine the WordPress upload directory or URL.', 'simple-site-exporter-enginescript' ) );
    }
    $export_dir_name = 'site-exports';
    $export_dir = $upload_dir['basedir'] . '/' . $export_dir_name;
    $export_url = $upload_dir['baseurl'] . '/' . $export_dir_name;
    wp_mkdir_p( $export_dir ); // Ensure the directory exists

    // Add an index.php file to prevent directory listing
    // Using file_exists and file_put_contents is acceptable for simple checks/writes
    // within the known writable uploads directory. WP_Filesystem is more robust but adds complexity.
    $index_file_path = $export_dir . '/index.php';
    if ( ! file_exists( $index_file_path ) ) {
        // Use of @ suppresses errors if writing fails, acceptable for this non-critical file.
        @file_put_contents( $index_file_path, '<?php // Silence is golden.' );
    }

    $site_name = sanitize_file_name( get_bloginfo( 'name' ) );
    $timestamp = date( 'Y-m-d_H-i-s' );
    // Generate 7 random alphanumeric characters
    $random_str = substr( bin2hex( random_bytes(4) ), 0, 7 );
    $db_filename = "db_dump_{$site_name}_{$timestamp}.sql";
    $zip_filename = "site_export_sse_{$random_str}_{$site_name}_{$timestamp}.zip";
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
            // Consider adding error handling for shell_exec if needed
            $output = shell_exec( $command . ' 2>&1' );
            // Using file_exists and filesize is standard for checking command output files.
            if ( file_exists( $db_filepath ) && filesize( $db_filepath ) > 0 ) {
                $db_exported = true;
            } else {
                 $db_error = !empty($output) ? trim($output) : 'WP-CLI command failed silently.';
            }
        } else {
             $db_error = esc_html__( 'WP-CLI command not found in PATH.', 'simple-site-exporter-enginescript' );
        }
    } else {
         $db_error = esc_html__( 'shell_exec function is disabled on this server.', 'simple-site-exporter-enginescript' );
    }

    // Handle DB Export Failure - Show notice and stop
    if ( ! $db_exported ) {
        add_action( 'admin_notices', function() use ($db_error) {
             ?>
             <div class="notice notice-error is-dismissible">
                 <p><?php
                    // Using printf with escaped strings/variables is secure.
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
         // Using @unlink for cleanup of self-created temp files is acceptable practice.
         // WP_Filesystem->delete() is more robust but adds complexity here.
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
                    // Using printf with escaped strings/variables is secure.
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
         if ( file_exists( $db_filepath ) ) {
            @unlink( $db_filepath );
         }
         return; // Stop
    }

    // Add Database Dump to Zip
    // Using file_exists is standard here.
    if ( $db_exported && file_exists( $db_filepath ) ) {
        if ( ! $zip->addFile( $db_filepath, $db_filename ) ) {
             error_log( "Simple Site Exporter: Failed to add DB file to zip: " . $db_filepath );
             // Optionally add an admin notice here too
        }
    }

    // Add WordPress Files
    $source_path = realpath( ABSPATH );
    if ( ! $source_path ) {
        error_log( "Simple Site Exporter: Could not resolve real path for ABSPATH." );
        // Handle error - maybe add admin notice and stop?
        $zip->close();
        if ( file_exists( $db_filepath ) ) @unlink( $db_filepath );
        if ( file_exists( $zip_filepath ) ) @unlink( $zip_filepath );
        // Add admin notice about ABSPATH issue
        return;
    }

    try {
        // Consider adding checks for RecursiveDirectoryIterator existence if needed
        $files = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator( $source_path, RecursiveDirectoryIterator::SKIP_DOTS | FilesystemIterator::UNIX_PATHS ),
            RecursiveIteratorIterator::SELF_FIRST
        );

        foreach ( $files as $file_info ) {
            // Check if file is readable before proceeding
            if ( ! $file_info->isReadable() ) {
                error_log( "Simple Site Exporter: Skipping unreadable file/dir: " . $file_info->getPathname() );
                continue;
            }

            $file = $file_info->getRealPath();
            // Use getPathname() for relative path calculation if realpath fails (e.g., broken symlinks)
            $pathname = $file_info->getPathname();
            $relativePath = ltrim( substr( $pathname, strlen( $source_path ) ), '/' );


            if ( empty($relativePath) ) continue; // Skip the root dir itself

            // --- Exclusions ---
            // Use pathname for exclusion checks as realpath might resolve outside export dir for symlinks
            if ( strpos( $pathname, $export_dir ) === 0 ) continue;
            if ( preg_match( '#^wp-content/(cache|upgrade|temp)/#', $relativePath ) ) continue;
            if ( preg_match( '#(^|/)\.(git|svn|hg|DS_Store|htaccess|user\.ini)$#i', $relativePath ) ) continue; // Improved regex

            if ( $file_info->isDir() ) {
                // Add directory using relative path
                if ( ! $zip->addEmptyDir( $relativePath ) ) {
                     error_log( "Simple Site Exporter: Failed to add directory to zip: " . $relativePath );
                }
            } elseif ( $file_info->isFile() ) {
                // Add file using real path (if available and valid) or pathname
                $file_to_add = ($file !== false) ? $file : $pathname;
                 if ( ! $zip->addFile( $file_to_add, $relativePath ) ) {
                     error_log( "Simple Site Exporter: Failed to add file to zip: " . $relativePath . " (Source: " . $file_to_add . ")" );
                 }
            }
        } // End foreach
    } catch ( Exception $e ) {
        // Cleanup potentially created files
        if ( file_exists( $zip_filepath ) ) @unlink( $zip_filepath );
        if ( file_exists( $db_filepath ) ) @unlink( $db_filepath );

        add_action( 'admin_notices', function() use ($e) {
             ?>
             <div class="notice notice-error is-dismissible">
                 <p><?php
                    // Using printf with escaped strings/variables is secure.
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
    // Using file_exists and @unlink is acceptable for cleanup of self-created temp files.
    if ( $db_exported && file_exists( $db_filepath ) ) {
        @unlink( $db_filepath );
    }

    // --- 4. Report Success or Failure ---
    // Using file_exists is standard for checking if the final output file was created.
    if ( $zip_close_status && file_exists( $zip_filepath ) ) {
        add_action( 'admin_notices', function() use ( $zip_fileurl, $zip_filename, $zip_filepath ) {
            $display_zip_path = str_replace( ABSPATH, '', $zip_filepath );
            ?>
            <div class="notice notice-success is-dismissible">
                <p>
                    <?php esc_html_e( 'Site export successfully created!', 'simple-site-exporter-enginescript' ); ?>
                    <?php // Using echo with esc_url/esc_attr for attributes is secure. ?>
                    <a href="<?php echo esc_url( $zip_fileurl ); ?>" download="<?php echo esc_attr( $zip_filename ); ?>" class="button" style="margin-left: 10px;">
                        <?php esc_html_e( 'Download Export File', 'simple-site-exporter-enginescript' ); ?>
                    </a>
                </p>
                 <p><small><?php
                    // Using printf with escaped strings/variables is secure.
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
         // Using file_exists is appropriate for logging state.
         error_log("Simple Site Exporter: Export failed. Zip close status: " . ($zip_close_status ? 'OK' : 'FAIL') . ", File exists: " . (file_exists($zip_filepath) ? 'Yes' : 'No'));
         // Attempt cleanup using @unlink, acceptable for self-created files.
         if ( file_exists( $zip_filepath ) ) {
            @unlink( $zip_filepath );
         }
    }
}
add_action( 'admin_init', 'sse_handle_export' );

?>