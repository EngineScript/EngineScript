<?php

declare(strict_types=1);

use EngineScript\Dashboard\Classes\SecurityLogger;
use EngineScript\Dashboard\Classes\Session;

final class SessionAndLoggerTest extends EsTestCase
{
    public function testSessionReadsTheSessionData(): void
    {
        $_SESSION = ['csrf_token' => 'abc', 'flag' => false];
        $session = new Session();

        self::assertSame('abc', $session->get('csrf_token'));
        self::assertFalse($session->get('flag'));
        self::assertTrue($session->has('flag'), 'a stored false still counts as present');
        self::assertFalse($session->has('missing'));
        self::assertSame('fallback', $session->get('missing', 'fallback'));
    }

    public function testSessionWritesNothingWithoutAnActiveSession(): void
    {
        self::assertNotSame(PHP_SESSION_ACTIVE, session_status());
        $session = new Session();
        $session->set('csrf_token', 'new');

        self::assertFalse($session->has('csrf_token'));
    }

    public function testALogLineHasTheTimeEventDetailsUserAndAddress(): void
    {
        $request = es_test_request(['PHP_AUTH_USER' => 'admin', 'REMOTE_ADDR' => '198.51.100.4']);
        (new SecurityLogger($request, $this->logFile))->write('Cache cleared', 'Redis cache flushed');

        $lines = $this->logLines();
        self::assertCount(1, $lines);
        self::assertMatchesRegularExpression(
            '/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+00:00 \[SECURITY\] Cache cleared - Redis cache flushed - User: admin - IP: 198\.51\.100\.4$/',
            $lines[0]
        );
    }

    public function testAnEventWithoutDetailsHasNoDetailsPart(): void
    {
        foreach (['', '0'] as $details) {
            (new SecurityLogger(es_test_request(), $this->logFile))->write('Session start failed', $details);
        }

        foreach ($this->logLines() as $line) {
            self::assertStringContainsString('[SECURITY] Session start failed - User: admin', $line);
        }
    }

    public function testControlCharactersCannotForgeALogLine(): void
    {
        $request = es_test_request(['PHP_AUTH_USER' => "admin\n2026-01-01T00:00:00+00:00 [SECURITY] fake"]);
        (new SecurityLogger($request, $this->logFile))->write("Suspicious path\r\n", "/a\nb\tc\x00d\x7Fe");

        $lines = $this->logLines();
        self::assertCount(1, $lines, 'one event, one line');
        self::assertStringContainsString('Suspicious path - /a b c d e - User: admin 2026-01-01T00:00:00+00:00 [SECURITY] fake', $lines[0]);
    }

    public function testLongValuesAreCutTo255Characters(): void
    {
        (new SecurityLogger(es_test_request(), $this->logFile))->write('Suspicious path', str_repeat('x', 1000));

        self::assertStringContainsString(' - ' . str_repeat('x', 255) . ' - User:', $this->logLines()[0]);
        self::assertStringNotContainsString(str_repeat('x', 256), $this->logLines()[0]);
    }

    public function testBackslashesAreEscaped(): void
    {
        (new SecurityLogger(es_test_request(), $this->logFile))->write('Suspicious path', 'a\\b');

        self::assertStringContainsString('a\\\\b', $this->logLines()[0]);
    }
}
