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

# Copy Sites.sh
cp -rf /usr/local/bin/enginescript/scripts/functions/cron/sites.sh /home/EngineScript/sites-list/sites.sh

# Set Cron Jobs
# Currently disabled:
#   - compression-cron.sh

# WordPress Cron Ping (every 15 minutes)
(crontab -l 2>/dev/null; echo "*/15 * * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash wp-cron.sh >/dev/null 2>&1") | crontab -

# Database Backup (daily)
if [ "${DAILY_LOCAL_DATABASE_BACKUP}" = 1 ];
  then
    (crontab -l 2>/dev/null; echo "0 1 * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash daily-database-backup.sh >/dev/null 2>&1") | crontab -
fi

# Database Backup (hourly)
if [ "${HOURLY_LOCAL_DATABASE_BACKUP}" = 1 ];
  then
    (crontab -l 2>/dev/null; echo "5 * * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash hourly-database-backup.sh >/dev/null 2>&1") | crontab -
fi

# WP-Content Backup (weekly)
if [ "${WEEKLY_LOCAL_WPCONTENT_BACKUP}" = 1 ];
  then
    (crontab -l 2>/dev/null; echo "10 1 */7 * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash weekly-wp-content-backup.sh >/dev/null 2>&1") | crontab -
fi

# Lossless Image Optimization on Web Directories
# (Only runs on new images since last run) (weekly)
if [ "${AUTOMATIC_LOSSLESS_IMAGE_OPTIMIZATION}" = 1 ];
  then
    (crontab -l 2>/dev/null; echo "37 5 */7 * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash optimize-images.sh >/dev/null 2>&1") | crontab -
fi

# Backup Nginx Configuration (daily)
(crontab -l 2>/dev/null; echo "47 6 * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash nginx-backup.sh >/dev/null 2>&1") | crontab -

# Backup PHP Configuration (daily)
(crontab -l 2>/dev/null; echo "48 6 * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash php-backup.sh >/dev/null 2>&1") | crontab -

# Retrieve Cloudflare Origin Certificate for Authenticated Pulls With Nginx (monthly)
(crontab -l 2>/dev/null; echo "49 5 1 * * cd /usr/local/bin/enginescript/scripts/install/nginx; bash nginx-cloudflare-origin-cert.sh >/dev/null 2>&1") | crontab -

# Retrieve  Cloudflare Server IP Ranges for Nginx (monthly)
(crontab -l 2>/dev/null; echo "50 5 1 * * cd /usr/local/bin/enginescript/scripts/install/nginx; bash nginx-cloudflare-ip-updater.sh >/dev/null 2>&1") | crontab -

# Retrieve  Cloudflare Server IP Ranges for UFW (monthly)
(crontab -l 2>/dev/null; echo "51 5 1 * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash ufw-cloudflare-cron.sh >/dev/null 2>&1") | crontab -

# Update WP-CLI & Packages (daily)
(crontab -l 2>/dev/null; echo "52 5 * * * cd /usr/local/bin/enginescript/scripts/update; bash wp-cli-update.sh >/dev/null 2>&1") | crontab -

# Update Wordfence CLI (daily)
(crontab -l 2>/dev/null; echo "53 5 * * * cd /usr/local/bin/enginescript/scripts/update; bash wordfence-cli-update.sh >/dev/null 2>&1") | crontab -

# Reset Ownership & Permissions for WordPress and EngineScript (daily)
(crontab -l 2>/dev/null; echo "54 5 * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash permissions.sh >/dev/null 2>&1") | crontab -

# EngineScript Automatic Updates (daily)
if [ "${AUTOMATIC_ENGINESCRIPT_UPDATES}" = 1 ];
  then
    (crontab -l 2>/dev/null; echo "55 5 * * * cd /usr/local/bin/enginescript/scripts/update; bash enginescript-update.sh >/dev/null 2>&1") | crontab -
fi

# Scan Uploads Directory for Potentially Unwanted .php Files (daily)
if [ "$PUSHBULLET_TOKEN" != PLACEHOLDER ];
	then
    (crontab -l 2>/dev/null; echo "56 5 * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash uploads-php-scan.sh >/dev/null 2>&1") | crontab -
fi

# Check WordPress Directories Against Checksums (daily)
if [ "$PUSHBULLET_TOKEN" != PLACEHOLDER ];
	then
    (crontab -l 2>/dev/null; echo "57 5 * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash checksums.sh >/dev/null 2>&1") | crontab -
fi
