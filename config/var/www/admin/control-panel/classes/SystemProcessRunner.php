<?php
/**
 * EngineScript Admin Dashboard - Process Runner
 *
 * Runs already-validated argv arrays for SystemCommand and owns the low-level
 * proc_open pipe lifecycle.
 *
 * @version 1.0.0
 * @security HIGH - Executes validated argv arrays without shell interpretation
 */

final class SystemProcessRunner
{
    /**
     * Maximum command output captured into memory.
     */
    private const MAX_OUTPUT_BYTES = 1048576;

    private const READ_SLEEP_MICROSECONDS = 50000;
    private const TERMINATE_GRACE_MICROSECONDS = 100000;

    /**
     * @param array<int,string> $command Absolute executable path plus arguments
     * @param array<int,string> $displayCommand Original command used only for logs
     */
    public function run(
        array $command,
        bool $captureStderr,
        int $timeoutSeconds,
        array $displayCommand
    ): string|false {
        $process = $this->openProcess($command, $captureStderr);
        if ($process === false) {
            return false;
        }

        return $this->collectOutput($process, $timeoutSeconds, $displayCommand);
    }

    /**
     * @param array<int,string> $command
     * @return array{process: resource, pipes: array<int, resource>, pipeIndex: int}|false
     */
    private function openProcess(array $command, bool $captureStderr): array|false
    {
        [$descriptors, $pipeIndex] = $this->buildPipeSpec($captureStderr);

        // codacy:ignore-start - argv array assembled from strict binary and argument allowlists
        // nosemgrep
        $process = proc_open($command, $descriptors, $pipes, null, null, ['bypass_shell' => true]);
        // codacy:ignore-end
        if (!is_resource($process)) {
            return false;
        }

        stream_set_blocking($pipes[$pipeIndex], false);

        return [
            'process' => $process,
            'pipes' => $pipes,
            'pipeIndex' => $pipeIndex,
        ];
    }

    /**
     * @param array{process: resource, pipes: array<int, resource>, pipeIndex: int} $process
     * @param array<int,string> $displayCommand
     */
    private function collectOutput(array $process, int $timeoutSeconds, array $displayCommand): string|false
    {
        $output = '';
        $deadline = microtime(true) + $timeoutSeconds;
        $terminated = false;

        while ($this->isRunning($process['process'])) {
            if ($this->appendPipeOutput($process['pipes'][$process['pipeIndex']], $output)) {
                $terminated = true;
                break;
            }

            if (microtime(true) >= $deadline) {
                $terminated = true;
                break;
            }

            usleep(self::READ_SLEEP_MICROSECONDS);
        }

        $this->appendPipeOutput($process['pipes'][$process['pipeIndex']], $output);

        if ($terminated) {
            $this->terminateProcess($process['process']);
            error_log('[EngineScript] SystemCommand terminated command: ' . implode(' ', $displayCommand));
        }

        $exitCode = $this->closeProcess($process);
        if ($terminated) {
            return false;
        }

        $output = trim($output);

        return $output !== '' ? $output : ($exitCode === 0 ? '' : false);
    }

    /**
     * @param resource $pipe
     */
    private function appendPipeOutput($pipe, string &$output): bool
    {
        $chunk = stream_get_contents($pipe);
        if (is_string($chunk) && $chunk !== '') {
            $output .= $chunk;
        }

        return strlen($output) > self::MAX_OUTPUT_BYTES;
    }

    /**
     * @param resource $process
     */
    private function isRunning($process): bool
    {
        $status = proc_get_status($process);

        return $status['running'];
    }

    /**
     * @param resource $process
     */
    private function terminateProcess($process): void
    {
        proc_terminate($process);
        usleep(self::TERMINATE_GRACE_MICROSECONDS);

        if ($this->isRunning($process)) {
            proc_terminate($process, 9);
        }
    }

    /**
     * @param array{process: resource, pipes: array<int, resource>, pipeIndex: int} $process
     */
    private function closeProcess(array $process): int
    {
        foreach ($process['pipes'] as $pipe) {
            if (is_resource($pipe)) {
                fclose($pipe);
            }
        }

        return proc_close($process['process']);
    }

    /**
     * @return array{0: array<int, array<int, string>>, 1: int}
     */
    private function buildPipeSpec(bool $captureStderr): array
    {
        $null = ['file', '/dev/null', 'w'];
        $pipe = ['pipe', 'r'];

        if ($captureStderr) {
            return [[0 => ['file', '/dev/null', 'r'], 1 => $null, 2 => $pipe], 2];
        }

        return [[0 => ['file', '/dev/null', 'r'], 1 => $pipe, 2 => $null], 1];
    }
}
