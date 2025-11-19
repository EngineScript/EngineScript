<?php
/**
 * ActivityService
 * Recent activity tracking
 * 
 * @version 1.0.0
 */

class ActivityService {
    
    /**
     * Get recent activity
     * @return array Recent activities
     */
    public static function getRecentActivity() {
        $activities = [];
        
        try {
            $ssh_activity = self::checkRecentSSHActivity();
            if ($ssh_activity) {
                $activities[] = $ssh_activity;
            }
            
            $activities[] = [
                'message' => 'System status updated',
                'time' => 'Just now',
                'icon' => 'fa-sync-alt'
            ];
        } catch (Exception $e) {
            error_log('Recent activity error: ' . $e->getMessage());
            $activities[] = [
                'message' => 'System monitoring active',
                'time' => 'Just now',
                'icon' => 'fa-shield-alt'
            ];
        }
        
        return $activities;
    }
    
    /**
     * Check recent SSH activity
     * @return array|null SSH activity or null
     */
    private static function checkRecentSSHActivity() {
        $auth_log = '/var/log/auth.log';
        $real_auth_log = realpath($auth_log);
        
        if (!self::isValidLogFile($real_auth_log, $auth_log)) {
            return null;
        }
        
        $handle = fopen($real_auth_log, 'r');
        if (!$handle) {
            return null;
        }
        
        $ssh_activity = self::parseAuthLogForActivity($handle);
        fclose($handle);
        
        return $ssh_activity;
    }
    
    /**
     * Validate log file
     * @param string $real_path Real path
     * @param string $expected_path Expected path
     * @return bool
     */
    private static function isValidLogFile($real_path, $expected_path) {
        return $real_path && 
               $real_path === $expected_path && 
               file_exists($real_path) && 
               is_readable($real_path);
    }
    
    /**
     * Parse auth log for activity
     * @param resource $handle File handle
     * @return array|null Activity or null
     */
    private static function parseAuthLogForActivity($handle) {
        $file_size = filesize('/var/log/auth.log');
        if (!$file_size || $file_size <= 0) {
            return null;
        }
        
        fseek($handle, max(0, $file_size - 1024), SEEK_SET);
        $content = fread($handle, 1024);
        
        if ($content && strpos($content, 'Accepted') !== false) {
            return [
                'message' => 'Recent SSH login detected',
                'time' => '5 minutes ago',
                'icon' => 'fa-sign-in-alt'
            ];
        }
        
        return null;
    }
}
