<?php

/**
 * Tests for GET /system/info: the distribution from os-release, the kernel, and the network.
 *
 * os-release is a temporary file (SystemController::useOsReleaseFile()); the commands are answered
 * by the test runner that EsTestCase installs.
 */

declare(strict_types=1);

use EngineScript\Dashboard\API\Controllers\SystemController;

final class SystemControllerTest extends EsTestCase
{
    protected function tearDown(): void
    {
        SystemController::useOsReleaseFile(null);
        parent::tearDown();
    }

    private function osRelease(string $content): void
    {
        $file = $this->makeTemporaryDirectory() . '/os-release';
        file_put_contents($file, $content);
        SystemController::useOsReleaseFile($file);
    }

    public function testInfoReportsTheDistributionKernelAndAddress(): void
    {
        $this->osRelease("NAME=\"Ubuntu\"\nPRETTY_NAME=\"Ubuntu 24.04.3 LTS\"\n");
        $this->runner->answers = [
            'uname -r' => '6.8.0-90-generic',
            'ip route get 8.8.8.8' => '8.8.8.8 via 10.0.0.1 dev eth0 src 10.0.0.5 uid 0',
        ];

        $result = $this->respond(fn() => $this->controller(SystemController::class)->getInfo());

        $this->assertSame(200, $result['status']);
        $this->assertSame('Ubuntu 24.04.3 LTS', $result['json']['os']);
        $this->assertSame('6.8.0-90-generic', $result['json']['kernel']);
        $this->assertStringEndsWith('(10.0.0.5)', $result['json']['network']);
    }

    public function testInfoFallsBackWhenNothingCanBeRead(): void
    {
        $this->osRelease("NAME=\"Ubuntu\"\n");
        $this->runner->answers = ['uname -r' => 'not a version'];

        $result = $this->respond(fn() => $this->controller(SystemController::class)->getInfo());

        $this->assertSame('Unknown Linux Distribution', $result['json']['os']);
        $this->assertSame('Unknown', $result['json']['kernel']);
        $this->assertStringEndsWith('(Unknown)', $result['json']['network']);
    }
}
