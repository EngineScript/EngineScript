<?php
/**
 * AlertService
 * System alerts and warnings
 * 
 * @version 1.0.0
 */

class AlertService {
    
    /**
     * Get system alerts
     * @return array System alerts
     */
    public static function getSystemAlerts() {
        $alerts = [];
        
        // Check disk usage
        $disk_usage = (float)str_replace('%', '', self::getDiskUsage());
        if ($disk_usage > 90) {
            $alerts[] = [
                'message' => 'High disk usage detected',
                'time' => 'Now',
                'type' => 'warning'
            ];
        }
        
        // Check memory usage
        $memory_usage = (float)str_replace('%', '', self::getMemoryUsage());
        if ($memory_usage > 85) {
            $alerts[] = [
                'message' => 'High memory usage detected',
                'time' => 'Now',
                'type' => 'warning'
            ];
        }
        
        // If no alerts, return success message
        if (empty($alerts)) {
            $alerts[] = [
                'message' => 'All systems operational',
                'time' => 'Just now',
                'type' => 'info'
            ];
        }
        
        return $alerts;
    }
    
    /**
     * Get disk usage percentage
     * @return string Disk usage percentage
     */
    private static function getDiskUsage() {
        $total = disk_total_space('/');
        $free = disk_free_space('/');
        if ($total && $free) {
            $used = $total - $free;
            return round(($used / $total) * 100, 1) . '%';
        }
        return '0%';
    }
    
    /**
     * Get memory usage percentage
     * @return string Memory usage percentage
     */
    private static function getMemoryUsage() {
        if (file_exists('/proc/meminfo')) { // codacy:ignore - file_exists() required for /proc filesystem check
            $meminfo = file_get_contents('/proc/meminfo'); // codacy:ignore - file_get_contents() required for memory info reading
            preg_match('/MemTotal:\s+(\d+)/', $meminfo, $total);
            preg_match('/MemAvailable:\s+(\d+)/', $meminfo, $available);
            
            if (!empty($total[1]) && !empty($available[1])) {
                $total_mem = $total[1];
                $available_mem = $available[1];
                $used_mem = $total_mem - $available_mem;
                return round(($used_mem / $total_mem) * 100, 1) . '%';
            }
        }
        return '0%';
    }
}
