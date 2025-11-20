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
            // Try mariadb first, fall back to mysql service name
            $mysqlStatus = ServiceStatusService::getServiceStatus('mariadb');
            if ($mysqlStatus['status'] === 'offline') {
                $mysqlStatus = ServiceStatusService::getServiceStatus('mysql');
            }
            
            // Try redis-server first, fall back to redis
            $redisStatus = ServiceStatusService::getServiceStatus('redis-server');
            if ($redisStatus['status'] === 'offline') {
                $redisStatus = ServiceStatusService::getServiceStatus('redis');
            }
            
            $services = [
                'nginx' => ServiceStatusService::getServiceStatus('nginx'),
                'php' => ServiceStatusService::getPhpServiceStatus(),
                'mysql' => $mysqlStatus,
                'redis' => $redisStatus
            ];
            self::jsonResponse($services);
        } catch (Exception $e) {
            self::handleException($e, 'Services status');
        }
    }
}
