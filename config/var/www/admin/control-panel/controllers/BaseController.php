<?php
/**
 * EngineScript Admin Dashboard - Base Controller
 * 
 * Abstract base class for all API controllers providing:
 * - Cache management (get/set/clear)
 * - Input validation helpers
 * - Output sanitization
 * - Error logging
 * 
 * All domain controllers should extend this class to inherit
 * common functionality and ensure consistent behavior.
 * 
 * @package EngineScript\Dashboard\API\Controllers
 * @version 1.0.0
 * @security HIGH - Handles caching and validation for all controllers
 */

// Ensure ApiResponse class is loaded
// codacy:ignore - require_once with __DIR__ constant is safe; no user input in path
require_once __DIR__ . '/../classes/ApiResponse.php';

// Ensure Session wrapper is loaded
// codacy:ignore - require_once with __DIR__ constant is safe; no user input in path
require_once __DIR__ . '/../classes/Session.php';

/**
 * Abstract Base Controller
 * 
 * Provides shared functionality for all API controllers:
 * - Response caching with configurable TTLs
 * - Input validation and sanitization
 * - Output sanitization for XSS prevention
 * - Security event logging
 * 
 * Usage:
 *   class MyController extends BaseController {
 *       public function getData() {
 *           if ($cached = $this->getCached('/my/endpoint')) {
 *               return $this->response->cached($cached, $this->getTtl('/my/endpoint'));
 *           }
 *           $data = $this->fetchData();
 *           $this->setCached('/my/endpoint', $data);
 *           return $this->response->success($data, $this->getTtl('/my/endpoint'));
 *       }
 *   }
 */
abstract class BaseController
{
    /**
     * Cache directory path
     */
    protected const CACHE_DIR = '/var/cache/enginescript/api/';

    /**
     * Default cache TTL in seconds
     */
    protected const CACHE_DEFAULT_TTL = 30;

    /**
     * Cache sweep interval in seconds
     */
    protected const CACHE_SWEEP_INTERVAL = 60;

    /**
     * Session wrapper instance — single point of $_SESSION access.
     */
    protected Session $session;

    /**
     * API response helper instance — avoids static calls in subclasses.
     */
    protected ApiResponse $response;

    /**
     * Initialise shared dependencies.
     *
     * Child controllers that define their own constructor must call
     * parent::__construct() to ensure these properties are available.
     */
    public function __construct()
    {
        $this->session  = new Session();
        $this->response = new ApiResponse();
    }

    /**
     * Cache TTL configuration per endpoint (in seconds)
     * Controllers can override this or use getTtl() method
     * 
     * @var array<string, int>
     */
    protected static $cacheTtlConfig = [
        '/system/info' => 60,           // 1 minute - system info rarely changes
        '/services/status' => 15,       // 15 seconds - service status should be fresh
        '/sites' => 120,                // 2 minutes - site list rarely changes
        '/sites/count' => 120,          // 2 minutes
        '/tools/filemanager/status' => 300, // 5 minutes - rarely changes
        '/monitoring/uptime' => 60,     // 1 minute
        '/monitoring/uptime/monitors' => 60, // 1 minute
        '/cache/status' => 30,          // 30 seconds - cache status updates frequently
    ];

    /**
     * Get the TTL for a specific endpoint
     * 
     * @param string $endpoint The API endpoint path
     * @return int TTL in seconds
     */
    protected function getTtl($endpoint)
    {
        return isset(self::$cacheTtlConfig[$endpoint]) 
            ? self::$cacheTtlConfig[$endpoint] 
            : self::CACHE_DEFAULT_TTL;
    }

    /**
     * Get cached response if valid and not expired
     * 
     * @param string $endpoint The API endpoint
     * @param array $params Optional query parameters for cache key
     * @return mixed|null Cached data or null if not found/expired
     */
    protected function getCached($endpoint, array $params = [])
    {
        $cache_file = $this->getCacheFilePath($endpoint, $params);
        
        // codacy:ignore - file_exists() required for cache validation in standalone API
        if (!file_exists($cache_file)) {
            return null;
        }
        
        // codacy:ignore - file_get_contents() required for cache reading in standalone API
        $cache_data = json_decode(file_get_contents($cache_file), true);
        
        if (!$cache_data || !isset($cache_data['timestamp']) || !isset($cache_data['data'])) {
            return null;
        }
        
        $ttl = $this->getTtl($endpoint);
        
        // Check if cache is still valid
        if (time() - $cache_data['timestamp'] > $ttl) {
            // Cache expired - remove it
            // codacy:ignore - unlink() required for expired cache removal in standalone API
            @unlink($cache_file);
            return null;
        }
        
        return $cache_data['data'];
    }

    /**
     * Store response data in cache
     * 
     * @param string $endpoint The API endpoint
     * @param mixed $data The response data to cache
     * @param array $params Optional query parameters for cache key
     * @return bool Success status
     */
    protected function setCached($endpoint, $data, array $params = [])
    {
        // Ensure cache directory exists
        // codacy:ignore - is_dir() required for cache directory check in standalone API
        if (!is_dir(self::CACHE_DIR)) {
            // codacy:ignore - mkdir() required for cache directory creation in standalone API
            @mkdir(self::CACHE_DIR, 0750, true);
        }
        
        $cache_file = $this->getCacheFilePath($endpoint, $params);
        $cache_data = [
            'timestamp' => time(),
            'endpoint' => $endpoint,
            'data' => $data
        ];
        
        // codacy:ignore - file_put_contents() required for cache writing in standalone API
        return @file_put_contents($cache_file, json_encode($cache_data), LOCK_EX) !== false;
    }

    /**
     * Clear cache for a specific endpoint or all caches
     * 
     * @param string|null $endpoint Optional endpoint to clear, null clears all
     * @return void
     */
    protected function clearCacheFor($endpoint = null)
    {
        // codacy:ignore - is_dir() required for filesystem operations in standalone API on hardcoded path
        if (!is_dir(self::CACHE_DIR)) {
            return;
        }
        
        if ($endpoint === null) {
            // Clear all cache files
            // codacy:ignore - glob() required for cache enumeration on hardcoded path
            $files = glob(self::CACHE_DIR . '*.json');
            foreach ($files as $file) {
                // codacy:ignore - unlink() required for cache deletion in standalone API
                @unlink($file);
            }
            return;
        }

        // Clear specific endpoint cache
        $safe_key = preg_replace('/[^a-zA-Z0-9_-]/', '_', $endpoint);
        // codacy:ignore - glob() required for cache enumeration on hardcoded path
        $files = glob(self::CACHE_DIR . $safe_key . '*.json');
        foreach ($files as $file) {
            // codacy:ignore - unlink() required for cache deletion in standalone API
            @unlink($file);
        }
    }

    /**
     * Get cache file path for an endpoint
     * 
     * @param string $endpoint The API endpoint
     * @param array $params Optional query parameters for cache key
     * @return string Cache file path
     */
    protected function getCacheFilePath($endpoint, array $params = [])
    {
        // Create cache key from endpoint and params
        $cache_key = $endpoint;
        if (!empty($params)) {
            ksort($params);
            $cache_key .= '_' . hash('xxh128', json_encode($params));
        }
        
        // Sanitize cache key for filesystem
        $safe_key = preg_replace('/[^a-zA-Z0-9_-]/', '_', $cache_key);
        return self::CACHE_DIR . $safe_key . '.json';
    }

    /**
     * Validate and sanitize a string input
     * 
     * @param string $input The input to validate
     * @param int $max_length Maximum allowed length (default 255)
     * @return string|false Sanitized string or false if invalid
     */
    protected function validateString($input, $max_length = 255)
    {
        $input = trim($input);
        if (strlen($input) > $max_length) {
            return false;
        }
        
        // Use htmlspecialchars for XSS prevention (handles <, >, ", ' via ENT_QUOTES)
        return htmlspecialchars($input, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }

    /**
     * Validate a path input (alphanumeric, dash, underscore, dot only)
     * 
     * @param string $input The path to validate
     * @return string|false Validated path or false if invalid
     */
    protected function validatePath($input)
    {
        // Only allow alphanumeric, dash, underscore, dot — implicitly blocks / and ..
        if (!preg_match('/^[a-zA-Z0-9._-]+$/', $input)) {
            return false;
        }
        
        // Belt-and-suspenders: reject path traversal sequences
        if (str_contains($input, '..')) {
            return false;
        }
        
        return $input;
    }

    /**
     * Validate a service name input
     * 
     * @param string $input The service name to validate
     * @return string|false Validated service name or false if invalid
     */
    protected function validateService($input)
    {
        // Allow known service names
        $allowed_services = ['nginx', 'mariadb', 'redis-server'];
        
        if (in_array($input, $allowed_services, true)) {
            return $input;
        }
        
        // Allow PHP-FPM services with flexible patterns:
        // php-fpm, php8.4-fpm, php-fpm8.4, php84-fpm, etc.
        if (preg_match('/^php[a-zA-Z0-9\.\-_]*fpm[a-zA-Z0-9\.\-_]*$/', $input)) {
            return $input;
        }
        
        return false;
    }

    /**
     * Generic input validation dispatcher
     * 
     * @param mixed $input The input to validate
     * @param string $type Type of validation: 'string', 'path', or 'service'
     * @param int $max_length Max length for string validation
     * @return mixed Validated input or false if invalid
     */
    protected function validateInput($input, $type = 'string', $max_length = 255)
    {
        if (empty($input) && $input !== '0') {
            return false;
        }
        
        switch ($type) {
            case 'string':
                return $this->validateString($input, $max_length);
            case 'path':
                return $this->validatePath($input);
            case 'service':
                return $this->validateService($input);
            default:
                return false;
        }
    }

    /**
     * Sanitize output data to prevent XSS in JSON responses
     * 
     * Recursively sanitizes arrays and encodes strings.
     * 
     * @param mixed $data The data to sanitize
     * @return mixed Sanitized data
     */
    protected function sanitizeOutput($data)
    {
        if (is_array($data)) {
            return array_map([$this, 'sanitizeOutput'], $data);
        }
        
        if (is_string($data)) {
            // Prevent XSS in JSON output
            return htmlspecialchars($data, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        }
        
        return $data;
    }

    /**
     * Log a security event
     *
     * Sanitizes all inputs to prevent log injection attacks.
     * Logs to /var/log/EngineScript/enginescript-api-security.log
     *
     * @param string $event The security event description
     * @param string $details Optional additional details
     * @return void
     */
    protected function logSecurityEvent($event, $details = '')
    {
        SecurityLogger::log($event, $details);
    }

    /**
     * Retrieve a value from the session.
     *
     * Delegates to the Session instance so that no controller ever accesses
     * the $_SESSION superglobal directly, satisfying PHPMD's SuperGlobals and
     * StaticAccess rules and improving testability.
     *
     * @param string $key     The session key to look up.
     * @param mixed  $default Value returned when the key is absent.
     * @return mixed The session value or $default.
     */
    protected function getSessionValue(string $key, mixed $default = null): mixed
    {
        return $this->session->get($key, $default);
    }

    /**
     * Store a value in the session.
     *
     * Delegates to the Session instance so that no controller ever accesses
     * the $_SESSION superglobal directly.
     *
     * @param string $key   The session key to set.
     * @param mixed  $value The value to store.
     * @return void
     */
    protected function setSessionValue(string $key, mixed $value): void
    {
        $this->session->set($key, $value);
    }

    /**
     * Get HTTP request method
     *
     * Centralizes $_SERVER access to avoid super-global access in subclasses.
     *
     * @return string HTTP method (uppercase), defaults to 'GET'
     */
    protected function getRequestMethod(): string
    {
        // codacy:ignore - Direct $_SERVER access centralized here to prevent super-global access in subclasses
        return strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET');
    }

    /**
     * Retrieve a GET query parameter without direct super-global access.
     *
     * Centralizes $_GET access via filter_input() so that no controller
     * touches the $_GET superglobal directly.
     *
     * @param string $key Query parameter name
     * @return string|null Trimmed value or null when absent/invalid
     */
    protected function getQueryParam(string $key): ?string
    {
        // codacy:ignore - filter_input() safely centralizes query access without exposing $_GET in controller actions
        $value = filter_input(INPUT_GET, $key, FILTER_UNSAFE_RAW);

        if ($value === null || $value === false || !is_string($value)) {
            return null;
        }

        $value = trim($value);

        return $value === '' ? null : $value;
    }
}
