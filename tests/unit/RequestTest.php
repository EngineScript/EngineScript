<?php

declare(strict_types=1);

use EngineScript\Dashboard\Classes\Request;

final class RequestTest extends EsTestCase
{
    public function testQueryAndFormValuesArePassedOnAsSent(): void
    {
        $request = esTestRequest([], ['endpoint' => " tools/status\n", 'blank' => ''], ['_csrf_token' => "abc\x00"]);

        self::assertSame(" tools/status\n", $request->query('endpoint'));
        self::assertSame("abc\x00", $request->post('_csrf_token'));
        self::assertNull($request->query('blank'), 'an empty value counts as absent');
        self::assertNull($request->query('missing'));
    }

    public function testNonScalarInputIsRefused(): void
    {
        $request = esTestRequest([], ['endpoint' => ['system', 'info']], ['_csrf_token' => ['x']]);

        self::assertNull($request->query('endpoint'));
        self::assertNull($request->post('_csrf_token'));
    }

    public function testScalarInputBecomesAString(): void
    {
        self::assertSame('7', esTestRequest([], ['n' => 7])->query('n'));
    }

    public function testMethodIsUpperCasedAndAnythingOddBecomesGet(): void
    {
        self::assertSame('POST', esTestRequest(['REQUEST_METHOD' => 'post'])->method());
        self::assertSame('PATCH', esTestRequest(['REQUEST_METHOD' => 'PATCH'])->method());
        self::assertSame('GET', esTestRequest(['REQUEST_METHOD' => "POST\n"])->method());
        self::assertSame('GET', esTestRequest(['REQUEST_METHOD' => 'M-SEARCH'])->method());
        self::assertSame('GET', (new Request([], [], []))->method(), 'no method at all');
    }

    public function testHeadersAreReadFromTheirServerKeys(): void
    {
        $request = esTestRequest([
            'HTTP_X_CSRF_TOKEN' => 'token',
            'CONTENT_TYPE' => 'application/json',
            'HTTP_X_EMPTY' => '',
        ]);

        self::assertSame('token', $request->header('X-CSRF-Token'));
        self::assertSame('token', $request->header('x-csrf-token'));
        self::assertSame('application/json', $request->header('Content-Type'), 'CONTENT_TYPE has no HTTP_ prefix');
        self::assertNull($request->header('X-Empty'));
        self::assertNull($request->header('X-Missing'));
    }

    public function testRemoteAddressMustBeAnIpAddress(): void
    {
        self::assertSame('203.0.113.7', esTestRequest()->remoteAddress());
        self::assertSame('2001:db8::1', esTestRequest(['REMOTE_ADDR' => '2001:db8::1'])->remoteAddress());
        self::assertSame('invalid', esTestRequest(['REMOTE_ADDR' => '203.0.113.7, 10.0.0.1'])->remoteAddress());
        self::assertSame('unknown', (new Request([], [], []))->remoteAddress());
    }

    public function testAuthenticatedUserComesFromBasicAuthentication(): void
    {
        self::assertSame('admin', esTestRequest()->authenticatedUser);
        self::assertSame('unknown', (new Request([], [], []))->authenticatedUser);
    }

    public function testBodyAndUriAreReturnedAsGiven(): void
    {
        $request = esTestRequest(['REQUEST_URI' => '/api/cache/clear?type=redis'], [], [], '{"types":["redis"]}');

        self::assertSame('{"types":["redis"]}', $request->body());
        self::assertSame('/api/cache/clear?type=redis', $request->uri());
        self::assertTrue($request->hasServer('HTTP_HOST'));
        self::assertFalse($request->hasServer('HTTP_ORIGIN'));
    }
}
