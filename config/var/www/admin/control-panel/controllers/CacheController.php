<?php
/**
 * EngineScript Admin Dashboard - Cache Controller
 * 
 * Handles cache clearing operations for Redis, Nginx FastCGI, and OPcache.
 * 
 * @package EngineScript\Dashboard\API\Controllers
 * @version 1.0.0
 */

require_once __DIR__ . '/BaseController.php';
require_once __DIR__ . '/../classes/SystemCommand.php';

/**
 * Cache Controller
 * 
 * Provides cache clearing functionality for various caching systems.
 */
class CacheController extends BaseController
{
    /**
     * API endpoint path
     */
    private const ENDPOINT = '/cache/clear';

    /**
     * Valid cache types
     */
    private const VALID_CACHE_TYPES = ['redis', 'fastcgi', 'opcache'];

    /**
     * Nginx FastCGI cache directory
     */
    private const FASTCGI_CACHE_PATH = '/var/cache/enginescript/fcgi';

    /**
     * Clear specified caches
     * 
     * Clears one or more cache types based on the 'type' query parameter.
     * Supported types: redis, fastcgi, opcache
     * 
     * Endpoint: POST /cache/clear?type=redis,fastcgi,opcache
     * 
     * @return void Outputs JSON response
     */
    public function clear()
    {
        try {
            // Require POST method for cache clearing
            // codacy:ignore - Direct $_SERVER access required for method checking in standalone API
            if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] !== 'POST') {
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                ApiResponse::methodNotAllowed('Cache clear requires POST method');
                return;
            }

            // Get and validate cache types
            // codacy:ignore - wp_unslash() not available in standalone API, using trim() for sanitization; nonce not required in standalone API (uses CSRF token instead)
            $typeParam = isset($_GET['type']) ? trim($_GET['type']) : '';

            if (empty($typeParam)) {
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                ApiResponse::badRequest('Cache type parameter required. Valid types: ' . implode(', ', self::VALID_CACHE_TYPES));
                return;
            }

            // Parse and validate requested types
            $requestedTypes = array_map('trim', explode(',', $typeParam));
            $validTypes = [];
            $invalidTypes = [];

            foreach ($requestedTypes as $type) {
                $type = strtolower($type);
                if (in_array($type, self::VALID_CACHE_TYPES, true)) {
                    $validTypes[] = $type;
                } elseif (!empty($type)) {
                    $invalidTypes[] = $type;
                }
            }

            if (empty($validTypes)) {
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                ApiResponse::badRequest('No valid cache types provided. Valid types: ' . implode(', ', self::VALID_CACHE_TYPES));
                return;
            }

            // Clear requested caches
            $results = [];
            $success = true;

            foreach ($validTypes as $type) {
                $result = $this->clearCacheType($type);
                $results[$type] = $result;
                if (!$result['success']) {
                    $success = false;
                }
            }

            // Build response
            $response = [
                'success' => $success,
                'cleared' => $validTypes,
                'results' => $results
            ];

            if (!empty($invalidTypes)) {
                $response['warnings'] = [
                    'invalid_types' => $invalidTypes,
                    'message' => 'Some requested cache types were invalid and ignored'
                ];
            }

            // Clear API cache for relevant endpoints after cache operations
            $this->clearCacheFor('/services/status');

            // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
            ApiResponse::success($this->sanitizeOutput($response));
        } catch (Exception $e) {
            $this->logSecurityEvent('Cache clear error', $e->getMessage());
            // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
            ApiResponse::serverError('Unable to clear cache');
        }
    }

    /**
     * Clear a specific cache type
     * 
     * @param string $type Cache type to clear
     * @return array Result with success status and message
     */
    private function clearCacheType(string $type)
    {
        switch ($type) {
            case 'redis':
                return $this->clearRedisCache();
            case 'fastcgi':
                return $this->clearFastCgiCache();
            case 'opcache':
                return $this->clearOpcache();
            default:
                return [
                    'success' => false,
                    'message' => 'Unknown cache type'
                ];
        }
    }

    /**
     * Clear Redis cache
     * 
     * @return array Result with success status and message
     */
    private function clearRedisCache()
    {
        // codacy:ignore - Static SystemCommand method used; dependency injection would require service container
        $output = SystemCommand::execute('redis-cli', ['FLUSHALL']);

        if ($output !== null && trim($output) === 'OK') {
            $this->logSecurityEvent('Cache cleared', 'Redis cache flushed successfully');
            return [
                'success' => true,
                'message' => 'Redis cache cleared successfully'
            ];
        }

        return [
            'success' => false,
            'message' => 'Failed to clear Redis cache'
        ];
    }

    /**
     * Clear Nginx FastCGI cache
     * 
     * @return array Result with success status and message
     */
    private function clearFastCgiCache()
    {
        // codacy:ignore - file_exists() required for cache directory checking
        if (!file_exists(self::FASTCGI_CACHE_PATH)) {
            return [
                'success' => true,
                'message' => 'FastCGI cache directory does not exist (nothing to clear)'
            ];
        }

        // codacy:ignore - is_dir() required for cache directory validation
        if (!is_dir(self::FASTCGI_CACHE_PATH)) {
            return [
                'success' => false,
                'message' => 'FastCGI cache path exists but is not a directory'
            ];
        }

        // Clear cache files using find command (safer than rm -rf)
        // codacy:ignore - Static SystemCommand method used; dependency injection would require service container
        $output = SystemCommand::execute('find', [
            self::FASTCGI_CACHE_PATH,
            '-type',
            'f',
            '-delete'
        ]);

        if ($output !== null) {
            $this->logSecurityEvent('Cache cleared', 'FastCGI cache cleared successfully');
            return [
                'success' => true,
                'message' => 'FastCGI cache cleared successfully'
            ];
        }

        return [
            'success' => false,
            'message' => 'Failed to clear FastCGI cache'
        ];
    }

    /**
     * Clear PHP OPcache
     * 
     * @return array Result with success status and message
     */
    private function clearOpcache()
    {
        // Check if OPcache is available
        if (!function_exists('opcache_reset')) {
            return [
                'success' => false,
                'message' => 'OPcache extension not available'
            ];
        }

        // Attempt to reset OPcache
        $result = opcache_reset();

        if ($result) {
            $this->logSecurityEvent('Cache cleared', 'OPcache reset successfully');
            return [
                'success' => true,
                'message' => 'OPcache cleared successfully'
            ];
        }

        return [
            'success' => false,
            'message' => 'Failed to reset OPcache'
        ];
    }

    /**
     * Get cache status (informational endpoint)
     * 
     * Returns current status of all cache systems.
     * 
     * Endpoint: GET /cache/status
     * 
     * @return void Outputs JSON response
     */
    public function getStatus()
    {
        try {
            // Check cache first
            $cached = $this->getCached('/cache/status');
            if ($cached !== null) {
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                ApiResponse::cached($cached, $this->getTtl('/cache/status'));
                return;
            }

            $status = [
                'redis' => $this->getRedisStatus(),
                'fastcgi' => $this->getFastCgiStatus(),
                'opcache' => $this->getOpcacheStatus()
            ];

            $result = $this->sanitizeOutput($status);

            // Cache the result
            $this->setCached('/cache/status', $result);

            ApiResponse::success($result, $this->getTtl('/cache/status'));
        } catch (Exception $e) {
            $this->logSecurityEvent('Cache status error', $e->getMessage());
            // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
            ApiResponse::serverError('Unable to retrieve cache status');
        }
    }

    /**
     * Get Redis cache status
     * 
     * @return array Redis status information
     */
    private function getRedisStatus()
    {
        // codacy:ignore - Static SystemCommand method used; dependency injection would require service container
        $output = SystemCommand::execute('redis-cli', ['INFO', 'memory']);

        if ($output === null) {
            return [
                'available' => false,
                'reason' => 'Unable to connect to Redis'
            ];
        }

        $status = [
            'available' => true,
            'used_memory' => null,
            'used_memory_human' => null
        ];

        // Parse memory info
        if (preg_match('/used_memory:(\d+)/', $output, $matches)) {
            $status['used_memory'] = (int) $matches[1];
        }
        if (preg_match('/used_memory_human:([^\r\n]+)/', $output, $matches)) {
            $status['used_memory_human'] = trim($matches[1]);
        }

        return $status;
    }

    /**
     * Get FastCGI cache status
     * 
     * @return array FastCGI cache status information
     */
    private function getFastCgiStatus()
    {
        // codacy:ignore - file_exists() and is_dir() required for cache status checking
        if (!file_exists(self::FASTCGI_CACHE_PATH) || !is_dir(self::FASTCGI_CACHE_PATH)) {
            return [
                'available' => false,
                'reason' => 'FastCGI cache directory not found'
            ];
        }

        // Get cache directory size
        // codacy:ignore - Static SystemCommand method used; dependency injection would require service container
        $output = SystemCommand::execute('du', ['-sh', self::FASTCGI_CACHE_PATH]);
        $size = 'Unknown';

        if ($output !== null) {
            $parts = preg_split('/\s+/', trim($output));
            if (!empty($parts[0])) {
                $size = $parts[0];
            }
        }

        return [
            'available' => true,
            'path' => self::FASTCGI_CACHE_PATH,
            'size' => $size
        ];
    }

    /**
     * Get OPcache status
     * 
     * @return array OPcache status information
     */
    private function getOpcacheStatus()
    {
        if (!function_exists('opcache_get_status')) {
            return [
                'available' => false,
                'reason' => 'OPcache extension not available'
            ];
        }

        $status = opcache_get_status(false);

        if (!$status) {
            return [
                'available' => false,
                'reason' => 'Unable to get OPcache status'
            ];
        }

        return [
            'available' => true,
            'enabled' => isset($status['opcache_enabled']) ? $status['opcache_enabled'] : false,
            'memory_usage' => isset($status['memory_usage']) ? [
                'used_memory' => isset($status['memory_usage']['used_memory']) ? $status['memory_usage']['used_memory'] : null,
                'free_memory' => isset($status['memory_usage']['free_memory']) ? $status['memory_usage']['free_memory'] : null,
                'wasted_memory' => isset($status['memory_usage']['wasted_memory']) ? $status['memory_usage']['wasted_memory'] : null
            ] : null,
            'statistics' => isset($status['opcache_statistics']) ? [
                'num_cached_scripts' => isset($status['opcache_statistics']['num_cached_scripts']) ? $status['opcache_statistics']['num_cached_scripts'] : null,
                'hits' => isset($status['opcache_statistics']['hits']) ? $status['opcache_statistics']['hits'] : null,
                'misses' => isset($status['opcache_statistics']['misses']) ? $status['opcache_statistics']['misses'] : null
            ] : null
        ];
    }
}
