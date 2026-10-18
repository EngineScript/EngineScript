<?php

/**
 * EngineScript Admin Dashboard - API Router
 *
 * Simple and efficient routing system for the API.
 * Maps URL paths to controller methods.
 *
 * Features:
 * - Route registration with controller/method binding and HTTP method policy
 * - Route aliases (multiple paths to same handler)
 * - 404 handling for unmatched routes
 *
 * @package EngineScript\Dashboard\API
 * @version 1.0.0
 * @security HIGH - Controls all API routing
 */

// Ensure response and request helpers are loaded for dispatching
// codacy:ignore - require_once with __DIR__ constant is safe; no user input in path
require_once __DIR__ . '/ApiResponder.php';
require_once __DIR__ . '/Request.php';
require_once __DIR__ . '/SecurityLogger.php';
require_once __DIR__ . '/Session.php';

/**
 * API Router
 *
 * Handles routing of API requests to appropriate controller methods. The
 * controller classes must be loaded before dispatch; api.php loads them.
 *
 * Usage:
 *   $router = new Router();
 *   $router->register('/system/info', 'SystemController', 'getInfo');
 *   $router->register('/cache/clear', 'CacheController', 'clear', ['POST']);
 *   $router->dispatch($path);
 *
 * Route aliases:
 *   $router->register('/sites', 'SiteController', 'getSites');
 *   $router->alias('/sites/', '/sites'); // Both paths go to same handler
 */
final class Router
{
    /**
     * Registered routes mapping path => [controller, method, methods]
     *
     * @var array<string, array{controller: class-string<BaseController>, method: string, methods: list<string>}>
     */
    private array $routes = [];

    /**
     * Route aliases mapping alias => canonical_path
     *
     * @var array<string, string>
     */
    private array $aliases = [];

    /**
     * Instance response handler for router errors.
     */
    private ApiResponder $response;

    /**
     * Request wrapper for method resolution.
     */
    private Request $request;

    /**
     * Shared security logger for controllers.
     */
    private SecurityLogger $securityLogger;

    /**
     * Shared session wrapper for controllers.
     */
    private Session $session;

    /**
     * Create a new Router instance
     */
    public function __construct(
        ?ApiResponder $response = null,
        ?Request $request = null,
        ?SecurityLogger $securityLogger = null,
        ?Session $session = null
    ) {
        $this->request = $request ?? new Request();
        $this->response = $response ?? new ApiResponder();
        $this->securityLogger = $securityLogger ?? new SecurityLogger($this->request);
        $this->session = $session ?? new Session();
    }

    /**
     * Register a route
     *
     * Maps a URL path to a controller and method.
     *
     * @param string $path The URL path (e.g., '/system/info')
     * @param class-string<BaseController> $controller The controller class name (e.g., 'SystemController')
     * @param string $method The controller method to call (e.g., 'getInfo')
     * @param list<string> $allowedMethods Allowed HTTP methods for this route
     * @return self For method chaining
     */
    public function register(string $path, string $controller, string $method, array $allowedMethods = ['GET']): self
    {
        $methods = array_values(array_unique(array_map('strtoupper', $allowedMethods)));
        $methods = array_values(array_filter($methods, static fn(string $candidate): bool => preg_match('/^[A-Z]+$/', $candidate) === 1));

        if ($methods === []) {
            $methods = ['GET'];
        }

        $this->routes[$path] = [
            'controller' => $controller,
            'method' => $method,
            'methods' => $methods,
        ];

        return $this;
    }

    /**
     * Create a route alias
     *
     * Maps an alias path to an existing route's canonical path.
     * Useful for handling trailing slashes or alternative paths.
     *
     * @param string $aliasPath The alias path (e.g., '/sites/')
     * @param string $canonicalPath The canonical path (e.g., '/sites')
     * @return self For method chaining
     */
    public function alias(string $aliasPath, string $canonicalPath): self
    {
        $this->aliases[$aliasPath] = $canonicalPath;

        return $this;
    }

    /**
     * Resolve a path to its canonical form
     *
     * Checks aliases and returns the canonical path.
     *
     * @param string $path The request path
     * @return string The canonical path
     */
    private function resolvePath(string $path): string
    {
        // Check if path is an alias
        if (isset($this->aliases[$path])) {
            return $this->aliases[$path];
        }

        return $path;
    }

    /**
     * Dispatch a request to the appropriate controller
     *
     * Matches the path to a registered route and calls the controller method.
     * Returns 404 error if no route matches.
     *
     * @param string $path The URL path to dispatch
     * @param string|null $requestMethod HTTP method, defaults to current request method
     */
    public function dispatch(string $path, ?string $requestMethod = null): void
    {
        // Resolve any aliases
        $canonicalPath = $this->resolvePath($path);

        // Check if route exists
        if (!isset($this->routes[$canonicalPath])) {
            $this->notFound($path);
            return;
        }

        // Get route info
        $route = $this->routes[$canonicalPath];
        $controllerName = $route['controller'];
        $methodName = $route['method'];
        $allowedMethods = $route['methods'];
        $actualMethod = strtoupper($requestMethod ?? $this->request->method());

        if (!in_array($actualMethod, $allowedMethods, true)) {
            $this->response->methodNotAllowed($allowedMethods);
            return;
        }

        // Verify controller class exists
        if (!class_exists($controllerName)) {
            $this->serverError("Controller not found: {$controllerName}");
            return;
        }

        // Instantiate controller
        $controller = new $controllerName($this->session, $this->response, $this->securityLogger, $this->request);

        // Verify method exists
        if (!method_exists($controller, $methodName)) {
            $this->serverError("Method not found: {$controllerName}::{$methodName}");
            return;
        }

        // Call the controller method
        $controller->{$methodName}();
    }

    /**
     * Handle 404 Not Found
     *
     * Logs the attempted path and returns a 404 error response.
     * Path is sanitized before logging to prevent injection.
     *
     * @param string $path The unmatched path
     */
    private function notFound(string $path): void
    {
        // Sanitize path for logging to prevent injection attacks
        $sanitized_path = preg_replace('/[^a-zA-Z0-9\/\-_.]/', '', $path) ?? '';
        error_log("API 404 - Path not matched: " . $sanitized_path);

        $this->response->notFound('Endpoint not found');
    }

    /**
     * Handle server errors during routing
     *
     * Logs the error and returns a 500 error response.
     *
     * @param string $message Error message for logging (not shown to client)
     */
    private function serverError(string $message): void
    {
        // Log internal error details
        error_log("API Router Error: " . $message);

        // Return generic error to client
        $this->response->serverError('Internal server error');
    }
}
