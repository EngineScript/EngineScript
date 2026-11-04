<?php

/**
 * EngineScript Admin Dashboard - Uptime Controller
 *
 * Handles UptimeRobot API integration endpoints.
 *
 * @package EngineScript\Dashboard\API\Controllers
 * @version 1.0.0
 */

declare(strict_types=1);

require_once __DIR__ . '/BaseController.php';
require_once __DIR__ . '/../classes/UptimeRobotAPI.php';

/**
 * Uptime Controller
 *
 * Provides UptimeRobot overall status and monitor details. Both endpoints
 * answer from one fetch of the monitor list, cached for a minute.
 *
 * @psalm-api
 */
final class UptimeController extends BaseController
{
    /**
     * Cache key of the shared monitor list
     */
    private const string CACHE_KEY = 'uptimerobot-monitors';

    /**
     * Monitor status codes, as the dashboard knows them
     */
    private const int STATUS_UNKNOWN      = -1;
    private const int STATUS_PAUSED       = 0;
    private const int STATUS_NOT_CHECKED  = 1;
    private const int STATUS_UP           = 2;
    private const int STATUS_SEEMS_DOWN   = 8;
    private const int STATUS_DOWN         = 9;

    /**
     * Status codes by UptimeRobot API v3 status name
     */
    private const array STATUS_CODES = [
        'PAUSED'     => self::STATUS_PAUSED,
        'STARTED'    => self::STATUS_NOT_CHECKED,
        'UP'         => self::STATUS_UP,
        'LOOKS_DOWN' => self::STATUS_SEEMS_DOWN,
        'DOWN'       => self::STATUS_DOWN,
    ];

    /**
     * UptimeRobot API instance
     */
    private ?UptimeRobotAPI $uptimeApi = null;

    /**
     * Get UptimeRobot API instance
     *
     * @return UptimeRobotAPI|null Returns null if not configured
     */
    private function getUptimeApi(): ?\UptimeRobotAPI
    {
        if ($this->uptimeApi === null) {
            $configPath = '/etc/enginescript/uptimerobot.conf';
            if (file_exists($configPath)) {
                $apiKey = $this->apiKeyFromConfig(parse_ini_file($configPath));

                if ($apiKey !== null) {
                    $this->uptimeApi = new UptimeRobotAPI($apiKey);
                }
            }
        }
        return $this->uptimeApi;
    }

    /**
     * The trimmed API key from the parsed configuration, or null when there is none.
     *
     * A key that trims to '' or '0' counts as none, as the earlier empty() test did.
     * The key is sent in a header, so it must be visible ASCII without spaces.
     */
    private function apiKeyFromConfig(mixed $config): ?string
    {
        if (!is_array($config) || !isset($config['api_key']) || !is_string($config['api_key'])) {
            return null;
        }

        $apiKey = trim($config['api_key']);

        if ($apiKey === '' || $apiKey === '0' || preg_match('/^[\x21-\x7E]+$/', $apiKey) !== 1) {
            return null;
        }

        return $apiKey;
    }

    /**
     * Get overall uptime status
     *
     * Returns aggregated status from UptimeRobot account.
     *
     * Endpoint: GET /monitoring/uptime
     *
     * @return void Outputs JSON response
     * @psalm-api
     */
    public function getStatus(): void
    {
        $this->respond(
            fn(array $monitors): array => $this->calculateOverallStatus($monitors),
            [],
            'Unable to retrieve uptime status'
        );
    }

    /**
     * Get detailed monitor list
     *
     * Returns all monitors with their current status and last day's uptime.
     *
     * Endpoint: GET /monitoring/uptime/monitors
     *
     * @return void Outputs JSON response
     * @psalm-api
     */
    public function getMonitors(): void
    {
        $this->respond(
            fn(array $monitors): array => $this->formatMonitors($monitors),
            ['monitors' => []],
            'Unable to retrieve uptime monitors'
        );
    }

    /**
     * Answer from the shared monitor list
     *
     * @param callable(array<mixed>): array<string, mixed> $format Builds the answer from the monitors
     * @param array<string, mixed> $emptyFields Added to the not-configured and error answers
     */
    private function respond(callable $format, array $emptyFields, string $failureMessage): void
    {
        try {
            $api = $this->getUptimeApi();

            if (!$api instanceof \UptimeRobotAPI) {
                $this->response->success([
                    'enabled' => false,
                    'reason' => 'UptimeRobot API not configured',
                ] + $emptyFields);
                return;
            }

            $result = $this->remember(self::CACHE_KEY, fn(): array => $this->fetchMonitors($api));
            $data = $result['data'];

            $answer = isset($data['error'])
                ? ['enabled' => true, 'error' => $data['error']] + $emptyFields
                : $format($this->arrayOrNull($data['monitors'] ?? null) ?? []);

            $this->respondCached($answer, $result['hit']);
        } catch (Throwable $e) {
            $this->securityLogger->write('Uptime error', $e->getMessage());
            $this->response->serverError($failureMessage);
        }
    }

    /**
     * Fetch the monitor list; a failure is cached too, so UptimeRobot is asked
     * at most once a minute
     *
     * @return array<string, mixed>
     */
    private function fetchMonitors(UptimeRobotAPI $api): array
    {
        $monitors = $api->getMonitors();

        if ($monitors !== false) {
            return ['monitors' => $monitors];
        }

        return [
            'error' => $api->wasRateLimited()
                ? 'UptimeRobot request limit reached; try again later'
                : 'Failed to fetch monitors from UptimeRobot API',
        ];
    }

    /**
     * Calculate overall status from monitors
     *
     * @param array<mixed> $monitors Monitors from UptimeRobotAPI
     * @return array<string, bool|int|string> Overall status summary
     */
    private function calculateOverallStatus(array $monitors): array
    {
        $total = count($monitors);
        $upCount = 0;
        $downCount = 0;
        $paused = 0;

        foreach (array_map($this->statusCode(...), $monitors) as $status) {
            switch ($status) {
                case self::STATUS_UP:
                    ++$upCount;
                    break;
                case self::STATUS_SEEMS_DOWN:
                case self::STATUS_DOWN:
                    ++$downCount;
                    break;
                case self::STATUS_PAUSED:
                case self::STATUS_NOT_CHECKED:
                    ++$paused;
                    break;
                default:
                    break;
            }
        }

        // Determine overall status; paused and not yet checked monitors do not count against healthy
        $active = $total - $paused;
        $overallStatus = 'unknown';
        if ($downCount > 0) {
            $overallStatus = 'critical';
        } elseif ($active > 0 && $upCount === $active) {
            $overallStatus = 'healthy';
        } elseif ($upCount > 0) {
            $overallStatus = 'partial';
        }

        return [
            'enabled' => true,
            'overall_status' => $overallStatus,
            'total_monitors' => $total,
            'up' => $upCount,
            'down' => $downCount,
            'paused' => $paused,
        ];
    }

    /**
     * Format monitors for output
     *
     * @param array<mixed> $monitors Monitors from UptimeRobotAPI
     * @return array<string, mixed> Formatted monitor list
     */
    private function formatMonitors(array $monitors): array
    {
        $formatted = array_values(array_map($this->formatMonitor(...), $monitors));

        return [
            'enabled' => true,
            'total' => count($formatted),
            'monitors' => $formatted,
        ];
    }

    /**
     * The dashboard's status code of one monitor (STATUS_UNKNOWN for an unknown status name)
     */
    private function statusCode(mixed $monitor): int
    {
        $status = is_array($monitor) ? $this->stringOrNull($monitor['status'] ?? null) : null;

        return $status === null
            ? self::STATUS_UNKNOWN
            : self::STATUS_CODES[strtoupper($status)] ?? self::STATUS_UNKNOWN;
    }

    /**
     * Format one monitor for output.
     *
     * @return array<string, mixed>
     */
    private function formatMonitor(mixed $monitor): array
    {
        $monitor = is_array($monitor) ? $monitor : [];
        $status = $this->statusCode($monitor);

        return [
            'id' => is_int($monitor['id'] ?? null) ? $monitor['id'] : 0,
            'name' => $this->stringOrNull($monitor['friendlyName'] ?? null) ?? 'Unknown',
            'url' => $this->stringOrNull($monitor['url'] ?? null) ?? '',
            'status' => $status,
            'status_text' => $this->getStatusText($status),
            'uptime_day' => $this->floatOrNull($monitor['lastDayUptime'] ?? null),
        ];
    }

    /**
     * The value as a float when it is a number, otherwise null.
     */
    private function floatOrNull(mixed $value): ?float
    {
        return is_int($value) || is_float($value) ? (float) $value : null;
    }

    /**
     * Get human-readable status text
     *
     * @param int $status Dashboard status code
     * @return string Status text
     */
    private function getStatusText(int $status): string
    {
        $statuses = [
            self::STATUS_PAUSED      => 'Paused',
            self::STATUS_NOT_CHECKED => 'Not checked yet',
            self::STATUS_UP          => 'Up',
            self::STATUS_SEEMS_DOWN  => 'Seems down',
            self::STATUS_DOWN        => 'Down',
        ];

        return $statuses[$status] ?? 'Unknown';
    }
}
