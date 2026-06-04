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

require_once __DIR__ . '/ApiResponder.php';

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
 *
 * @method static void success(mixed $data, ?int $ttl = null)
 * @method static void cached(mixed $data, int $ttl)
 * @method static void error(string $message, int $code = 500)
 * @method static void badRequest(string $message)
 * @method static void forbidden(string $message = 'Forbidden')
 * @method static void notFound(string $message = 'Not found')
 * @method static void methodNotAllowed(string|array $allowedMethod)
 * @method static void rateLimited(string $message = 'Rate limit exceeded')
 * @method static void serverError(string $message = 'Internal server error')
 * @method static void json(mixed $data, int $code = 200, array $headers = [])
 * @method static void noContent(int $code = 200)
 */
final class ApiResponse
{
    /**
     * Standard HTTP status codes used by API
     */
    public const HTTP_OK = ApiResponder::HTTP_OK;
    public const HTTP_BAD_REQUEST = ApiResponder::HTTP_BAD_REQUEST;
    public const HTTP_FORBIDDEN = ApiResponder::HTTP_FORBIDDEN;
    public const HTTP_NOT_FOUND = ApiResponder::HTTP_NOT_FOUND;
    public const HTTP_METHOD_NOT_ALLOWED = ApiResponder::HTTP_METHOD_NOT_ALLOWED;
    public const HTTP_TOO_MANY_REQUESTS = ApiResponder::HTTP_TOO_MANY_REQUESTS;
    public const HTTP_INTERNAL_ERROR = ApiResponder::HTTP_INTERNAL_ERROR;

    private function __construct()
    {
    }

    public static function __callStatic(string $name, array $arguments): void
    {
        (new ApiResponder())->{$name}(...$arguments);
    }
}
