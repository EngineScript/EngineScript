<?php

/**
 * PHP-CS-Fixer configuration.
 *
 * Checks the admin control panel's PHP against the PER Coding Style, which
 * supersedes PSR-12, and against the idioms of the panel's minimum PHP
 * version. `composer cs:check` runs it in check mode; it changes nothing.
 * PER-CS 3.0 is the current revision (2026-10-18); the tool-currency check of
 * each review moves the set when PHP-FIG publishes a newer one.
 */

declare(strict_types=1);

$finder = (new PhpCsFixer\Finder())
    ->in(__DIR__ . '/config/var/www/admin')
    ->name('*.php')
    ->append([__DIR__ . '/rector.php', __FILE__]);

return (new PhpCsFixer\Config())
    ->setRules([
        '@PER-CS3x0' => true,
        '@PHP8x2Migration' => true,
        // PER allows an empty body as {} on one line, or with the closing brace on
        // its own line; PSR-12, which PHPCS checks, requires the second form.
        'single_line_empty_body' => false,
    ])
    ->setFinder($finder)
    ->setCacheFile(__DIR__ . '/.php-cs-fixer.cache');
