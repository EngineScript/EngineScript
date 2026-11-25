<?php

declare(strict_types=1);

use EngineScript\Dashboard\API\Controllers\CacheController;

/**
 * The FastCGI cache's directory checks (is_dir on /var/cache/nginx) and OPcache's
 * state in the running PHP depend on the machine; the integration suite runs them
 * on a server. Here they are only checked for their shape.
 */
final class CacheControllerTest extends EsTestCase
{
    /**
     * @param array<string, mixed> $query
     * @return array{status: int, json: mixed, body: string}
     */
    private function clear(array $query = [], string $body = ''): array
    {
        $server = ['REQUEST_METHOD' => 'POST'] + ($body === '' ? [] : ['CONTENT_TYPE' => 'application/json']);
        $request = esTestRequest($server, $query, [], $body);

        return $this->respond(fn() => $this->controller(CacheController::class, $request)->clear());
    }

    public function testRedisIsFlushedAndTheClearIsLogged(): void
    {
        $this->runner->answers = ['redis-cli FLUSHALL' => 'OK'];
        $result = $this->clear(['type' => 'redis']);

        self::assertSame(200, $result['status']);
        self::assertSame(
            ['success' => true, 'cleared' => ['redis'], 'results' => ['redis' => ['success' => true, 'message' => 'Redis cache cleared successfully']]],
            $result['json']
        );
        self::assertStringContainsString('Cache cleared - Redis cache flushed successfully', $this->logLines()[0]);
    }

    public function testAFailedFlushIsReportedAndNotLogged(): void
    {
        foreach ([false, 'ERR unknown command', ''] as $output) {
            $this->runner->answers = ['redis-cli FLUSHALL' => $output];
            $result = $this->clear(['type' => 'redis']);
            self::assertFalse($result['json']['success'], var_export($output, true));
            self::assertSame(['success' => false, 'message' => 'Failed to clear Redis cache'], $result['json']['results']['redis']);
        }

        self::assertSame([], $this->logLines());
    }

    public function testTypesComeFromTheJsonBodyWhenTheQueryHasNone(): void
    {
        $this->runner->answers = ['redis-cli FLUSHALL' => 'OK'];

        self::assertSame(['redis'], $this->clear([], '{"types":["redis", 7, "REDIS"]}')['json']['cleared']);
        self::assertSame(['redis'], $this->clear([], '{"type":" Redis ,"}')['json']['cleared']);
        self::assertSame(['redis'], $this->clear([], '{"types":["redis"],"type":"opcache"}')['json']['cleared'], 'types wins');
    }

    public function testNamesIgnoreCaseAndSurroundingSpacesAndRepeats(): void
    {
        $this->runner->answers = ['redis-cli FLUSHALL' => 'OK'];

        self::assertSame(['redis'], $this->clear(['type' => " REDIS ,redis\n"])['json']['cleared']);
    }

    public function testUnknownTypesAreIgnoredWithAWarning(): void
    {
        $this->runner->answers = ['redis-cli FLUSHALL' => 'OK'];
        $result = $this->clear(['type' => 'redis,Foo,../x,foo']);

        self::assertSame(['redis'], $result['json']['cleared']);
        self::assertSame(
            ['invalid_types' => ['foo', '../x'], 'message' => 'Some requested cache types were invalid and ignored'],
            $result['json']['warnings']
        );
    }

    public function testNoTypeIsABadRequest(): void
    {
        $required = ['error' => 'Cache type required. Valid types: redis, fastcgi, opcache'];
        $noneValid = ['error' => 'No valid cache types provided. Valid types: redis, fastcgi, opcache'];
        $cases = [
            [[], '', $required],
            [['type' => ''], '', $required],
            [[], '{"types":[]}', $required],
            [['type' => ' , '], '', $noneValid],
        ];

        foreach ($cases as [$query, $body, $expected]) {
            $result = $this->clear($query, $body);
            self::assertSame(400, $result['status'], json_encode([$query, $body]) ?: '');
            self::assertSame($expected, $result['json'], json_encode([$query, $body]) ?: '');
        }
    }

    public function testOnlyUnknownTypesIsABadRequest(): void
    {
        $result = $this->clear(['type' => 'all,memcached']);

        self::assertSame(400, $result['status']);
        self::assertSame(['error' => 'No valid cache types provided. Valid types: redis, fastcgi, opcache'], $result['json']);
        self::assertSame([], $this->runner->calls, 'nothing was run');
    }

    public function testOpcacheReportsAResultEitherWay(): void
    {
        $result = $this->clear(['type' => 'opcache']);

        self::assertIsBool($result['json']['results']['opcache']['success']);
        self::assertContains($result['json']['results']['opcache']['message'], [
            'OPcache cleared successfully', 'Failed to reset OPcache', 'OPcache extension not available',
        ]);
    }

    public function testStatusReadsRedisMemory(): void
    {
        $this->runner->answers = ['redis-cli INFO memory' => "# Memory\r\nused_memory:1031336\r\nused_memory_human:1007.16K\r\nused_memory_rss:9000\r\n"];
        $result = $this->respond(fn() => $this->controller(CacheController::class)->getStatus());

        self::assertSame(200, $result['status']);
        self::assertSame(['available' => true, 'used_memory' => 1031336, 'used_memory_human' => '1007.16K'], $result['json']['redis']);
        self::assertIsBool($result['json']['fastcgi']['available']);
        self::assertIsBool($result['json']['opcache']['available']);
    }

    public function testRedisStatusWithoutRedisOrWithoutFigures(): void
    {
        $result = $this->respond(fn() => $this->controller(CacheController::class)->getStatus());
        self::assertSame(['available' => false, 'reason' => 'Unable to connect to Redis'], $result['json']['redis']);

        $this->runner->answers = ['redis-cli INFO memory' => '# Memory'];
        $result = $this->respond(fn() => $this->controller(CacheController::class)->getStatus());
        self::assertSame(['available' => true, 'used_memory' => null, 'used_memory_human' => null], $result['json']['redis']);
    }
}
