<?php

/**
 * Render the API responses the dashboard script tests serve to the page's fetch().
 *
 * Prints one JSON object: scenario name => "METHOD /api/path" => {status, body}.
 * Every body comes from the panel's own PHP: the Router and controllers with
 * SystemCommand's scripted runner, or ApiResponder for the answers api.php sends
 * itself (rate limit, invalid path, no session). Where a controller reads files
 * this machine lacks (sites-enabled, the UptimeRobot key), the test calls the
 * controller's own method that builds the answer from what it read, with
 * fixture input, and sends it through ApiResponder as the controller does.
 *
 * Run as: php -d display_errors=stderr tests/js/render-api.php
 */

declare(strict_types=1);

require dirname(__DIR__) . '/bootstrap.php';

const ES_TEST_TOKEN = 'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2'; // gitleaks:allow (a test value)

$running = [
    'systemctl is-active nginx.service' => 'active',
    'systemctl is-active mariadb.service' => 'active',
    'systemctl is-active redis-server.service' => 'active',
    'nginx -v' => 'nginx version: nginx/1.29.3',
    'mariadb --version' => 'mariadb from 11.8.3-MariaDB, client 15.2 for debian-linux-gnu (x86_64)',
    'redis-server --version' => 'Redis server v=8.2.3 sha=00000000:0 malloc=jemalloc-5.3.0 bits=64 build=1',
    'redis-cli INFO memory' => "used_memory:1031336\r\nused_memory_human:1007.16K\r\n",
    'redis-cli FLUSHALL' => 'OK',
    'uname -r' => '6.8.0-40-generic',
    'ip route get 8.8.8.8' => '8.8.8.8 via 10.0.0.1 dev eth0 src 10.0.0.5 uid 0',
];

/**
 * @return array{status: int, body: string}
 */
function es_capture(callable $answer): array
{
    http_response_code(200);
    ob_start();
    $answer();
    $body = (string) ob_get_clean();
    $status = http_response_code();

    return ['status' => is_int($status) ? $status : 0, 'body' => $body];
}

/**
 * @param array<string, string|false> $answers
 * @return array{status: int, body: string}
 */
function es_route(string $method, string $path, array $answers, array $session = ['csrf_token' => ES_TEST_TOKEN], array $query = []): array
{
    es_test_reset(new EsTestRunner($answers));
    $_SESSION = $session;
    $request = es_test_request(['REQUEST_METHOD' => $method, 'HTTP_X_CSRF_TOKEN' => ES_TEST_TOKEN], $query);
    $logger = new SecurityLogger($request, sys_get_temp_dir() . '/es-js-render.log');
    $router = new Router(new ApiResponder(), $request, $logger, new Session());

    return es_capture(static fn() => $router->dispatch($path));
}

/**
 * A controller's private method, called with fixture input.
 */
function es_private(string $class, string $method, mixed ...$arguments): mixed
{
    $request = es_test_request();
    $controller = new $class(new Session(), new ApiResponder(), new SecurityLogger($request, sys_get_temp_dir() . '/es-js-render.log'), $request);

    return new ReflectionMethod($class, $method)->invoke($controller, ...$arguments);
}

// Sites: SiteController's own reading of fixture nginx configurations and version.php files
$fixtures = sys_get_temp_dir() . '/es-js-sites-' . bin2hex(random_bytes(4));
$sites = [];
foreach (['example.com' => '6.8.3', 'shop.example' => null, 'x"><img src=x onerror=alert(1)>.example' => '6.7'] as $domain => $version) {
    $root = "{$fixtures}/" . md5($domain) . '/html';
    mkdir("{$root}/wp-includes", 0700, true);
    if ($version !== null) {
        file_put_contents("{$root}/wp-includes/version.php", "<?php\n\$wp_version = '{$version}';\n");
    }
    $config = "{$fixtures}/" . md5($domain) . '.conf';
    $ssl = $domain === 'shop.example' ? '' : "  ssl_certificate /etc/nginx/ssl/{$domain}/fullchain.pem;\n";
    file_put_contents($config, "server {\n  server_name {$domain} www.{$domain};\n{$ssl}  root {$root};\n  include /etc/nginx/globals/wp-secure.conf;\n}\n");
    $site = es_private(SiteController::class, 'processNginxConfig', realpath($config));
    if (is_array($site)) {
        $sites[] = $site;
    }
}
exec(PHP_OS_FAMILY === 'Windows' ? 'rmdir /s /q ' . escapeshellarg($fixtures) : 'rm -rf ' . escapeshellarg($fixtures));

// UptimeRobot configured: UptimeController's own status mapping and formatting of v3 records
$monitors = [
    ['id' => 101, 'friendlyName' => 'Main site', 'url' => 'https://example.com', 'status' => 'UP', 'lastDayUptime' => 99.98],
    ['id' => 102, 'friendlyName' => '<b>Shop</b> & café', 'url' => 'https://shop.example', 'status' => 'DOWN', 'lastDayUptime' => 0.0],
    ['id' => 103, 'friendlyName' => 'Blog', 'url' => 'javascript:alert(1)', 'status' => 'PAUSED', 'lastDayUptime' => null],
];

$responder = new ApiResponder();
$out = [];
$out['running'] = [
    'GET /api/csrf-token' => es_route('GET', '/csrf-token', $running),
    'GET /api/services/status' => es_route('GET', '/services/status', $running),
    'GET /api/system/info' => es_route('GET', '/system/info', $running),
    'GET /api/tools/status' => es_route('GET', '/tools/status', $running),
    'GET /api/tools/filemanager/status' => es_route('GET', '/tools/filemanager/status', $running),
    'GET /api/cache/status' => es_route('GET', '/cache/status', $running),
    'GET /api/monitoring/uptime' => es_route('GET', '/monitoring/uptime', $running),
    'GET /api/monitoring/uptime/monitors' => es_route('GET', '/monitoring/uptime/monitors', $running),
    'GET /api/sites' => es_capture(static fn() => $responder->success($sites)),
];
// Keyed by the types the dashboard sends in its JSON body, joined with commas
foreach (['redis', 'fastcgi', 'opcache', 'redis,fastcgi,opcache'] as $types) {
    $out['running']["POST /api/cache/clear {$types}"] = es_route('POST', '/cache/clear', $running, query: ['type' => $types]);
}
$out['uptime-configured'] = [
    'GET /api/monitoring/uptime' => es_capture(static fn() => $responder->success(es_private(UptimeController::class, 'calculateOverallStatus', $monitors))),
    'GET /api/monitoring/uptime/monitors' => es_capture(static fn() => $responder->success(es_private(UptimeController::class, 'formatMonitors', $monitors))),
];
$out['uptime-empty'] = [
    'GET /api/monitoring/uptime' => es_capture(static fn() => $responder->success(es_private(UptimeController::class, 'calculateOverallStatus', []))),
    'GET /api/monitoring/uptime/monitors' => es_capture(static fn() => $responder->success(es_private(UptimeController::class, 'formatMonitors', []))),
];
$out['services-stopped'] = [
    'GET /api/services/status' => es_route('GET', '/services/status', ['systemctl is-active nginx.service' => 'active', 'nginx -v' => 'nginx version: nginx/1.29.3']),
];
$out['no-sites'] = [
    'GET /api/sites' => es_capture(static fn() => $responder->success([])),
];
// SiteController cannot produce a domain with markup (its server_name pattern drops it); the
// dashboard checks each domain again. This is how the API would encode one.
$out['sites-markup'] = [
    'GET /api/sites' => es_capture(static fn() => $responder->success([
        ['domain' => 'x"><img src=x onerror=alert(1)>.example', 'wp_version' => '<b>6.8</b>', 'ssl_status' => 'Enabled'],
        ['domain' => 'good.example', 'wp_version' => '<b>6.8</b>', 'ssl_status' => 'Unknown'],
    ])),
];
$out['failures'] = [
    'csrf-missing' => es_route('GET', '/csrf-token', [], []),
    'csrf-refused' => es_capture(static fn() => $responder->forbidden('Invalid or missing CSRF token')),
    'rate-limited' => es_capture(static fn() => $responder->rateLimited()),
    'no-session' => es_capture(static fn() => $responder->error('Session storage unavailable', 503)),
    'not-found' => es_route('GET', '/no/such/route', $running),
    'POST /api/cache/clear redis' => es_route('POST', '/cache/clear', ['redis-cli FLUSHALL' => false], query: ['type' => 'redis']),
];

echo json_encode($out, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES);
