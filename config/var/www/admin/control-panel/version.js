/**
 * Dashboard Version Management
 * Single source of truth for cache-busting version strings
 * 
 * UPDATE THIS VERSION when making changes to any dashboard files
 * Format: YYYY.MM.DD.NN (year.month.day.build)
 * 
 * IMPORTANT: After updating, you must also update the hardcoded imports below.
 * This is a limitation of ES6 static imports which don't support template literals.
 */
export const DASHBOARD_VERSION = '2025.11.19.02';

/**
 * Helper function to generate versioned URLs for dynamic imports
 * Use this for dynamic import() statements, not static imports
 */
export function versionedUrl(path) {
    return `${path}?v=${DASHBOARD_VERSION}`;
}
