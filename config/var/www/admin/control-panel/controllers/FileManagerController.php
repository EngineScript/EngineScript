<?php

/**
 * EngineScript Admin Dashboard - File Manager Controller
 *
 * Handles TinyFileManager status endpoint.
 *
 * @package EngineScript\Dashboard\API\Controllers
 * @version 1.0.0
 */

declare(strict_types=1);

require_once __DIR__ . '/BaseController.php';

/**
 * File Manager Controller
 *
 * Provides status information about TinyFileManager installation.
 *
 * @psalm-api
 */
final class FileManagerController extends BaseController
{
    /**
     * TinyFileManager file paths
     */
    private const string TFM_FILE = '/var/www/admin/tools/tinyfilemanager/tinyfilemanager.php';
    private const string TFM_CONFIG = '/var/www/admin/tools/tinyfilemanager/config.php';
    private const string VARIABLES_FILE = '/usr/local/bin/enginescript/enginescript-variables.txt';

    /**
     * Get file manager status
     *
     * Returns availability, configuration status, version, and URL.
     *
     * Endpoint: GET /tools/filemanager/status
     *
     * @return void Outputs JSON response
     * @psalm-api
     */
    public function getStatus(): void
    {
        try {
            // Load EngineScript variables to get current version
            $current_version = $this->getFileManagerVersion();

            $status = [
                'available' => file_exists(self::TFM_FILE),
                'config_exists' => file_exists(self::TFM_CONFIG),
                'url' => '/tinyfilemanager/tinyfilemanager.php',
                'version' => $current_version,
            ];

            $this->response->success($status);
        } catch (Throwable $e) {
            $this->securityLogger->write('File manager status error', $e->getMessage());
            $this->response->serverError('Unable to retrieve file manager status');
        }
    }

    /**
     * Get TinyFileManager version from EngineScript variables
     *
     * @return string Version string or 'Unknown'
     */
    private function getFileManagerVersion(): string
    {
        $current_version = 'Unknown';

        if (file_exists(self::VARIABLES_FILE)) {
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
