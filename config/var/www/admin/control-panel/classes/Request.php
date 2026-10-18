<?php

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

require_once __DIR__ . '/RequestServerAccessor.php';

final class Request
{
    /**
     * Server-derived request value accessor.
     */
    private RequestServerAccessor $serverAccessor;

    /**
     * @var array<mixed>
     */
    private array $query;

    /**
     * @var array<mixed>
     */
    private array $post;

    private ?string $body;

    /**
     * @param array<mixed>|null $server
     * @param array<mixed>|null $query
     * @param array<mixed>|null $post
     *
     * @SuppressWarnings("PHPMD.Superglobals")
     */
    public function __construct(?array $server = null, ?array $query = null, ?array $post = null, ?string $body = null)
    {
        // codacy:ignore-start - Request superglobal access is intentionally centralized in this wrapper
        $this->serverAccessor = new RequestServerAccessor($server ?? $_SERVER);
        $this->query = $query ?? $_GET;
        $this->post = $post ?? $_POST;
        // codacy:ignore-end
        $this->body = $body;
    }

    public function hasServer(string $key): bool
    {
        return $this->serverAccessor->hasServer($key);
    }

    public function uri(): string
    {
        return $this->serverAccessor->uri();
    }

    public function hostHeader(): string
    {
        return $this->serverAccessor->hostHeader();
    }

    public function scheme(): string
    {
        return $this->serverAccessor->scheme();
    }

    public function remoteAddress(): string
    {
        return $this->serverAccessor->remoteAddress();
    }

    public function method(): string
    {
        $method = strtoupper($this->serverAccessor->serverString('REQUEST_METHOD', 'GET'));

        return preg_match('/^[A-Z]+$/', $method) === 1 ? $method : 'GET';
    }

    public function header(string $name): ?string
    {
        $normalized = strtoupper(str_replace('-', '_', $name));
        $serverKey = in_array($normalized, ['CONTENT_TYPE', 'CONTENT_LENGTH'], true)
            ? $normalized
            : 'HTTP_' . $normalized;

        if (!$this->serverAccessor->hasServer($serverKey)) {
            return null;
        }

        $value = $this->serverAccessor->serverString($serverKey);

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

        // codacy:ignore - file_get_contents() required for reading the raw request body in standalone API
        $input = file_get_contents('php://input');
        $this->body = is_string($input) ? $input : '';

        return $this->body;
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
