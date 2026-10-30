<?php

/**
 * EngineScript Admin Dashboard - Cache Controller
 *
 * Handles cache clearing operations for Redis, Nginx FastCGI, and OPcache.
 *
 * @package EngineScript\Dashboard\API\Controllers
 * @version 1.0.0
 */

declare(strict_types=1);

require_once __DIR__ . '/BaseController.php';
require_once __DIR__ . '/../classes/SystemCommand.php';

/**
 * Cache Controller
 *
 * Provides cache clearing functionality for various caching systems.
 *
 * @psalm-api
 */
final class CacheController extends BaseController
{
    /**
     * Valid cache types
     */
    private const array VALID_CACHE_TYPES = ['redis', 'fastcgi', 'opcache'];

    /**
     * Clear specified caches
     *
     * Clears one or more cache types based on the 'type' query parameter.
     * Supported types: redis, fastcgi, opcache
     *
     * Endpoint: POST /cache/clear?type=redis,fastcgi,opcache
     *
     * @return void Outputs JSON response
     * @psalm-api
     */
    public function clear(): void
    {
        try {
            // Validate and parse cache types from request
            $validated = $this->validateCacheTypes();
            if ($validated === null) {
                return;
            }

            [$validTypes, $invalidTypes] = $validated;

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
                'results' => $results,
            ];

            if (!empty($invalidTypes)) {
                $response['warnings'] = [
                    'invalid_types' => $invalidTypes,
                    'message' => 'Some requested cache types were invalid and ignored',
                ];
            }

            $this->response->success($response);
        } catch (Throwable $e) {
            $this->securityLogger->write('Cache clear error', $e->getMessage());
            $this->response->serverError('Unable to clear cache');
        }
    }

    /**
     * Validate and parse cache types from the request
     *
     * @return array{0: list<'redis'|'fastcgi'|'opcache'>, 1: list<string>}|null [validTypes, invalidTypes]
     *         or null if validation failed (response already sent)
     */
    private function validateCacheTypes(): ?array
    {
        $typeParam = $this->request->query('type') ?? '';

        if ($typeParam === '') {
            $body = $this->getJsonBody();
            $typeParam = $this->typeParamFromBody($body['types'] ?? $body['type'] ?? '');
        }

        if (empty($typeParam)) {
            $this->response->badRequest('Cache type required. Valid types: ' . implode(', ', self::VALID_CACHE_TYPES));
            return null;
        }

        $requestedTypes = array_map(trim(...), explode(',', $typeParam));
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

        $validTypes = array_values(array_unique($validTypes));
        $invalidTypes = array_values(array_unique($invalidTypes));

        if ($validTypes === []) {
            $this->response->badRequest('No valid cache types provided. Valid types: ' . implode(', ', self::VALID_CACHE_TYPES));
            return null;
        }

        return [$validTypes, $invalidTypes];
    }

    /**
     * The comma-separated cache types from the JSON body's "types" or "type" value.
     */
    private function typeParamFromBody(mixed $bodyTypes): string
    {
        if (is_array($bodyTypes)) {
            // Non-strings drop out here; empty names are skipped by the validation anyway.
            return implode(',', array_filter(array_map($this->stringOrNull(...), $bodyTypes)));
        }

        return is_string($bodyTypes) ? $bodyTypes : '';
    }

    /**
     * Clear a specific cache type
     *
     * @param 'redis'|'fastcgi'|'opcache' $type Cache type to clear
     * @return array{success: bool, message: string} Result with success status and message
     */
    private function clearCacheType(string $type): array
    {
        return match ($type) {
            'redis' => $this->clearRedisCache(),
            'fastcgi' => $this->clearFastCgiCache(),
            'opcache' => $this->clearOpcache(),
        };
    }

    /**
     * Clear Redis cache
     *
     * @return array{success: bool, message: string} Result with success status and message
     */
    private function clearRedisCache(): array
    {
        $output = SystemCommand::flushRedis();

        if ($output === 'OK') {
            $this->securityLogger->write('Cache cleared', 'Redis cache flushed successfully');
            return [
                'success' => true,
                'message' => 'Redis cache cleared successfully',
            ];
        }

        return [
            'success' => false,
            'message' => 'Failed to clear Redis cache',
        ];
    }

    /**
     * Clear Nginx FastCGI cache
     *
     * @return array{success: bool, message: string} Result with success status and message
     */
    private function clearFastCgiCache(): array
    {
        if (!file_exists(SystemCommand::FASTCGI_CACHE_PATH)) {
            return [
                'success' => true,
                'message' => 'FastCGI cache directory does not exist (nothing to clear)',
            ];
        }

        if (!is_dir(SystemCommand::FASTCGI_CACHE_PATH)) {
            return [
                'success' => false,
                'message' => 'FastCGI cache path exists but is not a directory',
            ];
        }

        // Clear cache files using find command (safer than rm -rf)
        $output = SystemCommand::clearFastCgiCache();

        if ($output !== false) {
            $this->securityLogger->write('Cache cleared', 'FastCGI cache cleared successfully');
            return [
                'success' => true,
                'message' => 'FastCGI cache cleared successfully',
            ];
        }

        return [
            'success' => false,
            'message' => 'Failed to clear FastCGI cache',
        ];
    }

    /**
     * Clear PHP OPcache
     *
     * @return array{success: bool, message: string} Result with success status and message
     */
    private function clearOpcache(): array
    {
        // Check if OPcache is available
        if (!function_exists('opcache_reset')) {
            return [
                'success' => false,
                'message' => 'OPcache extension not available',
            ];
        }

        // Attempt to reset OPcache
        $result = opcache_reset();

        if ($result) {
            $this->securityLogger->write('Cache cleared', 'OPcache reset successfully');
            return [
                'success' => true,
                'message' => 'OPcache cleared successfully',
            ];
        }

        return [
            'success' => false,
            'message' => 'Failed to reset OPcache',
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
     * @psalm-api
     */
    public function getStatus(): void
    {
        try {
            // Never cached: the status must show the effect of a cache clear at once.
            $status = [
                'redis' => $this->getRedisStatus(),
                'fastcgi' => $this->getFastCgiStatus(),
                'opcache' => $this->getOpcacheStatus(),
            ];

            $this->response->success($status);
        } catch (Throwable $e) {
            $this->securityLogger->write('Cache status error', $e->getMessage());
            $this->response->serverError('Unable to retrieve cache status');
        }
    }

    /**
     * Get Redis cache status
     *
     * @return array<string, bool|int|string|null> Redis status information
     */
    private function getRedisStatus(): array
    {
        $output = SystemCommand::getRedisMemoryInfo();

        if ($output === false) {
            return [
                'available' => false,
                'reason' => 'Unable to connect to Redis',
            ];
        }

        $status = [
            'available' => true,
            'used_memory' => null,
            'used_memory_human' => null,
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
     * @return array<string, bool|string> FastCGI cache status information
     */
    private function getFastCgiStatus(): array
    {
        if (!is_dir(SystemCommand::FASTCGI_CACHE_PATH)) {
            return [
                'available' => false,
                'reason' => 'FastCGI cache directory not found',
            ];
        }

        // Get cache directory size
        $output = SystemCommand::getFastCgiCacheSize();
        $size = 'Unknown';

        if ($output !== false) {
            $firstField = $this->whitespaceFields($output)[0] ?? '';
            if (!in_array($firstField, ['', '0'], true)) {
                $size = $firstField;
            }
        }

        return [
            'available' => true,
            'path' => SystemCommand::FASTCGI_CACHE_PATH,
            'size' => $size,
        ];
    }

    /**
     * Get OPcache status
     *
     * @return array<string, mixed> OPcache status information
     */
    private function getOpcacheStatus(): array
    {
        if (!function_exists('opcache_get_status')) {
            return [
                'available' => false,
                'reason' => 'OPcache extension not available',
            ];
        }

        $status = opcache_get_status(false);

        if ($status === false || $status === []) {
            return [
                'available' => false,
                'reason' => 'Unable to get OPcache status',
            ];
        }

        return [
            'available' => true,
            'enabled' => $status['opcache_enabled'] ?? false,
            'memory_usage' => $this->pickFields(
                $status['memory_usage'] ?? null,
                ['used_memory', 'free_memory', 'wasted_memory']
            ),
            'statistics' => $this->pickFields(
                $status['opcache_statistics'] ?? null,
                ['num_cached_scripts', 'hits', 'misses']
            ),
        ];
    }

    /**
     * The named fields of a status section (null for a missing field), or null without the section.
     *
     * @param list<string> $keys
     * @return array<string, mixed>|null
     */
    private function pickFields(mixed $section, array $keys): ?array
    {
        if (!is_array($section)) {
            return null;
        }

        return array_combine($keys, array_map(static fn(string $key): mixed => $section[$key] ?? null, $keys));
    }
}
