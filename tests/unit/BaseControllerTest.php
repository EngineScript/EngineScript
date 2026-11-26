<?php

/**
 * Tests for the shared controller code: the response cache and the request body helpers.
 *
 * The cache lives in a temporary directory (BaseController::useCacheDirectory()); SystemController
 * stands in for any controller, and the protected methods are reached through reflection.
 */

declare(strict_types=1);

use EngineScript\Dashboard\API\Controllers\BaseController;
use EngineScript\Dashboard\API\Controllers\SystemController;

final class BaseControllerTest extends EsTestCase
{
    private string $cacheDirectory;

    protected function setUp(): void
    {
        parent::setUp();
        $this->cacheDirectory = $this->makeTemporaryDirectory();
        BaseController::useCacheDirectory($this->cacheDirectory);
    }

    protected function tearDown(): void
    {
        BaseController::useCacheDirectory(null);
        parent::tearDown();
    }

    /**
     * Call a protected BaseController method.
     */
    private function call(BaseController $controller, string $method, mixed ...$arguments): mixed
    {
        return (new ReflectionMethod(BaseController::class, $method))->invoke($controller, ...$arguments);
    }

    public function testRememberFetchesOnceAndThenAnswersFromTheCache(): void
    {
        $controller = $this->controller(SystemController::class);
        $fetches = 0;
        $fetch = static function () use (&$fetches): array {
            ++$fetches;
            return ['value' => $fetches];
        };

        $first = $this->call($controller, 'remember', 'uptime/monitors', $fetch);
        $second = $this->call($controller, 'remember', 'uptime/monitors', $fetch);

        $this->assertSame(['data' => ['value' => 1], 'hit' => false], $first);
        $this->assertSame(['data' => ['value' => 1], 'hit' => true], $second);
        $this->assertSame(1, $fetches);
        $this->assertFileExists($this->cacheDirectory . '/uptime_monitors.json', 'The key is reduced to a safe file name.');
    }

    public function testExpiredCorruptAndMalformedEntriesAreFetchedAgain(): void
    {
        $controller = $this->controller(SystemController::class);
        $file = $this->cacheDirectory . '/key.json';
        $entries = [
            'expired' => json_encode(['timestamp' => time() - 3600, 'data' => ['old' => true]]),
            'corrupt' => '{not json',
            'malformed' => json_encode(['timestamp' => 'now', 'data' => 'x']),
        ];

        foreach ($entries as $label => $entry) {
            file_put_contents($file, (string) $entry);

            $result = $this->call($controller, 'remember', 'key', static fn(): array => ['fresh' => $label]);

            $this->assertSame(['data' => ['fresh' => $label], 'hit' => false], $result, $label);
        }
    }

    public function testCachedAndFreshResponsesCarryTheData(): void
    {
        $controller = $this->controller(SystemController::class);

        $hit = $this->respond(fn() => $this->call($controller, 'respondCached', ['a' => 1], true));
        $miss = $this->respond(fn() => $this->call($controller, 'respondCached', ['a' => 2], false));

        $this->assertSame(['a' => 1], $hit['json']);
        $this->assertSame(['a' => 2], $miss['json']);
    }

    public function testJsonBodyIsDecodedOnceAndAnythingButAnObjectIsEmpty(): void
    {
        $bodies = [
            '{"name":"value"}' => ['name' => 'value'],
            '   ' => [],
            '{broken' => [],
            '"a string"' => [],
        ];

        foreach ($bodies as $body => $expected) {
            $controller = $this->controller(SystemController::class, esTestRequest([], [], [], $body));

            $this->assertSame($expected, $this->call($controller, 'getJsonBody'), $body);
            $this->assertSame($expected, $this->call($controller, 'getJsonBody'), 'The second read returns the same.');
        }
    }

    public function testValueHelpers(): void
    {
        $controller = $this->controller(SystemController::class);

        $this->assertSame([1], $this->call($controller, 'arrayOrNull', [1]));
        $this->assertNull($this->call($controller, 'arrayOrNull', 'x'));
        $this->assertSame('x', $this->call($controller, 'stringOrNull', 'x'));
        $this->assertNull($this->call($controller, 'stringOrNull', 1));
        $this->assertSame(['a', 'b', 'c'], $this->call($controller, 'whitespaceFields', "  a \t b\nc "));
    }
}
