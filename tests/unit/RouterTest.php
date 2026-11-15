<?php

declare(strict_types=1);

use EngineScript\Dashboard\Classes\ApiResponder;
use EngineScript\Dashboard\Classes\Router;
use EngineScript\Dashboard\Classes\Session;

final class RouterTest extends EsTestCase
{
    /** The route table, with the methods each route accepts. */
    private const array ROUTES = [
        '/csrf-token' => ['GET', 'HEAD'],
        '/system/info' => ['GET', 'HEAD'],
        '/services/status' => ['GET', 'HEAD'],
        '/sites' => ['GET', 'HEAD'],
        '/tools/status' => ['GET', 'HEAD'],
        '/tools/filemanager/status' => ['GET', 'HEAD'],
        '/monitoring/uptime' => ['GET', 'HEAD'],
        '/monitoring/uptime/monitors' => ['GET', 'HEAD'],
        '/cache/clear' => ['POST'],
        '/cache/status' => ['GET', 'HEAD'],
    ];

    /**
     * @return array{status: int, json: mixed, body: string}
     */
    private function dispatch(string $path, string $method = 'GET'): array
    {
        $request = es_test_request(['REQUEST_METHOD' => $method]);
        $router = new Router(new ApiResponder(), $request, $this->logger($request), new Session());

        return $this->respond(static fn() => $router->dispatch($path));
    }

    public function testEveryRouteAnswersItsMethods(): void
    {
        $_SESSION['csrf_token'] = str_repeat('a', 64);

        foreach (self::ROUTES as $path => $methods) {
            // Their controllers read /etc/os-release and /etc/enginescript/uptimerobot.conf; the
            // integration suite runs them. The 405 test below shows that they are registered.
            if (in_array($path, ['/system/info', '/monitoring/uptime', '/monitoring/uptime/monitors'], true)) {
                continue;
            }

            foreach ($methods as $method) {
                $result = $this->dispatch($path, $method);
                self::assertNotSame(404, $result['status'], "{$method} {$path}");
                self::assertNotSame(405, $result['status'], "{$method} {$path}");
                self::assertIsArray($result['json'], "{$method} {$path} answers JSON");
            }
        }
    }

    public function testAnyOtherMethodGets405WithTheAllowedMethods(): void
    {
        foreach (self::ROUTES as $path => $methods) {
            foreach (['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'] as $method) {
                if (in_array($method, $methods, true)) {
                    continue;
                }

                $result = $this->dispatch($path, $method);
                self::assertSame(405, $result['status'], "{$method} {$path}");
                self::assertSame(['error' => 'Method not allowed. Use ' . implode(', ', $methods) . '.'], $result['json']);
            }
        }
    }

    public function testUnknownPathsGet404(): void
    {
        foreach (['/', '/batch', '/sites/count', '/system', '/cache/clear/now', '/System/info', '/services'] as $path) {
            $result = $this->dispatch($path);
            self::assertSame(404, $result['status'], $path);
            self::assertSame(['error' => 'Endpoint not found'], $result['json']);
        }
    }

    public function testAnUnknownPathIsNotLogged(): void
    {
        $this->dispatch('/no/such/route');

        self::assertSame([], $this->logLines());
    }
}
