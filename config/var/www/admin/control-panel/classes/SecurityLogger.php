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

namespace EngineScript\Dashboard\Classes;

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
        $safeEvent = self::sanitize($event);

        $logEntry = gmdate(DATE_ATOM) . " [SECURITY] " . $safeEvent;

        if ($details !== '' && $details !== '0') {
            $safeDetails = self::sanitize($details);
            $logEntry .= " - " . $safeDetails;
        }

        $clientIp = $this->request->remoteAddress();

        $logEntry .= " - User: " . self::sanitize($this->request->authenticatedUser);
        $logEntry .= " - IP: " . $clientIp . "\n";

        error_log($logEntry, 3, $this->logFile);
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
