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
     * API key for authentication
     * 
     * @var string
     */
    private $apiKey;

    /**
     * Create a new UptimeRobot API instance
     * 
     * @param string $apiKey UptimeRobot API key (read-only key recommended)
     */
    public function __construct($apiKey)
    {
        $this->apiKey = $apiKey;
    }

    /**
     * Get all monitors
     * 
     * Fetches all monitors with their current status and uptime ratios.
     * Requests uptime ratios for 1, 7, and 30 days.
     * 
     * @return array|false Array of monitors or false on error
     */
    public function getMonitors()
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
    public function getAccountDetails()
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

        return isset($response['account']) ? $response['account'] : false;
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
    private function makeRequest($endpoint, array $params = [])
    {
        // Validate endpoint to prevent injection
        if (!preg_match('/^[a-zA-Z]+$/', $endpoint)) {
            $this->logError('Invalid endpoint', ['endpoint' => $endpoint]);
            return false;
        }

        $url = self::API_BASE_URL . $endpoint;

        // Add API key to parameters
        $params['api_key'] = $this->apiKey;

        // Check if cURL is available
        if (!function_exists('curl_init')) {
            $this->logError('cURL not available', []);
            return false;
        }

        // Initialize cURL
        // codacy:ignore - curl_init() required for API communication in standalone service
        $ch = curl_init();

        // Set cURL options
        // codacy:ignore - curl functions required for secure API communication
        curl_setopt_array($ch, [
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
            // Security settings
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_MAXREDIRS => 0
        ]);

        // Execute request
        // codacy:ignore - curl_exec() required for API communication
        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);

        // codacy:ignore - curl_close() required for cleanup
        curl_close($ch);

        // Check for cURL errors
        if ($response === false) {
            $this->logError('cURL request failed', ['error' => $error]);
            return false;
        }

        // Check HTTP status code
        if ($httpCode !== 200) {
            $this->logError('API returned non-200 status', ['http_code' => $httpCode]);
            return false;
        }

        // Decode JSON response
        $decoded = json_decode($response, true);

        if (json_last_error() !== JSON_ERROR_NONE) {
            $this->logError('Invalid JSON response', ['error' => json_last_error_msg()]);
            return false;
        }

        return $decoded;
    }

    /**
     * Log an error
     * 
     * @param string $message Error message
     * @param array $context Additional context
     * @return void
     */
    private function logError($message, $context)
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
