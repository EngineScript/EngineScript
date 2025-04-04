#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# Load Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check Root User
if [ "${EUID}" -ne 0 ]; then
    echo "${BOLD}ALERT:${NORMAL} EngineScript should be executed as the root user."
    exit 1
fi

# Copy Sites List Template
if [ ! -f "/home/EngineScript/sites-list/sites.sh" ]; then
    cp -rf /usr/local/bin/enginescript/scripts/functions/cron/sites.sh /home/EngineScript/sites-list/sites.sh
fi

#----------------------------------------------------------------------------------
# Set Cron Jobs
#----------------------------------------------------------------------------------

# Security and Updates
[ "${ENGINESCRIPT_AUTO_EMERGENCY_UPDATES}" = 1 ] && \
    (crontab -l 2>/dev/null; echo "1 * * * * cd /usr/local/bin/enginescript/scripts/functions/auto-upgrade; emergency-auto-upgrade.sh >/dev/null 2>&1") | crontab -

[ "${ENGINESCRIPT_AUTO_UPDATE}" = 1 ] && \
    (crontab -l 2>/dev/null; echo "55 5 * * * cd /usr/local/bin/enginescript/scripts/update; bash enginescript-update.sh >/dev/null 2>&1") | crontab -

# WordPress Maintenance
(crontab -l 2>/dev/null; echo "*/15 * * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash wp-cron.sh >/dev/null 2>&1") | crontab -

# Backup Tasks
[ "${DAILY_LOCAL_DATABASE_BACKUP}" = 1 ] && \
    (crontab -l 2>/dev/null; echo "0 1 * * * cd /usr/local/bin/enginescript/scripts/functions/backup; bash daily-database-backup.sh >/dev/null 2>&1") | crontab -

[ "${HOURLY_LOCAL_DATABASE_BACKUP}" = 1 ] && \
    (crontab -l 2>/dev/null; echo "5 * * * * cd /usr/local/bin/enginescript/scripts/functions/backup; bash hourly-database-backup.sh >/dev/null 2>&1") | crontab -

[ "${WEEKLY_LOCAL_WPCONTENT_BACKUP}" = 1 ] && \
    (crontab -l 2>/dev/null; echo "10 1 */7 * * cd /usr/local/bin/enginescript/scripts/functions/backup; bash weekly-wp-content-backup.sh >/dev/null 2>&1") | crontab -

# System Maintenance
(crontab -l 2>/dev/null; echo "7 * * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash cleanup-cron.sh >/dev/null 2>&1") | crontab -

[ "${AUTOMATIC_LOSSLESS_IMAGE_OPTIMIZATION}" = 1 ] && \
    (crontab -l 2>/dev/null; echo "37 5 */7 * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash optimize-images.sh >/dev/null 2>&1") | crontab -

# Configuration Backups
(crontab -l 2>/dev/null; echo "47 6 * * * cd /usr/local/bin/enginescript/scripts/functions/backup; bash nginx-backup.sh >/dev/null 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "48 6 * * * cd /usr/local/bin/enginescript/scripts/functions/backup; bash php-backup.sh >/dev/null 2>&1") | crontab -

# Cloudflare Updates
(crontab -l 2>/dev/null; echo "49 5 1 * * cd /usr/local/bin/enginescript/scripts/install/nginx; bash nginx-cloudflare-origin-cert.sh >/dev/null 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "50 5 1 * * cd /usr/local/bin/enginescript/scripts/install/nginx; bash nginx-cloudflare-ip-updater.sh >/dev/null 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "51 5 1 * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash ufw-cloudflare-cron.sh >/dev/null 2>&1") | crontab -

# Tool Updates
(crontab -l 2>/dev/null; echo "52 5 * * * cd /usr/local/bin/enginescript/scripts/update; bash wp-cli-update.sh >/dev/null 2>&1") | crontab -
(crontab -l 2>/dev/null; echo "53 5 * * * cd /usr/local/bin/enginescript/scripts/update; bash wordfence-cli-update.sh >/dev/null 2>&1") | crontab -

# Permissions and Security
(crontab -l 2>/dev/null; echo "54 5 * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash permissions.sh >/dev/null 2>&1") | crontab -

[ "$PUSHBULLET_TOKEN" != PLACEHOLDER ] && {
    (crontab -l 2>/dev/null; echo "56 5 * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash uploads-php-scan.sh >/dev/null 2>&1") | crontab -
    (crontab -l 2>/dev/null; echo "57 5 * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash checksums.sh >/dev/null 2>&1") | crontab -
}
