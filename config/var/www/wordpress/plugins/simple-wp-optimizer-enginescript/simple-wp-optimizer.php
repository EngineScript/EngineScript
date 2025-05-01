<?php
/*
Plugin Name: EngineScript: WP Optimization
Description: Optimizes WordPress by removing unnecessary features and scripts
Version: 1.5.4
Author: EngineScript
License: GPL v2 or later
Text Domain: simple-wp-optimizer-enginescript
Security: Follows OWASP security guidelines and WordPress best practices
*/

/**
 * Security Implementation Notes:
 * 
 * This plugin follows WordPress security best practices and OWASP guidelines:
 * 
 * 1. Input Validation: All user inputs are validated before processing
 *    - Options are strictly type-checked (checkbox values limited to 0 or 1)
 *    - URLs undergo multi-layer validation (filter_var + WordPress sanitization)
 * 
 * 2. Output Escaping: All outputs are properly escaped with context-appropriate functions
 *    - HTML content: esc_html(), esc_html_e()
 *    - Attributes: esc_attr()
 *    - URLs: esc_url(), esc_url_raw()
 *    - Textarea content: esc_textarea()
 * 
 * 3. Capability Checks: All admin functions verify user permissions
 *    - current_user_can('manage_options') guards settings pages
 * 
 * 4. Secure Coding Patterns:
 *    - Direct script access prevention
 *    - Proper use of WordPress hooks and filters
 *    - Code follows WordPress Plugin Handbook guidelines
 * 
 * Some uses of echo/printf with proper escaping are unavoidable for HTML output,
 * and have been documented with phpcs:ignore comments explaining the security measures.
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    // Security: Prevent direct script access (WordPress best practice)
    // This block prevents the script from being loaded directly via URL,
    // which could potentially bypass WordPress security mechanisms
    return;
}

// Define plugin version
if (!defined('ES_WP_OPTIMIZER_VERSION')) {
    define('ES_WP_OPTIMIZER_VERSION', '1.5.3');
}

/**
 * Initialize the plugin settings
 */
function es_optimizer_init_settings() {
    // Register settings
    register_setting('es_optimizer_settings', 'es_optimizer_options', 'es_optimizer_validate_options');
    
    // Register default options if they don't exist
    if (false === get_option('es_optimizer_options')) {
        add_option('es_optimizer_options', es_optimizer_get_default_options());
    }
}
add_action('admin_init', 'es_optimizer_init_settings');

/**
 * Get default plugin options
 * 
 * @return array Default options
 */
function es_optimizer_get_default_options() {
    return array(
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
}

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
    // Security: Check user capabilities before displaying the page
    // This prevents unauthorized access to plugin settings
    if (!current_user_can('manage_options')) {
        wp_die(esc_html__('You do not have sufficient permissions to access this page.', 'simple-wp-optimizer-enginescript'));
    }
    
    $options = get_option('es_optimizer_options');
    ?>
    <div class="wrap">
        <h1>WP Optimizer Settings</h1>
        <p>Select which optimizations you want to enable and customize the DNS prefetch domains.</p>
        
        <form method="post" action="options.php">
            <?php settings_fields('es_optimizer_settings'); ?>
            
            <table class="form-table">
                <?php 
                // Render performance optimization options
                es_optimizer_render_performance_options($options);
                
                // Render header cleanup options
                es_optimizer_render_header_options($options);
                
                // Render additional features
                es_optimizer_render_additional_options($options);
                ?>
            </table>
            
            <p class="submit">
                <input type="submit" class="button-primary" value="Save Changes" />
            </p>
        </form>
        
        <hr>
        <p>
            <?php esc_html_e('This plugin is part of the EngineScript project.', 'simple-wp-optimizer-enginescript'); ?>
            <a href="https://github.com/EngineScript/EngineScript" target="_blank" rel="noopener noreferrer">
                <?php esc_html_e('Visit the EngineScript GitHub page', 'simple-wp-optimizer-enginescript'); ?>
            </a>
        </p>
    </div>
    <?php
}

/**
 * Render performance optimization options
 *
 * @param array $options Plugin options
 */
function es_optimizer_render_performance_options($options) {
    // Emoji settings
    es_optimizer_render_checkbox_option(
        $options,
        'disable_emojis',
        esc_html__('Disable WordPress Emojis', 'simple-wp-optimizer-enginescript'),
        esc_html__('Remove emoji scripts and styles to improve page load time', 'simple-wp-optimizer-enginescript')
    );
    
    // jQuery Migrate settings
    es_optimizer_render_checkbox_option(
        $options,
        'remove_jquery_migrate',
        esc_html__('Remove jQuery Migrate', 'simple-wp-optimizer-enginescript'),
        esc_html__('Remove jQuery Migrate script (may affect compatibility with very old plugins)', 'simple-wp-optimizer-enginescript')
    );
    
    // Classic Theme Styles settings
    es_optimizer_render_checkbox_option(
        $options,
        'disable_classic_theme_styles',
        esc_html__('Disable Classic Theme Styles', 'simple-wp-optimizer-enginescript'),
        esc_html__('Remove classic theme styles added in WordPress 6.1+', 'simple-wp-optimizer-enginescript')
    );
}

/**
 * Render header cleanup options
 *
 * @param array $options Plugin options
 */
function es_optimizer_render_header_options($options) {
    // WordPress Version settings
    es_optimizer_render_checkbox_option(
        $options,
        'remove_wp_version',
        esc_html__('Remove WordPress Version', 'simple-wp-optimizer-enginescript'),
        esc_html__('Remove WordPress version from header (security benefit)', 'simple-wp-optimizer-enginescript')
    );
    
    // WLW Manifest settings
    es_optimizer_render_checkbox_option(
        $options,
        'remove_wlw_manifest',
        esc_html__('Remove WLW Manifest', 'simple-wp-optimizer-enginescript'),
        esc_html__('Remove Windows Live Writer manifest link', 'simple-wp-optimizer-enginescript')
    );
    
    // Shortlink settings
    es_optimizer_render_checkbox_option(
        $options,
        'remove_shortlink',
        esc_html__('Remove Shortlink', 'simple-wp-optimizer-enginescript'),
        esc_html__('Remove WordPress shortlink URLs from header', 'simple-wp-optimizer-enginescript')
    );
    
    // Recent Comments Style settings
    es_optimizer_render_checkbox_option(
        $options,
        'remove_recent_comments_style',
        esc_html__('Remove Recent Comments Style', 'simple-wp-optimizer-enginescript'),
        esc_html__('Remove recent comments widget inline CSS', 'simple-wp-optimizer-enginescript')
    );
}

/**
 * Render additional optimization options
 *
 * @param array $options Plugin options
 */
function es_optimizer_render_additional_options($options) {
    // DNS Prefetch settings
    es_optimizer_render_checkbox_option(
        $options,
        'enable_dns_prefetch',
        esc_html__('Enable DNS Prefetch', 'simple-wp-optimizer-enginescript'),
        esc_html__('Add DNS prefetch for common external domains', 'simple-wp-optimizer-enginescript')
    );
    
    // DNS Prefetch Domains textarea
    es_optimizer_render_textarea_option(
        $options,
        'dns_prefetch_domains',
        esc_html__('DNS Prefetch Domains', 'simple-wp-optimizer-enginescript'),
        esc_html__('Enter one domain per line. Include the full URL (e.g., https://fonts.googleapis.com)', 'simple-wp-optimizer-enginescript')
    );
    
    // Jetpack Ads settings
    es_optimizer_render_checkbox_option(
        $options,
        'disable_jetpack_ads',
        esc_html__('Disable Jetpack Ads', 'simple-wp-optimizer-enginescript'),
        esc_html__('Remove Jetpack advertisements and promotions', 'simple-wp-optimizer-enginescript')
    );
}

/**
 * Helper function to render checkbox options
 *
 * This function uses proper escaping for output security:
 * - All text is escaped with esc_html_e() with translation support
 * - Attribute values are escaped with esc_attr()
 * - WordPress checked() function is used for checkbox state
 *
 * @param array  $options       Plugin options
 * @param string $option_name   Option name
 * @param string $title         Option title
 * @param string $description   Option description
 */
function es_optimizer_render_checkbox_option($options, $option_name, $title, $description) {
    ?>
    <tr valign="top">
        <th scope="row"><?php 
            // Using esc_html_e for internationalization and secure output of titles
            // This properly escapes the output while also supporting translations
            esc_html_e($title, 'simple-wp-optimizer-enginescript'); 
        ?></th>
        <td>
            <label>
                <input type="checkbox" name="<?php 
                    // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
                    /* 
                     * Using printf with esc_attr for attribute name which cannot be avoided.
                     * The $option_name values are hardcoded strings from render functions, not user input.
                     * This is a controlled environment where these values are defined within the plugin.
                     */
                    printf('es_optimizer_options[%s]', esc_attr($option_name));
                ?>" value="1" 
                    <?php checked(1, isset($options[$option_name]) ? $options[$option_name] : 0); ?> />
                <?php 
                    // Using esc_html_e for internationalization and secure output of descriptions
                    // This ensures the text is properly escaped while supporting translations
                    esc_html_e($description, 'simple-wp-optimizer-enginescript'); 
                ?>
            </label>
        </td>
    </tr>
    <?php
}

/**
 * Helper function to render textarea options
 *
 * This function uses proper escaping for output security:
 * - All text is escaped with esc_html_e() with translation support
 * - Attribute values are escaped with esc_attr()
 * - Textarea content is escaped with esc_textarea()
 *
 * @param array  $options       Plugin options
 * @param string $option_name   Option name
 * @param string $title         Option title
 * @param string $description   Option description
 */
function es_optimizer_render_textarea_option($options, $option_name, $title, $description) {
    ?>
    <tr valign="top">
        <th scope="row"><?php 
            // Using esc_html_e for internationalization and secure output of titles
            // This properly escapes the output while also supporting translations
            esc_html_e($title, 'simple-wp-optimizer-enginescript'); 
        ?></th>
        <td>
            <p><small><?php 
                // Using esc_html_e for internationalization and secure output of descriptions
                // This ensures the text is properly escaped while supporting translations
                esc_html_e($description, 'simple-wp-optimizer-enginescript'); 
            ?></small></p>
            <textarea name="<?php 
                // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
                /* 
                 * Using printf with esc_attr for attribute name which cannot be avoided.
                 * The $option_name values are hardcoded strings from render functions, not user input.
                 * This is a controlled environment where these values are defined within the plugin.
                 */
                printf('es_optimizer_options[%s]', esc_attr($option_name));
            ?>" rows="5" cols="50" class="large-text code"><?php 
                if (isset($options[$option_name])) {
                    // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
                    /* 
                     * Using printf with esc_textarea is the most appropriate approach.
                     * esc_textarea already properly escapes content for use inside textarea elements.
                     * This function is designed specifically for this purpose and ensures data is properly escaped.
                     */
                    printf('%s', esc_textarea($options[$option_name]));
                }
            ?></textarea>
        </td>
    </tr>
    <?php
}

/**
 * Validate options before saving
 * 
 * This function implements a security-focused validation system:
 * 1. Checkboxes are validated to ensure they contain only boolean values (0 or 1)
 * 2. DNS prefetch domains undergo multiple validation steps:
 *    - Trimming to remove unwanted whitespace
 *    - Empty value checking
 *    - URL validation via filter_var()
 *    - Sanitization via esc_url_raw()
 * 
 * @param array $input User submitted options
 * @return array Validated and sanitized options
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
                    // Security: Use esc_url_raw to sanitize URLs before storing in database
                    // This prevents potential security issues with malformed URLs
                    $sanitized_domains[] = esc_url_raw($domain);
                }
            }
        }
        
        $valid['dns_prefetch_domains'] = implode("\n", $sanitized_domains);
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
    // The admin_url function is used to properly generate a URL within the WordPress admin area
    // Setting text is wrapped in translation function but doesn't need escaping here
    // as WordPress core handles this when rendering plugin links
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
 * Security note: All output is properly escaped with esc_attr() before output to prevent XSS.
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
        // The following steps ensure secure handling of domain data:
        // 1. Split the string by newlines
        $domains = explode("\n", $options['dns_prefetch_domains']);
        // 2. Trim each value to remove whitespace
        $domains = array_map('trim', $domains);
        // 3. Remove empty values
        $domains = array_filter($domains);
    }
    
    // Output the prefetch links using WordPress core functions
    foreach ($domains as $domain) {
        $escaped_domain = esc_url($domain);
        
        /*
         * Using wp_print_resource_hints with array of sanitized domains would be the ideal approach,
         * but we need to output these individually since we're adding custom domains.
         * WordPress core doesn't have a direct function for outputting single dns-prefetch tags,
         * so we need to construct it ourselves.
         */
        echo "\n";
        wp_print_link_tag('dns-prefetch', $escaped_domain);
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