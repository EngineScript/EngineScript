<?php

/**
 * Bootstrap for the unit suite and for the dashboard script tests.
 *
 * Loads the control panel's classes and controllers, but not api.php, which
 * sends headers, starts a session, and exits. The commands SystemCommand would
 * run go to EsTestRunner, which answers from a script the test sets and records
 * each call; esTestReset() clears it with the rest of the shared state.
 *
 * Code whose behavior depends on real system commands, the files under /etc,
 * /var, and /home, real services, PHP sessions across requests, or nginx is not
 * tested here: the integration suite (tests/integration) runs it on a real
 * Ubuntu server stack.
 */

declare(strict_types=1);

use EngineScript\Dashboard\Classes\CommandRunner;
use EngineScript\Dashboard\Classes\Request;
use EngineScript\Dashboard\Classes\SystemCommand;

const ES_TEST_PANEL = __DIR__ . '/../config/var/www/admin/control-panel';

// As api.php loads them, in dependency order
require_once ES_TEST_PANEL . '/classes/CommandRunner.php';
require_once ES_TEST_PANEL . '/classes/SystemProcessRunner.php';
require_once ES_TEST_PANEL . '/classes/SystemCommand.php';
require_once ES_TEST_PANEL . '/classes/ApiResponder.php';
require_once ES_TEST_PANEL . '/classes/Request.php';
require_once ES_TEST_PANEL . '/classes/SecurityLogger.php';
require_once ES_TEST_PANEL . '/classes/Session.php';
require_once ES_TEST_PANEL . '/classes/RequestGuard.php';
require_once ES_TEST_PANEL . '/classes/UptimeRobotAPI.php';
require_once ES_TEST_PANEL . '/classes/Router.php';
require_once ES_TEST_PANEL . '/controllers/BaseController.php';
require_once ES_TEST_PANEL . '/controllers/CacheController.php';
require_once ES_TEST_PANEL . '/controllers/CsrfController.php';
require_once ES_TEST_PANEL . '/controllers/FileManagerController.php';
require_once ES_TEST_PANEL . '/controllers/ServiceController.php';
require_once ES_TEST_PANEL . '/controllers/SiteController.php';
require_once ES_TEST_PANEL . '/controllers/SystemController.php';
require_once ES_TEST_PANEL . '/controllers/ToolsController.php';
require_once ES_TEST_PANEL . '/controllers/UptimeController.php';

/**
 * Answers SystemCommand's commands from a script, and records every call.
 *
 * A command is named as SystemCommand writes it, for example
 * "systemctl is-active nginx.service". A command the script does not name
 * fails, as a missing executable would.
 */
final class EsTestRunner implements CommandRunner
{
    /** @var array<string, string|false> */
    public array $answers = [];

    /** @var list<array{command: list<string>, display: string, stderr: bool, timeout: int}> */
    public array $calls = [];

    /**
     * @param array<string, string|false> $answers
     */
    public function __construct(array $answers = [])
    {
        $this->answers = $answers;
    }

    public function run(array $command, bool $captureStderr, int $timeoutSeconds, array $displayCommand): string|false
    {
        $display = implode(' ', $displayCommand);
        $this->calls[] = [
            'command' => array_values($command),
            'display' => $display,
            'stderr' => $captureStderr,
            'timeout' => $timeoutSeconds,
        ];

        return $this->answers[$display] ?? false;
    }
}

/**
 * Clear the state the panel's code shares between requests: the session data,
 * the request superglobals, the response code, and the command runner.
 */
function esTestReset(?EsTestRunner $runner = null): EsTestRunner
{
    $runner ??= new EsTestRunner();
    SystemCommand::useRunner($runner);
    $_SESSION = [];
    $_GET = [];
    $_POST = [];
    http_response_code(200);

    return $runner;
}

/**
 * A Request built from arrays, with the server values a request through nginx has.
 *
 * @param array<string, mixed> $server
 * @param array<string, mixed> $query
 * @param array<string, mixed> $post
 */
function esTestRequest(array $server = [], array $query = [], array $post = [], string $body = ''): Request
{
    return new Request(
        $server + [
            'REQUEST_METHOD' => 'GET',
            'REQUEST_URI' => '/api/system/info',
            'HTTP_HOST' => 'admin.example.test',
            'REMOTE_ADDR' => '203.0.113.7',
            'PHP_AUTH_USER' => 'admin',
        ],
        $query,
        $post,
        $body
    );
}

esTestReset();

// The dashboard script tests load this file without PHPUnit, to render API responses.
if (class_exists(\PHPUnit\Framework\TestCase::class)) {
    require_once __DIR__ . '/EsTestCase.php';
    require_once __DIR__ . '/IntegrationTestCase.php';
}
