<?php

declare(strict_types=1);

/**
 * EngineScript Admin Dashboard - Instance API Response Handler
 *
 * Provides injectable response handling for controllers and routing.
 *
 * @package EngineScript\Dashboard\API
 * @version 1.0.0
 * @security HIGH - Handles all API output
 */
final class ApiResponder
{
    public const int HTTP_OK = 200;
    public const int HTTP_BAD_REQUEST = 400;
    public const int HTTP_FORBIDDEN = 403;
    public const int HTTP_NOT_FOUND = 404;
    public const int HTTP_METHOD_NOT_ALLOWED = 405;
    public const int HTTP_TOO_MANY_REQUESTS = 429;
    public const int HTTP_INTERNAL_ERROR = 500;

    private const JSON_FLAGS = JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE | JSON_THROW_ON_ERROR;

    public function badRequest(string $message = 'Bad request'): void
    {
        $this->error($message, self::HTTP_BAD_REQUEST);
    }

    public function forbidden(string $message = 'Forbidden'): void
    {
        $this->error($message, self::HTTP_FORBIDDEN);
    }

    public function notFound(string $message = 'Not found'): void
    {
        $this->error($message, self::HTTP_NOT_FOUND);
    }

    public function rateLimited(string $message = 'Rate limit exceeded'): void
    {
        $this->error($message, self::HTTP_TOO_MANY_REQUESTS);
    }

    public function serverError(string $message = 'Internal server error'): void
    {
        $this->error($message, self::HTTP_INTERNAL_ERROR);
    }

    public function success(mixed $data, ?int $ttl = null): void
    {
        $this->sendJson($data, $ttl);
    }

    public function cached(mixed $data, int $ttl): void
    {
        $this->sendJson($data, $ttl, 'HIT');
    }

    public function error(string $message, int $code = self::HTTP_INTERNAL_ERROR): void
    {
        http_response_code($code);

        $this->sendJson(['error' => $message]);
    }

    /**
     * @param string|list<string> $allowedMethod
     */
    public function methodNotAllowed(string|array $allowedMethod): void
    {
        $allowedMethods = is_array($allowedMethod) ? $allowedMethod : [$allowedMethod];
        $allowedMethods = array_values(array_unique(array_map(strtoupper(...), $allowedMethods)));
        $allowedMethods = array_values(array_filter(
            $allowedMethods,
            static fn(string $method): bool => preg_match('/^[A-Z]+$/', $method) === 1
        ));
        $allowHeader = implode(', ', $allowedMethods ?: ['GET']);

        header('Allow: ' . $allowHeader);
        $this->error('Method not allowed. Use ' . $allowHeader . '.', self::HTTP_METHOD_NOT_ALLOWED);
    }

    private function sendJson(mixed $data, ?int $ttl = null, ?string $cacheStatus = null): void
    {
        header('Cache-Control: no-store');
        // A server-cache lifetime controls diagnostics, never browser storage.
        if ($cacheStatus !== null || ($ttl !== null && $ttl > 0)) {
            header('X-Cache: ' . ($cacheStatus ?? 'MISS'));
        }

        try {
            echo json_encode($data, self::JSON_FLAGS);
        } catch (JsonException) {
            http_response_code(self::HTTP_INTERNAL_ERROR);
            echo '{"error":"Failed to encode JSON response"}';
        }
    }
}
