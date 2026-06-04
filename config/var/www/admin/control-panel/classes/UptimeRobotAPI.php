<?php
/**
 * EngineScript Admin Dashboard - UptimeRobot API Client
 * 
 * Secure wrapper for UptimeRobot API interactions.
 * Handles API authentication, request formatting, and response parsing.
 * 
 * @package EngineScript\Dashboard\API
 * @version 1.0.0
 * @security HIGH - Handles API credentials
 */

require_once __DIR__ . '/CurlInitException.php';

/**
 * UptimeRobot API Client
 * 
 * Provides methods to interact with UptimeRobot's API.
 * 
 * Usage:
 *   $api = new UptimeRobotAPI('your-api-key');
 *   $monitors = $api->getMonitors();
 */
class UptimeRobotAPI
{
    /**
     * UptimeRobot API base URL
     */
    private const API_BASE_URL = 'https://api.uptimerobot.com/v2/';

    /**
     * Request timeout in seconds
     */
    private const REQUEST_TIMEOUT = 10;

    /**
     * Create a new UptimeRobot API instance
     * 
     * @param string $apiKey UptimeRobot API key (read-only key recommended)
     */
    public function __construct(private string $apiKey)
    {
    }

    /**
     * Get all monitors
     * 
     * Fetches all monitors with their current status and uptime ratios.
     * Requests uptime ratios for 1, 7, and 30 days.
     * 
     * @return array|false Array of monitors or false on error
     */
    public function getMonitors(): array|false
    {
        $params = [
            'format' => 'json',
            'custom_uptime_ratios' => '1-7-30', // 1 day, 7 days, 30 days
            'response_times' => 0,
            'logs' => 0
        ];

        $response = $this->makeRequest('getMonitors', $params);

        if ($response === false) {
            return false;
        }

        // Check for successful response
        if (!isset($response['stat']) || $response['stat'] !== 'ok') {
            $this->logError('API returned non-ok status', $response);
            return false;
        }

        if (!isset($response['monitors']) || !is_array($response['monitors'])) {
            return [];
        }

        return $response['monitors'];
    }

    /**
     * Get account details
     * 
     * @return array|false Account details or false on error
     */
    public function getAccountDetails(): array|false
    {
        $params = [
            'format' => 'json'
        ];

        $response = $this->makeRequest('getAccountDetails', $params);

        if ($response === false) {
            return false;
        }

        if (!isset($response['stat']) || $response['stat'] !== 'ok') {
            return false;
        }

        return $response['account'] ?? false;
    }

    /**
     * Make an API request
     * 
     * Uses cURL to make a POST request to the UptimeRobot API.
     * 
     * @param string $endpoint API endpoint (e.g., 'getMonitors')
     * @param array $params Additional parameters to send
     * @return array|false Decoded response or false on error
     */
    private function makeRequest(string $endpoint, array $params = []): array|false
    {
        $url = $this->buildRequestUrl($endpoint);
        if ($url === false) {
            return false;
        }

        $params['api_key'] = $this->apiKey;

        try {
            $curlHandle = $this->createCurlHandle();
        } catch (CurlInitException $e) {
            $this->logError('Unable to initialize cURL handle', ['error' => $e->getMessage()]);
            return false;
        }

        if ($curlHandle === false) {
            return false;
        }

        if (!$this->configureCurlRequest($curlHandle, $url, $params)) {
            curl_close($curlHandle);
            return false;
        }

        return $this->decodeCurlResult($this->executeCurlRequest($curlHandle));
    }

    private function buildRequestUrl(string $endpoint): string|false
    {
        if (!preg_match('/^[a-zA-Z]+$/', $endpoint)) {
            $this->logError('Invalid endpoint', ['endpoint' => $endpoint]);
            return false;
        }

        return self::API_BASE_URL . $endpoint;
    }

    private function createCurlHandle(): CurlHandle|false
    {
        if (!function_exists('curl_init')) {
            $this->logError('cURL not available', []);
            return false;
        }

        // codacy:ignore - curl_init() required for API communication in standalone service
        $curlHandle = curl_init();
        if ($curlHandle === false) {
            throw new CurlInitException('Unable to initialize cURL handle');
        }

        return $curlHandle;
    }

    private function configureCurlRequest(CurlHandle $curlHandle, string $url, array $params): bool
    {
        // codacy:ignore - curl functions required for secure API communication
        $optionsSet = curl_setopt_array($curlHandle, [
            CURLOPT_URL => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => http_build_query($params),
            CURLOPT_TIMEOUT => self::REQUEST_TIMEOUT,
            CURLOPT_CONNECTTIMEOUT => 5,
            CURLOPT_HTTPHEADER => [
                'Content-Type: application/x-www-form-urlencoded',
                'Cache-Control: no-cache'
            ],
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_MAXREDIRS => 0
        ]);

        if ($optionsSet === false) {
            $this->logError('Unable to configure cURL request', []);
            return false;
        }

        return true;
    }

    /**
     * @return array{response: string|false, http_code: int, error: string}
     */
    private function executeCurlRequest(CurlHandle $curlHandle): array
    {
        // codacy:ignore - curl_exec() required for API communication
        $response = curl_exec($curlHandle);
        $result = [
            'response' => is_string($response) ? $response : false,
            'http_code' => (int) curl_getinfo($curlHandle, CURLINFO_HTTP_CODE),
            'error' => curl_error($curlHandle),
        ];

        // codacy:ignore - curl_close() required for cleanup
        curl_close($curlHandle);

        return $result;
    }

    /**
     * @param array{response: string|false, http_code: int, error: string} $result
     */
    private function decodeCurlResult(array $result): array|false
    {
        if ($result['response'] === false) {
            $this->logError('cURL request failed', ['error' => $result['error']]);
            return false;
        }

        if ($result['http_code'] !== 200) {
            $this->logError('API returned non-200 status', ['http_code' => $result['http_code']]);
            return false;
        }

        try {
            $decoded = json_decode($result['response'], true, 512, JSON_THROW_ON_ERROR);
        } catch (JsonException $e) {
            $this->logError('Invalid JSON response', ['error' => $e->getMessage()]);
            return false;
        }

        return is_array($decoded) ? $decoded : false;
    }

    /**
     * Log an error
     * 
     * @param string $message Error message
     * @param array $context Additional context
     * @return void
     */
    private function logError(string $message, array $context): void
    {
        // Sanitize message for logging
        $safe_message = preg_replace('/[\x00-\x1F\x7F]/', ' ', $message);
        $safe_message = substr($safe_message, 0, 255);

        // Don't log API key in context
        if (isset($context['api_key'])) {
            $context['api_key'] = '[REDACTED]';
        }

        // Sanitize context values
        $safe_context = [];
        foreach ($context as $key => $value) {
            if (is_string($value)) {
                $safe_context[$key] = substr(preg_replace('/[\x00-\x1F\x7F]/', ' ', $value), 0, 255);
            } elseif (is_numeric($value)) {
                $safe_context[$key] = $value;
            }
        }

        $log_entry = date('Y-m-d H:i:s') . " [UptimeRobotAPI] " . $safe_message;
        if (!empty($safe_context)) {
            $log_entry .= " - " . json_encode($safe_context);
        }
        $log_entry .= "\n";

        error_log($log_entry, 3, '/var/log/EngineScript/enginescript-api.log');
    }
}
