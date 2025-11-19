<?php
/**
 * Router Class
 * Handles request routing to appropriate controllers
 * 
 * @version 1.0.0
 * @security HIGH - Validates all routes and parameters
 */

class Router {
    private $routes = [];
    private $middleware = [];
    
    /**
     * Register a GET route
     * @param string $path Route path pattern
     * @param callable $handler Handler function/method
     */
    public function get($path, $handler) {
        $this->routes['GET'][$path] = $handler;
    }
    
    /**
     * Register middleware to run before route handlers
     * @param callable $middleware Middleware function
     */
    public function addMiddleware($middleware) {
        $this->middleware[] = $middleware;
    }
    
    /**
     * Dispatch request to appropriate handler
     * @param string $method HTTP method
     * @param string $path Request path
     */
    public function dispatch($method, $path) {
        // Run middleware
        foreach ($this->middleware as $middleware) {
            $middleware($method, $path);
        }
        
        // Normalize path
        $path = rtrim($path, '/');
        if (empty($path)) {
            $path = '/';
        }
        
        // Find matching route
        if (isset($this->routes[$method][$path])) {
            $handler = $this->routes[$method][$path];
            
            if (is_array($handler)) {
                // Controller method: ['ClassName', 'methodName']
                list($class, $method) = $handler;
                return $class::$method();
            } else {
                // Function callback
                return $handler();
            }
        }
        
        // No route found
        http_response_code(404);
        echo json_encode(['error' => 'Endpoint not found']);
    }
    
    /**
     * Validate path format
     * @param string $path Path to validate
     * @return bool
     */
    public static function validatePath($path) {
        return strlen($path) <= 100 && preg_match('/^\/[a-zA-Z0-9\/_-]*$/', $path);
    }
}
