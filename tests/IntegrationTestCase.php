<?php

/**
 * Base class for the integration suite (tests/integration).
 *
 * The suite runs as root on a real EngineScript server: a container from the
 * local server test suite's es-suite:site image after its update phase
 * (.private/tests/suite), never on CI's runner (D-075). It sends real HTTPS
 * requests through nginx to the admin site and checks real services, files,
 * and logs. The admin credentials come from the install options, as
 * EngineScript's scripts read them; no secret is printed.
 */

declare(strict_types=1);

use PHPUnit\Framework\TestCase;

abstract class IntegrationTestCase extends TestCase
{
    protected const string OPTIONS = '/home/EngineScript/enginescript-install-options.txt';
    protected const string PANEL = '/var/www/admin/control-panel';
    protected const string SECURITY_LOG = '/var/log/EngineScript/enginescript-api-security.log';

    protected static string $domain = '';

    protected static string $user = '';

    protected static string $password = '';

    private ?string $cookieJar = null;

    public static function setUpBeforeClass(): void
    {
        parent::setUpBeforeClass();
        if (self::$domain !== '') {
            return;
        }

        if (!is_readable(self::OPTIONS)) {
            self::fail('Setup: no EngineScript server here (' . self::OPTIONS . ' unreadable); run the suite as root in an es-suite:site container.');
        }

        self::$domain = getenv('ES_TEST_DOMAIN') ?: 'essuitetest.com';
        self::$user = self::option('ADMIN_CONTROL_PANEL_USERNAME');
        self::$password = self::option('ADMIN_CONTROL_PANEL_PASSWORD');

        $probe = curl_init('https://127.0.0.1/');
        curl_setopt_array($probe, [CURLOPT_RETURNTRANSFER => true, CURLOPT_SSL_VERIFYPEER => false, CURLOPT_SSL_VERIFYHOST => 0, CURLOPT_TIMEOUT => 10]);
        if (curl_exec($probe) === false && curl_errno($probe) === CURLE_COULDNT_CONNECT) {
            self::fail('Setup: nginx does not answer on 127.0.0.1:443.');
        }
    }

    protected function tearDown(): void
    {
        if ($this->cookieJar !== null && is_file($this->cookieJar)) {
            unlink($this->cookieJar);
        }

        $this->cookieJar = null;
        parent::tearDown();
    }

    /**
     * A value of the install options, read the way EngineScript's scripts read it.
     */
    protected static function option(string $name): string
    {
        return self::shell('source ' . escapeshellarg(self::OPTIONS) . ' && printf %s "${' . $name . '}"');
    }

    /**
     * The output of a bash command, trimmed.
     */
    protected static function shell(string $command): string
    {
        $output = [];
        exec('bash -c ' . escapeshellarg($command) . ' 2>/dev/null', $output);

        return trim(implode("\n", $output));
    }

    /**
     * Send one request to the admin site through nginx.
     *
     * @param array<string, string> $headers
     * @param bool|string $auth true for the admin's credentials, false for none, or "user:password"
     * @return array{status: int, headers: array<string, list<string>>, body: string, json: mixed}
     */
    protected function http(string $method, string $path, array $headers = [], string $body = '', bool|string $auth = true, bool $cookies = true): array
    {
        $host = 'admin.' . self::$domain;
        $handle = curl_init("https://{$host}{$path}");
        $responseHeaders = [];
        $options = [
            CURLOPT_RESOLVE => ["{$host}:443:127.0.0.1"],
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_SSL_VERIFYHOST => 0,
            CURLOPT_TIMEOUT => 40,
            CURLOPT_HTTPHEADER => array_map(static fn(string $k, string $v): string => "{$k}: {$v}", array_keys($headers), $headers),
            CURLOPT_HEADERFUNCTION => static function ($curl, string $line) use (&$responseHeaders): int {
                $parts = explode(':', $line, 2);
                if (count($parts) === 2) {
                    $responseHeaders[strtolower(trim($parts[0]))][] = trim($parts[1]);
                }

                return strlen($line);
            },
        ];
        if ($method === 'HEAD') {
            $options[CURLOPT_NOBODY] = true;
        }
        if ($body !== '') {
            $options[CURLOPT_POSTFIELDS] = $body;
        }
        if ($auth !== false) {
            $options[CURLOPT_USERPWD] = $auth === true ? self::$user . ':' . self::$password : $auth;
        }
        if ($cookies) {
            $this->cookieJar ??= tempnam(sys_get_temp_dir(), 'es-jar-') ?: null;
            $options[CURLOPT_COOKIEFILE] = $this->cookieJar;
            $options[CURLOPT_COOKIEJAR] = $this->cookieJar;
        }

        curl_setopt_array($handle, $options);
        $response = curl_exec($handle);
        $status = (int) curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
        if ($response === false) {
            self::fail("Setup: {$method} {$path} failed: " . curl_error($handle));
        }

        $text = is_string($response) ? $response : '';

        return ['status' => $status, 'headers' => $responseHeaders, 'body' => $text, 'json' => json_decode($text, true)];
    }

    /**
     * The session's CSRF token, loaded the way the dashboard loads it.
     */
    protected function csrfToken(): string
    {
        $token = $this->http('GET', '/api/csrf-token')['json']['csrf_token'] ?? null;
        self::assertIsString($token);

        return $token;
    }

    /**
     * The security log lines written while $action ran.
     *
     * @return list<string>
     */
    protected function logWhile(callable $action): array
    {
        clearstatcache();
        $before = is_file(self::SECURITY_LOG) ? filesize(self::SECURITY_LOG) : 0;
        $action();
        clearstatcache();
        $content = (string) file_get_contents(self::SECURITY_LOG, false, null, (int) $before);

        return array_values(array_filter(explode("\n", $content)));
    }
}
