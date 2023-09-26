#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 22.04 (jammy)
#----------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit
fi

#----------------------------------------------------------------------------
# Start Main Script

# Date
NOW=$(date +%m-%d-%Y-%H)

# Filenames
DATABASE_FILE="${NOW}-database.sql";
NGINX_FILE="${NOW}-nginx-vhost.conf.gz";
PHP_FILE="${NOW}-php.tar.gz";
SSL_FILE="${NOW}-ssl-keys.gz";
UPLOADS_FILE="${NOW}-uploads.tar.gz";
VHOST_FILE="${NOW}-nginx-vhost.conf.gz";
WPCONFIG_FILE="${NOW}-wp-config.php.gz";
WPCONTENT_FILE="${NOW}-wp-content.gz";

# Backup PHP Config
tar -zcf "/home/EngineScript/config-backups/php/$PHP_FILE" /etc/php

# Remove Old PHP Backups
find /home/EngineScript/config-backups/php -type f -mtime +30 | xargs rm -fR
