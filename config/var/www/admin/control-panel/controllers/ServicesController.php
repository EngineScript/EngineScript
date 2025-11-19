<?php
/**
 * ServicesController
 * Handles service status endpoints
 * 
 * @version 1.0.0
 */

require_once __DIR__ . '/../classes/BaseController.php';
require_once __DIR__ . '/../services/ServiceStatusService.php';

class ServicesController extends BaseController {
    
    /**
     * GET /services/status
     * Get status of all services
     */
    public static function getStatus() {
        try {
            $services = [
                'nginx' => ServiceStatusService::getServiceStatus('nginx'),
                'php' => ServiceStatusService::getPhpServiceStatus(),
                'mysql' => ServiceStatusService::getServiceStatus('mariadb'),
                'redis' => ServiceStatusService::getServiceStatus('redis-server')
            ];
            self::jsonResponse($services);
        } catch (Exception $e) {
            self::handleException($e, 'Services status');
        }
    }
}
