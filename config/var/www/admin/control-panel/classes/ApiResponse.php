<?php
/**
 * EngineScript Admin Dashboard - Centralized API Response Handler
 * 
 * Provides unified response handling for all API endpoints including:
 * - JSON response encoding
 * - HTTP status code management
 * - Cache header management
 * - Error response formatting
 * 
 * @package EngineScript\Dashboard\API
 * @version 1.0.0
 * @security HIGH - Handles all API output
 */

/**
 * Centralized API Response Handler
 * 
 * All controller methods should use this class to return responses
 * to ensure consistent formatting, headers, and cache behavior.
 * 
 * Usage examples:
 *   ApiResponse::success(['status' => 'ok']);
 *   ApiResponse::success($data, 300); // with cache TTL
 *   ApiResponse::cached($data, 300);   // cache HIT
 *   ApiResponse::error('Not found', 404);
 *   ApiResponse::methodNotAllowed('POST');
 *   ApiResponse::badRequest('Invalid input');
 */
final class ApiResponse
{
    /**
     * Standard HTTP status codes used by API
     */
    public const HTTP_OK = 200;
    public const HTTP_BAD_REQUEST = 400;
    public const HTTP_FORBIDDEN = 403;
    public const HTTP_NOT_FOUND = 404;
    public const HTTP_METHOD_NOT_ALLOWED = 405;
    public const HTTP_TOO_MANY_REQUESTS = 429;
    public const HTTP_INTERNAL_ERROR = 500;

    /**
     * Common JSON encoding flags for all API responses.
     */
    private const JSON_FLAGS = JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR;

    private function __construct()
    {
    }

    /**
     * Send a successful JSON response
     * 
     * Used when returning fresh data (cache MISS).
     * Optionally sets Cache-Control header if TTL provided.
     * 
     * @param mixed $data The data to encode as JSON
     * @param int|null $ttl Optional cache TTL in seconds for Cache-Control header
     * @return void
     */
    public static function success(mixed $data, ?int $ttl = null): void
    {
        if ($ttl !== null && $ttl > 0) {
            // codacy:ignore - header() required for cache control in standalone API
            header('X-Cache: MISS');
            header('Cache-Control: private, max-age=' . (int)$ttl);
        }
        
        self::sendJson($data);
    }

    /**
     * Send a cached response with appropriate cache headers
     * 
     * Used when returning data from cache (cache HIT).
     * Always sets X-Cache: HIT and Cache-Control headers.
     * 
     * @param mixed $data The cached data to return
     * @param int $ttl Cache TTL in seconds for Cache-Control header
     * @return void
     */
    public static function cached(mixed $data, int $ttl): void
    {
        // codacy:ignore - header() required for cache headers in standalone API
        header('X-Cache: HIT');
        header('Cache-Control: private, max-age=' . (int)$ttl);
        
        self::sendJson($data);
    }

    /**
     * Send an error response with appropriate HTTP status code
     * 
     * Sets HTTP response code and returns JSON error object.
     * Error format: {"error": "message"}
     * 
     * @param string $message Error message to return
     * @param int $code HTTP status code (default 500)
     * @return void
     */
    public static function error(string $message, int $code = self::HTTP_INTERNAL_ERROR): void
    {
        http_response_code($code);
        header('Cache-Control: no-store');

        self::sendJson(['error' => $message]);
    }

    /**
     * Send a 400 Bad Request response
     * 
     * Convenience method for invalid input errors.
     * 
     * @param string $message Error message describing the bad request
     * @return void
     */
    public static function badRequest(string $message): void
    {
        self::error($message, self::HTTP_BAD_REQUEST);
    }

    /**
     * Send a 403 Forbidden response
     * 
     * Convenience method for authorization/permission errors.
     * 
     * @param string $message Error message (default: 'Forbidden')
     * @return void
     */
    public static function forbidden(string $message = 'Forbidden'): void
    {
        self::error($message, self::HTTP_FORBIDDEN);
    }

    /**
     * Send a 404 Not Found response
     * 
     * Convenience method for missing resource errors.
     * 
     * @param string $message Error message (default: 'Not found')
     * @return void
     */
    public static function notFound(string $message = 'Not found'): void
    {
        self::error($message, self::HTTP_NOT_FOUND);
    }

    /**
     * Send a 405 Method Not Allowed response
     * 
     * Convenience method for wrong HTTP method errors.
     * Includes the expected method in the error message.
     * 
     * @param string|array<int, string> $allowedMethod The HTTP method(s) that should be used
     * @return void
     */
    public static function methodNotAllowed(string|array $allowedMethod): void
    {
        $allowedMethods = is_array($allowedMethod) ? $allowedMethod : [$allowedMethod];
        $allowedMethods = array_values(array_unique(array_map('strtoupper', $allowedMethods)));
        $allowedMethods = array_values(array_filter($allowedMethods, static fn (string $method): bool => preg_match('/^[A-Z]+$/', $method) === 1));
        $allowHeader = implode(', ', $allowedMethods ?: ['GET']);

        header('Allow: ' . $allowHeader);
        self::error('Method not allowed. Use ' . $allowHeader . '.', self::HTTP_METHOD_NOT_ALLOWED);
    }

    /**
     * Send a 429 Too Many Requests response
     * 
     * Convenience method for rate limiting errors.
     * 
     * @param string $message Error message (default: 'Rate limit exceeded')
     * @return void
     */
    public static function rateLimited(string $message = 'Rate limit exceeded'): void
    {
        self::error($message, self::HTTP_TOO_MANY_REQUESTS);
    }

    /**
     * Send a 500 Internal Server Error response
     * 
     * Convenience method for server errors.
     * Should be used with generic messages that don't expose internals.
     * 
     * @param string $message Generic error message (default: 'Internal server error')
     * @return void
     */
    public static function serverError(string $message = 'Internal server error'): void
    {
        self::error($message, self::HTTP_INTERNAL_ERROR);
    }

    /**
     * Send a JSON response with custom HTTP status code
     * 
     * Generic method for sending any response with any status code.
     * Use specific methods (success, error, etc.) when possible.
     * 
     * @param mixed $data The data to encode as JSON
     * @param int $code HTTP status code
     * @param array<string, string> $headers Optional additional headers as key => value pairs
     * @return void
     */
    public static function json(mixed $data, int $code = self::HTTP_OK, array $headers = []): void
    {
        http_response_code($code);
        
        // Set any additional headers
        foreach ($headers as $name => $value) {
            // codacy:ignore - header() required for custom headers in standalone API
            header("{$name}: {$value}");
        }
        
        self::sendJson($data);
    }

    /**
     * Send an empty response with only HTTP status code
     * 
     * Useful for OPTIONS requests or other responses that need no body.
     * 
     * @param int $code HTTP status code (default 200)
     * @return void
     */
    public static function noContent(int $code = self::HTTP_OK): void
    {
        http_response_code($code);
    }

    /**
     * Encode and send JSON while keeping failures deterministic.
     *
     * @param mixed $data The data to encode
     * @return void
     */
    private static function sendJson(mixed $data): void
    {
        try {
            // codacy:ignore - echo required for JSON API response in standalone API
            echo json_encode($data, self::JSON_FLAGS);
        } catch (JsonException) {
            http_response_code(self::HTTP_INTERNAL_ERROR);
            // codacy:ignore - echo required for JSON API response in standalone API
            echo '{"error":"Failed to encode JSON response"}';
        }
    }
}
