<?php
/**
 * ServiceStatusService
 * Service status management
 * 
 * @version 1.0.0
 */

class ServiceStatusService {
    
    /**
     * Get service status
     * @param string $service Service name
     * @return array Service status information
     */
    public static function getServiceStatus($service) {
        // Validate service name
        $service = self::validateService($service);
        if ($service === false) {
            error_log('Invalid service name attempted: ' . $service);
            return self::createErrorStatus();
        }
        
        try {
            $status = self::getSystemServiceStatus($service);
            $version = self::getServiceVersion($service);
            
            return [
                'status' => $status === 'active' ? 'online' : 'offline',
                'version' => $version,
                'online' => $status === 'active'
            ];
        } catch (Exception $e) {
            error_log('Service status error: ' . $e->getMessage());
            return self::createErrorStatus();
        }
    }
    
    /**
     * Get PHP-FPM service status
     * @return array PHP service status
     */
    public static function getPhpServiceStatus() {
        $php_service = self::findActivePhpFpmService();
        if ($php_service) {
            return self::getServiceStatus($php_service);
        }
        
        return [
            'status' => 'offline',
            'version' => 'Not Found',
            'online' => false
        ];
    }
    
    /**
     * Find active PHP-FPM service
     * @return string|null Service name or null
     */
    private static function findActivePhpFpmService() {
        $services_output = SystemCommand::getSystemdServices();
        
        if ($services_output === false || empty($services_output)) {
            return null;
        }
        
        $lines = explode("\n", trim($services_output));
        foreach ($lines as $line) {
            if (empty(trim($line))) {
                continue;
            }
            
            $parts = preg_split('/\s+/', trim($line));
            if (empty($parts[0]) || strlen($parts[0]) > 50) {
                continue;
            }
            
            $service_name = $parts[0];
            
            if (!preg_match('/^[a-zA-Z0-9\.\-_]+$/', $service_name)) {
                continue;
            }
            
            $service_name = preg_replace('/\.service$/', '', $service_name);
            
            if (stripos($service_name, 'php') !== false && stripos($service_name, 'fpm') !== false) {
                if (preg_match('/^php[a-zA-Z0-9\.\-_]*fpm[a-zA-Z0-9\.\-_]*$/', $service_name)) {
                    $status = self::getSystemServiceStatus($service_name);
                    if ($status === 'active') {
                        return $service_name;
                    }
                }
            }
        }
        
        return null;
    }
    
    /**
     * Validate service name
     * @param string $service Service name
     * @return string|false Validated service name or false
     */
    private static function validateService($service) {
        $allowed_services = ['nginx', 'mariadb', 'redis-server'];
        
        if (in_array($service, $allowed_services, true)) {
            return $service;
        }
        
        if (preg_match('/^php[a-zA-Z0-9\.\-_]*fpm[a-zA-Z0-9\.\-_]*$/', $service)) {
            return $service;
        }
        
        return false;
    }
    
    /**
     * Get system service status
     * @param string $service Service name
     * @return string Service status ('active' or 'inactive')
     */
    private static function getSystemServiceStatus($service) {
        $status_output = SystemCommand::getServiceStatus($service);
        if ($status_output === false || empty($status_output)) {
            return 'inactive';
        }
        
        // Check if service is active by looking for "Active: active" in output
        if (stripos($status_output, 'Active: active') !== false) {
            return 'active';
        }
        
        return 'inactive';
    }
    
    /**
     * Get service version
     * @param string $service Service name
     * @return string Service version
     */
    private static function getServiceVersion($service) {
        switch ($service) {
            case 'nginx':
                return self::getNginxVersion();
            case 'mariadb':
                return self::getMariadbVersion();
            case 'redis-server':
                return self::getRedisVersion();
            default:
                if (preg_match('/^php[a-zA-Z0-9\.\-_]*fpm[a-zA-Z0-9\.\-_]*$/', $service)) {
                    return self::getPhpVersion();
                }
                return 'Unknown';
        }
    }
    
    /**
     * Get Nginx version
     * @return string Nginx version
     */
    private static function getNginxVersion() {
        $version_output = SystemCommand::getNginxVersion();
        if ($version_output !== null && preg_match('/nginx\/(\d+\.\d+\.\d+)/', $version_output, $matches)) {
            return htmlspecialchars($matches[1], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        }
        return 'Unknown';
    }
    
    /**
     * Get PHP version
     * @return string PHP version
     */
    private static function getPhpVersion() {
        $version_output = SystemCommand::getPhpVersion();
        if ($version_output !== null && preg_match('/PHP (\d+\.\d+\.\d+)/', $version_output, $matches)) {
            return htmlspecialchars($matches[1], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        }
        return 'Unknown';
    }
    
    /**
     * Get MariaDB version
     * @return string MariaDB version
     */
    private static function getMariadbVersion() {
        $version_output = SystemCommand::getMariadbVersion();
        if ($version_output !== null && preg_match('/mariadb.*?(\d+\.\d+\.\d+)/', $version_output, $matches)) {
            return htmlspecialchars($matches[1], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        }
        return 'Unknown';
    }
    
    /**
     * Get Redis version
     * @return string Redis version
     */
    private static function getRedisVersion() {
        $version_output = SystemCommand::getRedisVersion();
        if ($version_output !== null && preg_match('/v=(\d+\.\d+\.\d+)/', $version_output, $matches)) {
            return htmlspecialchars($matches[1], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        }
        return 'Unknown';
    }
    
    /**
     * Create error status
     * @return array Error status array
     */
    private static function createErrorStatus() {
        return [
            'status' => 'error',
            'version' => 'Error',
            'online' => false
        ];
    }
}
