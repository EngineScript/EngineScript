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
require_once __DIR__ . '/../classes/CurlInitException.php'; // codacy:ignore - Secure class loading: path is a private constant resolved from __DIR__, no user input

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
    private const EXTERNAL_API_FILE = __DIR__ . '/../external-services/external-services-api.php';

    /**
     * Feed parser instance
     * 
     * @var ExternalServicesFeedParser|null
     */
    private ?ExternalServicesFeedParser $feedParser = null;

    /**
     * Load the external services API module
     * 
     * Ensures the ENGINESCRIPT_DASHBOARD constant is defined and the
     * external-services-api.php file is loaded exactly once.
     * 
     * @return void
     * @throws \RuntimeException If the API file is not found
     */
    private function loadExternalApi(): void
    {
        // codacy:ignore - file_exists() required for API file validation
        if (!file_exists(self::EXTERNAL_API_FILE)) {
            throw new \RuntimeException('External services API file not found');
        }

        if (!defined('ENGINESCRIPT_DASHBOARD')) {
            define('ENGINESCRIPT_DASHBOARD', true);
        }

        require_once self::EXTERNAL_API_FILE; // codacy:ignore - Secure class loading: path is a private constant resolved from __DIR__, no user input

        if ($this->feedParser === null) {
            $this->feedParser = new ExternalServicesFeedParser();
        }
    }

    /**
     * Get external services configuration
     * 
     * Returns all available external services.
     * User preferences are stored client-side in cookies.
     * 
     * Endpoint: GET /external-services/config
     * 
     * @return void Outputs JSON response
     */
    public function getConfig()
    {
        try {
            $cacheKey = '/external-services/config';
            $cached = $this->getCached($cacheKey);
            if ($cached !== null) {
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                $this->response->cached($cached, $this->getTtl($cacheKey));
                return;
            }

            $this->loadExternalApi();

            $config = $this->feedParser->getServicesConfig();
            $config = $this->sanitizeOutput($config);
            $this->setCached($cacheKey, $config);
            // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
            $this->response->success($config, $this->getTtl($cacheKey));
        } catch (Exception $e) {
            $this->logSecurityEvent('External services config error', $e->getMessage());
            // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
            $this->response->serverError('Unable to retrieve external services config');
        }
    }

    /**
     * Get external service status feed
     * 
     * Proxies to handleStatusFeed() which parses RSS/Atom/JSON status feeds.
     * 
     * Endpoint: GET /external-services/feed?feed=...
     * 
     * @return void Outputs JSON response
     */
    public function getFeed()
    {
        try {
            $feedType = $this->getQueryParam('feed') ?? '';

            if (empty($feedType)) {
                $this->response->badRequest('Missing feed parameter');
                return;
            }

            // Sanitize optional filter parameter
            $filter = $this->getQueryParam('filter');
            if ($filter !== null) {
                $filter = preg_replace('/[^a-zA-Z0-9_-]/', '', $filter);
                $filter = substr($filter, 0, 50);
                if (empty($filter)) {
                    $filter = null;
                }
            }

            $this->loadExternalApi();
            $this->feedParser->handleStatusFeed($feedType, $filter);
        } catch (Exception $e) {
            $this->logSecurityEvent('External services feed error', $e->getMessage());
            // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
            $this->response->serverError('Unable to fetch status feed');
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
            $slug = $this->getQueryParam('slug') ?? '';

            if (empty($slug)) {
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                $this->response->badRequest('Plugin slug parameter required');
                return;
            }

            // Validate slug format
            if (!$this->validateString($slug, 100)) {
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                $this->response->badRequest('Invalid plugin slug');
                return;
            }

            // Sanitize slug (alphanumeric, hyphens, underscores only)
            if (!preg_match('/^[a-z0-9\-_]+$/i', $slug)) {
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                $this->response->badRequest('Invalid plugin slug format');
                return;
            }

            // Check cache
            $cacheKey = '/external/plugin/' . $slug;
            $cached = $this->getCached($cacheKey);
            if ($cached !== null) {
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                $this->response->cached($cached, $this->getTtl(self::ENDPOINT));
                return;
            }

            // Fetch from WordPress.org API
            $result = $this->fetchPluginInfo($slug);

            if ($result === null) {
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                $this->response->error('Unable to fetch plugin information', ApiResponse::HTTP_BAD_GATEWAY);
                return;
            }

            // Cache and return result
            $this->setCached($cacheKey, $result);
            $this->response->success($result, $this->getTtl(self::ENDPOINT));
        } catch (Exception $e) {
            $this->logSecurityEvent('Plugin info error', $e->getMessage());
            // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
            $this->response->serverError('Unable to retrieve plugin information');
        }
    }

    /**
     * Build a cURL handle with secure defaults for outbound JSON API requests.
     *
     * @param string $url Request URL
     * @return \CurlHandle
     * @throws CurlInitException if cURL is unavailable
     */
    private function createCurlHandle(string $url): \CurlHandle
    {
        // codacy:ignore - curl functions required for secure outbound HTTP in standalone API
        $curl = curl_init();
        if ($curl === false) {
            throw new CurlInitException('curl_init() failed: cURL extension not available');
        }
        curl_setopt_array($curl, [
            CURLOPT_URL => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 10,
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_HTTPHEADER => [
                'User-Agent: EngineScript/1.0'
            ],
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_MAXREDIRS => 0
        ]);

        return $curl;
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

        $curl = $this->createCurlHandle($url);
        $response = curl_exec($curl); // codacy:ignore - curl_exec() required for API communication
        $httpCode = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_close($curl); // codacy:ignore - curl_close() required for cleanup

        if ($response === false || $httpCode !== 200) {
            return null;
        }

        $data = json_decode($response, true);

        if (json_last_error() !== JSON_ERROR_NONE || !is_array($data)) {
            return null;
        }

        // Return sanitized subset of plugin data
        return $this->sanitizeOutput([
            'name' => $data['name'] ?? '',
            'slug' => $data['slug'] ?? '',
            'version' => $data['version'] ?? '',
            'author' => strip_tags($data['author'] ?? ''),
            'requires' => $data['requires'] ?? '',
            'tested' => $data['tested'] ?? '',
            'requires_php' => $data['requires_php'] ?? '',
            'rating' => (int) ($data['rating'] ?? 0),
            'active_installs' => (int) ($data['active_installs'] ?? 0),
            'last_updated' => $data['last_updated'] ?? '',
            'download_link' => $data['download_link'] ?? ''
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
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                $this->response->cached($cached, $this->getTtl(self::ENDPOINT));
                return;
            }

            // Fetch from Cloudflare status page
            $result = $this->fetchCloudflareStatus();

            if ($result === null) {
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                $this->response->error('Unable to fetch Cloudflare status', ApiResponse::HTTP_BAD_GATEWAY);
                return;
            }

            // Cache and return result
            $this->setCached($cacheKey, $result);
            $this->response->success($result, $this->getTtl(self::ENDPOINT));
        } catch (Exception $e) {
            $this->logSecurityEvent('Cloudflare status error', $e->getMessage());
            // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
            $this->response->serverError('Unable to retrieve Cloudflare status');
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

        $curl = $this->createCurlHandle($url);
        $response = curl_exec($curl); // codacy:ignore - curl_exec() required for API communication
        $httpCode = curl_getinfo($curl, CURLINFO_HTTP_CODE);
        curl_close($curl); // codacy:ignore - curl_close() required for cleanup

        if ($response === false || $httpCode !== 200) {
            return null;
        }

        $data = json_decode($response, true);

        if (json_last_error() !== JSON_ERROR_NONE || !is_array($data)) {
            return null;
        }

        // Return sanitized status data
        return $this->sanitizeOutput([
            'indicator' => $data['status']['indicator'] ?? 'unknown',
            'description' => $data['status']['description'] ?? 'Unknown',
            'updated_at' => $data['page']['updated_at'] ?? null
        ]);
    }
}
