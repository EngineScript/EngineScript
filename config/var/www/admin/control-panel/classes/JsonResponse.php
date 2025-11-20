<?php
/**
 * JsonResponse Utility Class
 * Standalone JSON response helper for scripts that cannot extend BaseController
 * 
 * @version 1.0.0
 * @security HIGH - Provides secure response methods for standalone scripts
 */

class JsonResponse {
    
    /**
     * Send JSON response
     * @param mixed $data Data to send
     * @param int $status_code HTTP status code
     */
    public static function send($data, $status_code = 200) {
        http_response_code($status_code);
        header('Content-Type: application/json');
        echo json_encode(self::sanitizeOutput($data)); // codacy:ignore - echo required for JSON API response
    }
    
    /**
     * Send error response
     * @param string $message Error message
     * @param int $status_code HTTP status code
     */
    public static function error($message, $status_code = 500) {
        http_response_code($status_code);
        header('Content-Type: application/json');
        echo json_encode(['error' => $message]); // codacy:ignore - echo required for JSON API error response
    }
    
    /**
     * Send error response and exit
     * @param string $message Error message
     * @param int $status_code HTTP status code
     */
    public static function errorAndExit($message, $status_code = 500) {
        self::error($message, $status_code);
        exit; // codacy:ignore - exit required for standalone script termination
    }
    
    /**
     * Send 400 Bad Request response and exit
     * @param string $message Error message
     */
    public static function badRequest($message = 'Bad request') {
        self::errorAndExit($message, 400);
    }
    
    /**
     * Send 403 Forbidden response and exit
     * @param string $message Error message
     */
    public static function forbidden($message = 'Forbidden') {
        self::errorAndExit($message, 403);
    }
    
    /**
     * Send 404 Not Found response and exit
     * @param string $message Error message
     */
    public static function notFound($message = 'Not found') {
        self::errorAndExit($message, 404);
    }
    
    /**
     * Send 405 Method Not Allowed response and exit
     * @param string $message Error message
     */
    public static function methodNotAllowed($message = 'Method not allowed') {
        self::errorAndExit($message, 405);
    }
    
    /**
     * Send 429 Rate Limit Exceeded response and exit
     * @param string $message Error message
     */
    public static function rateLimitExceeded($message = 'Rate limit exceeded') {
        self::errorAndExit($message, 429);
    }
    
    /**
     * Sanitize output data
     * @param mixed $data Data to sanitize
     * @return mixed Sanitized data
     */
    private static function sanitizeOutput($data) {
        if (is_array($data)) {
            return array_map([self::class, 'sanitizeOutput'], $data);
        }
        if (is_string($data)) {
            return htmlspecialchars($data, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
        }
        return $data;
    }
}
