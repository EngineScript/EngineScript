<?php
/**
 * ServicesController
 * Handles service status endpoints
 * 
 * @version 1.0.0
 */

require_once __DIR__ . '/../classes/BaseController.php'; // codacy:ignore - Safe class loading with __DIR__ constant
require_once __DIR__ . '/../services/ServiceStatusService.php'; // codacy:ignore - Safe class loading with __DIR__ constant

class ServicesController extends BaseController {
    
    /**
     * GET /services/status
     * Get status of all services
     */
    public static function getStatus() {
        try {
            // Try mariadb first, fallback to mysql if not found
            // codacy:ignore - Static utility class pattern for stateless service operations
            $mysqlStatus = ServiceStatusService::getServiceStatus('mariadb');
            if ($mysqlStatus['status'] === 'not_found') {
                // codacy:ignore - Static utility class pattern for stateless service operations
                $mysqlStatus = ServiceStatusService::getServiceStatus('mysql');
            }
            
            // Try redis-server first, fallback to redis if not found
            // codacy:ignore - Static utility class pattern for stateless service operations
            $redisStatus = ServiceStatusService::getServiceStatus('redis-server');
            if ($redisStatus['status'] === 'not_found') {
                // codacy:ignore - Static utility class pattern for stateless service operations
                $redisStatus = ServiceStatusService::getServiceStatus('redis');
            }
            
            $status = [
                // codacy:ignore - Static utility class pattern for stateless service operations
                'nginx' => ServiceStatusService::getServiceStatus('nginx'),
                // codacy:ignore - Static utility class pattern for stateless service operations
                'php' => ServiceStatusService::getPhpServiceStatus(),
            self::jsonResponse($services);
        } catch (Exception $e) {
            self::handleException($e, 'Services status');
        }
    }
}
