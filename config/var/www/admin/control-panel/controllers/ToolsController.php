<?php
/**
 * ToolsController
 * Handles tool-related endpoints
 * 
 * @version 1.0.0
 */

require_once __DIR__ . '/../classes/BaseController.php';

class ToolsController extends BaseController {
    
    /**
     * GET /tools/filemanager/status
     * Get file manager status
     */
    public static function getFileManagerStatus() {
        try {
            // Load EngineScript variables to get current version
            $current_version = '2.6';
            if (file_exists('/usr/local/bin/enginescript/enginescript-variables.txt')) {
                $content = file_get_contents('/usr/local/bin/enginescript/enginescript-variables.txt');
                if (preg_match('/TINYFILEMANAGER_VER="([^"]*)"/', $content, $matches)) {
                    $current_version = isset($matches[1]) ? $matches[1] : '2.6';
                }
            }
            
            $tfm_file = '/var/www/admin/enginescript/tinyfilemanager/tinyfilemanager.php';
            $tfm_config = '/var/www/admin/enginescript/tinyfilemanager/config.php';
            
            $status = [
                'available' => file_exists($tfm_file),
                'config_exists' => file_exists($tfm_config),
                'writable_dirs' => [
                    '/var/www' => is_writable('/var/www'),
                    '/tmp' => is_writable('/tmp')
                ],
                'url' => '/tinyfilemanager/tinyfilemanager.php',
                'version' => $current_version
            ];
            
            self::jsonResponse($status);
        } catch (Exception $e) {
            self::handleException($e, 'File manager status');
        }
    }
}
