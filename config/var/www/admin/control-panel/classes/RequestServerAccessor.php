<?php
/**
 * EngineScript Admin Dashboard - Server Request Accessor
 *
 * Provides normalized access to server-derived request values.
 *
 * @package EngineScript\Dashboard\Classes
 * @version 1.0.0
 * @security HIGH - Normalizes server request input for the dashboard API
 */
final class RequestServerAccessor
{
    /**
     * @param array<string, mixed> $server
     */
    public function __construct(private array $server)
    {
    }

    public function hasServer(string $key): bool
    {
        return array_key_exists($key, $this->server);
    }

    public function serverString(string $key, string $default = ''): string
    {
        $value = $this->server[$key] ?? $default;

        return is_scalar($value) ? (string) $value : $default;
    }

    public function uri(): string
    {
        return $this->serverString('REQUEST_URI');
    }

    public function hostHeader(): string
    {
        return strtolower(trim($this->serverString('HTTP_HOST')));
    }

    public function scheme(): string
    {
        $https = strtolower($this->serverString('HTTPS'));

        return $https !== '' && $https !== 'off' && $https !== '0' ? 'https' : 'http';
    }

    public function remoteAddress(): string
    {
        $ipAddress = $this->serverString('REMOTE_ADDR', 'unknown');

        if ($ipAddress === 'unknown') {
            return 'unknown';
        }

        return filter_var($ipAddress, FILTER_VALIDATE_IP) !== false ? $ipAddress : 'invalid';
    }
}
