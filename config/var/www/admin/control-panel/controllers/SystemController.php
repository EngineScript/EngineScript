<?php
/**
 * SystemController
 * Handles system information endpoints
 * 
 * @version 1.0.0
 */

require_once __DIR__ . '/../classes/BaseController.php';
require_once __DIR__ . '/../classes/SystemCommand.php';
require_once __DIR__ . '/../services/SystemService.php';

class SystemController extends BaseController {
    
    /**
     * GET /system/info
     * Get system information
     */
    public static function getInfo() {
        try {
            $info = [
                'os' => SystemService::getOsInfo(),
                'kernel' => SystemService::getKernelVersion(),
                'network' => SystemService::getNetworkInfo()
            ];
            self::jsonResponse($info);
        } catch (Exception $e) {
            self::handleException($e, 'System info');
        }
    }
}
