#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 20.04 (focal)
#----------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

#----------------------------------------------------------------------------

# Filenames
NOW=$(date +%m-%d-%Y-%H%M)
PHP_FILE="${NOW}-php.tar.gz";

# Backup PHP Config
tar -zcf "/home/EngineScript/config-backups/php/$PHP_FILE" /etc/php

# Remove Old PHP Backups
find /home/EngineScript/config-backups/php -type f -mtime +30 | xargs rm -fR
