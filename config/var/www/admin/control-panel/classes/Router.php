<?php
/**
 * EngineScript Admin Dashboard - API Router
 * 
 * Simple and efficient routing system for the API.
 * Maps URL paths to controller methods.
 * 
 * Features:
 * - Route registration with controller/method binding
 * - Route aliases (multiple paths to same handler)
 * - 404 handling for unmatched routes
 * - Route debugging and listing
 * 
 * @package EngineScript\Dashboard\API
 * @version 1.0.0
 * @security HIGH - Controls all API routing
 */

// Ensure ApiResponse is loaded for error responses
require_once __DIR__ . '/ApiResponse.php';

/**
 * API Router
 * 
 * Handles routing of API requests to appropriate controller methods.
 * 
 * Usage:
 *   $router = new Router();
 *   $router->register('/system/info', 'SystemController', 'getInfo');
 *   $router->register('/sites', 'SiteController', 'listSites');
 *   $router->dispatch($path);
 * 
 * Route aliases:
 *   $router->register('/sites', 'SiteController', 'listSites');
 *   $router->alias('/sites/', '/sites'); // Both paths go to same handler
 */
class Router
{
    /**
     * Registered routes mapping path => [controller, method]
     * 
     * @var array<string, array{controller: string, method: string}>
     */
    private $routes = [];

    /**
     * Route aliases mapping alias => canonical_path
     * 
     * @var array<string, string>
     */
    private $aliases = [];

    /**
     * Base path for controller files
     * 
     * @var string
     */
    private $controllerPath;

    /**
     * Whether controllers have been loaded
     * 
     * @var bool
     */
    private $controllersLoaded = false;

    /**
     * Create a new Router instance
     * 
     * @param string|null $controllerPath Path to controller files (default: __DIR__/../controllers/)
     */
    public function __construct($controllerPath = null)
    {
        $this->controllerPath = $controllerPath ?? dirname(__DIR__) . '/controllers/';
    }

    /**
     * Register a route
     * 
     * Maps a URL path to a controller and method.
     * Controller files are auto-loaded from the controllers directory.
     * 
     * @param string $path The URL path (e.g., '/system/info')
     * @param string $controller The controller class name (e.g., 'SystemController')
     * @param string $method The controller method to call (e.g., 'getInfo')
     * @return self For method chaining
     */
    public function register($path, $controller, $method)
    {
        $this->routes[$path] = [
            'controller' => $controller,
            'method' => $method
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
    public function alias($aliasPath, $canonicalPath)
    {
        $this->aliases[$aliasPath] = $canonicalPath;
        
        return $this;
    }

    /**
     * Load all controller classes
     * 
     * Auto-loads controller files from the controllers directory.
     * Only loads once per request.
     * 
     * @return void
     */
    private function loadControllers()
    {
        if ($this->controllersLoaded) {
            return;
        }

        // Load base controller first
        $baseController = $this->controllerPath . 'BaseController.php';
        if (file_exists($baseController)) {
            require_once $baseController;
        }

        // Load all other controllers
        // codacy:ignore - glob() required for controller enumeration on hardcoded path
        $controllerFiles = glob($this->controllerPath . '*Controller.php');
        foreach ($controllerFiles as $file) {
            // Skip base controller (already loaded)
            if (basename($file) === 'BaseController.php') {
                continue;
            }
            require_once $file;
        }

        $this->controllersLoaded = true;
    }

    /**
     * Resolve a path to its canonical form
     * 
     * Checks aliases and returns the canonical path.
     * 
     * @param string $path The request path
     * @return string The canonical path
     */
    private function resolvePath($path)
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
     * @return void
     */
    public function dispatch($path)
    {
        // Resolve any aliases
        $canonicalPath = $this->resolvePath($path);
        
        // Check if route exists
        if (!isset($this->routes[$canonicalPath])) {
            $this->notFound($path);
            return;
        }
        
        // Load controllers if not already loaded
        $this->loadControllers();
        
        // Get route info
        $route = $this->routes[$canonicalPath];
        $controllerName = $route['controller'];
        $methodName = $route['method'];
        
        // Verify controller class exists
        if (!class_exists($controllerName)) {
            $this->serverError("Controller not found: {$controllerName}");
            return;
        }
        
        // Instantiate controller
        $controller = new $controllerName();
        
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
     * @return void
     */
    private function notFound($path)
    {
        // Sanitize path for logging to prevent injection attacks
        $sanitized_path = preg_replace('/[^a-zA-Z0-9\/\-_.]/', '', $path);
        error_log("API 404 - Path not matched: " . $sanitized_path);
        
        ApiResponse::notFound('Endpoint not found');
    }

    /**
     * Handle server errors during routing
     * 
     * Logs the error and returns a 500 error response.
     * 
     * @param string $message Error message for logging (not shown to client)
     * @return void
     */
    private function serverError($message)
    {
        // Log internal error details
        error_log("API Router Error: " . $message);
        
        // Return generic error to client
        ApiResponse::serverError('Internal server error');
    }

    /**
     * Get all registered routes
     * 
     * Useful for debugging and documentation.
     * 
     * @return array<string, array{controller: string, method: string}>
     */
    public function getRoutes()
    {
        return $this->routes;
    }

    /**
     * Get all route aliases
     * 
     * @return array<string, string>
     */
    public function getAliases()
    {
        return $this->aliases;
    }

    /**
     * Check if a route exists
     * 
     * @param string $path The path to check
     * @return bool True if route exists
     */
    public function hasRoute($path)
    {
        $canonicalPath = $this->resolvePath($path);
        return isset($this->routes[$canonicalPath]);
    }

    /**
     * Get route info for a path
     * 
     * @param string $path The path to look up
     * @return array|null Route info or null if not found
     */
    public function getRoute($path)
    {
        $canonicalPath = $this->resolvePath($path);
        return isset($this->routes[$canonicalPath]) ? $this->routes[$canonicalPath] : null;
    }
}
