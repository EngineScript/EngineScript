<?php
/**
 * SystemController
 * Handles system information endpoints
 * 
 * @version 1.0.0
 */

require_once __DIR__ . '/../classes/BaseController.php'; // codacy:ignore - Safe class loading with __DIR__ constant
require_once __DIR__ . '/../classes/SystemCommand.php'; // codacy:ignore - Safe class loading with __DIR__ constant
require_once __DIR__ . '/../services/SystemService.php'; // codacy:ignore - Safe class loading with __DIR__ constant

class SystemController extends BaseController {
    
    /**
     * GET /system/info
     * Get system information
     */
    public static function getInfo() {
        try {
            $info = [
                // codacy:ignore - Static utility class pattern for stateless service operations
                'os' => SystemService::getOsInfo(),
                // codacy:ignore - Static utility class pattern for stateless service operations
                'kernel' => SystemService::getKernelVersion(),
                // codacy:ignore - Static utility class pattern for stateless service operations
                'network' => SystemService::getNetworkInfo()
            ];
            self::jsonResponse($info);
        } catch (Exception $e) {
            self::handleException($e, 'System info');
        }
    }
}
