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
            $csrfToken = $this->getSessionValue('csrf_token');
            if ($csrfToken === null) {
                // Generate a new CSRF token if one does not exist
                try {
                    $csrfToken = bin2hex(random_bytes(32));
                } catch (\Exception $e) {
                    // Explicitly handle random_bytes() failure to avoid using an invalid token
                    $this->logSecurityEvent('CSRF token generation failed', $e->getMessage());
                    $this->response->serverError('Unable to generate CSRF token');
                    return;
                }
                $this->setSessionValue('csrf_token', $csrfToken);
            }
            $this->response->success([
                'csrf_token' => $csrfToken,
                'token_name' => '_csrf_token'
            ]);
        } catch (Exception $e) {
            $this->logSecurityEvent('CSRF token error', $e->getMessage());
            $this->response->serverError('Unable to retrieve CSRF token');
        }
    }
}
