<?php

declare(strict_types=1);

use EngineScript\Dashboard\API\Controllers\UptimeController;
use EngineScript\Dashboard\Classes\UptimeRobotAPI;

/**
 * UptimeRobotAPI against a local stand-in for UptimeRobot's API v3 (real HTTP,
 * recorded response shapes), and UptimeController's status mapping. The
 * controller reads its key from /etc/enginescript/uptimerobot.conf and caches in
 * /var/cache/enginescript/api; the integration suite runs that part.
 */
final class UptimeTest extends EsTestCase
{
    /** @var resource|null */
    private static $server = null;

    private static string $baseUrl = '';

    private static string $requestLog = '';

    public static function setUpBeforeClass(): void
    {
        parent::setUpBeforeClass();
        self::$requestLog = tempnam(sys_get_temp_dir(), 'es-stand-in-') ?: '';
        $router = __DIR__ . '/fixtures/uptimerobot-stand-in.php';

        for ($attempt = 0; $attempt < 5 && self::$server === null; $attempt++) {
            $port = random_int(20000, 45000);
            $process = proc_open(
                [PHP_BINARY, '-S', "127.0.0.1:{$port}", $router],
                [0 => ['pipe', 'r'], 1 => ['file', self::$requestLog . '.out', 'w'], 2 => ['file', self::$requestLog . '.err', 'w']],
                $pipes,
                null,
                ['ES_STAND_IN_LOG' => self::$requestLog] + getenv()
            );
            if (!is_resource($process)) {
                continue;
            }

            for ($wait = 0; $wait < 50; $wait++) {
                $socket = @fsockopen('127.0.0.1', $port, $errno, $errstr, 0.1);
                if (is_resource($socket)) {
                    fclose($socket);
                    self::$server = $process;
                    self::$baseUrl = "http://127.0.0.1:{$port}/v3";
                    break;
                }
                usleep(100_000);
            }

            if (self::$server === null) {
                proc_terminate($process);
                proc_close($process);
            }
        }

        if (self::$server === null) {
            self::fail('Setup: the UptimeRobot stand-in server did not start.');
        }
    }

    public static function tearDownAfterClass(): void
    {
        if (self::$server !== null) {
            proc_terminate(self::$server);
            proc_close(self::$server);
            self::$server = null;
        }

        foreach ([self::$requestLog, self::$requestLog . '.out', self::$requestLog . '.err'] as $file) {
            if (is_file($file)) {
                unlink($file);
            }
        }

        parent::tearDownAfterClass();
    }

    protected function setUp(): void
    {
        parent::setUp();
        file_put_contents(self::$requestLog, '');
    }

    private function api(string $scenario): UptimeRobotAPI
    {
        return new UptimeRobotAPI($scenario, self::$baseUrl, $this->logFile);
    }

    /**
     * @return list<array{method: string, uri: string, auth: string, accept: string}>
     */
    private function requests(): array
    {
        $lines = file(self::$requestLog, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [];

        return array_map(static fn(string $line): array => json_decode($line, true, 512, JSON_THROW_ON_ERROR), $lines);
    }

    public function testMonitorsKeepOnlyTheFieldsTheDashboardShows(): void
    {
        $monitors = $this->api('two-pages')->getMonitors();

        self::assertIsArray($monitors);
        self::assertSame(
            ['id' => 1, 'friendlyName' => 'Site 1 <b>&</b>', 'url' => 'https://site1.example', 'status' => 'UP', 'lastDayUptime' => 99.99],
            $monitors[0]
        );
        $encoded = json_encode($monitors, JSON_THROW_ON_ERROR);
        foreach (['monitor-secret-key', 'basic-user', 'basic-password', 'header-secret', 'apiKey', 'interval', 'lastDayUptimes'] as $secret) {
            self::assertStringNotContainsString($secret, $encoded);
        }
    }

    public function testEveryPageIsReadAndEntriesWithoutANumericIdAreDropped(): void
    {
        $monitors = $this->api('two-pages')->getMonitors();

        self::assertSame([1, 2, 3], array_column($monitors ?: [], 'id'));
    }

    public function testTheNextPageGoesToTheBaseUrlWhateverTheLinkNames(): void
    {
        $this->api('two-pages')->getMonitors();
        $uris = array_column($this->requests(), 'uri');

        self::assertSame('/v3/monitors?limit=200', $uris[0]);
        self::assertSame('/v3/monitors?limit=200&cursor=200', $uris[1]);
    }

    public function testEveryRequestCarriesTheKeyAsABearerTokenAndAsksForJson(): void
    {
        $this->api('two-pages')->getMonitors();

        foreach ($this->requests() as $request) {
            self::assertSame('GET', $request['method']);
            self::assertSame('Bearer two-pages', $request['auth']);
            self::assertSame('application/json', $request['accept']);
        }
    }

    public function testUptimeIsReadPerMonitorAndRoundedAndAFailedReadLeavesNull(): void
    {
        $monitors = $this->api('two-pages')->getMonitors() ?: [];

        self::assertSame([99.99, 100.0, null], array_column($monitors, 'lastDayUptime'));
        self::assertContains('/v3/monitors/3/stats/uptime', array_column($this->requests(), 'uri'));
        self::assertNotContains('/v3/monitors/x/stats/uptime', array_column($this->requests(), 'uri'));
    }

    public function testAboveEightMonitorsNoUptimeIsRead(): void
    {
        $monitors = $this->api('nine')->getMonitors() ?: [];

        self::assertCount(9, $monitors);
        self::assertSame(array_fill(0, 9, null), array_column($monitors, 'lastDayUptime'));
        self::assertCount(1, $this->requests(), 'only the list');
    }

    public function testARateLimitedUptimeReadStopsTheReads(): void
    {
        $api = $this->api('stats-429');
        $monitors = $api->getMonitors() ?: [];

        self::assertSame([null, null], array_column($monitors, 'lastDayUptime'));
        self::assertCount(2, $this->requests(), 'the list and one uptime read');
        self::assertTrue($api->wasRateLimited());
    }

    public function testMoreThanFivePagesIsAFailure(): void
    {
        self::assertFalse($this->api('endless')->getMonitors());
        self::assertCount(5, $this->requests());
        self::assertStringContainsString('[UptimeRobotAPI] More monitors than the pages read - {"pages":5}', $this->logLines()[0]);
    }

    public function testAnUnreadableCursorIsAFailure(): void
    {
        self::assertFalse($this->api('bad-cursor')->getMonitors());
        self::assertCount(1, $this->requests());
        self::assertStringContainsString('Unreadable next page link', $this->logLines()[0]);
    }

    public function testRateLimitIsRecognized(): void
    {
        $api = $this->api('rate-limited');

        self::assertFalse($api->getMonitors());
        self::assertTrue($api->wasRateLimited());
        self::assertStringContainsString('API returned non-200 status - {"http_code":429}', $this->logLines()[0]);
    }

    public function testOtherFailuresAreNotARateLimit(): void
    {
        foreach (['wrong-key' => 'API returned non-200 status - {"http_code":401}', 'bad-json' => 'Invalid JSON response', 'no-data' => 'Response without a monitor list'] as $scenario => $logged) {
            $api = $this->api($scenario);
            self::assertFalse($api->getMonitors(), $scenario);
            self::assertFalse($api->wasRateLimited(), $scenario);
            self::assertStringContainsString($logged, implode("\n", $this->logLines()), $scenario);
        }
    }

    public function testTheKeyNeverReachesTheLog(): void
    {
        foreach (['rate-limited', 'bad-json', 'endless', 'bad-cursor'] as $scenario) {
            $this->api($scenario)->getMonitors();
        }

        foreach ($this->logLines() as $line) {
            self::assertStringNotContainsString('Bearer', $line);
            self::assertDoesNotMatchRegularExpression('/rate-limited|bad-json|endless|bad-cursor/', $line);
        }
    }

    public function testAnUnreachableServerIsAFailure(): void
    {
        self::assertFalse((new UptimeRobotAPI('two-pages', 'http://127.0.0.1:9/v3', $this->logFile))->getMonitors());
        self::assertStringContainsString('cURL request failed', $this->logLines()[0]);
    }

    /**
     * @param list<array<string, mixed>> $monitors
     * @return array<string, mixed>
     */
    private function overall(array $monitors): array
    {
        $method = new ReflectionMethod(UptimeController::class, 'calculateOverallStatus');

        return $method->invoke($this->controller(UptimeController::class), $monitors);
    }

    /**
     * @return list<array<string, mixed>>
     */
    private static function monitors(string ...$statuses): array
    {
        return array_map(static fn(string $status): array => ['id' => 1, 'status' => $status], $statuses);
    }

    public function testTheOverallStatus(): void
    {
        self::assertSame('healthy', $this->overall(self::monitors('UP', 'UP', 'PAUSED', 'STARTED'))['overall_status']);
        self::assertSame('critical', $this->overall(self::monitors('UP', 'DOWN'))['overall_status']);
        self::assertSame('critical', $this->overall(self::monitors('LOOKS_DOWN'))['overall_status']);
        self::assertSame('partial', $this->overall(self::monitors('UP', 'NEW_STATE'))['overall_status']);
        self::assertSame('unknown', $this->overall(self::monitors('PAUSED'))['overall_status']);
        self::assertSame('unknown', $this->overall([])['overall_status']);
        self::assertSame('unknown', $this->overall(self::monitors('NEW_STATE'))['overall_status'], 'none up or down');
    }

    public function testTheCounts(): void
    {
        self::assertSame(
            ['enabled' => true, 'overall_status' => 'critical', 'total_monitors' => 6, 'up' => 2, 'down' => 2, 'paused' => 1],
            $this->overall(self::monitors('UP', 'up', 'DOWN', 'LOOKS_DOWN', 'PAUSED', 'NEW_STATE'))
        );
    }

    public function testEachMonitorIsFormattedForTheDashboard(): void
    {
        $method = new ReflectionMethod(UptimeController::class, 'formatMonitors');
        $result = $method->invoke($this->controller(UptimeController::class), [
            ['id' => 5, 'friendlyName' => 'Shop', 'url' => 'https://shop.example', 'status' => 'LOOKS_DOWN', 'lastDayUptime' => 97.5],
            ['id' => '6', 'status' => 'STARTED', 'lastDayUptime' => '99'],
            'junk',
        ]);

        self::assertSame(3, $result['total']);
        self::assertSame(
            ['id' => 5, 'name' => 'Shop', 'url' => 'https://shop.example', 'status' => 8, 'status_text' => 'Seems down', 'uptime_day' => 97.5],
            $result['monitors'][0]
        );
        self::assertSame(
            ['id' => 0, 'name' => 'Unknown', 'url' => '', 'status' => 1, 'status_text' => 'Not checked yet', 'uptime_day' => null],
            $result['monitors'][1]
        );
        self::assertSame(-1, $result['monitors'][2]['status']);
        self::assertSame('Unknown', $result['monitors'][2]['status_text']);
    }
}
