<?php
/**
 * MonitoringController
 * Handles monitoring endpoints
 * 
 * @version 1.0.0
 */

require_once __DIR__ . '/../classes/BaseController.php';

class MonitoringController extends BaseController {
    
    /**
     * GET /monitoring/uptime
     * Get uptime monitoring status
     */
    public static function getUptimeStatus() {
        try {
            require_once __DIR__ . '/../uptimerobot.php'; // codacy:ignore - Safe class loading with __DIR__ constant
            $uptime = new UptimeRobotAPI();
            
            if (!$uptime->isConfigured()) {
                self::jsonResponse([
                    'configured' => false,
                    'message' => 'Uptime Robot API key not configured'
                ]);
                return;
            }
            
            $monitors = $uptime->getMonitorStatus();
            $summary = [
                'configured' => true,
                'total_monitors' => count($monitors),
                // codacy:ignore - Short variable name acceptable in lambda function scope
                'up_monitors' => count(array_filter($monitors, function($m) { return $m['status_code'] == 2; })),
                // codacy:ignore - Short variable name acceptable in lambda function scope
                'down_monitors' => count(array_filter($monitors, function($m) { return in_array($m['status_code'], [8, 9]); })),
                'average_uptime' => count($monitors) > 0 ? 
                    round(array_sum(array_column($monitors, 'uptime_ratio')) / count($monitors), 2) : 0
            ];
            
            self::jsonResponse($summary);
        } catch (Exception $e) {
            self::errorResponse('Unable to retrieve uptime status', 500);
        }
    }
    
    /**
     * GET /monitoring/uptime/monitors
     * Get uptime monitors list
     */
    public static function getUptimeMonitors() {
        try {
            require_once __DIR__ . '/../uptimerobot.php';
            $uptime = new UptimeRobotAPI();
            
            if (!$uptime->isConfigured()) {
                self::jsonResponse([
                    'configured' => false,
                    'monitors' => [],
                    'message' => 'Uptime Robot API key not configured'
                ]);
                return;
            }
            
            $monitors = $uptime->getMonitorStatus();
            self::jsonResponse([
                'configured' => true,
                'monitors' => $monitors
            ]);
        } catch (Exception $e) {
            self::errorResponse('Unable to retrieve monitors', 500);
        }
    }
}
