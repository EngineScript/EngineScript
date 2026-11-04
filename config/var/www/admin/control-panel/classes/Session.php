<?php

declare(strict_types=1);

/**
 * EngineScript Admin Dashboard - Session Wrapper
 *
 * The one class that touches $_SESSION, so controllers receive the session as
 * a dependency.
 *
 * @package EngineScript\Dashboard\Classes
 * @version 1.0.0
 * @security HIGH - Single point of $_SESSION access for the entire dashboard
 */
final class Session
{
    /**
     * The value stored under a key, or $default when absent.
     *
     * @SuppressWarnings("PHPMD.Superglobals")
     */
    public function get(string $key, mixed $default = null): mixed
    {
        // PHP retains this request's data after session_write_close().
        return $_SESSION[$key] ?? $default;
    }

    /**
     * Whether a key exists in this request's session data.
     *
     * @SuppressWarnings("PHPMD.Superglobals")
     */
    public function has(string $key): bool
    {
        return isset($_SESSION) && array_key_exists($key, $_SESSION);
    }

    /**
     * Store a value; does nothing once the session is closed.
     *
     * @SuppressWarnings("PHPMD.Superglobals")
     *
     * @param bool|string|array<mixed> $value
     */
    public function set(string $key, bool|string|array $value): void
    {
        // Writes require an active session; closed snapshots remain read-only.
        if (session_status() !== PHP_SESSION_ACTIVE) {
            return;
        }

        $_SESSION[$key] = $value;
    }
}
