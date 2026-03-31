<?php
/**
 * EngineScript Admin Dashboard - Session Wrapper
 *
 * Encapsulates all access to the $_SESSION superglobal so that no other class
 * touches the superglobal directly.  Centralising the access here satisfies
 * PHPMD's SuperGlobals rule, improves testability (the class can be mocked or
 * subclassed in unit tests), and provides a single place to add future session
 * hardening (e.g. regeneration, encryption, or a custom session handler).
 *
 * @package EngineScript\Dashboard\Classes
 * @version 1.0.0
 * @security HIGH - Single point of $_SESSION access for the entire dashboard
 */
class Session
{
    /**
     * Retrieve a value from the session.
     *
     * This is the single, intentional access point for $_SESSION in the entire
     * dashboard.  The @SuppressWarnings annotation suppresses PHPMD's Superglobals
     * rule here by design — all other classes must go through this method.
     *
     * @SuppressWarnings(PHPMD.Superglobals)
     *
     * @param string $key     Session key to look up.
     * @param mixed  $default Value returned when the key is absent or the
     *                        session has not been started.
     * @return mixed The stored value, or $default.
     */
    public function get(string $key, mixed $default = null): mixed
    {
        // If the session has not been started, honour the documented contract and
        // return the default value without touching $_SESSION.
        if (session_status() !== PHP_SESSION_ACTIVE) {
            return $default;
        }

        // codacy:ignore - Direct $_SESSION access is intentionally centralised here; no other class should access $_SESSION
        return $_SESSION[$key] ?? $default;
    }
}
