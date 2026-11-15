<?php

declare(strict_types=1);

/**
 * Basic authentication, the routes nginx sends to PHP, and the headers on every
 * response, through the real admin vhost.
 */
final class AccessTest extends IntegrationTestCase
{
    private const array LOCATIONS = ['/', '/api/system/info', '/api.php?endpoint=system/info', '/phpmyadmin/', '/tinyfilemanager/tinyfilemanager.php', '/phpsysinfo/', '/phpinfo/', '/adminer/'];

    public function testEveryLocationAsksForBasicAuthentication(): void
    {
        foreach (self::LOCATIONS as $path) {
            $result = $this->http('GET', $path, auth: false);
            self::assertSame(401, $result['status'], $path);
            self::assertStringStartsWith('Basic realm=', $result['headers']['www-authenticate'][0] ?? '', $path);
        }
    }

    public function testAWrongPasswordIsRefusedEverywhere(): void
    {
        foreach (self::LOCATIONS as $path) {
            self::assertSame(401, $this->http('GET', $path, auth: self::$user . ':wrong-' . bin2hex(random_bytes(4)))['status'], $path);
        }
    }

    public function testTheDashboardAndTheApiAnswerTheAdmin(): void
    {
        $page = $this->http('GET', '/');
        self::assertSame(200, $page['status']);
        self::assertStringContainsString('http-equiv="Content-Security-Policy"', $page['body']);
        self::assertStringNotContainsString('{ES_DASHBOARD_VER}', $page['body'], 'the installer substituted the version');
        // The installer substitutes the stylesheet's URL; the comment that explains the placeholder keeps it.
        $version = self::shell('source /usr/local/bin/enginescript/enginescript-variables.txt && printf %s "${FONTAWESOME_VER}"');
        self::assertStringNotContainsString('font-awesome/{FONTAWESOME_VER}/', $page['body']);
        self::assertStringContainsString("https://cdnjs.cloudflare.com/ajax/libs/font-awesome/{$version}/css/all.min.css", $page['body']);

        self::assertSame(200, $this->http('GET', '/api/system/info')['status']);
    }

    public function testBothApiSpellingsReachTheSameEndpoint(): void
    {
        $rewritten = $this->http('GET', '/api/tools/status');
        $direct = $this->http('GET', '/api.php?endpoint=tools/status');

        self::assertSame(200, $rewritten['status']);
        self::assertSame($rewritten['json'], $direct['json']);
    }

    public function testNoOtherPhpFileRunsOrShowsItsSource(): void
    {
        foreach (['/classes/Router.php', '/controllers/CacheController.php', '/classes/RequestGuard.php', '/index.php', '/no-such.php', '/api.php/../classes/Router.php'] as $path) {
            $result = $this->http('GET', $path);
            self::assertSame(404, $result['status'], $path);
            self::assertStringNotContainsString('<?php', $result['body'], $path);
        }
    }

    public function testTheRemovedServicesRewriteIsGone(): void
    {
        self::assertSame(404, $this->http('GET', '/services/status')['status']);
    }

    public function testAnEndpointWithALineBreakOrNulIsRefused(): void
    {
        foreach (['tools/status%0a', 'tools/status%0d%0a', '%0atools/status', 'tools/status%00', 'tools/status.php'] as $endpoint) {
            $result = $this->http('GET', '/api.php?endpoint=' . $endpoint);
            self::assertSame(400, $result['status'], $endpoint);
            self::assertSame(['error' => 'Invalid path'], $result['json'], $endpoint);
        }

        self::assertSame(400, $this->http('GET', '/api.php?endpoint=' . str_repeat('a', 101))['status']);
    }

    public function testApiResponsesCarryTheirHeadersOnce(): void
    {
        foreach (['/api/system/info', '/api/no/such/route', '/api.php?endpoint=bad.path'] as $path) {
            $headers = $this->http('GET', $path)['headers'];
            self::assertSame(['no-store'], $headers['cache-control'] ?? [], $path);
            self::assertSame(["default-src 'none'; frame-ancestors 'none';"], $headers['content-security-policy'] ?? [], $path);
            self::assertSame(['application/json; charset=UTF-8'], $headers['content-type'] ?? [], $path);
            self::assertSame(['nosniff'], $headers['x-content-type-options'] ?? [], $path);
            self::assertSame(['DENY'], $headers['x-frame-options'] ?? [], $path);
            self::assertSame(['strict-origin-when-cross-origin'], $headers['referrer-policy'] ?? [], $path);
        }
    }

    public function testNoCrossOriginAccessIsGranted(): void
    {
        $plain = $this->http('GET', '/api/system/info', ['Origin' => 'https://evil.example']);
        $preflight = $this->http('OPTIONS', '/api/cache/clear', ['Origin' => 'https://evil.example', 'Access-Control-Request-Method' => 'POST']);

        foreach ([$plain, $preflight] as $result) {
            self::assertSame([], array_filter(array_keys($result['headers']), static fn(string $name): bool => str_starts_with($name, 'access-control-')));
        }
        self::assertSame(405, $preflight['status']);
    }

    public function testHeadAnswersWithoutABody(): void
    {
        $result = $this->http('HEAD', '/api/system/info');

        self::assertSame(200, $result['status']);
        self::assertSame('', $result['body']);
    }
}
