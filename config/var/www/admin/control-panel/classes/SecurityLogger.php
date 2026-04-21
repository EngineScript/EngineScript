<?php
/**
 * EngineScript Admin Dashboard - Security Logger
 * 
 * Provides centralized secure activity logging functionality,
 * preventing log injection and ensuring consistent log formatting.
 * 
 * @package EngineScript\Dashboard\Classes
 * @version 1.0.0
 * @security HIGH - Core logging infrastructure
 */
class SecurityLogger
{
    /**
     * Log a security event to the designated secure log file.
     * 
     * @param string $event   The primary event description
     * @param string $details Additional details about the event
     * @return void
     */
    public static function log(string $event, string $details = ''): void
    {
        $safe_event = self::sanitize($event);
        
        $log_entry = date('Y-m-d H:i:s') . " [SECURITY] " . $safe_event;
        
        if ($details) {
            $safe_details = self::sanitize($details);
            $log_entry .= " - " . $safe_details;
        }
        
        // Sanitize IP address for logging
        // codacy:ignore - Direct $_SERVER access required, wp_unslash() not available in standalone API
        $client_ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
        
        if ($client_ip !== 'unknown') {
            // Validate IP format to prevent injection
            if (!filter_var($client_ip, FILTER_VALIDATE_IP)) {
                $client_ip = 'invalid';
            }
        }
        
        $log_entry .= " - IP: " . $client_ip . "\n";
        
        // Log to a secure location
        $log_file = '/var/log/EngineScript/enginescript-api-security.log';
        error_log($log_entry, 3, $log_file);
    }

    /**
     * Sanitize input for safe log output
     * 
     * Prevents log injection attacks by escaping control characters.
     * 
     * @param string $input Raw input to sanitize
     * @return string Sanitized string safe for logging
     */
    private static function sanitize(string $input): string
    {
        // Remove all control characters (ASCII 0-31 and 127)
        // This includes \r, \n, \t, and other dangerous characters
        $sanitized = preg_replace('/[\x00-\x1F\x7F]/', ' ', $input);
        
        if (!is_string($sanitized)) {
            $sanitized = '';
        }
        
        // Collapse multiple spaces
        $sanitized = preg_replace('/\s+/', ' ', $sanitized);
        
        if (!is_string($sanitized)) {
            $sanitized = '';
        }
        
        // Limit length to prevent log flooding
        $sanitized = substr(trim($sanitized), 0, 255);
        
        // Encode any remaining special characters for safe output
        // codacy:ignore - addcslashes() required for log injection prevention
        return addcslashes($sanitized, '\\');
    }
}
