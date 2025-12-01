<?php
/**
 * EngineScript Admin Dashboard - CSRF Controller
 * 
 * Handles CSRF token generation and retrieval.
 * 
 * @package EngineScript\Dashboard\API\Controllers
 * @version 1.0.0
 * @security HIGH - CSRF protection
 */

require_once __DIR__ . '/BaseController.php';

/**
 * CSRF Token Controller
 * 
 * Provides CSRF token for frontend requests.
 * Token is stored in session and must be included in state-changing requests.
 */
class CsrfController extends BaseController
{
    /**
     * Get the current CSRF token
     * 
     * Returns the session CSRF token for use in forms and AJAX requests.
     * Token should be included as X-CSRF-Token header or _csrf_token parameter.
     * 
     * Endpoint: GET /csrf-token
     * 
     * @return void Outputs JSON response
     */
    public function getToken()
    {
        try {
            // codacy:ignore - Direct $_SESSION access required for CSRF token response
            if (isset($_SESSION['csrf_token'])) {
                ApiResponse::success([
                    'csrf_token' => $_SESSION['csrf_token'],
                    'token_name' => '_csrf_token'
                ]);
            } else {
                $this->logSecurityEvent('CSRF token missing', 'Session token not set');
                ApiResponse::serverError('Unable to generate CSRF token');
            }
        } catch (Exception $e) {
            $this->logSecurityEvent('CSRF token error', $e->getMessage());
            ApiResponse::serverError('Unable to generate CSRF token');
        }
    }
}
