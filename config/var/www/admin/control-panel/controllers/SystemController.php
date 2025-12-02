<?php
/**
 * EngineScript Admin Dashboard - System Controller
 * 
 * Handles system information endpoints including OS, kernel, and network info.
 * 
 * @package EngineScript\Dashboard\API\Controllers
 * @version 1.0.0
 */

require_once __DIR__ . '/BaseController.php';
require_once __DIR__ . '/../classes/SystemCommand.php';

/**
 * System Information Controller
 * 
 * Provides system-level information about the server.
 */
class SystemController extends BaseController
{
    /**
     * API endpoint path
     */
    private const ENDPOINT = '/system/info';

    /**
     * Get system information
     * 
     * Returns OS distribution, kernel version, and network information.
     * Response is cached based on configured TTL.
     * 
     * Endpoint: GET /system/info
     * 
     * @return void Outputs JSON response
     */
    public function getInfo()
    {
        try {
            // Check cache first
            $cached = $this->getCached(self::ENDPOINT);
            if ($cached !== null) {
                // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
                ApiResponse::cached($cached, $this->getTtl(self::ENDPOINT));
                return;
            }

            $info = [
                'os' => $this->getOsInfo(),
                'kernel' => $this->getKernelVersion(),
                'network' => $this->getNetworkInfo()
            ];

            $result = $this->sanitizeOutput($info);

            // Cache the result
            $this->setCached(self::ENDPOINT, $result);

            // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
            ApiResponse::success($result, $this->getTtl(self::ENDPOINT));
        } catch (Exception $e) {
            $this->logSecurityEvent('System info error', $e->getMessage());
            // codacy:ignore - Static ApiResponse method used; dependency injection would require service container
            ApiResponse::serverError('Unable to retrieve system info');
        }
    }

    /**
     * Get OS distribution information
     * 
     * Reads PRETTY_NAME from /etc/os-release
     * 
     * @return string OS distribution name or 'Unknown Linux Distribution'
     */
    private function getOsInfo()
    {
        // codacy:ignore - file_get_contents() required for OS info reading in standalone API
        $os_release = @file_get_contents('/etc/os-release');
        if ($os_release && preg_match('/PRETTY_NAME="([^"]+)"/', $os_release, $matches)) {
            return $matches[1];
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
    private function getKernelVersion()
    {
        try {
            // codacy:ignore - Static utility class pattern
            $version = SystemCommand::getKernelVersion();
            if ($version !== null) {
                $version = trim($version);
                // Validate kernel version format
                if (preg_match('/^[0-9]+\.[0-9]+\.[0-9]+/', $version)) {
                    return htmlspecialchars($version, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
                }
            }
        } catch (Exception $e) {
            $this->logSecurityEvent('Kernel version error', $e->getMessage());
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
    private function getNetworkInfo()
    {
        try {
            $hostname = gethostname();
            if ($hostname === false) {
                $hostname = 'Unknown';
            }

            if ($hostname !== 'Unknown') {
                $hostname = htmlspecialchars($hostname, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
            }

            // Use safer method to get IP
            $client_ip = 'Unknown';

            // codacy:ignore - file_exists() required for network info reading in standalone API
            if (file_exists('/proc/net/route')) {
                // codacy:ignore - Static utility class pattern
                $ip_output = SystemCommand::getNetworkIP();
                if ($ip_output !== null) {
                    $client_ip = trim($ip_output);
                    // Validate the IP
                    if (!filter_var($client_ip, FILTER_VALIDATE_IP)) {
                        $client_ip = 'Unknown';
                    }

                    if ($client_ip !== 'Unknown') {
                        $client_ip = htmlspecialchars($client_ip, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
                    }
                }
            }

            return $hostname . ' (' . $client_ip . ')';
        } catch (Exception $e) {
            $this->logSecurityEvent('Network info error', $e->getMessage());
            return 'Unknown (Unknown)';
        }
    }
}
