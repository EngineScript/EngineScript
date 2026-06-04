<?php
/**
 * EngineScript Admin Dashboard - Instance API Response Handler
 *
 * Provides injectable response handling for controllers and routing while the
 * ApiResponse class remains available as a static compatibility facade.
 *
 * @package EngineScript\Dashboard\API
 * @version 1.0.0
 * @security HIGH - Handles all API output
 *
 * @method void badRequest(string $message)
 * @method void forbidden(string $message = 'Forbidden')
 * @method void notFound(string $message = 'Not found')
 * @method void rateLimited(string $message = 'Rate limit exceeded')
 * @method void serverError(string $message = 'Internal server error')
 * @method void noContent(int $code = 200)
 */
final class ApiResponder
{
    public const HTTP_OK = 200;
    public const HTTP_BAD_REQUEST = 400;
    public const HTTP_FORBIDDEN = 403;
    public const HTTP_NOT_FOUND = 404;
    public const HTTP_METHOD_NOT_ALLOWED = 405;
    public const HTTP_TOO_MANY_REQUESTS = 429;
    public const HTTP_INTERNAL_ERROR = 500;

    private const JSON_FLAGS = JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR;

    private const ERROR_STATUS_CODES = [
        'badRequest' => self::HTTP_BAD_REQUEST,
        'forbidden' => self::HTTP_FORBIDDEN,
        'notFound' => self::HTTP_NOT_FOUND,
        'rateLimited' => self::HTTP_TOO_MANY_REQUESTS,
        'serverError' => self::HTTP_INTERNAL_ERROR,
    ];

    private const DEFAULT_ERROR_MESSAGES = [
        'badRequest' => 'Bad request',
        'forbidden' => 'Forbidden',
        'notFound' => 'Not found',
        'rateLimited' => 'Rate limit exceeded',
        'serverError' => 'Internal server error',
    ];

    public function __call(string $name, array $arguments): void
    {
        if ($name === 'noContent') {
            $code = $arguments[0] ?? self::HTTP_OK;
            http_response_code(is_int($code) ? $code : self::HTTP_OK);
            return;
        }

        if (!isset(self::ERROR_STATUS_CODES[$name])) {
            throw new BadMethodCallException('Unknown API response method: ' . $name);
        }

        $message = $arguments[0] ?? self::DEFAULT_ERROR_MESSAGES[$name];
        $message = is_scalar($message) ? (string) $message : self::DEFAULT_ERROR_MESSAGES[$name];

        $this->error($message, self::ERROR_STATUS_CODES[$name]);
    }

    public function success(mixed $data, ?int $ttl = null): void
    {
        if ($ttl !== null && $ttl > 0) {
            // codacy:ignore - header() required for cache control in standalone API
            header('X-Cache: MISS');
            header('Cache-Control: private, max-age=' . (int) $ttl);
        }

        $this->sendJson($data);
    }

    public function cached(mixed $data, int $ttl): void
    {
        // codacy:ignore - header() required for cache headers in standalone API
        header('X-Cache: HIT');
        header('Cache-Control: private, max-age=' . (int) $ttl);

        $this->sendJson($data);
    }

    public function error(string $message, int $code = self::HTTP_INTERNAL_ERROR): void
    {
        http_response_code($code);
        header('Cache-Control: no-store');

        $this->sendJson(['error' => $message]);
    }

    public function methodNotAllowed(string|array $allowedMethod): void
    {
        $allowedMethods = is_array($allowedMethod) ? $allowedMethod : [$allowedMethod];
        $allowedMethods = array_values(array_unique(array_map('strtoupper', $allowedMethods)));
        $allowedMethods = array_values(array_filter(
            $allowedMethods,
            static fn (string $method): bool => preg_match('/^[A-Z]+$/', $method) === 1
        ));
        $allowHeader = implode(', ', $allowedMethods ?: ['GET']);

        header('Allow: ' . $allowHeader);
        $this->error('Method not allowed. Use ' . $allowHeader . '.', self::HTTP_METHOD_NOT_ALLOWED);
    }

    /**
     * @param array<string, string> $headers
     */
    public function json(mixed $data, int $code = self::HTTP_OK, array $headers = []): void
    {
        http_response_code($code);

        foreach ($headers as $name => $value) {
            // codacy:ignore - header() required for custom headers in standalone API
            header("{$name}: {$value}");
        }

        $this->sendJson($data);
    }

    private function sendJson(mixed $data): void
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
