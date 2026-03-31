#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt || { echo "Error: Failed to source /usr/local/bin/enginescript/enginescript-variables.txt" >&2; exit 1; }
source /home/EngineScript/enginescript-install-options.txt || { echo "Error: Failed to source /home/EngineScript/enginescript-install-options.txt" >&2; exit 1; }

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }

# Add a cron job only if it doesn't already exist
add_cron_job() {
    local entry="$1"
    if ! crontab -l 2>/dev/null | awk -v entry="$entry" '$0 == entry { found=1; exit } END { exit !found }'; then
        (crontab -l 2>/dev/null; echo "$entry") | crontab -
    fi
}

# Copy Sites List Template
if [[ ! -f "/home/EngineScript/sites-list/sites.sh" ]]; then
    cp -rf /usr/local/bin/enginescript/scripts/functions/cron/sites.sh /home/EngineScript/sites-list/sites.sh
fi

#----------------------------------------------------------------------------------
# Set Cron Jobs
#----------------------------------------------------------------------------------

# Security and Updates
[[ "${ENGINESCRIPT_AUTO_EMERGENCY_UPDATES}" == "1" ]] && add_cron_job "1 * * * * cd /usr/local/bin/enginescript/scripts/functions/auto-upgrade; bash emergency-auto-upgrade.sh >/dev/null 2>&1"

[[ "${ENGINESCRIPT_AUTO_UPDATE}" == "1" ]] && add_cron_job "55 5 * * * cd /usr/local/bin/enginescript/scripts/update; bash enginescript-update.sh >/dev/null 2>&1"

# WordPress Maintenance
add_cron_job "*/15 * * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash wp-cron.sh >/dev/null 2>&1"

# Backup Tasks
[[ "${DAILY_LOCAL_DATABASE_BACKUP}" == "1" ]] && add_cron_job "0 1 * * * cd /usr/local/bin/enginescript/scripts/functions/backup; bash daily-database-backup.sh >/dev/null 2>&1"

[[ "${HOURLY_LOCAL_DATABASE_BACKUP}" == "1" ]] && add_cron_job "5 * * * * cd /usr/local/bin/enginescript/scripts/functions/backup; bash hourly-database-backup.sh >/dev/null 2>&1"

[[ "${WEEKLY_LOCAL_WPCONTENT_BACKUP}" == "1" ]] && add_cron_job "10 1 * * 0 cd /usr/local/bin/enginescript/scripts/functions/backup; bash weekly-wp-content-backup.sh >/dev/null 2>&1"

# System Maintenance
add_cron_job "7 * * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash cleanup-cron.sh >/dev/null 2>&1"

# API cache sweep - triggers API which runs sweepCache() (rate-limited in PHP)
add_cron_job "* * * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash sweep-api-cache.sh >/dev/null 2>&1"

[[ "${AUTOMATIC_LOSSLESS_IMAGE_OPTIMIZATION}" == "1" ]] && add_cron_job "37 5 * * 0 cd /usr/local/bin/enginescript/scripts/functions/cron; bash optimize-images.sh >/dev/null 2>&1"

# Configuration Backups
add_cron_job "47 6 * * * cd /usr/local/bin/enginescript/scripts/functions/backup; bash nginx-backup.sh >/dev/null 2>&1"
add_cron_job "48 6 * * * cd /usr/local/bin/enginescript/scripts/functions/backup; bash php-backup.sh >/dev/null 2>&1"

# Cloudflare Updates
add_cron_job "49 5 1 * * cd /usr/local/bin/enginescript/scripts/install/nginx; bash nginx-cloudflare-origin-cert.sh >/dev/null 2>&1"
add_cron_job "50 5 1 * * cd /usr/local/bin/enginescript/scripts/install/nginx; bash nginx-cloudflare-ip-updater.sh >/dev/null 2>&1"
add_cron_job "51 5 1 * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash ufw-cloudflare-cron.sh >/dev/null 2>&1"

# Tool Updates
add_cron_job "52 5 * * * cd /usr/local/bin/enginescript/scripts/update; bash wp-cli-update.sh >/dev/null 2>&1"
add_cron_job "53 5 * * * cd /usr/local/bin/enginescript/scripts/update; bash wordfence-cli-update.sh >/dev/null 2>&1"

# Permissions and Security
add_cron_job "54 5 * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash permissions.sh >/dev/null 2>&1"

[[ "$PUSHBULLET_TOKEN" != "PLACEHOLDER" ]] && {
    add_cron_job "56 5 * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash uploads-php-scan.sh >/dev/null 2>&1"
    add_cron_job "57 5 * * * cd /usr/local/bin/enginescript/scripts/functions/cron; bash checksums.sh >/dev/null 2>&1"
}
