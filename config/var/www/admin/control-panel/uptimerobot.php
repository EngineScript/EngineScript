<?php
/**
 * Uptime Robot API Integration for EngineScript Admin
 * Website monitoring and uptime tracking functionality
 * 
 * @version 1.0.0
 * @security MEDIUM - External API integration
 */

class UptimeRobotAPI {
    private $api_key;
    private $api_url = 'https://api.uptimerobot.com/v2/';
    
    public function __construct($api_key = null) {
        // Load API key from config file or environment
        $this->api_key = $api_key ?: $this->loadApiKey();
    }
    
    /**
     * Load API key from configuration file
     */
    private function loadApiKey() {
        $config_file = '/etc/enginescript/uptimerobot.conf';
        if (file_exists($config_file)) { // codacy:ignore - file_exists() required for configuration file checking in standalone service
            $content = file_get_contents($config_file); // codacy:ignore - file_get_contents() required for configuration reading in standalone service
            $lines = explode("\n", $content);
            
            foreach ($lines as $line) {
                $line = trim($line);
                if (empty($line) || strpos($line, '#') === 0) {
                    continue; // Skip empty lines and comments
                }
                
                if (strpos($line, '=') !== false) {
                    list($key, $value) = explode('=', $line, 2);
                    if (trim($key) === 'api_key') {
                        return trim($value);
                    }
                }
            }
        }
        return null;
    }
    
    /**
     * Make API request to Uptime Robot
     */
    private function makeRequest($endpoint, $params = []) {
        if (!$this->api_key) {
            throw new Exception('Uptime Robot API key not configured');
        }
        
        $params['api_key'] = $this->api_key;
        $params['format'] = 'json';
        
        $curl_handle = curl_init(); // codacy:ignore - cURL required for external API communication in standalone service
        curl_setopt_array($curl_handle, [ // codacy:ignore - cURL required for external API communication in standalone service
            CURLOPT_URL => $this->api_url . $endpoint,
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => http_build_query($params),
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 30,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_USERAGENT => 'EngineScript-Admin/1.0'
        ]);
        
        $response = curl_exec($curl_handle); // codacy:ignore - cURL required for external API communication in standalone service
        $http_code = curl_getinfo($curl_handle, CURLINFO_HTTP_CODE); // codacy:ignore - cURL required for external API communication in standalone service
        $error = curl_error($curl_handle); // codacy:ignore - cURL required for external API communication in standalone service
        curl_close($curl_handle); // codacy:ignore - cURL required for external API communication in standalone service
        
        if ($error) {
            throw new Exception('Curl error: ' . htmlspecialchars($error, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')); // codacy:ignore - htmlspecialchars() used for XSS prevention
        }
        
        if ($http_code !== 200) {
            throw new Exception('HTTP error: ' . (int)$http_code);
        }
        
        $data = json_decode($response, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new Exception('Invalid JSON response');
        }
        
        if ($data['stat'] !== 'ok') {
            $error_message = isset($data['error']['message']) ? 
                htmlspecialchars($data['error']['message'], ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8') : 
                'Unknown error';
            throw new Exception('API error: ' . $error_message); // codacy:ignore - $error_message is already escaped above
        }
        
        return $data;
    }
    
    /**
     * Get all monitors
     */
    public function getMonitors($monitor_ids = null) {
        $params = [];
        if ($monitor_ids) {
            $params['monitors'] = is_array($monitor_ids) ? implode('-', $monitor_ids) : $monitor_ids;
        }
        
        $response = $this->makeRequest('getMonitors', $params);
        return $response['monitors'] ?? [];
    }
    
    /**
     * Create a new monitor
     */
    public function createMonitor($url, $friendly_name, $type = 1) {
        $params = [
            'type' => $type, // 1 = HTTP(s), 2 = Keyword, 3 = Ping, 4 = Port
            'url' => $url,
            'friendly_name' => $friendly_name
        ];
        
        $response = $this->makeRequest('newMonitor', $params);
        return $response['monitor'] ?? null;
    }
    
    /**
     * Delete a monitor
     */
    public function deleteMonitor($monitor_id) {
        $params = ['id' => $monitor_id];
        $response = $this->makeRequest('deleteMonitor', $params);
        return $response['monitor'] ?? null;
    }
    
    /**
     * Get account details
     */
    public function getAccountDetails() {
        $response = $this->makeRequest('getAccountDetails');
        return $response['account'] ?? null;
    }
    
    /**
     * Get formatted monitor status for dashboard
     */
    public function getMonitorStatus($monitor_ids = null) {
        try {
            $monitors = $this->getMonitors($monitor_ids);
            $status_data = [];
            
            foreach ($monitors as $monitor) {
                $status_data[] = [
                    'id' => $monitor['id'],
                    'name' => $monitor['friendly_name'],
                    'url' => $monitor['url'],
                    'status' => $this->getStatusText($monitor['status']),
                    'status_code' => $monitor['status'],
                    'uptime_ratio' => round($monitor['all_time_uptime_ratio'] ?? 0, 2),
                    'response_time' => $monitor['average_response_time'] ?? 0,
                    'last_check' => isset($monitor['logs'][0]['datetime']) ? 
                        date('Y-m-d H:i:s', $monitor['logs'][0]['datetime']) : 'Unknown'
                ];
            }
            
            return $status_data;
        } catch (Exception $e) {
            error_log('Uptime Robot API Error: ' . $e->getMessage());
            return [];
        }
    }
    
    /**
     * Convert status code to text
     */
    private function getStatusText($status_code) {
        switch ($status_code) {
            case 0: return 'Paused';
            case 1: return 'Not checked yet';
            case 2: return 'Up';
            case 8: return 'Seems down';
            case 9: return 'Down';
            default: return 'Unknown';
        }
    }
    
    /**
     * Check if API is configured
     */
    public function isConfigured() {
        return !empty($this->api_key);
    }
}
?>
