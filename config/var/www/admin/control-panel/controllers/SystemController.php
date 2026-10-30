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

require_once __DIR__ . '/BaseController.php';
require_once __DIR__ . '/../classes/SystemCommand.php';

/**
 * System Information Controller
 *
 * Provides system-level information about the server.
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
    public function getInfo(): void
    {
        try {
            $info = [
                'os' => $this->getOsInfo(),
                'kernel' => $this->getKernelVersion(),
                'network' => $this->getNetworkInfo(),
            ];

            $this->response->success($info);
        } catch (Throwable $e) {
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
        $os_release = parse_ini_file('/etc/os-release');
        if (is_array($os_release) && !empty($os_release['PRETTY_NAME']) && is_string($os_release['PRETTY_NAME'])) {
            return $os_release['PRETTY_NAME'];
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
        } catch (Throwable $e) {
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
            $ip_address = SystemCommand::getNetworkIP();

            return sprintf(
                '%s (%s)',
                $hostname === false ? 'Unknown' : $hostname,
                $ip_address === false ? 'Unknown' : $ip_address
            );
        } catch (Throwable $e) {
            $this->securityLogger->write('Network info error', $e->getMessage());
            return 'Unknown (Unknown)';
        }
    }
}
