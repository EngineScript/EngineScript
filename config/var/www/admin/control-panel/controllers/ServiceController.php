<?php
/**
 * EngineScript Admin Dashboard - Service Controller
 * 
 * Handles service status endpoints for nginx, PHP-FPM, MariaDB, and Redis.
 * 
 * @package EngineScript\Dashboard\API\Controllers
 * @version 1.0.0
 */

require_once __DIR__ . '/BaseController.php';
require_once __DIR__ . '/../classes/SystemCommand.php';

/**
 * Service Status Controller
 * 
 * Provides status information for server services.
 */
class ServiceController extends BaseController
{
    /**
     * API endpoint path
     */
    private const ENDPOINT = '/services/status';

    /**
     * Get status of all services
     * 
     * Returns status of nginx, PHP-FPM, MariaDB, and Redis.
     * Response is cached based on configured TTL.
     * 
     * Endpoint: GET /services/status
     * 
     * @return void Outputs JSON response
     */
    public function getStatus()
    {
        try {
            // Check cache first
            $cached = $this->getCached(self::ENDPOINT);
            if ($cached !== null) {
                ApiResponse::cached($cached, $this->getTtl(self::ENDPOINT));
                return;
            }

            $services = [
                'nginx' => $this->getServiceStatus('nginx'),
                'php' => $this->getPhpServiceStatus(),
                'mysql' => $this->getServiceStatus('mariadb'),
                'redis' => $this->getServiceStatus('redis-server')
            ];

            $result = $this->sanitizeOutput($services);

            // Cache the result
            $this->setCached(self::ENDPOINT, $result);

            ApiResponse::success($result, $this->getTtl(self::ENDPOINT));
        } catch (Exception $e) {
            $this->logSecurityEvent('Services status error', $e->getMessage());
            ApiResponse::serverError('Unable to retrieve services status');
        }
    }

    /**
     * Get status of a specific service
     * 
     * @param string $service Service name to check
     * @return array Service status with 'status', 'version', and 'online' keys
     */
    private function getServiceStatus($service)
    {
        // Validate service name to prevent command injection
        $service = $this->validateService($service);
        if ($service === false) {
            $this->logSecurityEvent('Invalid service name attempted', $service);
            return $this->createErrorServiceStatus();
        }

        try {
            $status = $this->getSystemServiceStatus($service);
            $version = $this->getServiceVersion($service);

            return [
                'status' => $status === 'active' ? 'online' : 'offline',
                'version' => $version,
                'online' => $status === 'active'
            ];
        } catch (Exception $e) {
            $this->logSecurityEvent('Service status error', $e->getMessage());
            return $this->createErrorServiceStatus();
        }
    }

    /**
     * Get PHP-FPM service status
     * 
     * Dynamically finds and checks any running PHP-FPM service.
     * 
     * @return array Service status
     */
    private function getPhpServiceStatus()
    {
        $php_service = $this->findActivePhpFpmService();
        if ($php_service) {
            return $this->getServiceStatus($php_service);
        }

        // Fallback: return offline status if no PHP-FPM service found
        return [
            'status' => 'offline',
            'version' => 'Not Found',
            'online' => false
        ];
    }

    /**
     * Find active PHP-FPM service
     * 
     * Searches for any running PHP-FPM service using systemctl.
     * 
     * @return string|null Service name or null if not found
     */
    private function findActivePhpFpmService()
    {
        // codacy:ignore - Static utility class pattern
        $services_output = SystemCommand::getSystemdServices();

        if ($services_output === false || empty($services_output)) {
            return null;
        }

        // Parse services in PHP for better security control
        $lines = explode("\n", trim($services_output));
        foreach ($lines as $line) {
            if (empty(trim($line))) {
                continue;
            }

            // Extract service name (first column) with additional safety checks
            $parts = preg_split('/\s+/', trim($line));
            if (empty($parts[0]) || strlen($parts[0]) > 50) {
                continue;
            }

            $service_name = $parts[0];

            // Additional security: ensure service name contains only allowed characters
            if (!preg_match('/^[a-zA-Z0-9._@-]+$/', $service_name)) {
                continue;
            }

            // Check if it's a PHP-FPM service
            if (preg_match('/php[0-9.]*-?fpm/', $service_name)) {
                return $service_name;
            }
        }

        return null;
    }

    /**
     * Get system service status via systemctl
     * 
     * @param string $service Service name
     * @return string 'active', 'inactive', or 'unknown'
     */
    private function getSystemServiceStatus($service)
    {
        // codacy:ignore - Static utility class pattern
        $status_output = SystemCommand::getServiceStatus($service);
        return $status_output !== false ? $status_output : 'unknown';
    }

    /**
     * Get service version
     * 
     * @param string $service Service name
     * @return string Version string or 'Unknown'
     */
    private function getServiceVersion($service)
    {
        switch ($service) {
            case 'nginx':
                return $this->getNginxVersion();
            case 'mariadb':
                return $this->getMariadbVersion();
            case 'redis-server':
                return $this->getRedisVersion();
            default:
                // Check if it's any PHP-FPM service
                if (preg_match('/^php[a-zA-Z0-9\.\-_]*fpm[a-zA-Z0-9\.\-_]*$/', $service)) {
                    return $this->getPhpVersion();
                }
                return 'Unknown';
        }
    }

    /**
     * Create error service status response
     * 
     * @return array Error status
     */
    private function createErrorServiceStatus()
    {
        return [
            'status' => 'error',
            'version' => 'Error',
            'online' => false
        ];
    }

    /**
     * Get Nginx version
     * 
     * @return string Version or 'Unknown'
     */
    private function getNginxVersion()
    {
        // codacy:ignore - Static utility class pattern
        $version_output = SystemCommand::getNginxVersion();
        if ($version_output !== null && preg_match('/nginx\/(\d+\.\d+\.\d+)/', $version_output, $matches)) {
            return htmlspecialchars($matches[1], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        }
        return 'Unknown';
    }

    /**
     * Get PHP version
     * 
     * @return string Version or 'Unknown'
     */
    private function getPhpVersion()
    {
        // codacy:ignore - Static utility class pattern
        $version_output = SystemCommand::getPhpVersion();
        if ($version_output !== null && preg_match('/PHP (\d+\.\d+\.\d+)/', $version_output, $matches)) {
            return htmlspecialchars($matches[1], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        }
        return 'Unknown';
    }

    /**
     * Get MariaDB version
     * 
     * @return string Version or 'Unknown'
     */
    private function getMariadbVersion()
    {
        // codacy:ignore - Static utility class pattern
        $version_output = SystemCommand::getMariadbVersion();
        if ($version_output !== null && preg_match('/mariadb.*?(\d+\.\d+\.\d+)/', $version_output, $matches)) {
            return htmlspecialchars($matches[1], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        }
        return 'Unknown';
    }

    /**
     * Get Redis version
     * 
     * @return string Version or 'Unknown'
     */
    private function getRedisVersion()
    {
        // codacy:ignore - Static utility class pattern
        $version_output = SystemCommand::getRedisVersion();
        if ($version_output !== null && preg_match('/v=(\d+\.\d+\.\d+)/', $version_output, $matches)) {
            return htmlspecialchars($matches[1], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        }
        return 'Unknown';
    }
}
