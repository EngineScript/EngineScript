<?php

/**
 * EngineScript Admin Dashboard - Tools Controller
 *
 * Reports which optional admin tools are installed.
 *
 * @package EngineScript\Dashboard\API\Controllers
 */

declare(strict_types=1);

require_once __DIR__ . '/BaseController.php';

/**
 * Tools Controller
 *
 * Adminer is installed only with INSTALL_ADMINER=1 (off by default), so the dashboard shows
 * its card only when this says it is there.
 *
 * @psalm-api
 */
final class ToolsController extends BaseController
{
    private const string ADMINER_INDEX = '/var/www/admin/tools/adminer/index.php';

    /**
     * Which optional tools are installed
     *
     * Endpoint: GET /tools/status
     *
     * @return void Outputs JSON response
     * @psalm-api
     */
    public function getStatus(): void
    {
        $this->response->success([
            'adminer' => is_file(self::ADMINER_INDEX),
        ]);
    }
}
