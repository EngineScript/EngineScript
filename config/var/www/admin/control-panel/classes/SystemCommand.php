<?php
/**
 * SystemCommand Class
 * Encapsulates all shell command executions for security, testing, and maintainability
 *
 * Every command runs via proc_open() with array syntax — the OS spawns the
 * process directly, bypassing the shell entirely so no injection is possible.
 *
 * @version 1.2.0
 * @security HIGH - Zero shell_exec/exec usage; all execution via proc_open array
 */

class SystemCommand
{
    /**
     * Central allowlist — single source of truth for every executable we may invoke.
     *
     * @var array<int,string>
     */
    private const ALLOWED_BINARIES = [
        'du',
        'find',
        'ip',
        'mariadb',
        'nginx',
        'php',
        'redis-cli',
        'redis-server',
        'systemctl',
        'uname',
    ];

    /**
     * Binaries permitted through the public run() API — a restricted subset of
     * ALLOWED_BINARIES intentionally exposed for general-purpose command invocation.
     *
     * @var array<int,string>
     */
    private const RUN_ALLOWED_BINARIES = [
        'du',
        'find',
        'redis-cli',
    ];

    /**
     * Check if shell commands should be mocked (for testing)
     */
    private static function isMocked(): bool
    {
        return defined('ENGINESCRIPT_MOCK_SHELL') && ENGINESCRIPT_MOCK_SHELL;
    }

    /**
     * Mock command execution for testing
     */
    private static function mockCommand(): string
    {
        return '';
    }

    /**
     * Execute a process via proc_open without shell interpretation.
     *
     * The binary must be present in the internal allowlist. proc_open array
     * syntax calls execve(2) directly — the shell is never invoked, so
     * metacharacters in arguments are inert.
     *
     * @param array<int,string> $argv Command array (binary + arguments)
     * @param bool $captureStderr Read stderr instead of stdout (e.g. nginx -v)
     * @return string|false Trimmed output or false on failure
     */
    private static function execProc(array $argv, bool $captureStderr = false): string|false
    {
        if ($argv === []) {
            return false;
        }

        // Central allowlist — single source of truth for every executable we may
        // invoke. proc_open with an array calls execve(2) directly (no shell), so
        // shell metacharacters in arguments are inert by design.
        $allowed = self::ALLOWED_BINARIES;

        if (!in_array($argv[0], $allowed, true)) {
            error_log('[EngineScript] SystemCommand blocked non-allowlisted command: ' . $argv[0]);
            return false;
        }

        if (self::isMocked()) {
            return self::mockCommand();
        }

        [$descriptors, $pipeIndex] = self::buildPipeSpec($captureStderr);
        $proc = proc_open($argv, $descriptors, $pipes);

        if (!is_resource($proc)) {
            return false;
        }

        $output = trim((string) stream_get_contents($pipes[$pipeIndex]));

        foreach ($pipes as $pipe) {
            if (is_resource($pipe)) {
                fclose($pipe);
            }
        }

        proc_close($proc);

        return $output !== '' ? $output : false;
    }

    /**
     * Build the proc_open descriptor array and pipe-read index.
     *
     * @return array{0: array<int, array<int, string>>, 1: int}
     */
    private static function buildPipeSpec(bool $captureStderr): array
    {
        $null = ['file', '/dev/null', 'w'];
        $pipe = ['pipe', 'w'];

        if ($captureStderr) {
            return [[0 => ['file', '/dev/null', 'r'], 1 => $null, 2 => $pipe], 2];
        }

        return [[0 => ['file', '/dev/null', 'r'], 1 => $pipe, 2 => $null], 1];
    }

    /**
     * Run an allowlisted binary with arguments
     *
     * @param string $binary The binary name (must be in the allowlist)
     * @param array<int,string> $args Arguments to pass to the binary
     * @return string|false Command output or false on failure
     */
    public static function run(string $binary, array $args = []): string|false
    {
        if (!in_array($binary, self::RUN_ALLOWED_BINARIES, true)) {
            error_log('[EngineScript] SystemCommand::run() blocked non-allowlisted binary: ' . $binary);
            return false;
        }

        return self::execProc([$binary, ...$args]);
    }

    /**
     * Get systemd services
     * @return string|false Raw systemctl output or false on failure
     */
    public static function getSystemdServices(): string|false
    {
        return self::execProc(['systemctl', 'list-units', '--type=service', '--all', '--no-pager', '--no-legend']);
    }

    /**
     * Get kernel version
     * @return string|false Kernel version or false on failure
     */
    public static function getKernelVersion(): string|false
    {
        return self::execProc(['uname', '-r']);
    }

    /**
     * Get primary network IP address
     * @return string|false IP address or false on failure
     */
    public static function getNetworkIP(): string|false
    {
        // Run ip directly, parse in PHP instead of piping through awk
        $output = self::execProc(['ip', 'route', 'get', '8.8.8.8']);

        if ($output === false) {
            return false;
        }

        // Extract source IP from "... src 10.0.0.1 ..."
        if (preg_match('/src\s+(\S+)/', $output, $matches)) {
            return $matches[1];
        }

        return false;
    }

    /**
     * Get service status
     * @param string $service Service name (alphanumeric + dash/underscore/dot)
     * @return string|false Service status (active/inactive/failed/unknown) or false on error
     */
    public static function getServiceStatus(string $service): string|false
    {
        // Validate service name (alphanumeric, dash, underscore, dot only)
        // Dot supports PHP-FPM services like php-fpm8.4
        if (!preg_match('/^[a-zA-Z0-9._-]+$/', $service)) {
            return false;
        }

        $output = self::execProc(['systemctl', 'status', $service, '--no-pager']);

        if ($output === false || $output === '') {
            return false;
        }

        // Parse the Active line: "     Active: active (running) since ..."
        if (preg_match('/Active:\s+(active|inactive|failed|unknown)/', $output, $matches)) {
            return $matches[1];
        }

        return false;
    }

    /**
     * Get Nginx version
     * @return string|false Nginx version output or false on failure
     */
    public static function getNginxVersion(): string|false
    {
        // nginx -v writes to stderr
        return self::execProc(['nginx', '-v'], captureStderr: true);
    }

    /**
     * Get PHP version
     * @return string|false PHP version output or false on failure
     */
    public static function getPhpVersion(): string|false
    {
        return self::execProc(['php', '-v']);
    }

    /**
     * Get MariaDB version
     * @return string|false MariaDB version output or false on failure
     */
    public static function getMariadbVersion(): string|false
    {
        return self::execProc(['mariadb', '--version']);
    }

    /**
     * Get Redis version
     * @return string|false Redis version output or false on failure
     */
    public static function getRedisVersion(): string|false
    {
        return self::execProc(['redis-server', '--version']);
    }
}
