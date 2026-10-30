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

declare(strict_types=1);

require_once __DIR__ . '/CommandRunner.php';

final class SystemProcessRunner implements CommandRunner
{
    /**
     * Maximum command output captured into memory.
     */
    private const int MAX_OUTPUT_BYTES = 1048576;

    /**
     * Longest single wait for output, so a command that exits while another
     * process still holds its pipe is noticed.
     */
    private const int SELECT_SLICE_MICROSECONDS = 100000;

    /**
     * Poll intervals: while waiting for the exit after the pipe closed, and
     * after stream_select() failed (for example, interrupted by a signal).
     */
    private const int EXIT_POLL_MICROSECONDS = 1000;
    private const int FALLBACK_POLL_MICROSECONDS = 10000;

    private const int TERMINATE_GRACE_MICROSECONDS = 100000;

    #[\Override]
    public function run(
        array $command,
        bool $captureStderr,
        int $timeoutSeconds,
        array $displayCommand
    ): string|false {
        if (!is_executable($command[0])) {
            error_log('[EngineScript] SystemCommand executable not found or not executable: ' . $command[0]);
            return false;
        }

        $process = $this->openProcess($command, $captureStderr);
        if ($process === false) {
            return false;
        }

        return $this->collectOutput($process, $timeoutSeconds, $displayCommand);
    }

    /**
     * @param non-empty-list<string> $command
     * @return array{process: resource, pipes: array<resource>, pipeIndex: int}|false
     */
    private function openProcess(array $command, bool $captureStderr): array|false
    {
        [$descriptors, $pipeIndex] = $this->buildPipeSpec($captureStderr);

        // An argv array is run without a shell on Linux.
        // nosemgrep: php.lang.security.exec-use.exec-use
        $process = proc_open($command, $descriptors, $pipes);
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
     * @param array{process: resource, pipes: array<resource>, pipeIndex: int} $process
     * @param array<int,string> $displayCommand
     */
    private function collectOutput(array $process, int $timeoutSeconds, array $displayCommand): string|false
    {
        $output = '';
        $deadline = microtime(true) + (float) $timeoutSeconds;
        $pipe = $process['pipes'][$process['pipeIndex']];

        $terminated = !$this->readUntilClosed($pipe, $process['process'], $deadline, $output)
            || !$this->waitForExit($process['process'], $deadline);

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
     * Read the pipe until the command closes it or exits, waking as soon as
     * output arrives; false when the output grows too large or time runs out.
     *
     * @param resource $pipe
     * @param resource $process
     */
    private function readUntilClosed($pipe, $process, float $deadline, string &$output): bool
    {
        while (!feof($pipe)) {
            $waitMicroseconds = min(self::SELECT_SLICE_MICROSECONDS, (int) (($deadline - microtime(true)) * 1e6));
            if ($waitMicroseconds <= 0) {
                return false;
            }

            $read = [$pipe];
            $write = null;
            $except = null;
            $ready = stream_select($read, $write, $except, 0, $waitMicroseconds);
            if ($ready === false) {
                usleep(self::FALLBACK_POLL_MICROSECONDS);
            }

            if ($this->appendPipeOutput($pipe, $output)) {
                return false;
            }

            if ($ready !== 1 && !$this->isRunning($process)) {
                break;
            }
        }

        return !$this->appendPipeOutput($pipe, $output);
    }

    /**
     * Wait for the command to exit; false if it is still running at the deadline.
     *
     * @param resource $process
     */
    private function waitForExit($process, float $deadline): bool
    {
        while ($this->isRunning($process)) {
            if (microtime(true) >= $deadline) {
                return false;
            }

            usleep(self::EXIT_POLL_MICROSECONDS);
        }

        return true;
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
        return proc_get_status($process)['running'];
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
     * @param array{process: resource, pipes: array<resource>, pipeIndex: int} $process
     */
    private function closeProcess(array $process): int
    {
        foreach ($process['pipes'] as $pipe) {
            fclose($pipe);
        }

        // From PHP 8.3, proc_close() returns the exit code even after proc_get_status() saw the exit.
        return proc_close($process['process']);
    }

    /**
     * @return array{0: array<int, list<string>>, 1: int}
     */
    private function buildPipeSpec(bool $captureStderr): array
    {
        $null = ['file', '/dev/null', 'w'];
        $pipe = ['pipe', 'w'];

        if ($captureStderr) {
            return [[0 => ['file', '/dev/null', 'r'], 1 => $null, 2 => $pipe], 2];
        }

        return [[0 => ['file', '/dev/null', 'r'], 1 => $pipe, 2 => $null], 1];
    }
}
