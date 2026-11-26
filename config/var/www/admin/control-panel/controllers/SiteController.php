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

namespace EngineScript\Dashboard\API\Controllers;

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
     * Directory of the enabled nginx sites, NGINX_SITES_PATH unless a test chose another
     */
    private static string $nginxSitesPath = self::NGINX_SITES_PATH;

    /**
     * Read the sites from another directory, or from NGINX_SITES_PATH again for null; for tests
     *
     * @psalm-api
     */
    public static function useNginxSitesPath(?string $path): void
    {
        self::$nginxSitesPath = $path ?? self::NGINX_SITES_PATH;
    }

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
        } catch (\Throwable $e) {
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
            if (!is_dir(self::$nginxSitesPath)) {
                return $sites;
            }

            $validFiles = $this->scanNginxConfigs(self::$nginxSitesPath);
            if ($validFiles === false) {
                return $sites;
            }

            foreach ($validFiles as $configRealPath) {
                $siteInfo = $this->processNginxConfig($configRealPath);
                if ($siteInfo !== null) {
                    $sites[] = $siteInfo;
                }
            }
        } catch (\Throwable $e) {
            $this->securityLogger->write('WordPress sites enumeration error', $e->getMessage());
        }

        return $sites;
    }

    /**
     * Scan nginx config files in directory
     *
     * @param string $realPath Directory path
     * @return list<string>|false Array of valid config paths or false on error
     */
    private function scanNginxConfigs(string $realPath): array|false
    {
        $files = scandir($realPath);
        if ($files === false) {
            return false;
        }

        $validFiles = [];
        foreach ($files as $file) {
            if (in_array($file, ['.', '..', 'default'], true)) {
                continue;
            }

            // Validate filename to prevent traversal
            if (!preg_match('/^[a-zA-Z0-9._-]+\z/', $file)) {
                $this->securityLogger->write('Suspicious nginx config filename', $file);
                continue;
            }

            $configPath = $realPath . '/' . $file;
            if (!is_file($configPath) || !is_readable($configPath)) {
                continue;
            }

            $configRealPath = $this->resolveInside($configPath, $realPath);
            if ($configRealPath === null) {
                $this->securityLogger->write('Config file path traversal attempt', $configPath);
                continue;
            }

            $validFiles[] = $configRealPath;
        }

        return $validFiles;
    }

    /**
     * Process a single nginx config file
     *
     * @param string $configRealPath Path to config file
     * @return array<string, string>|null Site info or null if not WordPress
     */
    private function processNginxConfig($configRealPath): ?array
    {
        $configContent = file_get_contents($configRealPath);
        if ($configContent === false || !$this->isWordPressConfig($configContent)) {
            return null;
        }

        $domain = $this->extractPrimaryDomain($configContent);
        if ($domain === '') {
            return null;
        }

        $documentRoot = $this->extractDocumentRoot($configContent);
        $wpVersion = $this->getWordPressVersion($documentRoot);

        return [
            'domain' => $domain,
            'wp_version' => $wpVersion,
            'ssl_status' => str_contains($configContent, 'ssl_certificate') ? 'Enabled' : 'Unknown',
        ];
    }

    private function isWordPressConfig(string $configContent): bool
    {
        return str_contains($configContent, 'wordpress') || str_contains($configContent, 'wp-');
    }

    private function extractPrimaryDomain(string $configContent): string
    {
        if (!preg_match('/server_name\s+([a-zA-Z0-9.-]+(?:\s+[a-zA-Z0-9.-]+)*)\s*;/', $configContent, $matches)) {
            return '';
        }

        $domainParts = preg_split('/\s+/', trim($matches[1]));
        $primaryDomain = is_array($domainParts) ? $domainParts[0] : '';

        $validatedDomain = filter_var($primaryDomain, FILTER_VALIDATE_DOMAIN, FILTER_FLAG_HOSTNAME);
        if ($validatedDomain === false || $validatedDomain === '0') {
            return '';
        }

        return $primaryDomain;
    }

    private function extractDocumentRoot(string $configContent): string
    {
        if (!preg_match('/root\s+([^\s;]+)\s*;/', $configContent, $matches)) {
            return '';
        }

        $documentRoot = trim($matches[1]);
        if (!preg_match('/^\/[a-zA-Z0-9\/_.-]+\z/', $documentRoot)) {
            return '';
        }

        $realDocumentRoot = realpath($documentRoot);

        return is_string($realDocumentRoot) ? $realDocumentRoot : '';
    }

    /**
     * Get WordPress version from a site's document root
     *
     * @param string $documentRoot Document root path
     * @return string WordPress version or 'Unknown'
     */
    private function getWordPressVersion(string $documentRoot): string
    {
        try {
            $realVersionFile = $this->validateWordPressPath($documentRoot);
            if ($realVersionFile === false) {
                return 'Unknown';
            }

            return $this->parseWordPressVersion($realVersionFile);
        } catch (\Throwable $e) {
            $this->securityLogger->write('WordPress version detection error', $e->getMessage());
            return 'Unknown';
        }
    }

    /**
     * Validate WordPress installation path
     *
     * @param string $documentRoot Document root to validate
     * @return string|false Path to version.php or false if invalid
     */
    private function validateWordPressPath(string $documentRoot): false|string
    {
        // extractDocumentRoot() has resolved the root already.
        if ($documentRoot === '') {
            return false;
        }

        $realVersionFile = $this->resolveInside($documentRoot . '/wp-includes/version.php', $documentRoot);
        if ($realVersionFile === null) {
            return false;
        }

        return is_readable($realVersionFile) ? $realVersionFile : false;
    }

    /**
     * The path with links resolved, if it exists and stays inside the directory;
     * the one containment check of each file the controller reads
     */
    private function resolveInside(string $path, string $directory): ?string
    {
        $resolved = realpath($path);

        return is_string($resolved) && str_starts_with($resolved, $directory . DIRECTORY_SEPARATOR) ? $resolved : null;
    }

    /**
     * Parse WordPress version from version.php file
     *
     * @param string $realVersionFile Path to version.php
     * @return string Version string or 'Unknown'
     */
    private function parseWordPressVersion(string $realVersionFile): string
    {
        $content = file_get_contents($realVersionFile);
        if ($content === false) {
            return 'Unknown';
        }

        // Look for the WordPress version variable
        $pattern = '/\$wp_version\s*=\s*[\'"]'
            . '([0-9]+\.[0-9]+(?:\.[0-9]+)?(?:-[a-zA-Z0-9-]+)?)[\'"]/';
        if (preg_match($pattern, $content, $matches)) {
            return $matches[1];
        }

        return 'Unknown';
    }
}
