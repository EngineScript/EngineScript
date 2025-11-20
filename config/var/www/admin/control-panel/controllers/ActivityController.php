<?php
/**
 * ActivityController
 * Handles activity and alerts endpoints
 * 
 * @version 1.0.0
 */

require_once __DIR__ . '/../classes/BaseController.php'; // codacy:ignore - Safe class loading with __DIR__ constant
require_once __DIR__ . '/../services/ActivityService.php'; // codacy:ignore - Safe class loading with __DIR__ constant
require_once __DIR__ . '/../services/AlertService.php'; // codacy:ignore - Safe class loading with __DIR__ constant

class ActivityController extends BaseController {
    
    /**
     * GET /activity/recent
     * Get recent activity
     */
    public static function getRecent() {
        try {
            // codacy:ignore - Static utility class pattern for stateless service operations
            $activity = ActivityService::getRecentActivity();
            self::jsonResponse($activity);
        } catch (Exception $e) {
            self::handleException($e, 'Recent activity');
        }
    }
    
    /**
     * GET /alerts
     * Get system alerts
     */
    public static function getAlerts() {
        try {
            // codacy:ignore - Static utility class pattern for stateless service operations
            $alerts = AlertService::getSystemAlerts();
            self::jsonResponse($alerts);
        } catch (Exception $e) {
            self::handleException($e, 'Alerts');
        }
    }
}
