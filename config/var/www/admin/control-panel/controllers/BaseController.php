<?php

/**
 * EngineScript Admin Dashboard - Base Controller
 *
 * Abstract base class for all API controllers providing:
 * - Caching of the one external source (UptimeRobot)
 * - Decoding of the JSON request body
 *
 * All domain controllers should extend this class to inherit
 * common functionality and ensure consistent behavior.
 *
 * @package EngineScript\Dashboard\API\Controllers
 * @version 1.0.0
 * @security HIGH - Handles caching and validation for all controllers
 */

declare(strict_types=1);

// Ensure response/request helper classes are loaded
require_once __DIR__ . '/../classes/ApiResponder.php';
require_once __DIR__ . '/../classes/Request.php';
require_once __DIR__ . '/../classes/SecurityLogger.php';

// Ensure Session wrapper is loaded
require_once __DIR__ . '/../classes/Session.php';

/**
 * Abstract Base Controller
 *
 * Provides shared functionality for all API controllers:
 * - Caching of the one external source (UptimeRobot)
 * - Decoding of the JSON request body
 *
 * Usage:
 *   class MyController extends BaseController {
 *       public function getData() {
 *           $result = $this->remember('my-source', fn () => $this->fetchData());
 *           $this->respondCached($result['data'], $result['hit']);
 *       }
 *   }
 */
abstract class BaseController
{
    /**
     * Cache directory path
     */
    private const string CACHE_DIR = '/var/cache/enginescript/api/';

    /**
     * Server-side cache lifetime in seconds. Only UptimeRobot is cached: it is
     * an external service with a request limit. The cron sweep removes entries
     * older than a minute in any case.
     */
    private const int CACHE_TTL = 60;

    /**
     * Cached decoded JSON request body for state-changing endpoints.
     *
     * @var array<mixed>|null
     */
    private ?array $jsonBody = null;

    /**
     * Initialize shared dependencies.
     *
     * Final, because the router and the batch endpoint build every controller
     * with these arguments.
     */
    final public function __construct(
        protected Session $session,
        protected ApiResponder $response,
        protected SecurityLogger $securityLogger,
        protected Request $request
    ) {
    }

    /**
     * The cached data for a key, or else the fetched data, stored for later requests
     *
     * Fetches for one key are serialized by a lock, so requests that miss the
     * cache together fetch once.
     *
     * @param callable(): array<mixed> $fetch
     * @return array{data: array<mixed>, hit: bool}
     */
    protected function remember(string $key, callable $fetch): array
    {
        $cached = $this->getCached($key);
        if ($cached !== null) {
            return ['data' => $cached, 'hit' => true];
        }

        $lock = fopen($this->getCacheFilePath($key) . '.lock', 'c');
        if ($lock !== false) {
            flock($lock, LOCK_EX);
        }

        try {
            $cached = $this->getCached($key);
            if ($cached !== null) {
                return ['data' => $cached, 'hit' => true];
            }

            $data = $fetch();
            $this->setCached($key, $data);

            return ['data' => $data, 'hit' => false];
        } finally {
            if ($lock !== false) {
                flock($lock, LOCK_UN);
                fclose($lock);
            }
        }
    }

    /**
     * Send data that remember() gave, marked as a cache hit or miss
     *
     * @param array<mixed> $data
     */
    protected function respondCached(array $data, bool $hit): void
    {
        if ($hit) {
            $this->response->cached($data, self::CACHE_TTL);
        } else {
            $this->response->success($data, self::CACHE_TTL);
        }
    }

    /**
     * Get cached data if present and not expired
     *
     * @return array<mixed>|null Cached data or null if not found/expired
     */
    private function getCached(string $key): ?array
    {
        $cache_file = $this->getCacheFilePath($key);

        if (!file_exists($cache_file)) {
            return null;
        }

        $cache_content = file_get_contents($cache_file);
        if ($cache_content === false) {
            return null;
        }

        try {
            $cache_data = $this->arrayOrNull(json_decode($cache_content, true, 512, JSON_THROW_ON_ERROR));
        } catch (JsonException) {
            // Corrupt cache entries are ignored and replaced by fresh responses.
            return null;
        }

        if ($cache_data === null || !isset($cache_data['timestamp']) || !is_int($cache_data['timestamp']) || !isset($cache_data['data']) || !is_array($cache_data['data'])) {
            return null;
        }

        // Check if cache is still valid
        if (time() - $cache_data['timestamp'] > self::CACHE_TTL) {
            // Cache expired - remove it
            @unlink($cache_file);
            return null;
        }

        return $cache_data['data'];
    }

    /**
     * Store response data in cache
     *
     * The entry is written to a temporary file and renamed into place, so a
     * concurrent reader never sees a partly written entry. The cache directory is
     * created by the installer.
     *
     * @param array<mixed> $data The data to cache
     */
    private function setCached(string $key, array $data): void
    {
        $cache_file = $this->getCacheFilePath($key);
        $cache_data = [
            'timestamp' => time(),
            'key' => $key,
            'data' => $data,
        ];

        try {
            $encoded = json_encode($cache_data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            return;
        }

        // Write to a temporary name and rename it, so a reader never sees a half-written file.
        $tempFile = $cache_file . '.' . bin2hex(random_bytes(8)) . '.tmp';
        if (file_put_contents($tempFile, $encoded) === false) {
            return;
        }

        if (!rename($tempFile, $cache_file)) {
            unlink($tempFile);
        }
    }

    /**
     * Get cache file path for a key
     */
    private function getCacheFilePath(string $key): string
    {
        $safe_key = preg_replace('/[^a-zA-Z0-9_-]/', '_', $key) ?? '';
        return self::CACHE_DIR . $safe_key . '.json';
    }

    /**
     * Decode and cache a JSON request body.
     *
     * @return array<mixed>
     */
    protected function getJsonBody(): array
    {
        if ($this->jsonBody !== null) {
            return $this->jsonBody;
        }

        $input = $this->request->body();
        if (trim($input) === '') {
            $this->jsonBody = [];
            return $this->jsonBody;
        }

        try {
            $this->jsonBody = $this->arrayOrNull(json_decode($input, true, 512, JSON_THROW_ON_ERROR)) ?? [];
        } catch (JsonException) {
            $this->jsonBody = [];
        }

        return $this->jsonBody;
    }

    /**
     * The value when it is an array, otherwise null.
     *
     * @return array<mixed>|null
     */
    protected function arrayOrNull(mixed $value): ?array
    {
        return is_array($value) ? $value : null;
    }

    /**
     * The value when it is a string, otherwise null.
     */
    protected function stringOrNull(mixed $value): ?string
    {
        return is_string($value) ? $value : null;
    }

    /**
     * The whitespace-separated fields of the trimmed text (none if the split fails).
     *
     * @return list<string>
     */
    protected function whitespaceFields(string $text): array
    {
        $fields = preg_split('/\s+/', trim($text));

        return $fields === false ? [] : $fields;
    }
}
