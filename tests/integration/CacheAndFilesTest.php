<?php

declare(strict_types=1);

/**
 * Cache status and clearing with their real effects, and the files the
 * installer leaves: ownership, permissions, and the logs.
 */
final class CacheAndFilesTest extends IntegrationTestCase
{
    private function clear(string $type): array
    {
        return $this->http('POST', "/api/cache/clear?type={$type}", ['X-CSRF-Token' => $this->csrfToken()]);
    }

    public function testRedisIsReallyFlushed(): void
    {
        self::shell('redis-cli SET es-integration-key 1');
        self::assertSame('1', self::shell('redis-cli EXISTS es-integration-key'));

        $lines = $this->logWhile(fn() => self::assertTrue($this->clear('redis')['json']['results']['redis']['success']));

        self::assertSame('0', self::shell('redis-cli EXISTS es-integration-key'));
        self::assertStringContainsString('Cache cleared - Redis cache flushed successfully', implode("\n", $lines));
    }

    public function testTheFastCgiCacheFilesAreDeleted(): void
    {
        $file = '/var/cache/nginx/es-integration/entry';
        // As nginx's workers write cache entries: owned by www-data
        @mkdir(dirname($file), 0755, true);
        file_put_contents($file, 'cached page');
        chown(dirname($file), 'www-data');
        chown($file, 'www-data');

        $result = $this->clear('fastcgi')['json']['results']['fastcgi'];

        clearstatcache();
        self::assertSame(['success' => true, 'message' => 'FastCGI cache cleared successfully'], $result);
        self::assertFileDoesNotExist($file);
        @rmdir(dirname($file));
    }

    public function testOpcacheIsResetAndReported(): void
    {
        self::assertSame(['success' => true, 'message' => 'OPcache cleared successfully'], $this->clear('opcache')['json']['results']['opcache']);

        $status = $this->http('GET', '/api/cache/status')['json'];
        self::assertTrue($status['opcache']['available']);
        self::assertTrue($status['opcache']['enabled']);
        self::assertIsInt($status['opcache']['memory_usage']['used_memory']);
    }

    public function testCacheStatusReadsTheRealCaches(): void
    {
        $status = $this->http('GET', '/api/cache/status')['json'];

        self::assertTrue($status['redis']['available']);
        self::assertIsInt($status['redis']['used_memory']);
        self::assertSame(['available' => true, 'path' => '/var/cache/nginx', 'size' => explode("\t", self::shell('du -sh /var/cache/nginx'))[0]], $status['fastcgi']);
    }

    public function testThePanelIsOwnedByTheWebServerWithoutWritableOrExecutableFiles(): void
    {
        self::assertSame('', self::shell('find ' . self::PANEL . ' ! -user www-data -o ! -group www-data'), 'every file www-data:www-data');
        self::assertSame('', self::shell('find ' . self::PANEL . ' -type f ! -perm 644'), 'files 644');
        self::assertSame('', self::shell('find ' . self::PANEL . ' -type d ! -perm 755'), 'directories 755');
        self::assertFileDoesNotExist(self::PANEL . '/README.md');
        self::assertFileDoesNotExist(self::PANEL . '/LICENSE');
    }

    public function testSecretsAndLogsHaveTheirModes(): void
    {
        self::assertSame('root:www-data 640', self::shell('stat -c "%U:%G %a" /etc/enginescript/uptimerobot.conf'));
        self::assertSame('root:root 755', self::shell('stat -c "%U:%G %a" /etc/enginescript'));
        foreach (['enginescript-api.log', 'enginescript-api-security.log'] as $log) {
            self::assertSame('www-data:www-data 644', self::shell("stat -c '%U:%G %a' /var/log/EngineScript/{$log}"), $log);
        }
    }

    public function testNoInstallOptionSecretReachesAResponse(): void
    {
        $bodies = '';
        foreach (['/api/system/info', '/api/services/status', '/api/sites', '/api/tools/status', '/api/tools/filemanager/status', '/api/monitoring/uptime', '/api/monitoring/uptime/monitors', '/api/cache/status', '/api/csrf-token'] as $path) {
            $bodies .= $this->http('GET', $path)['body'];
        }

        foreach (['ADMIN_CONTROL_PANEL_PASSWORD', 'FILEMANAGER_PASSWORD', 'MARIADB_ADMIN_PASSWORD', 'PHPMYADMIN_PASSWORD', 'WP_ADMIN_PASSWORD', 'CF_GLOBAL_API_KEY', 'PUSHBULLET_TOKEN'] as $name) {
            $value = self::option($name);
            if (strlen($value) >= 6 && $value !== 'PLACEHOLDER') {
                self::assertStringNotContainsString($value, $bodies, $name);
            }
        }
    }
}
