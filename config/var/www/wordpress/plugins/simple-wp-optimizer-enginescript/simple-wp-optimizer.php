<?php
/*
Plugin Name: EngineScript: WP Optimization
Description: Optimizes WordPress by removing unnecessary features and scripts
Version: 1.5.0
Author: EngineScript
License: GPL v2 or later
Text Domain: simple-wp-optimizer-enginescript
*/

// Prevent direct access
if (!defined('ABSPATH')) {
    return; // Prevent direct script access (WordPress best practice)
}

// Define plugin version
if (!defined('ES_WP_OPTIMIZER_VERSION')) {
    define('ES_WP_OPTIMIZER_VERSION', '1.5.0');
}

/**
 * Initialize the plugin settings
 */
function es_optimizer_init_settings() {
    // Register settings
    register_setting('es_optimizer_settings', 'es_optimizer_options', 'es_optimizer_validate_options');
    
    // Register default options if they don't exist
    if (false === get_option('es_optimizer_options')) {
        $default_options = array(
            'disable_emojis' => 1,
            'remove_jquery_migrate' => 1,
            'disable_classic_theme_styles' => 1,
            'remove_wp_version' => 1,
            'remove_wlw_manifest' => 1,
            'remove_shortlink' => 1,
            'remove_recent_comments_style' => 1,
            'enable_dns_prefetch' => 1,
            'dns_prefetch_domains' => implode("\n", array(
                'https://fonts.googleapis.com',
                'https://fonts.gstatic.com',
                'https://ajax.googleapis.com',
                'https://apis.google.com',
                'https://www.google-analytics.com'
            )),
            'disable_jetpack_ads' => 1
        );
        
        add_option('es_optimizer_options', $default_options);
    }
}
add_action('admin_init', 'es_optimizer_init_settings');

/**
 * Add settings page to the admin menu
 */
function es_optimizer_add_settings_page() {
    add_options_page(
        'WP Optimizer Settings',
        'WP Optimizer',
        'manage_options',
        'es-optimizer-settings',
        'es_optimizer_settings_page'
    );
}
add_action('admin_menu', 'es_optimizer_add_settings_page');

/**
 * Render the settings page
 */
function es_optimizer_settings_page() {
    if (!current_user_can('manage_options')) {
        wp_die(__('You do not have sufficient permissions to access this page.'));
    }
    
    $options = get_option('es_optimizer_options');
    ?>
    <div class="wrap">
        <h1>WP Optimizer Settings</h1>
        <p>Select which optimizations you want to enable and customize the DNS prefetch domains.</p>
        
        <form method="post" action="options.php">
            <?php settings_fields('es_optimizer_settings'); ?>
            
            <table class="form-table">
                <tr valign="top">
                    <th scope="row">Disable WordPress Emojis</th>
                    <td>
                        <label>
                            <input type="checkbox" name="es_optimizer_options[disable_emojis]" value="1" <?php checked(1, isset($options['disable_emojis']) ? $options['disable_emojis'] : 0); ?> />
                            Remove emoji scripts and styles to improve page load time
                        </label>
                    </td>
                </tr>
                
                <tr valign="top">
                    <th scope="row">Remove jQuery Migrate</th>
                    <td>
                        <label>
                            <input type="checkbox" name="es_optimizer_options[remove_jquery_migrate]" value="1" <?php checked(1, isset($options['remove_jquery_migrate']) ? $options['remove_jquery_migrate'] : 0); ?> />
                            Remove jQuery Migrate script (may affect compatibility with very old plugins)
                        </label>
                    </td>
                </tr>
                
                <tr valign="top">
                    <th scope="row">Disable Classic Theme Styles</th>
                    <td>
                        <label>
                            <input type="checkbox" name="es_optimizer_options[disable_classic_theme_styles]" value="1" <?php checked(1, isset($options['disable_classic_theme_styles']) ? $options['disable_classic_theme_styles'] : 0); ?> />
                            Remove classic theme styles added in WordPress 6.1+
                        </label>
                    </td>
                </tr>
                
                <tr valign="top">
                    <th scope="row">Remove WordPress Version</th>
                    <td>
                        <label>
                            <input type="checkbox" name="es_optimizer_options[remove_wp_version]" value="1" <?php checked(1, isset($options['remove_wp_version']) ? $options['remove_wp_version'] : 0); ?> />
                            Remove WordPress version from header (security benefit)
                        </label>
                    </td>
                </tr>
                
                <tr valign="top">
                    <th scope="row">Remove WLW Manifest</th>
                    <td>
                        <label>
                            <input type="checkbox" name="es_optimizer_options[remove_wlw_manifest]" value="1" <?php checked(1, isset($options['remove_wlw_manifest']) ? $options['remove_wlw_manifest'] : 0); ?> />
                            Remove Windows Live Writer manifest link
                        </label>
                    </td>
                </tr>
                
                <tr valign="top">
                    <th scope="row">Remove Shortlink</th>
                    <td>
                        <label>
                            <input type="checkbox" name="es_optimizer_options[remove_shortlink]" value="1" <?php checked(1, isset($options['remove_shortlink']) ? $options['remove_shortlink'] : 0); ?> />
                            Remove WordPress shortlink URLs from header
                        </label>
                    </td>
                </tr>
                
                <tr valign="top">
                    <th scope="row">Remove Recent Comments Style</th>
                    <td>
                        <label>
                            <input type="checkbox" name="es_optimizer_options[remove_recent_comments_style]" value="1" <?php checked(1, isset($options['remove_recent_comments_style']) ? $options['remove_recent_comments_style'] : 0); ?> />
                            Remove recent comments widget inline CSS
                        </label>
                    </td>
                </tr>
                
                <tr valign="top">
                    <th scope="row">Enable DNS Prefetch</th>
                    <td>
                        <label>
                            <input type="checkbox" name="es_optimizer_options[enable_dns_prefetch]" value="1" <?php checked(1, isset($options['enable_dns_prefetch']) ? $options['enable_dns_prefetch'] : 0); ?> />
                            Add DNS prefetch for common external domains
                        </label>
                    </td>
                </tr>
                
                <tr valign="top">
                    <th scope="row">DNS Prefetch Domains</th>
                    <td>
                        <p><small>Enter one domain per line. Include the full URL (e.g., https://fonts.googleapis.com)</small></p>
                        <textarea name="es_optimizer_options[dns_prefetch_domains]" rows="5" cols="50" class="large-text code"><?php echo esc_textarea(isset($options['dns_prefetch_domains']) ? $options['dns_prefetch_domains'] : ''); ?></textarea>
                    </td>
                </tr>
                
                <tr valign="top">
                    <th scope="row">Disable Jetpack Ads</th>
                    <td>
                        <label>
                            <input type="checkbox" name="es_optimizer_options[disable_jetpack_ads]" value="1" <?php checked(1, isset($options['disable_jetpack_ads']) ? $options['disable_jetpack_ads'] : 0); ?> />
                            Remove Jetpack advertisements and promotions
                        </label>
                    </td>
                </tr>
            </table>
            
            <p class="submit">
                <input type="submit" class="button-primary" value="Save Changes" />
            </p>
        </form>
        
        <hr>
        <p>
            <?php esc_html_e('This plugin is part of the EngineScript project.', 'simple-wp-optimizer-enginescript'); ?>
            <a href="<?php echo esc_url('https://github.com/EngineScript/EngineScript'); ?>" target="_blank" rel="noopener noreferrer">
                <?php esc_html_e('Visit the EngineScript GitHub page', 'simple-wp-optimizer-enginescript'); ?>
            </a>
        </p>
    </div>
    <?php
}

/**
 * Validate options before saving
 */
function es_optimizer_validate_options($input) {
    $valid = array();
    
    // Validate checkboxes (0 or 1)
    $checkboxes = array(
        'disable_emojis', 'remove_jquery_migrate', 'disable_classic_theme_styles',
        'remove_wp_version', 'remove_wlw_manifest', 'remove_shortlink',
        'remove_recent_comments_style', 'enable_dns_prefetch', 'disable_jetpack_ads'
    );
    
    foreach ($checkboxes as $checkbox) {
        $valid[$checkbox] = isset($input[$checkbox]) ? 1 : 0;
    }
    
    // Validate and sanitize the DNS prefetch domains
    if (isset($input['dns_prefetch_domains'])) {
        $domains = explode("\n", trim($input['dns_prefetch_domains']));
        $sanitized_domains = array();
        
        foreach ($domains as $domain) {
            $domain = trim($domain);
            if (!empty($domain)) {
                // Basic URL validation
                if (filter_var($domain, FILTER_VALIDATE_URL)) {
                    $sanitized_domains[] = esc_url_raw($domain);
                }
            }
        }
        
        $valid['dns_prefetch_domains'] = implode("\n", $sanitized_domains);
    } else {
        $valid['dns_prefetch_domains'] = '';
    }
    
    return $valid;
}

/**
 * Disable WordPress emoji functionality
 * 
 * Completely removes emoji-related scripts and styles which most sites don't need.
 * This improves page load time and reduces HTTP requests.
 * 
 * @since 1.0.0
 */
function disable_emojis() {
    $options = get_option('es_optimizer_options');
    
    // Only proceed if the option is enabled
    if (!isset($options['disable_emojis']) || !$options['disable_emojis']) {
        return;
    }
    
    // Remove emoji scripts and styles from front end
    remove_action('wp_head', 'print_emoji_detection_script', 7);
    remove_action('wp_print_styles', 'print_emoji_styles');
    
    // Remove emoji scripts and styles from admin area
    remove_action('admin_print_scripts', 'print_emoji_detection_script');
    remove_action('admin_print_styles', 'print_emoji_styles'); 
    
    // Remove emojis from RSS feeds
    remove_filter('the_content_feed', 'wp_staticize_emoji');
    remove_filter('comment_text_rss', 'wp_staticize_emoji'); 
    
    // Remove emojis from emails
    remove_filter('wp_mail', 'wp_staticize_emoji_for_email');
    
    // Disable emoji in TinyMCE editor
    add_filter('tiny_mce_plugins', 'disable_emojis_tinymce');
    
    // Remove emoji DNS prefetch
    add_filter('wp_resource_hints', 'disable_emojis_remove_dns_prefetch', 10, 2);
}
add_action('init', 'disable_emojis');

/**
 * Add settings link to plugins page
 * 
 * @param array $links Plugin action links
 * @return array Modified plugin action links
 */
function es_optimizer_add_settings_link($links) {
    $settings_link = '<a href="' . admin_url('options-general.php?page=es-optimizer-settings') . '">' . __('Settings') . '</a>';
    array_unshift($links, $settings_link);
    return $links;
}
$plugin = plugin_basename(__FILE__);
add_filter("plugin_action_links_$plugin", 'es_optimizer_add_settings_link');

/**
 * Filter function used to remove the tinymce emoji plugin.
 * 
 * @param array $plugins 
 * @return array Difference betwen the two arrays
 */
function disable_emojis_tinymce($plugins) {
    if (is_array($plugins)) {
        return array_diff($plugins, array('wpemoji'));
    }
    return array();
}

/**
 * Remove emoji CDN hostname from DNS prefetching hints.
 *
 * @param array $urls URLs to print for resource hints.
 * @param string $relation_type The relation type the URLs are printed for.
 * @return array Difference betwen the two arrays.
 */
function disable_emojis_remove_dns_prefetch($urls, $relation_type) {
    if ('dns-prefetch' == $relation_type) {
        $emoji_svg_url = apply_filters('emoji_svg_url', 'https://s.w.org/images/core/emoji/2/svg/');
        $urls = array_diff($urls, array($emoji_svg_url));
    }
    return $urls;
}

/**
 * Remove JQuery Migrate
 * 
 * jQuery Migrate is primarily used for backward compatibility with older jQuery code.
 * Modern themes and plugins generally don't need it, so removing it improves load time.
 * 
 * @since 1.0.0
 * @param WP_Scripts $scripts WP_Scripts object
 */
function remove_jquery_migrate($scripts) {
    $options = get_option('es_optimizer_options');
    
    // Only proceed if the option is enabled
    if (!isset($options['remove_jquery_migrate']) || !$options['remove_jquery_migrate']) {
        return;
    }
    
    if (!is_admin() && isset($scripts->registered['jquery'])) {
        $script = $scripts->registered['jquery'];
        
        // Remove jquery-migrate from jquery dependencies
        if ($script->deps) {
            $script->deps = array_diff($script->deps, array('jquery-migrate'));
        }
    }
}
add_action('wp_default_scripts', 'remove_jquery_migrate');

/**
 * Disable classic-themes css added in WP 6.1
 */
function disable_classic_theme_styles() {
    $options = get_option('es_optimizer_options');
    
    // Only proceed if the option is enabled
    if (!isset($options['disable_classic_theme_styles']) || !$options['disable_classic_theme_styles']) {
        return;
    }
    
    wp_deregister_style('classic-theme-styles');
    wp_dequeue_style('classic-theme-styles');
}
add_action('wp_enqueue_scripts', 'disable_classic_theme_styles', 100);

/**
 * Remove WordPress version, WLW manifest, and shortlink
 */
function remove_header_items() {
    $options = get_option('es_optimizer_options');
    
    // Remove WordPress Version from Header
    if (isset($options['remove_wp_version']) && $options['remove_wp_version']) {
        remove_action('wp_head', 'wp_generator');
    }
    
    // Remove Windows Live Writer Manifest
    if (isset($options['remove_wlw_manifest']) && $options['remove_wlw_manifest']) {
        remove_action('wp_head', 'wlwmanifest_link');
    }
    
    // Remove WP Shortlink URLs
    if (isset($options['remove_shortlink']) && $options['remove_shortlink']) {
        remove_action('wp_head', 'wp_shortlink_wp_head', 10, 0);
    }
}
add_action('init', 'remove_header_items');

/**
 * Remove Recent Comments Widget CSS Styles
 */
function remove_recent_comments_style() {
    $options = get_option('es_optimizer_options');
    
    // Only proceed if the option is enabled
    if (isset($options['remove_recent_comments_style']) && $options['remove_recent_comments_style']) {
        add_filter('show_recent_comments_widget_style', '__return_false', 99);
    }
}
add_action('init', 'remove_recent_comments_style');

/**
 * Add DNS prefetching for common external domains
 * 
 * DNS prefetching can reduce latency when connecting to common external services.
 * This is particularly helpful for sites using Google Fonts, Analytics, etc.
 * 
 * @since 1.4.1
 */
function add_dns_prefetch() {
    $options = get_option('es_optimizer_options');
    
    // Only proceed if the option is enabled
    if (!isset($options['enable_dns_prefetch']) || !$options['enable_dns_prefetch']) {
        return;
    }
    
    // Only add if not admin
    if (is_admin()) {
        return;
    }

    // Get domains from settings
    $domains = array();
    if (isset($options['dns_prefetch_domains']) && !empty($options['dns_prefetch_domains'])) {
        $domains = explode("\n", $options['dns_prefetch_domains']);
        $domains = array_map('trim', $domains);
        $domains = array_filter($domains);
    }
    
    // Output the prefetch links
    foreach ($domains as $domain) {
        echo '<link rel="dns-prefetch" href="' . esc_attr($domain) . '" />' . "\n";
    }
}
// Hook after wp_head and before other elements are added
add_action('wp_head', 'add_dns_prefetch', 0);

/**
 * Disable Jetpack advertisements
 */
function disable_jetpack_ads() {
    $options = get_option('es_optimizer_options');
    
    // Only proceed if the option is enabled
    if (isset($options['disable_jetpack_ads']) && $options['disable_jetpack_ads']) {
        add_filter('jetpack_just_in_time_msgs', '__return_false', 20);
        add_filter('jetpack_show_promotions', '__return_false', 20);
        add_filter('jetpack_blaze_enabled', '__return_false');
    }
}
add_action('init', 'disable_jetpack_ads');