<?php
/**
 * SecurityController
 * Handles security-related endpoints
 * 
 * @version 1.0.0
 */

require_once __DIR__ . '/../classes/BaseController.php';

class SecurityController extends BaseController {
    
    /**
     * GET /csrf-token
     * Return CSRF token
     */
    public static function getCsrfToken() {
        try {
            if (isset($_SESSION['csrf_token'])) {
                self::jsonResponse([
                    'csrf_token' => $_SESSION['csrf_token'],
                    'token_name' => '_csrf_token'
                ]);
            } else {
                self::errorResponse('Unable to generate CSRF token');
            }
        } catch (Exception $e) {
            self::handleException($e, 'CSRF token');
        }
    }
}
