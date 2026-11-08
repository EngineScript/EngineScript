#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript settings and shared functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# Date
NOW=$(date +%m-%d-%Y-%H)

# Filename
PHP_FILE="${NOW}-php.tar.gz"

# Backup PHP Config
tar -zcf "/home/EngineScript/config-backups/php/${PHP_FILE}" /etc/php

# Remove Old PHP Backups
find /home/EngineScript/config-backups/php -type f -mtime +30 -delete
