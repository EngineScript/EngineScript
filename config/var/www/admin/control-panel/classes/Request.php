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
 *
 * @method bool hasServer(string $key)
 * @method string serverString(string $key, string $default = '')
 * @method string uri()
 * @method string hostHeader()
 * @method string scheme()
 * @method string remoteAddress()
 */
class Request
{
    /**
     * @var array<string, mixed>
     */
    private array $server;

    /**
     * @var array<string, mixed>
     */
    private array $query;

    /**
     * @var array<string, mixed>
     */
    private array $post;

    private ?string $body;

    /**
     * @param array<string, mixed>|null $server
     * @param array<string, mixed>|null $query
     * @param array<string, mixed>|null $post
     *
     * @SuppressWarnings(PHPMD.Superglobals)
     */
    public function __construct(?array $server = null, ?array $query = null, ?array $post = null, ?string $body = null)
    {
        // codacy:ignore-start - Request superglobal access is intentionally centralized in this wrapper
        $this->server = $server ?? $_SERVER;
        $this->query = $query ?? $_GET;
        $this->post = $post ?? $_POST;
        // codacy:ignore-end
        $this->body = $body;
    }

    public function __call(string $name, array $arguments): mixed
    {
        switch ($name) {
            case 'hasServer':
                return is_string($arguments[0] ?? null) && array_key_exists($arguments[0], $this->server);

            case 'serverString':
                return $this->serverString(
                    is_string($arguments[0] ?? null) ? $arguments[0] : '',
                    is_string($arguments[1] ?? null) ? $arguments[1] : ''
                );

            case 'uri':
                return $this->serverString('REQUEST_URI');

            case 'hostHeader':
                return strtolower(trim($this->serverString('HTTP_HOST')));

            case 'scheme':
                $https = strtolower($this->serverString('HTTPS'));
                return $https !== '' && $https !== 'off' && $https !== '0' ? 'https' : 'http';

            case 'remoteAddress':
                $ipAddress = $this->serverString('REMOTE_ADDR', 'unknown');
                if ($ipAddress === 'unknown') {
                    return 'unknown';
                }
                return filter_var($ipAddress, FILTER_VALIDATE_IP) !== false ? $ipAddress : 'invalid';

            default:
                throw new BadMethodCallException('Unknown request method: ' . $name);
        }
    }

    private function serverString(string $key, string $default = ''): string
    {
        $value = $this->server[$key] ?? $default;

        return is_scalar($value) ? (string) $value : $default;
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

        if (!array_key_exists($serverKey, $this->server)) {
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
