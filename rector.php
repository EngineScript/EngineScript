<?php

/**
 * Rector configuration.
 *
 * Rector keeps the admin control panel's PHP on current idioms. `composer
 * rector` runs it as a dry run, which fails when any rule would change the
 * code. The plugin repositories' skip list is not copied: each of its rules
 * is skipped there for a WordPress reason that does not apply here. A rule is
 * skipped here only for a reason this code gives, stated beside it.
 */

declare(strict_types=1);

use Rector\Config\RectorConfig;

return RectorConfig::configure()
    ->withPaths([
        __DIR__ . '/config/var/www/admin',
    ])
    ->withPhpSets(php83: true)
    ->withPreparedSets(
        deadCode: true,
        codeQuality: true,
        typeDeclarations: true,
        earlyReturn: true,
    );
