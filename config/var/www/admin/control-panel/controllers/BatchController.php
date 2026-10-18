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
 *
 * @psalm-api
 */
final class BatchController extends BaseController
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
        '/cache/status',
    ];

    /**
     * Maximum batch size to prevent abuse
     */
    private const MAX_BATCH_SIZE = 10;

    /**
     * Controller mappings for batch dispatch
     *
     * @var array<string, array{class-string<BaseController>, string}>
     */
    private const ENDPOINT_CONTROLLERS = [
        '/system/info' => [SystemController::class, 'getInfo'],
        '/services/status' => [ServiceController::class, 'getStatus'],
        '/sites' => [SiteController::class, 'getSites'],
        '/sites/count' => [SiteController::class, 'getSitesCount'],
        '/tools/filemanager/status' => [FileManagerController::class, 'getStatus'],
        '/monitoring/uptime' => [UptimeController::class, 'getStatus'],
        '/monitoring/uptime/monitors' => [UptimeController::class, 'getMonitors'],
        '/cache/status' => [CacheController::class, 'getStatus'],
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
     * @psalm-api
     */
    public function handle(): void
    {
        try {
            $requests = $this->validateBatchInput();
            if ($requests === null) {
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
                    ++$cached_count;
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
            $this->response->success([
                'results' => $results,
                'errors' => $errors,
                'cached_count' => $cached_count,
            ]);
        } catch (Throwable $e) {
            $this->logSecurityEvent('Batch request error', $e->getMessage());
            $this->response->serverError('Unable to process batch request');
        }
    }

    /**
     * Validate batch request input
     *
     * @return array<mixed>|null Validated requests array or null if validation failed (response already sent)
     */
    private function validateBatchInput(): ?array
    {
        // Only accept POST for batch requests
        if ($this->getRequestMethod() !== 'POST') {
            $this->response->methodNotAllowed('POST');
            return null;
        }

        // Parse JSON body
        $input = $this->request->body();
        if (trim($input) === '') {
            $this->response->badRequest('Invalid request. Expected JSON with "requests" array.');
            return null;
        }

        try {
            $data = $this->arrayOrNull(json_decode($input, true, 512, JSON_THROW_ON_ERROR));
        } catch (JsonException) {
            $this->response->badRequest('Invalid JSON request body.');
            return null;
        }

        if ($data === null || !isset($data['requests']) || !is_array($data['requests'])) {
            $this->response->badRequest('Invalid request. Expected JSON with "requests" array.');
            return null;
        }

        // Limit batch size to prevent abuse
        if (count($data['requests']) > self::MAX_BATCH_SIZE) {
            $this->response->badRequest('Batch size exceeds maximum of ' . self::MAX_BATCH_SIZE . ' requests.');
            return null;
        }

        return $data['requests'];
    }

    /**
     * Execute a single endpoint and capture its output
     *
     * @param string $endpoint The endpoint to execute
     * @return array<mixed>|null The result or null on failure
     */
    private function executeEndpoint(string $endpoint): ?array
    {
        if (!isset(self::ENDPOINT_CONTROLLERS[$endpoint])) {
            return null;
        }

        [$controllerClass, $method] = self::ENDPOINT_CONTROLLERS[$endpoint];
        $bufferStarted = false;

        try {
            if (!class_exists($controllerClass)) {
                return null;
            }

            // Capture output
            ob_start();
            $bufferStarted = true;
            $controller = new $controllerClass($this->session, $this->response, $this->securityLogger, $this->request);
            if (method_exists($controller, $method)) {
                $controller->$method();
            }
            $output = ob_get_clean();
            $bufferStarted = false;

            // Parse JSON output
            if (!is_string($output) || $output === '') {
                return null;
            }

            return $this->arrayOrNull(json_decode($output, true, 512, JSON_THROW_ON_ERROR));
        } catch (Throwable $e) {
            if ($bufferStarted && ob_get_level() > 0) {
                ob_end_clean();
            }
            $this->logSecurityEvent('Batch endpoint error', $endpoint . ': ' . $e->getMessage());
            return null;
        }
    }
}
