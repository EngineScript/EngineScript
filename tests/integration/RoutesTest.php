<?php

declare(strict_types=1);

/**
 * Each read route against the server's real services, files, and commands.
 */
final class RoutesTest extends IntegrationTestCase
{
    public function testServicesReportTheRealStateAndVersions(): void
    {
        $services = $this->http('GET', '/api/services/status')['json'];

        foreach (['nginx' => 'nginx', 'mysql' => 'mariadb', 'redis' => 'redis-server'] as $key => $unit) {
            self::assertSame(self::shell("systemctl is-active {$unit}") === 'active', $services[$key]['online'], $key);
        }
        self::assertSame(self::shell("nginx -v 2>&1 | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+' | head -1"), $services['nginx']['version']);
        self::assertSame(self::shell("mariadb --version | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+' | head -1"), $services['mysql']['version']);
        self::assertSame(self::shell("redis-server --version | grep -oE 'v=[0-9.]+' | cut -d= -f2"), $services['redis']['version']);
        self::assertTrue($services['php']['online']);
        self::assertStringStartsWith(self::shell("source /usr/local/bin/enginescript/enginescript-variables.txt && printf %s \"\${PHP_VER}\""), $services['php']['version'], 'PHP-FPM answers, at the installed version');
    }

    public function testASingleStoppedServiceShowsOffline(): void
    {
        self::shell('systemctl stop redis-server');
        try {
            $services = $this->http('GET', '/api/services/status')['json'];
        } finally {
            self::shell('systemctl start redis-server');
        }

        self::assertFalse($services['redis']['online']);
        self::assertTrue($services['nginx']['online']);
    }

    public function testSystemInfoIsTheServers(): void
    {
        $info = $this->http('GET', '/api/system/info')['json'];

        self::assertSame(self::shell('source /etc/os-release && printf %s "$PRETTY_NAME"'), $info['os']);
        self::assertSame(self::shell('uname -r'), $info['kernel']);
        self::assertStringStartsWith(self::shell('hostname') . ' (', $info['network']);
        self::assertMatchesRegularExpression('/\((\d{1,3}(\.\d{1,3}){3}|[0-9a-f:]+|Unknown)\)$/', $info['network']);
    }

    public function testTheWordPressSiteIsFoundWithItsVersion(): void
    {
        $sites = $this->http('GET', '/api/sites')['json'];
        $site = array_values(array_filter($sites, fn(array $s): bool => $s['domain'] === self::$domain))[0] ?? null;

        self::assertNotNull($site, 'the suite\'s site');
        $version = self::shell("grep -oP \"wp_version = '\\K[^']+\" /var/www/sites/" . self::$domain . '/html/wp-includes/version.php');
        self::assertSame($version, $site['wp_version']);
        self::assertSame('Enabled', $site['ssl_status']);
    }

    public function testSiteDiscoveryStaysInsideItsDirectories(): void
    {
        $outside = '/etc/nginx/es-integration-outside.conf';
        $link = '/etc/nginx/sites-enabled/zz-es-integration-link.conf';
        $notWordPress = '/etc/nginx/sites-enabled/zz-es-integration-static';
        $escapeSite = '/etc/nginx/sites-enabled/zz-es-integration-escape';
        $escapeRoot = '/var/www/sites/escape.test/html';
        file_put_contents($outside, "server { server_name outside.test; root /var/www/outside; } # wordpress\n");
        symlink($outside, $link);
        file_put_contents($notWordPress, "server { server_name static.test; root /var/www/static; }\n");
        mkdir("{$escapeRoot}/wp-includes", 0755, true);
        file_put_contents('/tmp/es-integration-version.php', "<?php\n\$wp_version = '9.9.9';\n");
        symlink('/tmp/es-integration-version.php', "{$escapeRoot}/wp-includes/version.php");
        file_put_contents($escapeSite, "server { server_name escape.test; root {$escapeRoot}; } # wp-\n");

        try {
            $domains = array_column($this->http('GET', '/api/sites')['json'], 'wp_version', 'domain');
        } finally {
            foreach ([$link, $outside, $notWordPress, $escapeSite, "{$escapeRoot}/wp-includes/version.php", '/tmp/es-integration-version.php'] as $file) {
                @unlink($file);
            }
            @rmdir("{$escapeRoot}/wp-includes");
            @rmdir($escapeRoot);
            @rmdir('/var/www/sites/escape.test');
        }

        self::assertArrayNotHasKey('outside.test', $domains, 'a link out of sites-enabled is not read');
        self::assertArrayNotHasKey('static.test', $domains, 'not WordPress');
        self::assertSame('Unknown', $domains['escape.test'] ?? null, 'a version.php outside the root is not read');
    }

    public function testToolsAndFileManagerReportWhatIsInstalled(): void
    {
        self::assertSame(['adminer' => is_file('/var/www/admin/tools/adminer/index.php')], $this->http('GET', '/api/tools/status')['json']);

        $fileManager = $this->http('GET', '/api/tools/filemanager/status')['json'];
        self::assertSame(is_file('/var/www/admin/tools/tinyfilemanager/tinyfilemanager.php'), $fileManager['available']);
        self::assertSame(is_file('/var/www/admin/tools/tinyfilemanager/config.php'), $fileManager['config_exists']);
        self::assertSame(self::shell("source /usr/local/bin/enginescript/enginescript-variables.txt && printf %s \"\${TINYFILEMANAGER_VER}\""), $fileManager['version']);
    }

    public function testUptimeWithoutAKeyIsNotConfigured(): void
    {
        self::assertSame('PLACEHOLDER', self::option('UPTIMEROBOT_API_KEY'), 'the suite\'s server has no UptimeRobot key');
        self::assertSame(['enabled' => false, 'reason' => 'UptimeRobot API not configured'], $this->http('GET', '/api/monitoring/uptime')['json']);
        self::assertSame(['enabled' => false, 'reason' => 'UptimeRobot API not configured', 'monitors' => []], $this->http('GET', '/api/monitoring/uptime/monitors')['json']);
    }
}
