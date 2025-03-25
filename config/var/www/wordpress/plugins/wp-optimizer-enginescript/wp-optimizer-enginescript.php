<?php
/*
Plugin Name: WP Optimization (EngineScript)
Description: Optimizes WordPress by removing unnecessary features and scripts
Version: 1.1.0
Author: EngineScript
License: GPL v2 or later
*/

// Define plugin constants
define('WP_OPTIMIZATION_VERSION', '1.1.0');
define('WP_OPTIMIZATION_FILE', __FILE__);
define('WP_OPTIMIZATION_PATH', plugin_dir_path(__FILE__));

// Prevent direct access
if (!defined('ABSPATH')) {
    exit('No direct script access allowed');
}

class WP_Optimization {
    private static $instance = null;
    
    /**
     * Get plugin instance
     */
    public static function get_instance() {
        if (null === self::$instance) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    /**
     * Private constructor to prevent direct creation
     */
    private function __construct() {
        // Initialize plugin
        add_action('init', [$this, 'disable_emojis']);
        add_action('wp_default_scripts', [$this, 'remove_jquery_migrate']);
        add_filter('wp_enqueue_scripts', [$this, 'disable_classic_theme_styles'], 100);
        
        // Remove header items
        remove_action('wp_head', 'wp_generator');
        remove_action('wp_head', 'wlwmanifest_link');
        remove_action('wp_head', 'wp_shortlink_wp_head', 10, 0);
        remove_action('wp_head', 'rest_output_link_wp_head');
        remove_action('wp_head', 'wp_oembed_add_discovery_links');
        remove_action('wp_head', 'rsd_link');
        
        // Disable widget styles and Jetpack ads
        add_filter('show_recent_comments_widget_style', '__return_false', 99);
        
        // Only add Jetpack filters if active
        if ($this->is_jetpack_active()) {
            add_filter('jetpack_just_in_time_msgs', '__return_false', 20);
            add_filter('jetpack_show_promotions', '__return_false', 20);
            add_filter('jetpack_blaze_enabled', '__return_false');
        }
    }

    /**
     * Check if Jetpack is active
     */
    private function is_jetpack_active() {
        return class_exists('Jetpack');
    }

    /**
     * Disable the emoji's
     */
    public function disable_emojis() {
        remove_action('wp_head', 'print_emoji_detection_script', 7);
        remove_action('admin_print_scripts', 'print_emoji_detection_script');
        remove_action('wp_print_styles', 'print_emoji_styles');
        remove_action('admin_print_styles', 'print_emoji_styles'); 
        remove_filter('the_content_feed', 'wp_staticize_emoji');
        remove_filter('comment_text_rss', 'wp_staticize_emoji'); 
        remove_filter('wp_mail', 'wp_staticize_emoji_for_email');
        add_filter('tiny_mce_plugins', [$this, 'disable_emojis_tinymce']);
        add_filter('wp_resource_hints', [$this, 'disable_emojis_remove_dns_prefetch'], 10, 2);
    }

    /**
     * Filter function used to remove the tinymce emoji plugin.
     * 
     * @param array $plugins 
     * @return array Difference between the two arrays
     */
    public function disable_emojis_tinymce($plugins) {
        return is_array($plugins) ? array_diff($plugins, ['wpemoji']) : [];
    }

    /**
     * Remove emoji CDN hostname from DNS prefetching hints.
     *
     * @param array $urls URLs to print for resource hints.
     * @param string $relation_type The relation type the URLs are printed for.
     * @return array Difference between the two arrays.
     */
    public function disable_emojis_remove_dns_prefetch($urls, $relation_type) {
        if ('dns-prefetch' == $relation_type) {
            $emoji_svg_url = apply_filters('emoji_svg_url', 'https://s.w.org/images/core/emoji/2/svg/');
            $urls = array_diff($urls, [$emoji_svg_url]);
        }
        return $urls;
    }

    /**
     * Remove JQuery Migrate
     */
    public function remove_jquery_migrate($scripts) {
        if (!is_admin() && isset($scripts->registered['jquery'])) {
            $script = $scripts->registered['jquery'];
            if ($script->deps) {
                $script->deps = array_diff($script->deps, ['jquery-migrate']);
            }
        }
    }

    /**
     * Disable classic-themes css added in WP 6.1
     */
    public function disable_classic_theme_styles() {
        wp_deregister_style('classic-theme-styles');
        wp_dequeue_style('classic-theme-styles');
    }

    // Prevent cloning
    private function __clone() {}
    
    // Prevent unserialize
    private function __wakeup() {}
}

// Initialize using singleton
WP_Optimization::get_instance();
