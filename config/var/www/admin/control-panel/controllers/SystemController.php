<?php

/**
 * EngineScript Admin Dashboard - System Controller
 *
 * Handles system information endpoints including OS, kernel, and network info.
 *
 * @package EngineScript\Dashboard\API\Controllers
 * @version 1.0.0
 */

declare(strict_types=1);

namespace EngineScript\Dashboard\API\Controllers;

use EngineScript\Dashboard\Classes\SystemCommand;

/**
 * System Information Controller
 *
 * Provides system-level information about the server.
 *
 * SystemCommand is a static wrapper by design: tests swap its command runner with
 * SystemCommand::useRunner().
 * @SuppressWarnings("PHPMD.StaticAccess")
 *
 * @psalm-api
 */
final class SystemController extends BaseController
{
    /**
     * Get system information
     *
     * Returns OS distribution, kernel version, and network information.
     *
     * Endpoint: GET /system/info
     *
     * @return void Outputs JSON response
     * @psalm-api
     */
    /**
     * The os-release file to read, /etc/os-release unless a test chose another
     */
    private static string $osReleaseFile = '/etc/os-release';

    /**
     * Read the distribution from another os-release file, or from /etc/os-release again for null; for tests
     *
     * @psalm-api
     */
    public static function useOsReleaseFile(?string $path): void
    {
        self::$osReleaseFile = $path ?? '/etc/os-release';
    }

    public function getInfo(): void
    {
        try {
            $info = [
                'os' => $this->getOsInfo(),
                'kernel' => $this->getKernelVersion(),
                'network' => $this->getNetworkInfo(),
            ];

            $this->response->success($info);
        } catch (\Throwable $e) {
            $this->securityLogger->write('System info error', $e->getMessage());
            $this->response->serverError('Unable to retrieve system info');
        }
    }

    /**
     * Get OS distribution information
     *
     * Reads PRETTY_NAME from /etc/os-release
     *
     * @return string OS distribution name or 'Unknown Linux Distribution'
     */
    private function getOsInfo(): string
    {
        $osRelease = parse_ini_file(self::$osReleaseFile);
        if (is_array($osRelease) && !empty($osRelease['PRETTY_NAME']) && is_string($osRelease['PRETTY_NAME'])) {
            return $osRelease['PRETTY_NAME'];
        }

        return 'Unknown Linux Distribution';
    }

    /**
     * Get kernel version
     *
     * Uses SystemCommand to safely retrieve kernel version.
     *
     * @return string Kernel version or 'Unknown'
     */
    private function getKernelVersion(): string
    {
        try {
            $version = SystemCommand::getKernelVersion();
            if ($version !== false && preg_match('/^[0-9]+\.[0-9]+\.[0-9]+/', $version)) {
                return $version;
            }
        } catch (\Throwable $e) {
            $this->securityLogger->write('Kernel version error', $e->getMessage());
        }
        return 'Unknown';
    }

    /**
     * Get network information
     *
     * Returns hostname and primary IP address.
     *
     * @return string Network info in format "hostname (ip)"
     */
    private function getNetworkInfo(): string
    {
        try {
            $hostname = gethostname();
            // getNetworkIP() returns a validated address or false.
            $ipAddress = SystemCommand::getNetworkIP();

            return sprintf(
                '%s (%s)',
                $hostname === false ? 'Unknown' : $hostname,
                $ipAddress === false ? 'Unknown' : $ipAddress
            );
        } catch (\Throwable $e) {
            $this->securityLogger->write('Network info error', $e->getMessage());
            return 'Unknown (Unknown)';
        }
    }
}
