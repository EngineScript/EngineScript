<?php

/**
 * EngineScript Admin Dashboard - CSRF Controller
 *
 * Retrieves the CSRF token initialized by the API entry point.
 *
 * @package EngineScript\Dashboard\API\Controllers
 * @version 1.0.0
 * @security HIGH - CSRF protection
 */

declare(strict_types=1);

require_once __DIR__ . '/BaseController.php';

/**
 * CSRF Token Controller
 *
 * Provides CSRF token for frontend requests.
 * Token is stored in session and must be included in state-changing requests.
 *
 * @psalm-api
 */
final class CsrfController extends BaseController
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
     * @psalm-api
     */
    public function getToken(): void
    {
        try {
            $csrfToken = $this->stringOrNull($this->session->get('csrf_token'));
            if ($csrfToken === null) {
                $this->response->serverError('Unable to retrieve CSRF token');
                return;
            }
            $this->response->success([
                'csrf_token' => $csrfToken,
                'token_name' => '_csrf_token',
            ]);
        } catch (Throwable $e) {
            $this->securityLogger->write('CSRF token error', $e->getMessage());
            $this->response->serverError('Unable to retrieve CSRF token');
        }
    }
}
