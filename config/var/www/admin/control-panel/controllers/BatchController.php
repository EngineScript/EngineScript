<?php
/**
 * EngineScript Admin Dashboard - Batch Controller
 * 
 * Handles batch API requests for multiple endpoints in a single call.
 * 
 * @package EngineScript\Dashboard\API\Controllers
 * @version 1.0.0
 */

require_once __DIR__ . '/BaseController.php';

/**
 * Batch Controller
 * 
 * Provides batch request handling for multiple API endpoints.
 */
class BatchController extends BaseController
{
    /**
     * Allowed endpoints for batch requests
     * Only GET endpoints that return JSON are allowed
     */
    private const ALLOWED_ENDPOINTS = [
        '/system/info',
        '/services/status',
        '/sites',
        '/sites/count',
        '/tools/filemanager/status',
        '/monitoring/uptime',
        '/monitoring/uptime/monitors',
    ];

    /**
     * Maximum batch size to prevent abuse
     */
    private const MAX_BATCH_SIZE = 10;

    /**
     * Controller mappings for batch dispatch
     */
    private const ENDPOINT_CONTROLLERS = [
        '/system/info' => ['SystemController', 'getInfo'],
        '/services/status' => ['ServiceController', 'getStatus'],
        '/sites' => ['SiteController', 'getSites'],
        '/sites/count' => ['SiteController', 'getSitesCount'],
        '/tools/filemanager/status' => ['FileManagerController', 'getStatus'],
        '/monitoring/uptime' => ['UptimeController', 'getStatus'],
        '/monitoring/uptime/monitors' => ['UptimeController', 'getMonitors'],
    ];

    /**
     * Handle batch API request
     * 
     * Accepts POST with JSON body: { "requests": ["/endpoint1", "/endpoint2", ...] }
     * Returns: { "results": { "/endpoint1": {...}, "/endpoint2": {...} }, "errors": {...} }
     * 
     * Endpoint: POST /batch
     * 
     * @return void Outputs JSON response
     */
    public function handle()
    {
        try {
            // Only accept POST for batch requests
            // codacy:ignore - Direct $_SERVER access required for method checking in standalone API
            if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] !== 'POST') {
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                ApiResponse::methodNotAllowed('Method not allowed. Use POST.');
                return;
            }

            // Parse JSON body
            $input = file_get_contents('php://input'); // codacy:ignore - file_get_contents() required for reading POST body
            $data = json_decode($input, true);

            if (!$data || !isset($data['requests']) || !is_array($data['requests'])) {
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                ApiResponse::badRequest('Invalid request. Expected JSON with "requests" array.');
                return;
            }

            $requests = $data['requests'];

            // Limit batch size to prevent abuse
            if (count($requests) > self::MAX_BATCH_SIZE) {
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                ApiResponse::badRequest('Batch size exceeds maximum of ' . self::MAX_BATCH_SIZE . ' requests.');
                return;
            }

            $results = [];
            $errors = [];
            $cached_count = 0;

            foreach ($requests as $endpoint) {
                // Validate endpoint
                if (!is_string($endpoint)) {
                    $errors[] = ['endpoint' => $endpoint, 'error' => 'Invalid endpoint type'];
                    continue;
                }

                // Sanitize and validate endpoint
                $clean_endpoint = preg_replace('/[^a-zA-Z0-9\/_-]/', '', $endpoint);

                if (!in_array($clean_endpoint, self::ALLOWED_ENDPOINTS, true)) {
                    $errors[$endpoint] = 'Endpoint not allowed in batch requests';
                    continue;
                }

                // Check cache first
                $cached = $this->getCached($clean_endpoint);
                if ($cached !== null) {
                    $results[$clean_endpoint] = $cached;
                    $cached_count++;
                    continue;
                }

                // Execute the endpoint via controller
                $result = $this->executeEndpoint($clean_endpoint);
                if ($result === null) {
                    $errors[$clean_endpoint] = 'Failed to process endpoint';
                    continue;
                }

                $results[$clean_endpoint] = $result;
                // Cache the result
                $this->setCached($clean_endpoint, $result);
            }

            // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
            ApiResponse::success([
                'results' => $results,
                'errors' => $errors,
                'cached_count' => $cached_count
            ]);
        } catch (Exception $e) {
            $this->logSecurityEvent('Batch request error', $e->getMessage());
            // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
            ApiResponse::serverError('Unable to process batch request');
        }
    }

    /**
     * Execute a single endpoint and capture its output
     * 
     * @param string $endpoint The endpoint to execute
     * @return array|null The result or null on failure
     */
    private function executeEndpoint(string $endpoint)
    {
        if (!isset(self::ENDPOINT_CONTROLLERS[$endpoint])) {
            return null;
        }

        list($controllerClass, $method) = self::ENDPOINT_CONTROLLERS[$endpoint];

        try {
            // Load controller file
            $controllerFile = __DIR__ . '/' . $controllerClass . '.php';
            if (!file_exists($controllerFile)) { // codacy:ignore - file_exists() required for controller loading
                return null;
            }

            // codacy:ignore - require_once with __DIR__ and whitelisted controller name from ENDPOINT_CONTROLLERS constant; no user input
            require_once $controllerFile;

            if (!class_exists($controllerClass)) {
                return null;
            }

            // Capture output
            ob_start();
            $controller = new $controllerClass();
            $controller->$method();
            $output = ob_get_clean();

            // Parse JSON output
            $result = json_decode($output, true);
            return $result;
        } catch (Exception $e) {
            ob_end_clean();
            $this->logSecurityEvent('Batch endpoint error', $endpoint . ': ' . $e->getMessage());
            return null;
        }
    }
}
