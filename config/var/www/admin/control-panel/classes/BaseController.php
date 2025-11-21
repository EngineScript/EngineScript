<?php
/**
 * BaseController Class
 * Base controller with common functionality
 * 
 * @version 1.0.0
 * @security HIGH - Provides secure response methods
 */

class BaseController {
    
    /**
     * Send JSON response
     * @param mixed $data Data to send
     * @param int $status_code HTTP status code
     */
    protected static function jsonResponse($data, $status_code = 200) {
        http_response_code($status_code);
        echo json_encode(self::sanitizeOutput($data)); // codacy:ignore - echo required for JSON API response
    }
    
    /**
     * Send error response
     * @param string $message Error message
     * @param int $status_code HTTP status code
     */
    protected static function errorResponse($message, $status_code = 500) {
        http_response_code($status_code);
        echo json_encode(['error' => $message]); // codacy:ignore - echo required for JSON API error response
    }
    
    /**
     * Sanitize output data
     * @param mixed $data Data to sanitize
     * @return mixed Sanitized data
     */
    protected static function sanitizeOutput($data) {
        if (is_array($data)) {
            return array_map([self::class, 'sanitizeOutput'], $data);
        }
        if (is_string($data)) {
            return htmlspecialchars($data, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        }
        return $data;
    }
    
    /**
     * Log security event
     * @param string $event Event description
     * @param string $details Additional details
     */
    protected static function logSecurityEvent($event, $details = '') {
        $safe_event = preg_replace('/[\r\n\t]/', ' ', $event);
        $safe_event = substr(trim($safe_event), 0, 255);
        
        $log_entry = date('Y-m-d H:i:s') . " [SECURITY] " . $safe_event;
        
        if ($details) {
            $safe_details = preg_replace('/[\r\n\t]/', ' ', $details);
            $safe_details = substr(trim($safe_details), 0, 255);
            $log_entry .= " - " . $safe_details;
        }
        
        $client_ip = isset($_SERVER['REMOTE_ADDR']) ? $_SERVER['REMOTE_ADDR'] : 'unknown'; // codacy:ignore - $_SERVER access required for security logging, wp_unslash() not available in standalone API
        if ($client_ip !== 'unknown' && !filter_var($client_ip, FILTER_VALIDATE_IP)) {
            $client_ip = 'invalid';
        }
        $log_entry .= " - IP: " . $client_ip . "\n";
        
        $log_file = '/var/log/EngineScript/enginescript-api-security.log';
        error_log($log_entry, 3, $log_file);
    }
    
    /**
     * Handle exceptions uniformly across all controllers
     */
    // codacy:ignore - Short variable name is standard convention for exceptions
    protected static function handleException($e, $context) {
        self::logSecurityEvent($context . ' error', $e->getMessage());
        self::errorResponse('Unable to process request');
    }
}
