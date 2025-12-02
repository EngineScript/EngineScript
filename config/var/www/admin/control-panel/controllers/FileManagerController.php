<?php
/**
 * EngineScript Admin Dashboard - File Manager Controller
 * 
 * Handles TinyFileManager status endpoint.
 * 
 * @package EngineScript\Dashboard\API\Controllers
 * @version 1.0.0
 */

require_once __DIR__ . '/BaseController.php';

/**
 * File Manager Controller
 * 
 * Provides status information about TinyFileManager installation.
 */
class FileManagerController extends BaseController
{
    /**
     * API endpoint path
     */
    private const ENDPOINT = '/tools/filemanager/status';

    /**
     * TinyFileManager file paths
     */
    private const TFM_FILE = '/var/www/admin/enginescript/tinyfilemanager/tinyfilemanager.php';
    private const TFM_CONFIG = '/var/www/admin/enginescript/tinyfilemanager/config.php';
    private const VARIABLES_FILE = '/usr/local/bin/enginescript/enginescript-variables.txt';

    /**
     * Get file manager status
     * 
     * Returns availability, configuration status, version, and permissions.
     * 
     * Endpoint: GET /tools/filemanager/status
     * 
     * @return void Outputs JSON response
     */
    public function getStatus()
    {
        try {
            // Check cache first
            $cached = $this->getCached(self::ENDPOINT);
            if ($cached !== null) {
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                ApiResponse::cached($cached, $this->getTtl(self::ENDPOINT));
                return;
            }

            // Load EngineScript variables to get current version
            $current_version = $this->getFileManagerVersion();

            $status = [
                'available' => file_exists(self::TFM_FILE), // codacy:ignore - file_exists() required for status checking
                'config_exists' => file_exists(self::TFM_CONFIG), // codacy:ignore - file_exists() required for status checking
                'writable_dirs' => [
                    '/var/www' => is_writable('/var/www'), // codacy:ignore - is_writable() required for permission checking
                    '/tmp' => is_writable('/tmp') // codacy:ignore - is_writable() required for permission checking
                ],
                'url' => '/tinyfilemanager/tinyfilemanager.php',
                'version' => $current_version
            ];

            $result = $this->sanitizeOutput($status);

            // Cache the result
            $this->setCached(self::ENDPOINT, $result);

            // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
            ApiResponse::success($result, $this->getTtl(self::ENDPOINT));
        } catch (Exception $e) {
            $this->logSecurityEvent('File manager status error', $e->getMessage());
            // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
            ApiResponse::serverError('Unable to retrieve file manager status');
        }
    }

    /**
     * Get TinyFileManager version from EngineScript variables
     * 
     * @return string Version string or 'Unknown'
     */
    private function getFileManagerVersion()
    {
        $current_version = 'Unknown';

        // codacy:ignore - file_exists() required for version checking in standalone service
        if (file_exists(self::VARIABLES_FILE)) {
            // codacy:ignore - file_get_contents() required for version reading in standalone service
            $content = file_get_contents(self::VARIABLES_FILE);
            if ($content !== false) {
                preg_match('/TINYFILEMANAGER_VER="([^"]*)"/', $content, $matches);
                if (isset($matches[1]) && !empty($matches[1])) {
                    $current_version = $matches[1];
                }
            }
        }

        return $current_version;
    }
}
