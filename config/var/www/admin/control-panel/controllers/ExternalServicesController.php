<?php
/**
 * EngineScript Admin Dashboard - External Services Controller
 * 
 * Handles proxy routing to external services API.
 * 
 * @package EngineScript\Dashboard\API\Controllers
 * @version 1.0.0
 */

require_once __DIR__ . '/BaseController.php';

/**
 * External Services Controller
 * 
 * Routes requests to external-services-api.php for WordPress.org plugin info,
 * Cloudflare status, and other external service integrations.
 */
class ExternalServicesController extends BaseController
{
    /**
     * API endpoint path
     */
    private const ENDPOINT = '/external';

    /**
     * External services API file path
     */
    private const EXTERNAL_API_FILE = __DIR__ . '/../external-services-api.php';

    /**
     * Handle external services request
     * 
     * Proxies the request to external-services-api.php which handles:
     * - WordPress.org plugin information
     * - Cloudflare status
     * - Other external service integrations
     * 
     * Endpoint: GET /external?endpoint=...
     * 
     * @return void Outputs JSON response
     */
    public function handle()
    {
        try {
            // Verify external API file exists
            // codacy:ignore - file_exists() required for API file validation
            if (!file_exists(self::EXTERNAL_API_FILE)) {
                $this->logSecurityEvent('External services error', 'External services API file not found');
                ApiResponse::serverError('External services API not available');
                return;
            }

            // Get the endpoint parameter
            $endpoint = isset($_GET['endpoint']) ? trim($_GET['endpoint']) : '';

            if (empty($endpoint)) {
                ApiResponse::badRequest('Endpoint parameter required');
                return;
            }

            // Validate endpoint parameter
            if (!$this->validateString($endpoint, 1, 100)) {
                ApiResponse::badRequest('Invalid endpoint parameter');
                return;
            }

            // Check cache for GET requests
            $cacheKey = self::ENDPOINT . '/' . $endpoint;
            if ($_SERVER['REQUEST_METHOD'] === 'GET') {
                $cached = $this->getCached($cacheKey);
                if ($cached !== null) {
                    ApiResponse::cached($cached, $this->getTtl(self::ENDPOINT));
                    return;
                }
            }

            // Include and execute external services API
            // The external API file handles its own output
            $this->executeExternalApi($endpoint);
        } catch (Exception $e) {
            $this->logSecurityEvent('External services error', $e->getMessage());
            ApiResponse::serverError('Unable to process external services request');
        }
    }

    /**
     * Execute external services API
     * 
     * Includes the external-services-api.php file and captures its output.
     * 
     * @param string $endpoint Requested endpoint
     * @return void
     */
    private function executeExternalApi(string $endpoint)
    {
        // Start output buffering to capture API response
        ob_start();

        try {
            // Include the external services API
            // This file will handle the request based on $_GET['endpoint']
            include self::EXTERNAL_API_FILE;

            // Get the output
            $output = ob_get_clean();

            // If the external API already output JSON, we're done
            // The response was already sent by external-services-api.php
            if (!empty($output)) {
                echo $output;
            }
        } catch (Exception $e) {
            ob_end_clean();
            throw $e;
        }
    }

    /**
     * Get WordPress.org plugin info
     * 
     * Retrieves plugin information from WordPress.org API.
     * 
     * Endpoint: GET /external/plugin?slug=...
     * 
     * @return void Outputs JSON response
     */
    public function getPluginInfo()
    {
        try {
            $slug = isset($_GET['slug']) ? trim($_GET['slug']) : '';

            if (empty($slug)) {
                ApiResponse::badRequest('Plugin slug parameter required');
                return;
            }

            // Validate slug format
            if (!$this->validateString($slug, 1, 100)) {
                ApiResponse::badRequest('Invalid plugin slug');
                return;
            }

            // Sanitize slug (alphanumeric, hyphens, underscores only)
            if (!preg_match('/^[a-z0-9\-_]+$/i', $slug)) {
                ApiResponse::badRequest('Invalid plugin slug format');
                return;
            }

            // Check cache
            $cacheKey = '/external/plugin/' . $slug;
            $cached = $this->getCached($cacheKey);
            if ($cached !== null) {
                ApiResponse::cached($cached, $this->getTtl(self::ENDPOINT));
                return;
            }

            // Fetch from WordPress.org API
            $result = $this->fetchPluginInfo($slug);

            if ($result === null) {
                ApiResponse::error('Unable to fetch plugin information', ApiResponse::HTTP_BAD_GATEWAY);
                return;
            }

            // Cache and return result
            $this->setCached($cacheKey, $result);
            ApiResponse::success($result, $this->getTtl(self::ENDPOINT));
        } catch (Exception $e) {
            $this->logSecurityEvent('Plugin info error', $e->getMessage());
            ApiResponse::serverError('Unable to retrieve plugin information');
        }
    }

    /**
     * Fetch plugin info from WordPress.org
     * 
     * @param string $slug Plugin slug
     * @return array|null Plugin data or null on failure
     */
    private function fetchPluginInfo(string $slug)
    {
        $url = 'https://api.wordpress.org/plugins/info/1.2/?action=plugin_information&slug=' . urlencode($slug);

        $context = stream_context_create([
            'http' => [
                'method' => 'GET',
                'timeout' => 10,
                'header' => 'User-Agent: EngineScript/1.0'
            ]
        ]);

        // codacy:ignore - file_get_contents() with stream context required for external API calls
        $response = @file_get_contents($url, false, $context);

        if ($response === false) {
            return null;
        }

        $data = json_decode($response, true);

        if (json_last_error() !== JSON_ERROR_NONE || !is_array($data)) {
            return null;
        }

        // Return sanitized subset of plugin data
        return $this->sanitizeOutput([
            'name' => isset($data['name']) ? $data['name'] : '',
            'slug' => isset($data['slug']) ? $data['slug'] : '',
            'version' => isset($data['version']) ? $data['version'] : '',
            'author' => isset($data['author']) ? strip_tags($data['author']) : '',
            'requires' => isset($data['requires']) ? $data['requires'] : '',
            'tested' => isset($data['tested']) ? $data['tested'] : '',
            'requires_php' => isset($data['requires_php']) ? $data['requires_php'] : '',
            'rating' => isset($data['rating']) ? (int) $data['rating'] : 0,
            'active_installs' => isset($data['active_installs']) ? (int) $data['active_installs'] : 0,
            'last_updated' => isset($data['last_updated']) ? $data['last_updated'] : '',
            'download_link' => isset($data['download_link']) ? $data['download_link'] : ''
        ]);
    }

    /**
     * Get Cloudflare status
     * 
     * Retrieves current Cloudflare system status.
     * 
     * Endpoint: GET /external/cloudflare/status
     * 
     * @return void Outputs JSON response
     */
    public function getCloudflareStatus()
    {
        try {
            // Check cache
            $cacheKey = '/external/cloudflare/status';
            $cached = $this->getCached($cacheKey);
            if ($cached !== null) {
                ApiResponse::cached($cached, $this->getTtl(self::ENDPOINT));
                return;
            }

            // Fetch from Cloudflare status page
            $result = $this->fetchCloudflareStatus();

            if ($result === null) {
                ApiResponse::error('Unable to fetch Cloudflare status', ApiResponse::HTTP_BAD_GATEWAY);
                return;
            }

            // Cache and return result
            $this->setCached($cacheKey, $result);
            ApiResponse::success($result, $this->getTtl(self::ENDPOINT));
        } catch (Exception $e) {
            $this->logSecurityEvent('Cloudflare status error', $e->getMessage());
            ApiResponse::serverError('Unable to retrieve Cloudflare status');
        }
    }

    /**
     * Fetch Cloudflare status from status page API
     * 
     * @return array|null Status data or null on failure
     */
    private function fetchCloudflareStatus()
    {
        $url = 'https://www.cloudflarestatus.com/api/v2/status.json';

        $context = stream_context_create([
            'http' => [
                'method' => 'GET',
                'timeout' => 10,
                'header' => 'User-Agent: EngineScript/1.0'
            ]
        ]);

        // codacy:ignore - file_get_contents() with stream context required for external API calls
        $response = @file_get_contents($url, false, $context);

        if ($response === false) {
            return null;
        }

        $data = json_decode($response, true);

        if (json_last_error() !== JSON_ERROR_NONE || !is_array($data)) {
            return null;
        }

        // Return sanitized status data
        return $this->sanitizeOutput([
            'indicator' => isset($data['status']['indicator']) ? $data['status']['indicator'] : 'unknown',
            'description' => isset($data['status']['description']) ? $data['status']['description'] : 'Unknown',
            'updated_at' => isset($data['page']['updated_at']) ? $data['page']['updated_at'] : null
        ]);
    }
}
