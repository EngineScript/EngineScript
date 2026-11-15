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

namespace EngineScript\Dashboard\API\Controllers;

use EngineScript\Dashboard\Classes\ApiResponder;
use EngineScript\Dashboard\Classes\Request;
use EngineScript\Dashboard\Classes\SecurityLogger;
use EngineScript\Dashboard\Classes\Session;

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
     * an external service with a request limit. An expired entry is replaced on
     * the next read; es.cache empties the directory.
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
     * Final, because the router builds every controller with these arguments.
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
            return;
        }

        $this->response->success($data, self::CACHE_TTL);
    }

    /**
     * Get cached data if present and not expired
     *
     * @SuppressWarnings("PHPMD.ErrorControlOperator") Two requests can find the same entry expired;
     *                  the one whose unlink comes second has nothing left to remove, and no reason to warn.
     *
     * @return array<mixed>|null Cached data or null if not found/expired
     */
    private function getCached(string $key): ?array
    {
        $cacheFile = $this->getCacheFilePath($key);

        if (!file_exists($cacheFile)) {
            return null;
        }

        $cacheContent = file_get_contents($cacheFile);
        if ($cacheContent === false) {
            return null;
        }

        try {
            $cacheData = $this->arrayOrNull(json_decode($cacheContent, true, 512, JSON_THROW_ON_ERROR));
        } catch (\JsonException) {
            // Corrupt cache entries are ignored and replaced by fresh responses.
            return null;
        }

        if (
            $cacheData === null
            || !isset($cacheData['timestamp'])
            || !is_int($cacheData['timestamp'])
            || !isset($cacheData['data'])
            || !is_array($cacheData['data'])
        ) {
            return null;
        }

        // Check if cache is still valid
        if (time() - $cacheData['timestamp'] > self::CACHE_TTL) {
            // Cache expired - remove it
            @unlink($cacheFile);
            return null;
        }

        return $cacheData['data'];
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
        $cacheFile = $this->getCacheFilePath($key);
        $cacheData = [
            'timestamp' => time(),
            'key' => $key,
            'data' => $data,
        ];

        try {
            $encoded = json_encode($cacheData, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR);
        } catch (\JsonException) {
            return;
        }

        // Write to a temporary name and rename it, so a reader never sees a half-written file.
        $tempFile = $cacheFile . '.' . bin2hex(random_bytes(8)) . '.tmp';
        if (file_put_contents($tempFile, $encoded) === false) {
            return;
        }

        if (!rename($tempFile, $cacheFile)) {
            // The temporary file this method created: a random name in the cache directory
            // nosemgrep: php.lang.security.unlink-use.unlink-use
            unlink($tempFile);
        }
    }

    /**
     * Get cache file path for a key
     */
    private function getCacheFilePath(string $key): string
    {
        $safeKey = preg_replace('/[^a-zA-Z0-9_-]/', '_', $key) ?? '';
        return self::CACHE_DIR . $safeKey . '.json';
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
        } catch (\JsonException) {
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
