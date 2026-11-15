<?php

/**
 * EngineScript Admin Dashboard - Request Guard
 *
 * The checks api.php runs on every request before routing: the rate-limit
 * count and the CSRF token.
 *
 * @package EngineScript\Dashboard\Classes
 */

declare(strict_types=1);

namespace EngineScript\Dashboard\Classes;

final class RequestGuard
{
    /**
     * The stored rate-limit state, or a fresh window when nothing usable is stored.
     *
     * @return array<mixed>
     */
    public static function rateLimitState(mixed $stored): array
    {
        return is_array($stored) ? $stored : ['count' => 0, 'reset' => time() + 60];
    }

    /**
     * The request count after this request.
     *
     * @param array<mixed> $rateLimit
     */
    public static function nextRateLimitCount(array $rateLimit): int
    {
        return isset($rateLimit['count']) && is_int($rateLimit['count']) ? $rateLimit['count'] + 1 : 1;
    }

    /**
     * Validates the CSRF token for every method but GET, HEAD, and OPTIONS.
     * The token can be sent in the X-CSRF-Token header or a _csrf_token form or JSON field.
     *
     * @return bool True if valid or not required (GET/HEAD/OPTIONS), false if invalid
     */
    public static function validateCsrfToken(Request $request, Session $session, SecurityLogger $securityLogger): bool
    {
        $method = $request->method();

        if (self::isCsrfSafeMethod($method)) {
            return true;
        }

        $clientToken = self::csrfTokenFromRequest($request, $securityLogger);
        if ($clientToken === false) {
            return false;
        }

        return self::csrfTokenIsValid($method, $clientToken, $session->get('csrf_token'), $securityLogger);
    }

    public static function isCsrfSafeMethod(string $method): bool
    {
        return in_array($method, ['GET', 'HEAD', 'OPTIONS'], true);
    }

    public static function csrfTokenFromRequest(Request $request, SecurityLogger $securityLogger): string|false|null
    {
        $headerToken = $request->header('X-CSRF-Token');
        if ($headerToken !== null) {
            return $headerToken;
        }

        $postToken = $request->post('_csrf_token');
        if ($postToken !== null) {
            return $postToken;
        }

        if (!str_contains(strtolower($request->header('Content-Type') ?? ''), 'application/json')) {
            return null;
        }

        return self::csrfTokenFromJsonBody($request, $securityLogger);
    }

    public static function csrfTokenFromJsonBody(Request $request, SecurityLogger $securityLogger): string|false|null
    {
        $input = $request->body();
        if (trim($input) === '') {
            return null;
        }

        try {
            return self::csrfTokenFromDecodedBody(json_decode($input, true, 512, JSON_THROW_ON_ERROR));
        } catch (\JsonException) {
            $securityLogger->write('CSRF token JSON parse failed', 'Invalid JSON body');
            return false;
        }
    }

    public static function csrfTokenFromDecodedBody(mixed $body): ?string
    {
        if (!is_array($body) || !isset($body['_csrf_token']) || !is_string($body['_csrf_token'])) {
            return null;
        }

        return $body['_csrf_token'];
    }

    public static function csrfTokenIsValid(
        string $method,
        ?string $clientToken,
        mixed $sessionToken,
        SecurityLogger $securityLogger
    ): bool {
        if (in_array($clientToken, [null, '', '0'], true) || !is_string($sessionToken) || $sessionToken === '') {
            $securityLogger->write('CSRF token missing', $method . ' request without token');
            return false;
        }

        if (!hash_equals($sessionToken, $clientToken)) {
            $securityLogger->write('CSRF token mismatch', 'Invalid token submitted');
            return false;
        }

        return true;
    }
}
