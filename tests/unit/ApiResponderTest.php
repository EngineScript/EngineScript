<?php

declare(strict_types=1);

final class ApiResponderTest extends EsTestCase
{
    public function testSuccessSendsTheDataAsJsonWithStatus200(): void
    {
        $result = $this->respond(static fn() => (new ApiResponder())->success(['enabled' => true, 'up' => 3]));

        self::assertSame(200, $result['status']);
        self::assertSame('{"enabled":true,"up":3}', $result['body']);
    }

    public function testStringsAreSentAsTheyAreNotEscaped(): void
    {
        $result = $this->respond(static fn() => (new ApiResponder())->success(['name' => "Pete's Shop & Café </script>", 'url' => 'https://a.test/x']));

        self::assertSame("Pete's Shop & Café </script>", $result['json']['name']);
        self::assertStringContainsString('https://a.test/x', $result['body'], 'slashes are not escaped');
    }

    public function testInvalidUtf8BecomesTheReplacementCharacter(): void
    {
        $result = $this->respond(static fn() => (new ApiResponder())->success(['name' => "bad \xC3\x28 byte"]));

        self::assertSame("bad \u{FFFD}( byte", $result['json']['name']);
    }

    /**
     * @return iterable<string, array{string, int, string}>
     */
    public static function errors(): iterable
    {
        yield 'bad request' => ['badRequest', 400, 'Bad request'];
        yield 'forbidden' => ['forbidden', 403, 'Forbidden'];
        yield 'not found' => ['notFound', 404, 'Not found'];
        yield 'rate limited' => ['rateLimited', 429, 'Rate limit exceeded'];
        yield 'server error' => ['serverError', 500, 'Internal server error'];
    }

    #[\PHPUnit\Framework\Attributes\DataProvider('errors')]
    public function testEachErrorHasItsStatusAndDefaultMessage(string $method, int $status, string $message): void
    {
        $result = $this->respond(static fn() => (new ApiResponder())->{$method}());

        self::assertSame($status, $result['status']);
        self::assertSame(['error' => $message], $result['json']);
    }

    public function testAnErrorCarriesTheGivenMessageAndCode(): void
    {
        $result = $this->respond(static fn() => (new ApiResponder())->error('Session storage unavailable', 503));

        self::assertSame(503, $result['status']);
        self::assertSame(['error' => 'Session storage unavailable'], $result['json']);
    }

    public function testMethodNotAllowedNamesTheAllowedMethods(): void
    {
        $result = $this->respond(static fn() => (new ApiResponder())->methodNotAllowed(['get', 'HEAD', 'GET']));

        self::assertSame(405, $result['status']);
        self::assertSame(['error' => 'Method not allowed. Use GET, HEAD.'], $result['json']);
    }

    public function testMethodNotAllowedDropsMalformedNamesAndFallsBackToGet(): void
    {
        $result = $this->respond(static fn() => (new ApiResponder())->methodNotAllowed(['P0ST', "POST\n"]));

        self::assertSame(['error' => 'Method not allowed. Use GET.'], $result['json']);
    }

    public function testCachedAndSuccessSendTheSameBody(): void
    {
        $cached = $this->respond(static fn() => (new ApiResponder())->cached(['a' => 1], 60));
        $fresh = $this->respond(static fn() => (new ApiResponder())->success(['a' => 1], 60));

        self::assertSame($fresh['body'], $cached['body']);
        self::assertSame(200, $cached['status']);
    }
}
