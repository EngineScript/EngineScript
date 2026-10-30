<?php

/**
 * EngineScript Admin Dashboard - API Router
 *
 * Maps API paths to controller methods through one route table.
 *
 * @package EngineScript\Dashboard\API
 * @version 1.0.0
 * @security HIGH - Controls all API routing
 */

declare(strict_types=1);

// Ensure response and request helpers are loaded for dispatching
require_once __DIR__ . '/ApiResponder.php';
require_once __DIR__ . '/Request.php';
require_once __DIR__ . '/SecurityLogger.php';
require_once __DIR__ . '/Session.php';

/**
 * API Router
 *
 * The controller classes must be loaded before dispatch; api.php loads them.
 * Unknown paths answer 404; a method a route does not allow answers 405 with
 * an Allow header. GET routes also answer HEAD.
 */
final readonly class Router
{
    private const array GET = ['GET', 'HEAD'];
    private const array POST = ['POST'];

    public function __construct(
        private ApiResponder $response,
        private Request $request,
        private SecurityLogger $securityLogger,
        private Session $session
    ) {
    }

    /**
     * Dispatch the request for a path that api.php has already validated
     */
    public function dispatch(string $path): void
    {
        $route = $this->route($path);

        if ($route === null) {
            error_log('API 404 - Path not matched: ' . $path);
            $this->response->notFound('Endpoint not found');
            return;
        }

        [$allowedMethods, $handler] = $route;

        if (!in_array($this->request->method(), $allowedMethods, true)) {
            $this->response->methodNotAllowed($allowedMethods);
            return;
        }

        $handler();
    }

    /**
     * The route table: allowed HTTP methods and handler of each path
     *
     * @return array{list<string>, Closure(): void}|null
     */
    private function route(string $path): ?array
    {
        return match ($path) {
            '/csrf-token' => [self::GET, fn() => $this->controller(CsrfController::class)->getToken()],
            '/system/info' => [self::GET, fn() => $this->controller(SystemController::class)->getInfo()],
            '/services/status' => [self::GET, fn() => $this->controller(ServiceController::class)->getStatus()],
            '/sites' => [self::GET, fn() => $this->controller(SiteController::class)->getSites()],
            '/tools/status' => [self::GET, fn() => $this->controller(ToolsController::class)->getStatus()],
            '/tools/filemanager/status' => [
                self::GET,
                fn() => $this->controller(FileManagerController::class)->getStatus(),
            ],
            '/monitoring/uptime' => [self::GET, fn() => $this->controller(UptimeController::class)->getStatus()],
            '/monitoring/uptime/monitors' => [
                self::GET,
                fn() => $this->controller(UptimeController::class)->getMonitors(),
            ],
            '/cache/clear' => [self::POST, fn() => $this->controller(CacheController::class)->clear()],
            '/cache/status' => [self::GET, fn() => $this->controller(CacheController::class)->getStatus()],
            default => null,
        };
    }

    /**
     * @template T of BaseController
     * @param class-string<T> $controllerClass
     * @return T
     */
    private function controller(string $controllerClass): BaseController
    {
        return new $controllerClass($this->session, $this->response, $this->securityLogger, $this->request);
    }
}
