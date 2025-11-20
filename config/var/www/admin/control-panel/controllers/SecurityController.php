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
            if (isset($_SESSION['csrf_token'])) { // codacy:ignore - $_SESSION required for CSRF protection
                return BaseController::jsonResponse(['token' => $_SESSION['csrf_token']]);
            } else { // codacy:ignore - Else clause needed for explicit error handling with proper HTTP status
                return BaseController::errorResponse('CSRF token not available', 500);
            }
        } catch (Exception $e) {
            self::handleException($e, 'CSRF token');
        }
    }
}
