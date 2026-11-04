<?php

/**
 * SystemCommand Class
 * Encapsulates all shell command executions for security, testing, and maintainability
 *
 * Every command runs via proc_open() with array syntax — the OS spawns the
 * process directly, bypassing the shell entirely so no injection is possible.
 * Each public method runs one fixed command; no caller supplies an argument.
 * Tests replace the process runner with useRunner().
 *
 * @version 1.2.0
 * @security HIGH - Zero shell_exec/exec usage; all execution via proc_open array
 */

declare(strict_types=1);

require_once __DIR__ . '/SystemProcessRunner.php';

final class SystemCommand
{
    /**
     * Nginx FastCGI cache directory (fastcgi_cache_path in nginx.conf).
     */
    public const string FASTCGI_CACHE_PATH = '/var/cache/nginx';

    /**
     * Maximum time a dashboard command may run before it is terminated.
     */
    private const int DEFAULT_TIMEOUT_SECONDS = 8;

    /**
     * Maximum time all commands of one API request may take together.
     */
    private const int REQUEST_BUDGET_SECONDS = 20;

    /**
     * Absolute path of every executable the dashboard may run.
     *
     * proc_open receives these paths, so PATH cannot influence which
     * executable is launched.
     *
     * @var array<string,string>
     */
    private const array BINARY_PATHS = [
        'du' => '/usr/bin/du',
        'find' => '/usr/bin/find',
        'ip' => '/usr/sbin/ip',
        'mariadb' => '/usr/bin/mariadb',
        'nginx' => '/usr/sbin/nginx',
        'redis-cli' => '/usr/bin/redis-cli',
        'redis-server' => '/usr/bin/redis-server',
        'systemctl' => '/usr/bin/systemctl',
        'uname' => '/usr/bin/uname',
    ];

    /**
     * The systemd units whose state the dashboard reports, by service name.
     *
     * @var array<string,string>
     */
    private const array SERVICE_UNITS = [
        'nginx' => 'nginx.service',
        'mariadb' => 'mariadb.service',
        'redis-server' => 'redis-server.service',
    ];

    private static ?CommandRunner $runner = null;

    /**
     * When this request's command budget runs out (microtime), set by the first command.
     */
    private static ?float $budgetDeadline = null;

    /**
     * Run the commands through another runner, and start a new time budget; for tests
     *
     * @psalm-api
     */
    public static function useRunner(CommandRunner $runner): void
    {
        self::$runner = $runner;
        self::$budgetDeadline = null;
    }

    /**
     * Execute one of the fixed commands via proc_open without shell interpretation.
     *
     * @param non-empty-list<string> $argv Command array (binary name from BINARY_PATHS + arguments)
     * @param bool $captureStderr Read stderr instead of stdout (e.g. nginx -v)
     * @return string|false Trimmed output or false on failure
     */
    private static function execProc(array $argv, bool $captureStderr = false): string|false
    {
        $binaryPath = self::BINARY_PATHS[$argv[0]] ?? null;
        if ($binaryPath === null) {
            error_log('[EngineScript] SystemCommand blocked unknown command: ' . $argv[0]);
            return false;
        }

        $timeoutSeconds = self::remainingSeconds();
        if ($timeoutSeconds <= 0) {
            error_log('[EngineScript] SystemCommand skipped command, request time budget used up: ' . implode(' ', $argv));
            return false;
        }

        $command = $argv;
        $command[0] = $binaryPath;

        self::$runner ??= new SystemProcessRunner();

        return self::$runner->run($command, $captureStderr, $timeoutSeconds, $argv);
    }

    /**
     * Whole seconds a command may run: the per-command limit, cut to what is
     * left of this request's budget.
     */
    private static function remainingSeconds(): int
    {
        self::$budgetDeadline ??= microtime(true) + (float) self::REQUEST_BUDGET_SECONDS;
        $remaining = (int) floor(self::$budgetDeadline - microtime(true));

        return min(self::DEFAULT_TIMEOUT_SECONDS, $remaining);
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
     * Get the systemd state of one of the dashboard's services
     *
     * `systemctl is-active` prints the unit's state (active, inactive, failed,
     * activating, ...), also for a missing unit, and exits non-zero unless active.
     *
     * @param string $service A key of SERVICE_UNITS: nginx, mariadb, or redis-server
     * @return string|false The state, or false for an unknown service or a failed command
     */
    public static function getServiceState(string $service): string|false
    {
        $unit = self::SERVICE_UNITS[$service] ?? null;
        if ($unit === null) {
            return false;
        }

        $output = self::execProc(['systemctl', 'is-active', $unit]);
        if ($output === false || $output === '') {
            return false;
        }

        // One state word; ignore anything after the first line.
        return strtok($output, "\n");
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

    /**
     * Empty every Redis database
     * @return string|false Redis's reply ("OK") or false on failure
     */
    public static function flushRedis(): string|false
    {
        return self::execProc(['redis-cli', 'FLUSHALL']);
    }

    /**
     * Get Redis's memory section of INFO
     * @return string|false INFO output or false on failure
     */
    public static function getRedisMemoryInfo(): string|false
    {
        return self::execProc(['redis-cli', 'INFO', 'memory']);
    }

    /**
     * Get the FastCGI cache directory's size, as `du -sh` prints it
     * @return string|false du output or false on failure
     */
    public static function getFastCgiCacheSize(): string|false
    {
        return self::execProc(['du', '-sh', self::FASTCGI_CACHE_PATH]);
    }

    /**
     * Delete every file in the FastCGI cache directory
     * @return string|false Empty output on success, false on failure
     */
    public static function clearFastCgiCache(): string|false
    {
        return self::execProc(['find', self::FASTCGI_CACHE_PATH, '-type', 'f', '-delete']);
    }
}
