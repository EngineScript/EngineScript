<?php
/**
 * SitesController
 * Handles WordPress sites endpoints
 * 
 * @version 1.0.0
 */

require_once __DIR__ . '/../classes/BaseController.php'; // codacy:ignore - Safe class loading with __DIR__ constant
require_once __DIR__ . '/../services/WordPressService.php'; // codacy:ignore - Safe class loading with __DIR__ constant

class SitesController extends BaseController {
    
    /**
     * GET /sites
     * Get list of WordPress sites
     */
    public static function getSites() {
        try {
            // codacy:ignore - Static utility class pattern for stateless service operations
            $sites = WordPressService::getWordPressSites();
            self::jsonResponse($sites);
        } catch (Exception $e) {
            self::handleException($e, 'Sites');
        }
    }
    
    /**
     * GET /sites/count
     * Get count of WordPress sites
     */
    public static function getCount() {
        try {
            $sites = WordPressService::getWordPressSites();
            self::jsonResponse(['count' => count($sites)]);
        } catch (Exception $e) {
            self::handleException($e, 'Sites count');
        }
    }
}
