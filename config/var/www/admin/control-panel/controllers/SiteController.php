<?php

/**
 * EngineScript Admin Dashboard - Site Controller
 *
 * Handles WordPress site enumeration and information endpoints.
 *
 * @package EngineScript\Dashboard\API\Controllers
 * @version 1.0.0
 */

declare(strict_types=1);

require_once __DIR__ . '/BaseController.php';

/**
 * WordPress Sites Controller
 *
 * Provides information about WordPress sites hosted on the server.
 *
 * @psalm-api
 */
final class SiteController extends BaseController
{
    /**
     * Nginx sites-enabled directory
     */
    private const string NGINX_SITES_PATH = '/etc/nginx/sites-enabled';

    /**
     * Get all WordPress sites
     *
     * Scans nginx configuration to find WordPress installations.
     * Returns domain, WordPress version, and SSL status.
     *
     * Endpoint: GET /sites
     *
     * @return void Outputs JSON response
     * @psalm-api
     */
    public function getSites(): void
    {
        try {
            $this->response->success($this->getWordPressSites());
        } catch (Throwable $e) {
            $this->securityLogger->write('Sites error', $e->getMessage());
            $this->response->serverError('Unable to retrieve sites');
        }
    }


    /**
     * Get all WordPress sites from nginx configuration
     *
     * @return list<array<string, string>> List of site information
     */
    private function getWordPressSites(): array
    {
        $sites = [];

        try {
            if (!is_dir(self::NGINX_SITES_PATH)) {
                return $sites;
            }

            $valid_files = $this->scanNginxConfigs(self::NGINX_SITES_PATH);
            if ($valid_files === false) {
                return $sites;
            }

            foreach ($valid_files as $config_real_path) {
                $site_info = $this->processNginxConfig($config_real_path);
                if ($site_info !== null) {
                    $sites[] = $site_info;
                }
            }
        } catch (Throwable $e) {
            $this->securityLogger->write('WordPress sites enumeration error', $e->getMessage());
        }

        return $sites;
    }

    /**
     * Scan nginx config files in directory
     *
     * @param string $real_path Directory path
     * @return list<string>|false Array of valid config paths or false on error
     */
    private function scanNginxConfigs(string $real_path): array|false
    {
        $files = scandir($real_path);
        if ($files === false) {
            return false;
        }

        $valid_files = [];
        foreach ($files as $file) {
            if (in_array($file, ['.', '..', 'default'], true)) {
                continue;
            }

            // Validate filename to prevent traversal
            if (!preg_match('/^[a-zA-Z0-9._-]+$/', $file)) {
                $this->securityLogger->write('Suspicious nginx config filename', $file);
                continue;
            }

            $config_path = $real_path . '/' . $file;
            if (!is_file($config_path) || !is_readable($config_path)) {
                continue;
            }

            $config_real_path = $this->resolveInside($config_path, $real_path);
            if ($config_real_path === null) {
                $this->securityLogger->write('Config file path traversal attempt', $config_path);
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
     * @return array<string, string>|null Site info or null if not WordPress
     */
    private function processNginxConfig($config_real_path): ?array
    {
        $config_content = file_get_contents($config_real_path);
        if ($config_content === false || !$this->isWordPressConfig($config_content)) {
            return null;
        }

        $domain = $this->extractPrimaryDomain($config_content);
        if ($domain === '') {
            return null;
        }

        $document_root = $this->extractDocumentRoot($config_content);
        $wp_version = $this->getWordPressVersion($document_root);

        return [
            'domain' => $domain,
            'wp_version' => $wp_version,
            'ssl_status' => str_contains($config_content, 'ssl_certificate') ? 'Enabled' : 'Unknown',
        ];
    }

    private function isWordPressConfig(string $config_content): bool
    {
        return str_contains($config_content, 'wordpress') || str_contains($config_content, 'wp-');
    }

    private function extractPrimaryDomain(string $config_content): string
    {
        if (!preg_match('/server_name\s+([a-zA-Z0-9.-]+(?:\s+[a-zA-Z0-9.-]+)*)\s*;/', $config_content, $matches)) {
            return '';
        }

        $domain_parts = preg_split('/\s+/', trim($matches[1]));
        $primary_domain = is_array($domain_parts) ? $domain_parts[0] : '';

        $validatedDomain = filter_var($primary_domain, FILTER_VALIDATE_DOMAIN, FILTER_FLAG_HOSTNAME);
        if ($validatedDomain === false || $validatedDomain === '0') {
            return '';
        }

        return $primary_domain;
    }

    private function extractDocumentRoot(string $config_content): string
    {
        if (!preg_match('/root\s+([^\s;]+)\s*;/', $config_content, $matches)) {
            return '';
        }

        $document_root = trim($matches[1]);
        if (!preg_match('/^\/[a-zA-Z0-9\/_.-]+$/', $document_root)) {
            return '';
        }

        $realDocumentRoot = realpath($document_root);

        return is_string($realDocumentRoot) ? $realDocumentRoot : '';
    }

    /**
     * Get WordPress version from a site's document root
     *
     * @param string $document_root Document root path
     * @return string WordPress version or 'Unknown'
     */
    private function getWordPressVersion(string $document_root): string
    {
        try {
            $real_version_file = $this->validateWordPressPath($document_root);
            if ($real_version_file === false) {
                return 'Unknown';
            }

            return $this->parseWordPressVersion($real_version_file);
        } catch (Throwable $e) {
            $this->securityLogger->write('WordPress version detection error', $e->getMessage());
            return 'Unknown';
        }
    }

    /**
     * Validate WordPress installation path
     *
     * @param string $document_root Document root to validate
     * @return string|false Path to version.php or false if invalid
     */
    private function validateWordPressPath(string $document_root): false|string
    {
        // extractDocumentRoot() has resolved the root already.
        if ($document_root === '') {
            return false;
        }

        $real_version_file = $this->resolveInside($document_root . '/wp-includes/version.php', $document_root);
        if ($real_version_file === null) {
            return false;
        }

        return is_readable($real_version_file) ? $real_version_file : false;
    }

    /**
     * The path with links resolved, if it exists and stays inside the directory;
     * the one containment check of each file the controller reads
     */
    private function resolveInside(string $path, string $directory): ?string
    {
        $resolved = realpath($path);

        return is_string($resolved) && str_starts_with($resolved, $directory . '/') ? $resolved : null;
    }

    /**
     * Parse WordPress version from version.php file
     *
     * @param string $real_version_file Path to version.php
     * @return string Version string or 'Unknown'
     */
    private function parseWordPressVersion(string $real_version_file): string
    {
        $content = file_get_contents($real_version_file);
        if ($content === false) {
            return 'Unknown';
        }

        // Look for the WordPress version variable
        if (preg_match('/\$wp_version\s*=\s*[\'"]([0-9]+\.[0-9]+(?:\.[0-9]+)?(?:-[a-zA-Z0-9-]+)?)[\'"]/', $content, $matches)) {
            return $matches[1];
        }

        return 'Unknown';
    }
}
