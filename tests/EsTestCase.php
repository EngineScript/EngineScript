<?php

/**
 * Base class for the unit suite.
 */

declare(strict_types=1);

use PHPUnit\Framework\TestCase;

/**
 * Starts every test with a fresh command runner, empty session and request
 * data, response code 200, and a security log in a temporary directory.
 */
abstract class EsTestCase extends TestCase
{
    protected EsTestRunner $runner;

    protected string $logFile;

    /** @var list<string> */
    private array $temporaryDirectories = [];

    protected function setUp(): void
    {
        parent::setUp();
        $this->runner = es_test_reset();
        $this->logFile = $this->makeTemporaryDirectory() . '/security.log';
    }

    protected function tearDown(): void
    {
        foreach ($this->temporaryDirectories as $directory) {
            $this->removeDirectory($directory);
        }

        $this->temporaryDirectories = [];
        es_test_reset();
        parent::tearDown();
    }

    /**
     * An empty directory that is removed after the test; no trailing slash.
     */
    protected function makeTemporaryDirectory(): string
    {
        $directory = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'es-unit-' . bin2hex(random_bytes(8));
        mkdir($directory, 0700, true);
        $this->temporaryDirectories[] = $directory;

        return $directory;
    }

    /**
     * The lines the code under test wrote to the security log.
     *
     * @return list<string>
     */
    protected function logLines(): array
    {
        if (!is_file($this->logFile)) {
            return [];
        }

        $lines = file($this->logFile, FILE_IGNORE_NEW_LINES);

        return $lines === false ? [] : $lines;
    }

    protected function logger(?Request $request = null): SecurityLogger
    {
        return new SecurityLogger($request ?? es_test_request(), $this->logFile);
    }

    /**
     * A controller as the Router builds it, with this test's security log.
     *
     * @template T of BaseController
     * @param class-string<T> $class
     * @return T
     */
    protected function controller(string $class, ?Request $request = null): BaseController
    {
        $request ??= es_test_request();

        return new $class(new Session(), new ApiResponder(), $this->logger($request), $request);
    }

    /**
     * Run code that answers a request, and return the response code, the decoded
     * JSON body, and the raw body.
     *
     * @return array{status: int, json: mixed, body: string}
     */
    protected function respond(callable $answer): array
    {
        http_response_code(200);
        ob_start();
        try {
            $answer();
        } finally {
            $body = (string) ob_get_clean();
        }

        $status = http_response_code();

        return [
            'status' => is_int($status) ? $status : 0,
            'json' => json_decode($body, true),
            'body' => $body,
        ];
    }

    private function removeDirectory(string $directory): void
    {
        if (!is_dir($directory)) {
            return;
        }

        $items = scandir($directory);
        foreach ($items === false ? [] : array_diff($items, ['.', '..']) as $item) {
            $path = $directory . DIRECTORY_SEPARATOR . $item;
            is_dir($path) && !is_link($path) ? $this->removeDirectory($path) : unlink($path);
        }

        rmdir($directory);
    }
}
