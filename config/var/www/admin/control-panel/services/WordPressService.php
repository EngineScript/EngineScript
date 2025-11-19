<?php
/**
 * WordPressService
 * WordPress sites discovery and management
 * 
 * @version 1.0.0
 */

class WordPressService {
    
    /**
     * Get all WordPress sites
     * @return array List of WordPress sites
     */
    public static function getWordPressSites() {
        $sites = [];
        $nginx_sites_path = '/etc/nginx/sites-enabled';
        
        try {
            $real_path = self::validateNginxSitesPath($nginx_sites_path);
            if (!$real_path) {
                return $sites;
            }
            
            $valid_files = self::scanNginxConfigs($real_path);
            if ($valid_files === false) {
                return $sites;
            }
            
            foreach ($valid_files as $config_real_path) {
                $site_info = self::processNginxConfig($config_real_path);
                if ($site_info !== null) {
                    $sites[] = $site_info;
                }
            }
        } catch (Exception $e) {
            error_log('WordPress sites enumeration error: ' . $e->getMessage());
        }
        
        return $sites;
    }
    
    /**
     * Get WordPress version from document root
     * @param string $document_root Document root path
     * @return string WordPress version
     */
    public static function getWordPressVersion($document_root) {
        try {
            $real_version_file = self::validateWordPressPath($document_root);
            if (!$real_version_file) {
                return 'Unknown';
            }
            
            return self::parseWordPressVersion($real_version_file);
        } catch (Exception $e) {
            error_log('WordPress version detection error: ' . $e->getMessage());
            return 'Unknown';
        }
    }
    
    /**
     * Validate nginx sites path
     * @param string $nginx_sites_path Path to validate
     * @return string|false Real path or false
     */
    private static function validateNginxSitesPath($nginx_sites_path) {
        $real_path = realpath($nginx_sites_path);
        if ($real_path !== '/etc/nginx/sites-enabled') {
            error_log('Nginx sites path traversal attempt: ' . $nginx_sites_path);
            return false;
        }
        
        if (!is_dir($real_path)) {
            return false;
        }
        
        return $real_path;
    }
    
    /**
     * Scan nginx config files
     * @param string $real_path Real path to scan
     * @return array|false Array of valid files or false
     */
    private static function scanNginxConfigs($real_path) {
        $files = scandir($real_path);
        if ($files === false) {
            return false;
        }
        
        $valid_files = [];
        foreach ($files as $file) {
            if ($file === '.' || $file === '..' || $file === 'default') {
                continue;
            }
            
            if (!preg_match('/^[a-zA-Z0-9._-]+$/', $file)) {
                error_log('Suspicious nginx config filename: ' . $file);
                continue;
            }
            
            $config_path = $real_path . '/' . $file;
            $config_real_path = realpath($config_path);
            
            if (!$config_real_path || strpos($config_real_path, $real_path . '/') !== 0) {
                error_log('Config file path traversal attempt: ' . $config_path);
                continue;
            }
            
            $valid_files[] = $config_real_path;
        }
        
        return $valid_files;
    }
    
    /**
     * Process nginx config file
     * @param string $config_real_path Config file path
     * @return array|null Site information or null
     */
    private static function processNginxConfig($config_real_path) {
        $config_content = file_get_contents($config_real_path);
        if ($config_content === false) {
            return null;
        }
        
        if (strpos($config_content, 'wordpress') === false && 
            strpos($config_content, 'wp-') === false) {
            return null;
        }
        
        $domain = '';
        $document_root = '';
        
        if (preg_match('/server_name\s+([a-zA-Z0-9.-]+(?:\s+[a-zA-Z0-9.-]+)*)\s*;/', $config_content, $matches)) {
            $domain = trim($matches[1]);
            $domain_parts = preg_split('/\s+/', $domain);
            $primary_domain = $domain_parts[0];
            
            if (filter_var($primary_domain, FILTER_VALIDATE_DOMAIN, FILTER_FLAG_HOSTNAME)) {
                $domain = htmlspecialchars($primary_domain, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
            }
        }
        
        if (preg_match('/root\s+([^\s;]+)\s*;/', $config_content, $matches)) {
            $document_root = trim($matches[1]);
            if (preg_match('/^\/[a-zA-Z0-9\/_.-]+$/', $document_root)) {
                $document_root = realpath($document_root);
            }
            
            if (!$document_root) {
                $document_root = '';
            }
        }
        
        if (empty($domain)) {
            return null;
        }
        
        $wp_version = self::getWordPressVersion($document_root);
        
        return [
            'domain' => $domain,
            'status' => 'online',
            'wp_version' => $wp_version,
            'ssl_status' => 'Enabled'
        ];
    }
    
    /**
     * Validate WordPress path
     * @param string $document_root Document root path
     * @return string|false Version file path or false
     */
    private static function validateWordPressPath($document_root) {
        if (empty($document_root) || !is_dir($document_root)) {
            return false;
        }
        
        $version_file = $document_root . '/wp-includes/version.php';
        $real_version_file = realpath($version_file);
        
        if (!$real_version_file || 
            strpos($real_version_file, realpath($document_root) . '/') !== 0) {
            return false;
        }
        
        if (file_exists($real_version_file) && is_readable($real_version_file)) {
            return $real_version_file;
        }
        
        return false;
    }
    
    /**
     * Parse WordPress version from file
     * @param string $real_version_file Version file path
     * @return string WordPress version
     */
    private static function parseWordPressVersion($real_version_file) {
        $content = file_get_contents($real_version_file);
        if ($content === false) {
            return 'Unknown';
        }
        
        if (preg_match('/\$wp_version\s*=\s*[\'"]([0-9]+\.[0-9]+(?:\.[0-9]+)?(?:-[a-zA-Z0-9-]+)?)[\'"]/', $content, $matches)) {
            $version = $matches[1];
            if (preg_match('/^[0-9]+\.[0-9]+(?:\.[0-9]+)?(?:-[a-zA-Z0-9-]+)?$/', $version)) {
                return htmlspecialchars($version, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
            }
        }
        
        return 'Unknown';
    }
}
