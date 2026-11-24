<?php

/**
 * A stand-in for UptimeRobot's API v3, for PHP's built-in server. The scenario is
 * the API key the client sends ("Authorization: Bearer <scenario>"). Each request
 * is appended to the file ES_STAND_IN_LOG names, as one JSON line.
 *
 * The records follow the v3 responses recorded on a live account in Phase 10
 * (phase-10-evidence/uptimerobot-v3): data, nextLink, string status, and the
 * secret-bearing fields the panel must drop.
 */

declare(strict_types=1);

$auth = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
$scenario = str_starts_with($auth, 'Bearer ') ? substr($auth, 7) : '';
$path = parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_PATH);
parse_str((string) parse_url($_SERVER['REQUEST_URI'] ?? '', PHP_URL_QUERY), $query);

$log = getenv('ES_STAND_IN_LOG');
if (is_string($log) && $log !== '') {
    file_put_contents($log, json_encode([
        'method' => $_SERVER['REQUEST_METHOD'] ?? '',
        'uri' => $_SERVER['REQUEST_URI'] ?? '',
        'auth' => $auth,
        'accept' => $_SERVER['HTTP_ACCEPT'] ?? '',
    ]) . "\n", FILE_APPEND);
}

function esMonitor(int $id, string $status): array
{
    return [
        'id' => $id,
        'friendlyName' => "Site {$id} <b>&</b>",
        'url' => "https://site{$id}.example",
        'status' => $status,
        'interval' => 300,
        'apiKey' => 'monitor-secret-key',
        'httpUsername' => 'basic-user',
        'httpPassword' => 'basic-password',
        'customHttpHeaders' => [['name' => 'X-Token', 'value' => 'header-secret']],
        'lastDayUptimes' => ['bucketSize' => 3600, 'histogram' => []],
    ];
}

function esAnswer(int $status, mixed $body): void
{
    http_response_code($status);
    header('Content-Type: application/json');
    echo is_string($body) ? $body : json_encode($body);
}

$cursor = $query['cursor'] ?? null;
$statsId = preg_match('#^/v3/monitors/(\d+)/stats/uptime$#', (string) $path, $m) === 1 ? (int) $m[1] : null;

if ($statsId !== null) {
    match (true) {
        $scenario === 'stats-429' => esAnswer(429, ['error' => 'Too many requests']),
        $statsId === 3 => esAnswer(500, ['error' => 'internal']),
        $statsId === 2 => esAnswer(200, ['uptime' => 100]),
        default => esAnswer(200, ['uptime' => 99.98765]),
    };
    return true;
}

if ($path !== '/v3/monitors') {
    esAnswer(404, ['error' => 'not found']);
    return true;
}

match ($scenario) {
    'two-pages' => $cursor === null
        ? esAnswer(200, [
            'data' => [esMonitor(1, 'UP'), esMonitor(2, 'DOWN'), ['id' => 'x'], 'junk'],
            // Another host in the link: the client must keep its own base URL.
            'nextLink' => 'https://evil.example/v3/monitors?cursor=200&limit=200',
        ])
        : esAnswer(200, ['data' => [esMonitor(3, 'PAUSED')], 'nextLink' => null]),
    'nine' => esAnswer(200, ['data' => array_map(static fn(int $id) => esMonitor($id, 'UP'), range(1, 9)), 'nextLink' => null]),
    'endless' => esAnswer(200, ['data' => [esMonitor((int) ($cursor ?? 0) + 1, 'UP')], 'nextLink' => 'https://api.example/v3/monitors?cursor=' . ((int) ($cursor ?? 0) + 1)]),
    'bad-cursor' => esAnswer(200, ['data' => [esMonitor(1, 'UP')], 'nextLink' => 'https://api.example/v3/monitors?cursor=../etc']),
    'rate-limited' => esAnswer(429, ['error' => 'Too many requests']),
    'bad-json' => esAnswer(200, '{"data": ['),
    'no-data' => esAnswer(200, ['monitors' => []]),
    'stats-429' => esAnswer(200, ['data' => [esMonitor(1, 'UP'), esMonitor(4, 'UP')], 'nextLink' => null]),
    default => esAnswer(401, ['error' => 'unauthorized']),
};

return true;
