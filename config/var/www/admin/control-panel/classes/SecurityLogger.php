<?php

/**
 * EngineScript Admin Dashboard - Security Logger
 *
 * Provides centralized secure activity logging functionality,
 * preventing log injection and ensuring consistent log formatting.
 *
 * @package EngineScript\Dashboard\Classes
 * @version 1.0.0
 * @security HIGH - Core logging infrastructure
 */

declare(strict_types=1);

require_once __DIR__ . '/Request.php';

final readonly class SecurityLogger
{
    public const string LOG_FILE = '/var/log/EngineScript/enginescript-api-security.log';

    /**
     * @param string $logFile The log file; replaced only by tests
     */
    public function __construct(private Request $request, private string $logFile = self::LOG_FILE)
    {
    }

    /**
     * Log a security event using this logger's request context.
     *
     * @param string $event   The primary event description
     * @param string $details Additional details about the event
     */
    public function write(string $event, string $details = ''): void
    {
        $safe_event = self::sanitize($event);

        $log_entry = gmdate(DATE_ATOM) . " [SECURITY] " . $safe_event;

        if ($details !== '' && $details !== '0') {
            $safe_details = self::sanitize($details);
            $log_entry .= " - " . $safe_details;
        }

        $client_ip = $this->request->remoteAddress();

        $log_entry .= " - User: " . self::sanitize($this->request->authenticatedUser);
        $log_entry .= " - IP: " . $client_ip . "\n";

        error_log($log_entry, 3, $this->logFile);
    }

    /**
     * Sanitize input for safe log output
     *
     * Prevents log injection attacks by escaping control characters.
     *
     * @param string $input Raw input to sanitize
     * @return string Sanitized string safe for logging
     */
    private static function sanitize(string $input): string
    {
        // Remove all control characters (ASCII 0-31 and 127)
        // This includes \r, \n, \t, and other dangerous characters
        $sanitized = preg_replace('/[\x00-\x1F\x7F]/', ' ', $input);

        if (!is_string($sanitized)) {
            $sanitized = '';
        }

        // Collapse multiple spaces
        $sanitized = preg_replace('/\s+/', ' ', $sanitized);

        if (!is_string($sanitized)) {
            $sanitized = '';
        }

        // Limit length to prevent log flooding
        $sanitized = substr(trim($sanitized), 0, 255);

        // Encode any remaining special characters for safe output
        return addcslashes($sanitized, '\\');
    }
}
