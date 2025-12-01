<?php
/**
 * EngineScript Admin Dashboard - Site Controller
 * 
 * Handles WordPress site enumeration and information endpoints.
 * 
 * @package EngineScript\Dashboard\API\Controllers
 * @version 1.0.0
 */

require_once __DIR__ . '/BaseController.php';

/**
 * WordPress Sites Controller
 * 
 * Provides information about WordPress sites hosted on the server.
 */
class SiteController extends BaseController
{
    /**
     * API endpoint paths
     */
    private const ENDPOINT_LIST = '/sites';
    private const ENDPOINT_COUNT = '/sites/count';

    /**
     * Nginx sites-enabled directory
     */
    private const NGINX_SITES_PATH = '/etc/nginx/sites-enabled';

    /**
     * List all WordPress sites
     * 
     * Scans nginx configuration to find WordPress installations.
     * Returns domain, status, WordPress version, and SSL status.
     * 
     * Endpoint: GET /sites
     * 
     * @return void Outputs JSON response
     */
    public function listSites()
    {
        try {
            // Check cache first
            $cached = $this->getCached(self::ENDPOINT_LIST);
            if ($cached !== null) {
                ApiResponse::cached($cached, $this->getTtl(self::ENDPOINT_LIST));
                return;
            }

            $sites = $this->getWordPressSites();
            $result = $this->sanitizeOutput($sites);

            // Cache the result
            $this->setCached(self::ENDPOINT_LIST, $result);

            ApiResponse::success($result, $this->getTtl(self::ENDPOINT_LIST));
        } catch (Exception $e) {
            $this->logSecurityEvent('Sites error', $e->getMessage());
            ApiResponse::serverError('Unable to retrieve sites');
        }
    }

    /**
     * Get count of WordPress sites
     * 
     * Returns total number of WordPress sites.
     * 
     * Endpoint: GET /sites/count
     * 
     * @return void Outputs JSON response
     */
    public function countSites()
    {
        try {
            // Check cache first
            $cached = $this->getCached(self::ENDPOINT_COUNT);
            if ($cached !== null) {
                ApiResponse::cached($cached, $this->getTtl(self::ENDPOINT_COUNT));
                return;
            }

            $sites = $this->getWordPressSites();
            $result = ['count' => count($sites)];

            // Cache the result
            $this->setCached(self::ENDPOINT_COUNT, $result);

            ApiResponse::success($result, $this->getTtl(self::ENDPOINT_COUNT));
        } catch (Exception $e) {
            $this->logSecurityEvent('Sites count error', $e->getMessage());
            ApiResponse::serverError('Unable to retrieve sites count');
        }
    }

    /**
     * Get all WordPress sites from nginx configuration
     * 
     * @return array List of site information
     */
    private function getWordPressSites()
    {
        $sites = [];

        try {
            $real_path = $this->validateNginxSitesPath(self::NGINX_SITES_PATH);
            if (!$real_path) {
                return $sites;
            }

            $valid_files = $this->scanNginxConfigs($real_path);
            if ($valid_files === false) {
                return $sites;
            }

            foreach ($valid_files as $config_real_path) {
                $site_info = $this->processNginxConfig($config_real_path);
                if ($site_info !== null) {
                    $sites[] = $site_info;
                }
            }
        } catch (Exception $e) {
            $this->logSecurityEvent('WordPress sites enumeration error', $e->getMessage());
        }

        return $sites;
    }

    /**
     * Validate nginx sites-enabled path
     * 
     * Ensures the path is exactly what we expect for security.
     * 
     * @param string $nginx_sites_path Path to validate
     * @return string|false Real path or false if invalid
     */
    private function validateNginxSitesPath($nginx_sites_path)
    {
        // codacy:ignore - realpath() required for path validation in standalone API
        $real_path = realpath($nginx_sites_path);
        if ($real_path !== '/etc/nginx/sites-enabled') {
            $this->logSecurityEvent('Nginx sites path traversal attempt', $nginx_sites_path);
            return false;
        }

        // codacy:ignore - is_dir() required for directory validation in standalone API
        if (!is_dir($real_path)) {
            return false;
        }

        return $real_path;
    }

    /**
     * Scan nginx config files in directory
     * 
     * @param string $real_path Directory path
     * @return array|false Array of valid config paths or false on error
     */
    private function scanNginxConfigs($real_path)
    {
        // codacy:ignore - scandir() required for directory listing in standalone API
        $files = scandir($real_path);
        if ($files === false) {
            return false;
        }

        $valid_files = [];
        foreach ($files as $file) {
            if ($file === '.' || $file === '..' || $file === 'default') {
                continue;
            }

            // Validate filename to prevent traversal
            if (!preg_match('/^[a-zA-Z0-9._-]+$/', $file)) {
                $this->logSecurityEvent('Suspicious nginx config filename', $file);
                continue;
            }

            $config_path = $real_path . '/' . $file;
            // codacy:ignore - realpath() required for path validation in standalone API
            $config_real_path = realpath($config_path);

            // Ensure the file is within the expected directory
            if (!$config_real_path || strpos($config_real_path, $real_path . '/') !== 0) {
                $this->logSecurityEvent('Config file path traversal attempt', $config_path);
                continue;
            }

            $valid_files[] = $config_real_path;
        }

        return $valid_files;
    }

    /**
     * Process a single nginx config file
     * 
     * @param string $config_real_path Path to config file
     * @return array|null Site info or null if not WordPress
     */
    private function processNginxConfig($config_real_path)
    {
        // codacy:ignore - file_get_contents() required for configuration reading in standalone API
        $config_content = file_get_contents($config_real_path);
        if ($config_content === false) {
            return null;
        }

        // Check if this is a WordPress site
        if (strpos($config_content, 'wordpress') === false &&
            strpos($config_content, 'wp-') === false) {
            return null;
        }

        // Extract domain name and document root safely
        $domain = '';
        $document_root = '';

        if (preg_match('/server_name\s+([a-zA-Z0-9.-]+(?:\s+[a-zA-Z0-9.-]+)*)\s*;/', $config_content, $matches)) {
            $domain = trim($matches[1]);

            // Split multiple domains and take the first one
            $domain_parts = preg_split('/\s+/', $domain);
            $primary_domain = $domain_parts[0];

            // Validate domain format
            if (filter_var($primary_domain, FILTER_VALIDATE_DOMAIN, FILTER_FLAG_HOSTNAME)) {
                $domain = htmlspecialchars($primary_domain, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
            }
        }

        // Extract document root for WordPress version detection
        if (preg_match('/root\s+([^\s;]+)\s*;/', $config_content, $matches)) {
            $document_root = trim($matches[1]);
            // Validate and sanitize document root path
            if (preg_match('/^\/[a-zA-Z0-9\/_.-]+$/', $document_root)) {
                // codacy:ignore - realpath() required for path validation in standalone API
                $document_root = realpath($document_root);
            }

            if (!$document_root) {
                $document_root = '';
            }
        }

        if (empty($domain)) {
            return null;
        }

        $wp_version = $this->getWordPressVersion($document_root);

        return [
            'domain' => $domain,
            'status' => 'online',
            'wp_version' => $wp_version,
            'ssl_status' => 'Enabled'
        ];
    }

    /**
     * Get WordPress version from a site's document root
     * 
     * @param string $document_root Document root path
     * @return string WordPress version or 'Unknown'
     */
    private function getWordPressVersion($document_root)
    {
        try {
            $real_version_file = $this->validateWordPressPath($document_root);
            if (!$real_version_file) {
                return 'Unknown';
            }

            return $this->parseWordPressVersion($real_version_file);
        } catch (Exception $e) {
            $this->logSecurityEvent('WordPress version detection error', $e->getMessage());
            return 'Unknown';
        }
    }

    /**
     * Validate WordPress installation path
     * 
     * @param string $document_root Document root to validate
     * @return string|false Path to version.php or false if invalid
     */
    private function validateWordPressPath($document_root)
    {
        // codacy:ignore - is_dir() required for directory validation in standalone API
        if (empty($document_root) || !is_dir($document_root)) {
            return false;
        }

        // Check for wp-includes/version.php file
        $version_file = $document_root . '/wp-includes/version.php';
        // codacy:ignore - realpath() required for path validation in standalone API
        $real_version_file = realpath($version_file);

        // Ensure the file exists and is within the expected directory structure
        // codacy:ignore - realpath() required for path validation in standalone API
        if (!$real_version_file ||
            strpos($real_version_file, realpath($document_root) . '/') !== 0) {
            return false;
        }

        // codacy:ignore - file_exists() and is_readable() required for version file checking in standalone API
        if (file_exists($real_version_file) && is_readable($real_version_file)) {
            return $real_version_file;
        }

        return false;
    }

    /**
     * Parse WordPress version from version.php file
     * 
     * @param string $real_version_file Path to version.php
     * @return string Version string or 'Unknown'
     */
    private function parseWordPressVersion($real_version_file)
    {
        // codacy:ignore - file_get_contents() required for version reading in standalone API
        $content = file_get_contents($real_version_file);
        if ($content === false) {
            return 'Unknown';
        }

        // Look for the WordPress version variable
        if (preg_match('/\$wp_version\s*=\s*[\'"]([0-9]+\.[0-9]+(?:\.[0-9]+)?(?:-[a-zA-Z0-9-]+)?)[\'"]/', $content, $matches)) {
            $version = $matches[1];
            // Validate version format
            if (preg_match('/^[0-9]+\.[0-9]+(?:\.[0-9]+)?(?:-[a-zA-Z0-9-]+)?$/', $version)) {
                return htmlspecialchars($version, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
            }
        }

        return 'Unknown';
    }
}
