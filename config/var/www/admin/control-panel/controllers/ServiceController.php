<?php

/**
 * EngineScript Admin Dashboard - Service Controller
 *
 * Handles service status endpoints for nginx, PHP-FPM, MariaDB, and Redis.
 *
 * @package EngineScript\Dashboard\API\Controllers
 * @version 1.0.0
 */

declare(strict_types=1);

require_once __DIR__ . '/BaseController.php';
require_once __DIR__ . '/../classes/SystemCommand.php';

/**
 * Service Status Controller
 *
 * Provides status information for server services.
 *
 * @psalm-api
 */
final class ServiceController extends BaseController
{
    /**
     * Get status of all services
     *
     * Returns status of nginx, PHP-FPM, MariaDB, and Redis. Not cached: the
     * commands take about 0.3 s together (measured in Phase 11).
     *
     * Endpoint: GET /services/status
     *
     * @return void Outputs JSON response
     * @psalm-api
     */
    public function getStatus(): void
    {
        try {
            $services = [
                'nginx' => $this->getServiceStatus('nginx'),
                'php' => $this->getPhpServiceStatus(),
                'mysql' => $this->getServiceStatus('mariadb'),
                'redis' => $this->getServiceStatus('redis-server'),
            ];

            $this->response->success($services);
        } catch (Throwable $e) {
            $this->securityLogger->write('Services status error', $e->getMessage());
            $this->response->serverError('Unable to retrieve services status');
        }
    }

    /**
     * Get status of one of the services SystemCommand knows: nginx, mariadb, or redis-server
     *
     * @return array{version: string, online: bool} Service status
     */
    private function getServiceStatus(string $service): array
    {
        try {
            $online = SystemCommand::getServiceState($service) === 'active';

            return [
                'version' => $this->getServiceVersion($service),
                'online' => $online,
            ];
        } catch (Throwable $e) {
            $this->securityLogger->write('Service status error', $e->getMessage());
            return $this->createErrorServiceStatus();
        }
    }

    /**
     * Get PHP-FPM service status
     *
     * This request is answered by PHP-FPM, so the service is running, and the
     * running process reports its own version.
     *
     * @return array{version: string, online: bool} Service status
     */
    private function getPhpServiceStatus(): array
    {
        return [
            'version' => sprintf('%d.%d.%d', PHP_MAJOR_VERSION, PHP_MINOR_VERSION, PHP_RELEASE_VERSION),
            'online' => true,
        ];
    }

    /**
     * Get service version
     *
     * @return string Version string or 'Unknown'
     */
    private function getServiceVersion(string $service): string
    {
        return match ($service) {
            'nginx' => $this->parseVersionOutput(SystemCommand::getNginxVersion(), '/nginx\/(\d+\.\d+\.\d+)/'),
            'mariadb' => $this->parseVersionOutput(SystemCommand::getMariadbVersion(), '/mariadb.*?(\d+\.\d+\.\d+)/'),
            'redis-server' => $this->parseVersionOutput(SystemCommand::getRedisVersion(), '/v=(\d+\.\d+\.\d+)/'),
            default => 'Unknown',
        };
    }

    /**
     * Create error service status response
     *
     * @return array{version: string, online: bool} Error status
     */
    private function createErrorServiceStatus(): array
    {
        return [
            'version' => 'Error',
            'online' => false,
        ];
    }

    /**
     * Extract a version string from command output.
     *
     * Applies $pattern to $output and returns the first capture group.
     * Returns 'Unknown' when output is false or the pattern does not match.
     *
     * @param string|false $output Raw command output
     * @param non-empty-string $pattern PCRE pattern with one capture group for the version
     * @return string Version string or 'Unknown'
     */
    private function parseVersionOutput(string|false $output, string $pattern): string
    {
        if ($output !== false && preg_match($pattern, $output, $matches)) {
            return $matches[1];
        }
        return 'Unknown';
    }
}
