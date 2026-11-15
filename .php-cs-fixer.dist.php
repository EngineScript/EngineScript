<?php

/**
 * PHP-CS-Fixer configuration.
 *
 * Checks the admin control panel's PHP against the PER Coding Style, which
 * supersedes PSR-12, and against the idioms of the panel's minimum PHP
 * version. `composer cs:check` runs it in check mode; it changes nothing.
 * PHP-FIG has published PER-CS 3.1; PHP-CS-Fixer's newest set is 3.0 (checked
 * 2026-11-15). The tool-currency check of each review moves the set when
 * PHP-CS-Fixer adds a newer one.
 */

declare(strict_types=1);

$finder = (new PhpCsFixer\Finder())
    ->in(__DIR__ . '/config/var/www/admin')
    ->name('*.php')
    ->append([__DIR__ . '/rector.php', __FILE__]);

return (new PhpCsFixer\Config())
    ->setRules([
        '@PER-CS3x0' => true,
        '@PHP8x3Migration' => true,
        // PER allows an empty body as {} on one line, or with the closing brace on
        // its own line; PSR-12, which PHPCS checks, requires the second form.
        'single_line_empty_body' => false,
    ])
    ->setFinder($finder)
    ->setCacheFile(__DIR__ . '/.php-cs-fixer.cache');
