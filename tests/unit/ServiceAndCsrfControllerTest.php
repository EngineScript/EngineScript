<?php

declare(strict_types=1);

use EngineScript\Dashboard\API\Controllers\CsrfController;
use EngineScript\Dashboard\API\Controllers\ServiceController;

final class ServiceAndCsrfControllerTest extends EsTestCase
{
    private const array RUNNING = [
        'systemctl is-active nginx.service' => 'active',
        'systemctl is-active mariadb.service' => 'active',
        'systemctl is-active redis-server.service' => 'active',
        'nginx -v' => 'nginx version: nginx/1.29.3',
        'mariadb --version' => 'mariadb from 12.3.4-MariaDB, client 15.2 for debian-linux-gnu (x86_64)',
        'redis-server --version' => 'Redis server v=8.2.3 sha=00000000:0 malloc=jemalloc-5.3.0 bits=64 build=1',
    ];

    public function testServicesReportStateAndVersion(): void
    {
        $this->runner->answers = self::RUNNING;
        $result = $this->respond(fn() => $this->controller(ServiceController::class)->getStatus());

        self::assertSame(200, $result['status']);
        self::assertSame(['version' => '1.29.3', 'online' => true], $result['json']['nginx']);
        self::assertSame(['version' => '12.3.4', 'online' => true], $result['json']['mysql']);
        self::assertSame(['version' => '8.2.3', 'online' => true], $result['json']['redis']);
        self::assertSame(['nginx', 'php', 'mysql', 'redis'], array_keys($result['json']));
    }

    public function testPhpIsTheRunningProcessAndAlwaysOnline(): void
    {
        $result = $this->respond(fn() => $this->controller(ServiceController::class)->getStatus());

        self::assertSame(
            ['version' => PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION . '.' . PHP_RELEASE_VERSION, 'online' => true],
            $result['json']['php']
        );
    }

    public function testAStoppedOrUncheckableServiceIsOffline(): void
    {
        $this->runner->answers = ['systemctl is-active nginx.service' => "activating\nextra"] + self::RUNNING;
        unset($this->runner->answers['systemctl is-active redis-server.service']);
        $result = $this->respond(fn() => $this->controller(ServiceController::class)->getStatus());

        self::assertFalse($result['json']['nginx']['online'], 'only "active" counts');
        self::assertFalse($result['json']['redis']['online'], 'a failed check');
        self::assertTrue($result['json']['mysql']['online']);
    }

    public function testAVersionThatCannotBeReadIsUnknown(): void
    {
        $this->runner->answers = ['nginx -v' => 'nginx version: openresty', 'redis-server --version' => ''] + self::RUNNING;
        unset($this->runner->answers['mariadb --version']);
        $result = $this->respond(fn() => $this->controller(ServiceController::class)->getStatus());

        self::assertSame('Unknown', $result['json']['nginx']['version']);
        self::assertSame('Unknown', $result['json']['mysql']['version']);
        self::assertSame('Unknown', $result['json']['redis']['version']);
    }

    public function testEachServiceRunsItsFixedCommands(): void
    {
        $this->runner->answers = self::RUNNING;
        $this->respond(fn() => $this->controller(ServiceController::class)->getStatus());

        self::assertSame(
            [
                ['/usr/bin/systemctl', 'is-active', 'nginx.service'],
                ['/usr/sbin/nginx', '-v'],
                ['/usr/bin/systemctl', 'is-active', 'mariadb.service'],
                ['/usr/bin/mariadb', '--version'],
                ['/usr/bin/systemctl', 'is-active', 'redis-server.service'],
                ['/usr/bin/redis-server', '--version'],
            ],
            array_column($this->runner->calls, 'command')
        );
        self::assertTrue($this->runner->calls[1]['stderr'], 'nginx -v prints to stderr');
    }

    public function testTheCsrfTokenComesFromTheSession(): void
    {
        $_SESSION['csrf_token'] = str_repeat('ab', 32);
        $result = $this->respond(fn() => $this->controller(CsrfController::class)->getToken());

        self::assertSame(200, $result['status']);
        self::assertSame(['csrf_token' => str_repeat('ab', 32), 'token_name' => '_csrf_token'], $result['json']);
    }

    public function testNoTokenInTheSessionIsAServerError(): void
    {
        foreach ([[], ['csrf_token' => 123]] as $session) {
            $_SESSION = $session;
            $result = $this->respond(fn() => $this->controller(CsrfController::class)->getToken());
            self::assertSame(500, $result['status']);
            self::assertSame(['error' => 'Unable to retrieve CSRF token'], $result['json']);
        }
    }
}
