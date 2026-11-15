<?php

declare(strict_types=1);

final class SystemCommandTest extends EsTestCase
{
    public function testEveryCommandRunsAnAbsoluteExecutableWithFixedArguments(): void
    {
        SystemCommand::getKernelVersion();
        SystemCommand::getNetworkIP();
        SystemCommand::getNginxVersion();
        SystemCommand::getMariadbVersion();
        SystemCommand::getRedisVersion();
        SystemCommand::flushRedis();
        SystemCommand::getRedisMemoryInfo();
        SystemCommand::getFastCgiCacheSize();
        SystemCommand::clearFastCgiCache();

        self::assertSame(
            [
                ['/usr/bin/uname', '-r'],
                ['/usr/sbin/ip', 'route', 'get', '8.8.8.8'],
                ['/usr/sbin/nginx', '-v'],
                ['/usr/bin/mariadb', '--version'],
                ['/usr/bin/redis-server', '--version'],
                ['/usr/bin/redis-cli', 'FLUSHALL'],
                ['/usr/bin/redis-cli', 'INFO', 'memory'],
                ['/usr/bin/du', '-sh', '/var/cache/nginx'],
                ['/usr/bin/find', '/var/cache/nginx', '-type', 'f', '-delete'],
            ],
            array_column($this->runner->calls, 'command')
        );
    }

    public function testEachCommandMayRunEightSeconds(): void
    {
        SystemCommand::getKernelVersion();

        self::assertSame(8, $this->runner->calls[0]['timeout']);
        self::assertFalse($this->runner->calls[0]['stderr']);
    }

    public function testOnlyTheThreeServicesCanBeChecked(): void
    {
        $this->runner->answers = ['systemctl is-active nginx.service' => 'active'];

        self::assertSame('active', SystemCommand::getServiceState('nginx'));
        self::assertFalse(SystemCommand::getServiceState('ssh'));
        self::assertFalse(SystemCommand::getServiceState('nginx.service; reboot'));
        self::assertCount(1, $this->runner->calls, 'no command for an unknown service');
    }

    public function testTheStateIsTheFirstLineAndEmptyOutputIsAFailure(): void
    {
        $this->runner->answers = ['systemctl is-active mariadb.service' => "failed\nmore"];
        self::assertSame('failed', SystemCommand::getServiceState('mariadb'));

        $this->runner->answers = ['systemctl is-active mariadb.service' => ''];
        self::assertFalse(SystemCommand::getServiceState('mariadb'));
    }

    public function testTheNetworkAddressIsTheRoutesSourceAndMustBeValid(): void
    {
        $this->runner->answers = ['ip route get 8.8.8.8' => '8.8.8.8 via 10.0.0.1 dev eth0 src 10.0.0.5 uid 0'];
        self::assertSame('10.0.0.5', SystemCommand::getNetworkIP());

        $this->runner->answers = ['ip route get 8.8.8.8' => '8.8.8.8 dev eth0 src 2001:db8::5 metric 100'];
        self::assertSame('2001:db8::5', SystemCommand::getNetworkIP());

        foreach (['8.8.8.8 via 10.0.0.1 dev eth0', 'src 999.1.1.1', 'src ::::'] as $output) {
            $this->runner->answers = ['ip route get 8.8.8.8' => $output];
            self::assertFalse(SystemCommand::getNetworkIP(), $output);
        }
    }

    public function testOutputIsPassedThroughAsTheRunnerReturnsIt(): void
    {
        $this->runner->answers = ['uname -r' => '6.8.0-40-generic', 'du -sh /var/cache/nginx' => "12K\t/var/cache/nginx"];

        self::assertSame('6.8.0-40-generic', SystemCommand::getKernelVersion());
        self::assertSame("12K\t/var/cache/nginx", SystemCommand::getFastCgiCacheSize());
        self::assertFalse(SystemCommand::getMariadbVersion(), 'a failed command');
    }
}
