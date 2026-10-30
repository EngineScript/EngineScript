<?php

declare(strict_types=1);

/**
 * EngineScript Admin Dashboard - Request Wrapper
 *
 * Centralizes access to request superglobals so controllers and routing code can
 * depend on an injectable request object instead of reaching into globals.
 *
 * @package EngineScript\Dashboard\Classes
 * @version 1.0.0
 * @security HIGH - Single point of request input access for the dashboard API
 */
final class Request
{
    /**
     * @var array<mixed>
     */
    private array $server;

    /**
     * @var array<mixed>
     */
    private array $query;

    /**
     * @var array<mixed>
     */
    private array $post;

    /**
     * Basic-auth identity captured with this request; never includes the password.
     */
    public readonly string $authenticatedUser;

    /**
     * @param array<mixed>|null $server
     * @param array<mixed>|null $query
     * @param array<mixed>|null $post
     *
     * @SuppressWarnings("PHPMD.Superglobals")
     */
    public function __construct(?array $server = null, ?array $query = null, ?array $post = null, private ?string $body = null)
    {
        $this->server = $server ?? $_SERVER;
        $this->query = $query ?? $_GET;
        $this->post = $post ?? $_POST;
        $this->authenticatedUser = $this->serverString('PHP_AUTH_USER', 'unknown');
    }

    public function hasServer(string $key): bool
    {
        return array_key_exists($key, $this->server);
    }

    public function uri(): string
    {
        return $this->serverString('REQUEST_URI');
    }

    public function remoteAddress(): string
    {
        $ipAddress = $this->serverString('REMOTE_ADDR', 'unknown');

        if ($ipAddress === 'unknown') {
            return 'unknown';
        }

        return filter_var($ipAddress, FILTER_VALIDATE_IP) !== false ? $ipAddress : 'invalid';
    }

    public function method(): string
    {
        $method = strtoupper($this->serverString('REQUEST_METHOD', 'GET'));

        return preg_match('/^[A-Z]+$/', $method) === 1 ? $method : 'GET';
    }

    public function header(string $name): ?string
    {
        $normalized = strtoupper(str_replace('-', '_', $name));
        $serverKey = in_array($normalized, ['CONTENT_TYPE', 'CONTENT_LENGTH'], true)
            ? $normalized
            : 'HTTP_' . $normalized;

        if (!$this->hasServer($serverKey)) {
            return null;
        }

        $value = $this->serverString($serverKey);

        return $value === '' ? null : $value;
    }

    public function query(string $key): ?string
    {
        return $this->scalarInput($this->query[$key] ?? null);
    }

    public function post(string $key): ?string
    {
        return $this->scalarInput($this->post[$key] ?? null);
    }

    public function body(): string
    {
        if ($this->body !== null) {
            return $this->body;
        }

        $input = file_get_contents('php://input');
        $this->body = is_string($input) ? $input : '';

        return $this->body;
    }

    private function serverString(string $key, string $default = ''): string
    {
        if (!isset($this->server[$key])) {
            return $default;
        }

        return is_scalar($this->server[$key]) ? (string) $this->server[$key] : $default;
    }

    private function scalarInput(mixed $value): ?string
    {
        if (!is_scalar($value)) {
            return null;
        }

        $value = trim((string) $value);

        return $value === '' ? null : $value;
    }
}
