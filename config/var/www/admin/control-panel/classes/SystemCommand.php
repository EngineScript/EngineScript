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

require_once __DIR__ . '/SystemProcessRunner.php';

class SystemCommand
{
    /**
     * Maximum time a dashboard command may run before it is terminated.
     */
    private const DEFAULT_TIMEOUT_SECONDS = 8;

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
     * Absolute executable paths for Ubuntu-based EngineScript servers.
     *
     * The public API still accepts short binary names, but proc_open receives
     * absolute paths so PATH cannot influence which executable is launched.
     *
     * @var array<string,string>
     */
    private const BINARY_PATHS = [
        'du' => '/usr/bin/du',
        'find' => '/usr/bin/find',
        'ip' => '/usr/sbin/ip',
        'mariadb' => '/usr/bin/mariadb',
        'nginx' => '/usr/sbin/nginx',
        'php' => '/usr/bin/php',
        'redis-cli' => '/usr/bin/redis-cli',
        'redis-server' => '/usr/bin/redis-server',
        'systemctl' => '/usr/bin/systemctl',
        'uname' => '/usr/bin/uname',
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
     * Exact public run() invocations currently needed by the dashboard.
     *
     * Keeping this narrower than the binary allowlist prevents future callers
     * from passing semantically dangerous flags such as find -exec.
     *
     * @var array<string, list<list<string>>>
     */
    private const RUN_ALLOWED_ARGUMENTS = [
        'du' => [
            ['-sh', '/var/cache/enginescript/fcgi'],
        ],
        'find' => [
            ['/var/cache/enginescript/fcgi', '-type', 'f', '-delete'],
        ],
        'redis-cli' => [
            ['FLUSHALL'],
            ['INFO', 'memory'],
        ],
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

    private static ?SystemProcessRunner $processRunner = null;

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
    private static function execProc(
        array $argv,
        bool $captureStderr = false,
        int $timeoutSeconds = self::DEFAULT_TIMEOUT_SECONDS
    ): string|false {
        if (!self::hasValidCommandParts($argv)) {
            return false;
        }

        $binary = $argv[0];
        $binaryPath = self::resolveBinaryPath($binary);
        if ($binaryPath === false) {
            return false;
        }

        if (self::isMocked()) {
            return self::mockCommand($argv);
        }

        if (!is_executable($binaryPath)) {
            error_log('[EngineScript] SystemCommand executable not found or not executable: ' . $binaryPath);
            return false;
        }

        $command = $argv;
        $command[0] = $binaryPath;

        return self::processRunner()->run($command, $captureStderr, $timeoutSeconds, $argv);
    }

    /**
     * @param array<int,string> $argv
     */
    private static function hasValidCommandParts(array $argv): bool
    {
        if ($argv === []) {
            return false;
        }

        foreach ($argv as $part) {
            if (!is_string($part) || str_contains($part, "\0")) {
                error_log('[EngineScript] SystemCommand blocked invalid command argument');
                return false;
            }
        }

        return true;
    }

    private static function resolveBinaryPath(string $binary): string|false
    {
        if (!in_array($binary, self::ALLOWED_BINARIES, true) || !isset(self::BINARY_PATHS[$binary])) {
            error_log('[EngineScript] SystemCommand blocked non-allowlisted command: ' . $binary);
            return false;
        }

        return self::BINARY_PATHS[$binary];
    }

    private static function processRunner(): SystemProcessRunner
    {
        self::$processRunner ??= new SystemProcessRunner();

        return self::$processRunner;
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

        $normalizedArgs = [];
        foreach ($args as $arg) {
            if (!is_string($arg)) {
                error_log('[EngineScript] SystemCommand::run() blocked non-string argument for binary: ' . $binary);
                return false;
            }

            $normalizedArgs[] = $arg;
        }
        $args = $normalizedArgs;

        if (!self::isAllowedRunInvocation($binary, $args)) {
            error_log('[EngineScript] SystemCommand::run() blocked non-allowlisted invocation: ' . $binary);
            return false;
        }

        return self::execProc([$binary, ...$args]);
    }

    /**
     * Verify public run() calls use one of the exact command shapes required by
     * the dashboard.
     *
     * @param array<int,string> $args
     */
    private static function isAllowedRunInvocation(string $binary, array $args): bool
    {
        foreach (self::RUN_ALLOWED_ARGUMENTS[$binary] ?? [] as $allowedArgs) {
            if ($args === $allowedArgs) {
                return true;
            }
        }

        return false;
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
            $ipAddress = $matches[1];
            if (filter_var($ipAddress, FILTER_VALIDATE_IP) !== false) {
                return $ipAddress;
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
