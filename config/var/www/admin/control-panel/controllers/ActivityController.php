<?php
/**
 * ActivityController
 * Handles activity and alerts endpoints
 * 
 * @version 1.0.0
 */

require_once __DIR__ . '/../classes/BaseController.php';
require_once __DIR__ . '/../services/ActivityService.php';
require_once __DIR__ . '/../services/AlertService.php';

class ActivityController extends BaseController {
    
    /**
     * GET /activity/recent
     * Get recent activity
     */
    public static function getRecent() {
        try {
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
            $alerts = AlertService::getSystemAlerts();
            self::jsonResponse($alerts);
        } catch (Exception $e) {
            self::handleException($e, 'Alerts');
        }
    }
}
