<?php

/**
 * EngineScript Admin Dashboard - UptimeRobot API Client
 *
 * Reads the account's monitors from UptimeRobot's API v3.
 *
 * @package EngineScript\Dashboard\API
 * @version 1.0.0
 * @security HIGH - Handles API credentials
 */

declare(strict_types=1);

/**
 * UptimeRobot API Client
 *
 * Each monitor is reduced to the fields the dashboard shows as soon as it is
 * received: v3 monitor records also carry secrets (the monitor's API key, HTTP
 * credentials, custom headers), which must never reach a cache or a response.
 *
 * Usage:
 *   $api = new UptimeRobotAPI('your-api-key');
 *   $monitors = $api->getMonitors();
 *
 * @psalm-type UptimeMonitor = array{
 *     id: int,
 *     friendlyName: string,
 *     url: string,
 *     status: string,
 *     lastDayUptime: float|null
 * }
 */
final class UptimeRobotAPI
{
    /**
     * UptimeRobot API v3 base URL
     */
    public const string DEFAULT_BASE_URL = 'https://api.uptimerobot.com/v3';

    /**
     * Monitors per page (v3's maximum)
     */
    private const int PAGE_LIMIT = 200;

    /**
     * Pages read at most: 1,000 monitors, half the free plan's 10 requests a minute
     */
    private const int MAX_PAGES = 5;

    /**
     * Accounts with at most this many monitors get each monitor's uptime, one
     * request per monitor: with the list, 9 of the free plan's 10 requests a minute
     */
    private const int MAX_UPTIME_MONITORS = 8;

    /**
     * Timeout of one request, and of all requests of one read together, in seconds
     */
    private const int REQUEST_TIMEOUT = 10;
    private const int TOTAL_TIMEOUT = 20;

    /**
     * HTTP status of the last failed request, if any
     */
    private ?int $lastHttpStatus = null;

    /**
     * Create a new UptimeRobot API instance
     *
     * @param string $apiKey UptimeRobot API key
     * @param string $baseUrl API base URL; replaced only by tests
     */
    public function __construct(
        private readonly string $apiKey,
        private readonly string $baseUrl = self::DEFAULT_BASE_URL
    ) {
    }

    /**
     * Get all monitors, following the pages, with their uptime where read
     *
     * @return list<UptimeMonitor>|false Monitors, or false on error
     */
    public function getMonitors(): array|false
    {
        $this->lastHttpStatus = null;
        $deadline = microtime(true) + (float) self::TOTAL_TIMEOUT;
        $monitors = [];
        $cursor = null;

        for ($page = 0; $page < self::MAX_PAGES; ++$page) {
            $response = $this->request($this->pageUrl($cursor), $deadline);
            if ($response === false) {
                return false;
            }

            if (!isset($response['data']) || !is_array($response['data'])) {
                $this->logError('Response without a monitor list', []);
                return false;
            }

            $monitors = [
                ...$monitors,
                ...array_values(array_filter(array_map($this->reduceMonitor(...), $response['data']))),
            ];

            $cursor = $this->nextCursor($response['nextLink'] ?? null);
            if ($cursor === false) {
                return false;
            }
            if ($cursor === null) {
                return $this->withUptimes($monitors, $deadline);
            }
        }

        $this->logError('More monitors than the pages read', ['pages' => self::MAX_PAGES]);
        return false;
    }

    /**
     * Whether the last failure was UptimeRobot's rate limit (HTTP 429)
     */
    public function wasRateLimited(): bool
    {
        return $this->lastHttpStatus === 429;
    }

    /**
     * The fields the dashboard shows of one monitor, its uptime not yet read;
     * null for an entry without a numeric id
     *
     * @return UptimeMonitor|null
     */
    private function reduceMonitor(mixed $monitor): ?array
    {
        if (!is_array($monitor)) {
            return null;
        }

        $monitorId = $this->intOrNull($monitor['id'] ?? null);
        if ($monitorId === null) {
            return null;
        }

        return [
            'id' => $monitorId,
            'friendlyName' => $this->stringOrNull($monitor['friendlyName'] ?? null) ?? 'Unknown',
            'url' => $this->stringOrNull($monitor['url'] ?? null) ?? '',
            'status' => $this->stringOrNull($monitor['status'] ?? null) ?? '',
            'lastDayUptime' => null,
        ];
    }

    /**
     * The monitors with their uptime over the last 24 hours, in percent
     *
     * The list's own history (lastDayUptimes) came back empty on a live account,
     * so each monitor's statistics are read, for accounts with at most
     * MAX_UPTIME_MONITORS monitors. A failed read leaves that monitor's uptime
     * null; a 429 or the end of the time allowed stops the reads.
     *
     * @param list<UptimeMonitor> $monitors
     * @return list<UptimeMonitor>
     */
    private function withUptimes(array $monitors, float $deadline): array
    {
        if (count($monitors) > self::MAX_UPTIME_MONITORS) {
            return $monitors;
        }

        foreach ($monitors as $index => $monitor) {
            $statsUrl = rtrim($this->baseUrl, '/') . '/monitors/' . $monitor['id'] . '/stats/uptime';
            $stats = $this->request($statsUrl, $deadline);
            if ($stats === false) {
                if ($this->wasRateLimited() || $deadline - microtime(true) < 1.0) {
                    break;
                }
                continue;
            }

            $uptime = $this->floatOrNull($stats['uptime'] ?? null);
            $monitors[$index]['lastDayUptime'] = $uptime === null ? null : round($uptime, 2);
        }

        return array_values($monitors);
    }

    /**
     * The value as a float when it is a number, otherwise null.
     */
    private function floatOrNull(mixed $value): ?float
    {
        return is_int($value) || is_float($value) ? (float) $value : null;
    }

    /**
     * The cursor of the next page; null on the last page, false if unreadable
     *
     * The next request is built from the cursor alone, so the API key is only
     * ever sent to the base URL, whatever the link names.
     */
    private function nextCursor(mixed $nextLink): string|false|null
    {
        if ($nextLink === null || $nextLink === '') {
            return null;
        }

        $query = is_string($nextLink) ? parse_url($nextLink, PHP_URL_QUERY) : null;
        parse_str(is_string($query) ? $query : '', $params);
        $cursor = $this->stringOrNull($params['cursor'] ?? null);
        if ($cursor !== null && ctype_digit($cursor)) {
            return $cursor;
        }

        $this->logError('Unreadable next page link', []);
        return false;
    }

    /**
     * @return non-empty-string
     */
    private function pageUrl(?string $cursor): string
    {
        $params = ['limit' => self::PAGE_LIMIT];
        if ($cursor !== null) {
            $params['cursor'] = $cursor;
        }

        return rtrim($this->baseUrl, '/') . '/monitors?' . http_build_query($params);
    }

    /**
     * One GET request
     *
     * @param non-empty-string $url
     * @return array<mixed>|false Decoded response or false on error
     */
    private function request(string $url, float $deadline): array|false
    {
        $timeout = min(self::REQUEST_TIMEOUT, (int) floor($deadline - microtime(true)));
        if ($timeout < 1) {
            $this->logError('Time for the requests used up', []);
            return false;
        }

        $curlHandle = curl_init();
        if ($curlHandle === false) {
            $this->logError('Unable to initialize cURL handle', []);
            return false;
        }

        $optionsSet = curl_setopt_array($curlHandle, [
            CURLOPT_URL => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_HTTPGET => true,
            CURLOPT_TIMEOUT => $timeout,
            CURLOPT_CONNECTTIMEOUT => min(5, $timeout),
            CURLOPT_HTTPHEADER => [
                'Authorization: Bearer ' . $this->apiKey,
                'Accept: application/json',
            ],
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
            CURLOPT_FOLLOWLOCATION => false,
        ]);
        if (!$optionsSet) {
            $this->logError('Unable to configure cURL request', []);
            return false;
        }

        $response = curl_exec($curlHandle);
        $httpCode = $this->intOrNull(curl_getinfo($curlHandle, CURLINFO_RESPONSE_CODE)) ?? 0;

        if (!is_string($response)) {
            $this->logError('cURL request failed', ['error' => curl_error($curlHandle)]);
            return false;
        }

        if ($httpCode !== 200) {
            $this->lastHttpStatus = $httpCode;
            $this->logError('API returned non-200 status', ['http_code' => $httpCode]);
            return false;
        }

        try {
            return $this->arrayOrFalse(json_decode($response, true, 512, JSON_THROW_ON_ERROR));
        } catch (JsonException $e) {
            $this->logError('Invalid JSON response', ['error' => $e->getMessage()]);
            return false;
        }
    }

    /**
     * @return array<mixed>|false
     */
    private function arrayOrFalse(mixed $value): array|false
    {
        return is_array($value) ? $value : false;
    }

    private function stringOrNull(mixed $value): ?string
    {
        return is_string($value) ? $value : null;
    }

    private function intOrNull(mixed $value): ?int
    {
        return is_int($value) ? $value : null;
    }

    /**
     * Log an error
     *
     * @param string $message Error message
     * @param array<string, int|string> $context Additional context; never the API key
     */
    private function logError(string $message, array $context): void
    {
        $safe_context = [];
        foreach ($context as $key => $value) {
            $safe_context[$key] = is_string($value)
                ? substr(preg_replace('/[\x00-\x1F\x7F]/', ' ', $value) ?? '', 0, 255)
                : $value;
        }

        $log_entry = gmdate(DATE_ATOM) . " [UptimeRobotAPI] " . $message;
        if ($safe_context !== []) {
            // A cURL error text is the one value that could hold invalid UTF-8.
            $encoded = json_encode($safe_context, JSON_INVALID_UTF8_SUBSTITUTE);
            $log_entry .= " - " . ($encoded === false ? '[context not encodable]' : $encoded);
        }
        $log_entry .= "\n";

        error_log($log_entry, 3, '/var/log/EngineScript/enginescript-api.log');
    }
}
