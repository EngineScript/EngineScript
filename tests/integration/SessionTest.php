<?php

declare(strict_types=1);

/**
 * The session across requests: its cookie, the CSRF token, the rate limit, and
 * the refusal when PHP cannot store sessions.
 */
final class SessionTest extends IntegrationTestCase
{
    private const string SESSIONS = '/var/cache/php-sessions';

    public function testTheSessionCookieIsHostOnlySecureHttpOnlyAndStrict(): void
    {
        $cookie = $this->http('GET', '/api/system/info', cookies: false)['headers']['set-cookie'][0] ?? '';

        self::assertMatchesRegularExpression('/^__Host-esp_session=[A-Za-z0-9,-]+;/', $cookie);
        foreach (['secure', 'httponly', 'samesite=strict', 'path=/'] as $attribute) {
            self::assertMatchesRegularExpression('/;\s*' . preg_quote($attribute, '/') . '(;|$)/i', $cookie, $attribute);
        }
        self::assertStringNotContainsStringIgnoringCase('domain=', $cookie);
    }

    public function testTheTokenStaysTheSameWithinASessionAndDiffersBetweenSessions(): void
    {
        $first = $this->csrfToken();
        self::assertMatchesRegularExpression('/^[0-9a-f]{64}\z/', $first);
        self::assertSame($first, $this->csrfToken());

        $other = $this->http('GET', '/api/csrf-token', cookies: false)['json']['csrf_token'] ?? '';
        self::assertNotSame($first, $other);
    }

    public function testTheCacheClearNeedsThisSessionsToken(): void
    {
        $token = $this->csrfToken();

        self::assertSame(403, $this->http('POST', '/api/cache/clear?type=opcache')['status'], 'no token');
        self::assertSame(403, $this->http('POST', '/api/cache/clear?type=opcache', ['X-CSRF-Token' => str_repeat('0', 64)])['status'], 'wrong token');
        self::assertSame(403, $this->http('POST', '/api/cache/clear?type=opcache', ['X-CSRF-Token' => $token], cookies: false)['status'], 'another session');
        self::assertSame(200, $this->http('POST', '/api/cache/clear?type=opcache', ['X-CSRF-Token' => $token])['status'], 'header');
        self::assertSame(200, $this->http('POST', '/api/cache/clear?type=opcache', ['Content-Type' => 'application/x-www-form-urlencoded'], '_csrf_token=' . $token)['status'], 'form field');
        self::assertSame(200, $this->http('POST', '/api/cache/clear', ['Content-Type' => 'application/json'], json_encode(['_csrf_token' => $token, 'types' => ['opcache']]) ?: '')['status'], 'JSON body');
    }

    public function testATokenFailureIsLoggedWithTheUser(): void
    {
        $lines = $this->logWhile(fn() => $this->http('POST', '/api/cache/clear?type=opcache'));

        self::assertCount(1, $lines);
        self::assertStringContainsString('[SECURITY] CSRF token missing - POST request without token - User: ' . self::$user . ' - IP: 127.0.0.1', $lines[0]);
        self::assertStringNotContainsString(self::$password, $lines[0]);
    }

    public function testAPostToAReadRouteNeedsTheTokenThenGets405(): void
    {
        self::assertSame(403, $this->http('POST', '/api/system/info')['status']);

        $result = $this->http('POST', '/api/system/info', ['X-CSRF-Token' => $this->csrfToken()]);
        self::assertSame(405, $result['status']);
        self::assertSame(['GET, HEAD'], $result['headers']['allow'] ?? []);
    }

    public function testTheRateLimitCountsAHundredRequestsAMinutePerSession(): void
    {
        $statuses = [];
        for ($i = 0; $i < 103; $i++) {
            $statuses[] = $this->http('GET', '/api/tools/status')['status'];
        }

        self::assertSame(array_fill(0, 100, 200), array_slice($statuses, 0, 100));
        self::assertSame([429, 429, 429], array_slice($statuses, 100));
        self::assertSame(['error' => 'Rate limit exceeded'], $this->http('GET', '/api/tools/status')['json']);
        self::assertSame(200, $this->http('GET', '/api/tools/status', cookies: false)['status'], 'a new session has its own count (CR-SEC-002, deferred)');
    }

    public function testWithoutSessionStorageEveryRequestGets503(): void
    {
        $mode = fileperms(self::SESSIONS) & 0777;
        chmod(self::SESSIONS, 0);
        try {
            $lines = $this->logWhile(function (): void {
                foreach (['GET /api/system/info', 'GET /api/csrf-token', 'POST /api/cache/clear?type=opcache'] as $request) {
                    [$method, $path] = explode(' ', $request);
                    $result = $this->http($method, $path, cookies: false);
                    self::assertSame(503, $result['status'], $request);
                    self::assertSame(['error' => 'Session storage unavailable'], $result['json'], $request);
                }
            });
        } finally {
            chmod(self::SESSIONS, $mode);
        }

        self::assertCount(3, array_filter($lines, static fn(string $line): bool => str_contains($line, 'Session start failed')));
        self::assertSame(200, $this->http('GET', '/api/system/info', cookies: false)['status']);
    }
}
