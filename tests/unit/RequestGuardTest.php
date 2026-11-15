<?php

declare(strict_types=1);

use EngineScript\Dashboard\Classes\RequestGuard;
use EngineScript\Dashboard\Classes\Session;

final class RequestGuardTest extends EsTestCase
{
    private const string TOKEN = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'; // gitleaks:allow (a test value)

    public function testAFreshRateLimitWindowStartsAtZeroAndLastsAMinute(): void
    {
        $before = time();
        $state = RequestGuard::rateLimitState(null);

        self::assertSame(0, $state['count']);
        self::assertIsInt($state['reset']);
        self::assertGreaterThanOrEqual($before + 60, $state['reset']);
        self::assertLessThanOrEqual(time() + 60, $state['reset']);
        self::assertSame(['count' => 0, 'reset' => $state['reset']], RequestGuard::rateLimitState('corrupt'));
    }

    public function testAStoredWindowIsKept(): void
    {
        $stored = ['count' => 42, 'reset' => 1_900_000_000];

        self::assertSame($stored, RequestGuard::rateLimitState($stored));
    }

    public function testTheCountRisesByOneAndRestartsWhenUnreadable(): void
    {
        self::assertSame(1, RequestGuard::nextRateLimitCount(['count' => 0]));
        self::assertSame(100, RequestGuard::nextRateLimitCount(['count' => 99]));
        self::assertSame(1, RequestGuard::nextRateLimitCount(['count' => '99']));
        self::assertSame(1, RequestGuard::nextRateLimitCount([]));
    }

    public function testOnlyGetHeadAndOptionsSkipTheToken(): void
    {
        foreach (['GET', 'HEAD', 'OPTIONS'] as $method) {
            self::assertTrue(RequestGuard::isCsrfSafeMethod($method), $method);
        }

        foreach (['POST', 'PUT', 'PATCH', 'DELETE', 'PURGE', 'get'] as $method) {
            self::assertFalse(RequestGuard::isCsrfSafeMethod($method), $method);
        }
    }

    public function testASafeMethodPassesWithoutAToken(): void
    {
        $_SESSION['csrf_token'] = self::TOKEN;

        self::assertTrue(RequestGuard::validateCsrfToken(es_test_request(), new Session(), $this->logger()));
        self::assertSame([], $this->logLines());
    }

    public function testTheHeaderTokenIsAccepted(): void
    {
        $_SESSION['csrf_token'] = self::TOKEN;
        $request = es_test_request(['REQUEST_METHOD' => 'POST', 'HTTP_X_CSRF_TOKEN' => self::TOKEN]);

        self::assertTrue(RequestGuard::validateCsrfToken($request, new Session(), $this->logger($request)));
    }

    public function testTheFormFieldTokenIsAccepted(): void
    {
        $_SESSION['csrf_token'] = self::TOKEN;
        $request = es_test_request(['REQUEST_METHOD' => 'POST'], [], ['_csrf_token' => self::TOKEN]);

        self::assertTrue(RequestGuard::validateCsrfToken($request, new Session(), $this->logger($request)));
    }

    public function testTheJsonBodyTokenIsAcceptedOnlyForAJsonContentType(): void
    {
        $_SESSION['csrf_token'] = self::TOKEN;
        $body = json_encode(['_csrf_token' => self::TOKEN, 'types' => ['redis']], JSON_THROW_ON_ERROR);
        $json = es_test_request(['REQUEST_METHOD' => 'POST', 'CONTENT_TYPE' => 'application/json; charset=utf-8'], [], [], $body);
        $plain = es_test_request(['REQUEST_METHOD' => 'POST', 'CONTENT_TYPE' => 'text/plain'], [], [], $body);

        self::assertTrue(RequestGuard::validateCsrfToken($json, new Session(), $this->logger($json)));
        self::assertFalse(RequestGuard::validateCsrfToken($plain, new Session(), $this->logger($plain)));
    }

    public function testTheHeaderWinsOverTheFormField(): void
    {
        $request = es_test_request(['REQUEST_METHOD' => 'POST', 'HTTP_X_CSRF_TOKEN' => 'from-header'], [], ['_csrf_token' => 'from-form']);

        self::assertSame('from-header', RequestGuard::csrfTokenFromRequest($request, $this->logger($request)));
    }

    public function testAMissingTokenIsRefusedAndLogged(): void
    {
        $_SESSION['csrf_token'] = self::TOKEN;
        $request = es_test_request(['REQUEST_METHOD' => 'POST']);

        self::assertFalse(RequestGuard::validateCsrfToken($request, new Session(), $this->logger($request)));
        self::assertCount(1, $this->logLines());
        self::assertStringContainsString('[SECURITY] CSRF token missing - POST request without token', $this->logLines()[0]);
    }

    public function testAWrongTokenIsRefusedAndLogged(): void
    {
        $_SESSION['csrf_token'] = self::TOKEN;
        $request = es_test_request(['REQUEST_METHOD' => 'POST', 'HTTP_X_CSRF_TOKEN' => strrev(self::TOKEN)]);

        self::assertFalse(RequestGuard::validateCsrfToken($request, new Session(), $this->logger($request)));
        self::assertStringContainsString('CSRF token mismatch', $this->logLines()[0]);
    }

    public function testATokenWithSurroundingWhitespaceIsRefused(): void
    {
        $_SESSION['csrf_token'] = self::TOKEN;

        foreach ([self::TOKEN . "\n", ' ' . self::TOKEN, self::TOKEN . "\x00"] as $sent) {
            $request = es_test_request(['REQUEST_METHOD' => 'POST'], [], ['_csrf_token' => $sent]);
            self::assertFalse(RequestGuard::validateCsrfToken($request, new Session(), $this->logger($request)), json_encode($sent) ?: '');
        }
    }

    public function testNoTokenInTheSessionRefusesEveryToken(): void
    {
        foreach ([null, '', 42] as $stored) {
            $_SESSION = $stored === null ? [] : ['csrf_token' => $stored];
            $request = es_test_request(['REQUEST_METHOD' => 'POST', 'HTTP_X_CSRF_TOKEN' => self::TOKEN]);
            self::assertFalse(RequestGuard::validateCsrfToken($request, new Session(), $this->logger($request)));
        }
    }

    public function testEmptyAndZeroTokensCountAsMissing(): void
    {
        foreach ([null, '', '0'] as $sent) {
            self::assertFalse(RequestGuard::csrfTokenIsValid('POST', $sent, '0', $this->logger()), var_export($sent, true));
        }
    }

    public function testInvalidJsonIsRefusedAndLogged(): void
    {
        $request = es_test_request(['REQUEST_METHOD' => 'POST', 'CONTENT_TYPE' => 'application/json'], [], [], '{"_csrf_token":');

        self::assertFalse(RequestGuard::csrfTokenFromRequest($request, $this->logger($request)));
        self::assertStringContainsString('CSRF token JSON parse failed - Invalid JSON body', $this->logLines()[0]);
    }

    public function testAJsonBodyWithoutAStringTokenHasNone(): void
    {
        self::assertNull(RequestGuard::csrfTokenFromDecodedBody(['_csrf_token' => 123]));
        self::assertNull(RequestGuard::csrfTokenFromDecodedBody('token'));
        self::assertNull(RequestGuard::csrfTokenFromDecodedBody([]));
        self::assertSame('t', RequestGuard::csrfTokenFromDecodedBody(['_csrf_token' => 't']));

        $blank = es_test_request(['REQUEST_METHOD' => 'POST', 'CONTENT_TYPE' => 'application/json'], [], [], "  \n");
        self::assertNull(RequestGuard::csrfTokenFromJsonBody($blank, $this->logger($blank)));
    }
}
