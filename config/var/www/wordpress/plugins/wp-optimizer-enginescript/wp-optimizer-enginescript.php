<?php
/*
Plugin Name: WP Optimization (EngineScript)
Description: Optimizes WordPress by removing unnecessary features and scripts
Version: 1.2.0
Author: EngineScript
License: GPL v2 or later
*/

// Prevent direct access
if (!defined('ABSPATH')) {
    exit('No direct script access allowed');
}

/**
 * Disable the emoji's
 */
function disable_emojis() {
    remove_action('wp_head', 'print_emoji_detection_script', 7);
    remove_action('admin_print_scripts', 'print_emoji_detection_script');
    remove_action('wp_print_styles', 'print_emoji_styles');
    remove_action('admin_print_styles', 'print_emoji_styles'); 
    remove_filter('the_content_feed', 'wp_staticize_emoji');
    remove_filter('comment_text_rss', 'wp_staticize_emoji'); 
    remove_filter('wp_mail', 'wp_staticize_emoji_for_email');
    add_filter('tiny_mce_plugins', 'disable_emojis_tinymce');
    add_filter('wp_resource_hints', 'disable_emojis_remove_dns_prefetch', 10, 2);
}
add_action('init', 'disable_emojis');

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
 */
function remove_jquery_migrate($scripts) {
    if (!is_admin() && isset($scripts->registered['jquery'])) {
        $script = $scripts->registered['jquery'];
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
    wp_deregister_style('classic-theme-styles');
    wp_dequeue_style('classic-theme-styles');
}
add_filter('wp_enqueue_scripts', 'disable_classic_theme_styles', 100);

// Remove WordPress Version from Header
remove_action('wp_head', 'wp_generator');

// Remove Windows Live Writer Manifest
remove_action('wp_head', 'wlwmanifest_link');

// Remove WP Shortlink URLs
remove_action('wp_head', 'wp_shortlink_wp_head', 10, 0);

// Remove Recent Comments Widget CSS Styles
add_filter('show_recent_comments_widget_style', '__return_false', 99);

// Remove Jetpack Advertisements
add_filter('jetpack_just_in_time_msgs', '__return_false', 20);
add_filter('jetpack_show_promotions', '__return_false', 20);
add_filter('jetpack_blaze_enabled', '__return_false');