<?php
/**
 * ExternalServicesController
 * Handles external services endpoints
 * 
 * @version 1.0.0
 */

require_once __DIR__ . '/../classes/BaseController.php';

class ExternalServicesController extends BaseController {
    
    /**
     * GET /external-services/config
     * Get external services configuration
     */
    public static function getConfig() {
        define('ENGINESCRIPT_DASHBOARD', true);
        require_once __DIR__ . '/../external-services/external-services-api.php'; // codacy:ignore - Safe module loading with __DIR__ constant
        handleExternalServicesConfig();
    }
    
    /**
     * GET /external-services/feed
     * Get external service feed status
     */
    public static function getFeed() {
        define('ENGINESCRIPT_DASHBOARD', true);
        require_once __DIR__ . '/../external-services/external-services-api.php';
        handleStatusFeed();
    }
}
