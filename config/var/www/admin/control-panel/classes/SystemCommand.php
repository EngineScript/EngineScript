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
     * Default mock result when mocking is enabled but no specific configuration
     * has been provided. Use `false` to simulate a command failure, or a non-empty
     * string to simulate successful output.
     *
     * @var string|false
     */
    private static string|false $defaultMockResult = '';

    /**
     * Map of command signatures to specific mock results.
     * The key is the binary followed by its arguments, joined with a single space.
     *
     * @var array<string,string|false>
     */
    private static array $mockResultsByCommand = [];

    /**
     * Optional queue of mock results to return in order, regardless of command.
     *
     * @var list<string|false>
     */
    private static array $mockResultQueue = [];

    /**
     * Check if shell commands should be mocked (for testing)
     */
    private static function isMocked(): bool
    {
        return defined('ENGINESCRIPT_MOCK_SHELL') && ENGINESCRIPT_MOCK_SHELL;
    }

    /**
     * Configure a specific mock result for a given command (binary + args).
     *
     * @param array<int,string> $argv
     * @param string|false $result
     */
    public static function setMockResultForCommand(array $argv, string|false $result): void
    {
        if ($argv === []) {
            return;
        }
        $key = implode(' ', $argv);
        self::$mockResultsByCommand[$key] = $result;
    }

    /**
     * Configure the default mock result used when no command-specific mock is set.
     *
     * @param string|false $result
     */
    public static function setDefaultMockResult(string|false $result): void
    {
        self::$defaultMockResult = $result;
    }

    /**
     * Push a mock result onto the queue to be returned by subsequent calls
     * in the order added.
     *
     * @param string|false $result
     */
    public static function enqueueMockResult(string|false $result): void
    {
        self::$mockResultQueue[] = $result;
    }

    /**
     * Reset all configured mock results to their defaults.
     */
    public static function resetMockResults(): void
    {
        self::$defaultMockResult    = '';
        self::$mockResultsByCommand = [];
        self::$mockResultQueue      = [];
    }

    /**
     * Mock command execution for testing.
     *
     * @param array<int,string> $argv
     * @return string|false
     */
    private static function mockCommand(array $argv): string|false
    {
        // If a queued result exists, use it first to allow ordered scenarios.
        if (self::$mockResultQueue !== []) {
            return array_shift(self::$mockResultQueue);
        }

        // Next, try a command-specific mock result.
        if ($argv !== []) {
            $key = implode(' ', $argv);
            if (array_key_exists($key, self::$mockResultsByCommand)) {
                return self::$mockResultsByCommand[$key];
            }
        }

        // Fall back to the default mock result (empty string by default,
        // preserving existing behavior).
        return self::$defaultMockResult;
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
            return self::mockCommand($argv);
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
        $pipe = ['pipe', 'r'];

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

        // Extract source IP from "... src 10.0.0.1 ..." and validate it
        if (preg_match('/\bsrc\s+([0-9a-fA-F:.]+)/', $output, $matches)) {
            $ip = $matches[1];
            if (filter_var($ip, FILTER_VALIDATE_IP) !== false) {
                return $ip;
            }
        }

        return false;
    }

    /**
     * Get service status
     * @param string $service Service name (e.g. nginx, php-fpm8.4, getty@tty1, nginx.service)
     * @return string|false Service status string (active/inactive/failed/activating/etc.) or false on error
     */
    public static function getServiceStatus(string $service): string|false
    {
        // Validate service name:
        // - must start with alphanumeric
        // - may contain '.', '_', '-', '@' only between alphanumeric segments
        // - may optionally end with a '.service' suffix
        if (!preg_match('/^[A-Za-z0-9]+([._@-][A-Za-z0-9]+)*(\\.service)?$/', $service)) {
            return false;
        }

        // Normalize to full unit name: append ".service" if no suffix is present
        // This allows callers to pass "nginx" or "php-fpm8.4" without the ".service" suffix
        if (!str_ends_with($service, '.service')) {
            $service .= '.service';
        }

        $output = self::execProc(['systemctl', 'status', $service, '--no-pager']);

        if ($output === false || $output === '') {
            return false;
        }

        // Parse the Active line: "     Active: active (running) since ..."
        // Match any primary systemd active state token (e.g. active, inactive, failed, unknown,
        // activating, deactivating, reloading, maintenance, etc.)
        if (preg_match('/Active:\s+([a-zA-Z]+(?:-[a-zA-Z]+)*)/', $output, $matches)) {
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
