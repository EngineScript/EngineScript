<?php

declare(strict_types=1);

/**
 * EngineScript Admin Dashboard - Command Runner
 *
 * What SystemCommand needs to run one command: SystemProcessRunner on a
 * server, a stand-in in tests (SystemCommand::useRunner()).
 *
 * @version 1.0.0
 */
interface CommandRunner
{
    /**
     * @param non-empty-list<string> $command Absolute executable path plus arguments
     * @param array<int,string> $displayCommand Original command used only for logs
     * @return string|false Trimmed output; '' for a command that printed nothing and
     *                      exited 0; false on failure
     */
    public function run(
        array $command,
        bool $captureStderr,
        int $timeoutSeconds,
        array $displayCommand
    ): string|false;
}
