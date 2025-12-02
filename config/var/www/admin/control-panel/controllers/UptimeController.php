<?php
/**
 * EngineScript Admin Dashboard - Uptime Controller
 * 
 * Handles UptimeRobot API integration endpoints.
 * 
 * @package EngineScript\Dashboard\API\Controllers
 * @version 1.0.0
 */

require_once __DIR__ . '/BaseController.php';
require_once __DIR__ . '/../classes/UptimeRobotAPI.php';

/**
 * Uptime Controller
 * 
 * Provides UptimeRobot overall status and monitor details.
 */
class UptimeController extends BaseController
{
    /**
     * API endpoint paths
     */
    private const ENDPOINT_STATUS = '/monitoring/uptime';
    private const ENDPOINT_MONITORS = '/monitoring/uptime/monitors';

    /**
     * UptimeRobot API instance
     * 
     * @var UptimeRobotAPI|null
     */
    private $uptimeApi = null;

    /**
     * Get UptimeRobot API instance
     * 
     * @return UptimeRobotAPI|null Returns null if not configured
     */
    private function getUptimeApi()
    {
        if ($this->uptimeApi === null) {
            $configPath = '/etc/enginescript/uptimerobot.conf';
            // codacy:ignore - file_exists() required for config checking in standalone service
            if (file_exists($configPath)) {
                // codacy:ignore - parse_ini_file() required for config parsing in standalone service
                $config = parse_ini_file($configPath);
                if ($config && !empty($config['api_key'])) {
                    $this->uptimeApi = new UptimeRobotAPI($config['api_key']);
                }
            }
        }
        return $this->uptimeApi;
    }

    /**
     * Get overall uptime status
     * 
     * Returns aggregated status from UptimeRobot account.
     * 
     * Endpoint: GET /uptime/status
     * 
     * @return void Outputs JSON response
     */
    public function getStatus()
    {
        try {
            // Check cache first
            $cached = $this->getCached(self::ENDPOINT_STATUS);
            if ($cached !== null) {
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                ApiResponse::cached($cached, $this->getTtl(self::ENDPOINT_STATUS));
                return;
            }

            $api = $this->getUptimeApi();

            if (!$api) {
                $result = [
                    'enabled' => false,
                    'reason' => 'UptimeRobot API not configured'
                ];
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                ApiResponse::success($result, $this->getTtl(self::ENDPOINT_STATUS));
                return;
            }

            $monitors = $api->getMonitors();

            if (!$monitors) {
                $result = [
                    'enabled' => true,
                    'error' => 'Failed to fetch monitors from UptimeRobot API'
                ];
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                ApiResponse::success($result, $this->getTtl(self::ENDPOINT_STATUS));
                return;
            }

            // Calculate overall status
            $overall = $this->calculateOverallStatus($monitors);
            $result = $this->sanitizeOutput($overall);

            // Cache the result
            $this->setCached(self::ENDPOINT_STATUS, $result);

            // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
            ApiResponse::success($result, $this->getTtl(self::ENDPOINT_STATUS));
        } catch (Exception $e) {
            $this->logSecurityEvent('Uptime status error', $e->getMessage());
            // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
            ApiResponse::serverError('Unable to retrieve uptime status');
        }
    }

    /**
     * Get detailed monitor list
     * 
     * Returns all monitors with their current status and uptime ratios.
     * 
     * Endpoint: GET /uptime/monitors
     * 
     * @return void Outputs JSON response
     */
    public function getMonitors()
    {
        try {
            // Check cache first
            $cached = $this->getCached(self::ENDPOINT_MONITORS);
            if ($cached !== null) {
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                ApiResponse::cached($cached, $this->getTtl(self::ENDPOINT_MONITORS));
                return;
            }

            $api = $this->getUptimeApi();

            if (!$api) {
                $result = [
                    'enabled' => false,
                    'reason' => 'UptimeRobot API not configured',
                    'monitors' => []
                ];
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                ApiResponse::success($result, $this->getTtl(self::ENDPOINT_MONITORS));
                return;
            }

            $monitors = $api->getMonitors();

            if (!$monitors) {
                $result = [
                    'enabled' => true,
                    'error' => 'Failed to fetch monitors from UptimeRobot API',
                    'monitors' => []
                ];
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                ApiResponse::success($result, $this->getTtl(self::ENDPOINT_MONITORS));
                return;
            }

            // Format monitors for output
            $formatted = $this->formatMonitors($monitors);
            $result = $this->sanitizeOutput($formatted);

            // Cache the result
            $this->setCached(self::ENDPOINT_MONITORS, $result);

            // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
            ApiResponse::success($result, $this->getTtl(self::ENDPOINT_MONITORS));
        } catch (Exception $e) {
            $this->logSecurityEvent('Uptime monitors error', $e->getMessage());
            // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
            ApiResponse::serverError('Unable to retrieve uptime monitors');
        }
    }

    /**
     * Calculate overall status from monitors
     * 
     * @param array $monitors Raw monitor data from API
     * @return array Overall status summary
     */
    private function calculateOverallStatus(array $monitors)
    {
        $total = count($monitors);
        $upCount = 0;
        $down = 0;
        $paused = 0;

        foreach ($monitors as $monitor) {
            $status = isset($monitor['status']) ? (int) $monitor['status'] : 0;
            switch ($status) {
                case 2: // Up
                    $up++;
                    break;
                case 8: // Seems down
                case 9: // Down
                    $down++;
                    break;
                case 0: // Paused
                case 1: // Not checked yet
                    $paused++;
                    break;
                default:
                    break;
            }
        }

        // Determine overall status
        $overall_status = 'unknown';
        if ($total > 0) {
            if ($down > 0) {
                $overall_status = 'critical';
            } elseif ($up === $total) {
                $overall_status = 'healthy';
            } elseif ($up > 0) {
                $overall_status = 'partial';
            }
        }

        return [
            'enabled' => true,
            'overall_status' => $overall_status,
            'total_monitors' => $total,
            'up' => $up,
            'down' => $down,
            'paused' => $paused
        ];
    }

    /**
     * Format monitors for output
     * 
     * @param array $monitors Raw monitor data from API
     * @return array Formatted monitor list
     */
    private function formatMonitors(array $monitors)
    {
        $formatted = [];

        foreach ($monitors as $monitor) {
            $status = isset($monitor['status']) ? (int) $monitor['status'] : 0;
            $status_text = $this->getStatusText($status);

            $formatted[] = [
                'id' => isset($monitor['id']) ? (int) $monitor['id'] : 0,
                'name' => isset($monitor['friendly_name']) ? $monitor['friendly_name'] : 'Unknown',
                'url' => isset($monitor['url']) ? $monitor['url'] : '',
                'status' => $status,
                'status_text' => $status_text,
                'uptime_day' => isset($monitor['custom_uptime_ratio']) ? $this->parseUptimeRatio($monitor['custom_uptime_ratio'], 0) : null,
                'uptime_week' => isset($monitor['custom_uptime_ratio']) ? $this->parseUptimeRatio($monitor['custom_uptime_ratio'], 1) : null,
                'uptime_month' => isset($monitor['custom_uptime_ratio']) ? $this->parseUptimeRatio($monitor['custom_uptime_ratio'], 2) : null,
                'last_check' => isset($monitor['last_check_time']) ? (int) $monitor['last_check_time'] : null
            ];
        }

        return [
            'enabled' => true,
            'total' => count($formatted),
            'monitors' => $formatted
        ];
    }

    /**
     * Get human-readable status text
     * 
     * @param int $status UptimeRobot status code
     * @return string Status text
     */
    private function getStatusText(int $status)
    {
        $statuses = [
            0 => 'Paused',
            1 => 'Not checked yet',
            2 => 'Up',
            8 => 'Seems down',
            9 => 'Down'
        ];

        return isset($statuses[$status]) ? $statuses[$status] : 'Unknown';
    }

    /**
     * Parse uptime ratio from API response
     * 
     * @param string $ratio Hyphen-separated uptime ratios
     * @param int $index Index to extract (0=day, 1=week, 2=month)
     * @return float|null Parsed ratio or null
     */
    private function parseUptimeRatio($ratio, int $index)
    {
        if (empty($ratio)) {
            return null;
        }

        $parts = explode('-', $ratio);
        if (isset($parts[$index])) {
            return (float) $parts[$index];
        }

        return null;
    }
}
