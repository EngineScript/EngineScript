#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/VisiStruct/EngineScript
# Author:       Peter Downey
# Company:      VisiStruct
# License:      GPL v3.0
# OS:           Ubuntu 20.04 (focal)
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
cp -p /usr/local/bin/enginescript/enginescript/cron/sites.sh /home/EngineScript/sites-list/sites.sh

# Set Cron Jobs

# WordPress Cron Ping (every 36 minutes)
(crontab -l 2>/dev/null; echo "*/36 * * * * cd /usr/local/bin/enginescript/enginescript/cron; bash wp-cron.sh >/dev/null 2>&1") | crontab -

# EngineScript Cleanup (daily)
(crontab -l 2>/dev/null; echo "0 1 * * * cd /usr/local/bin/enginescript/enginescript/functions; bash enginescript-cleanup.sh >/dev/null 2>&1") | crontab -

# Static File Brotli & GZip Compression Cron (monthly)
#(crontab -l 2>/dev/null; echo "0 2 1 * * cd /usr/local/bin/enginescript/enginescript/cron; bash compression-cron.sh >/dev/null 2>&1") | crontab -

# Lossless Image Optimization on Web Directories
# (Only runs on new images since last run) (every 5 days)
if [ "${AUTOMATIC_LOSSLESS_IMAGE_OPTIMIZATION}" = 1 ];
  then
    (crontab -l 2>/dev/null; echo "30 2 */5 * * cd /usr/local/bin/enginescript/enginescript/cron; bash optimize-images.sh >/dev/null 2>&1") | crontab -
  else
    # Do nothing!
    echo "Skipping Automatic Image Optimization cron install"
fi

# Retrieve Cloudflare Origin Certificate for Authenticated Pulls With Nginx (monthly)
# Cloudflare recently changed the certificate link. It can no longer be retrieved via a command. This may change in the future. For now, we use an existing cert.
#(crontab -l 2>/dev/null; echo "0 3 1 * * cd /usr/local/bin/enginescript/enginescript/install/nginx; bash nginx-cloudflare-origin-cert.sh >/dev/null 2>&1") | crontab -

# Retrive Cloudflare Server IP Ranges for Nginx (monthly)
(crontab -l 2>/dev/null; echo "1 3 1 * * cd /usr/local/bin/enginescript/enginescript/install/nginx; bash nginx-cloudflare-ip-updater.sh >/dev/null 2>&1") | crontab -

# Retrive Cloudflare Server IP Ranges for UFW (monthly)
(crontab -l 2>/dev/null; echo "2 3 1 * * cd /usr/local/bin/enginescript/enginescript/cron; bash ufw-cloudflare-cron.sh >/dev/null 2>&1") | crontab -

# Update EngineScript & Related Software (Excluding Nginx, PHP, and MariaDB) (monthly)
(crontab -l 2>/dev/null; echo "6 3 1 * * cd /usr/local/bin/enginescript/enginescript/update; bash software-update.sh >/dev/null 2>&1") | crontab -

# Backup WordPress Databases & Upload Directories (daily)
(crontab -l 2>/dev/null; echo "0 4 * * * cd /usr/local/bin/enginescript/enginescript/cron; bash backups.sh >/dev/null 2>&1") | crontab -

# Backup WordPress Databases to Dropbox (daily)
if [ "${INSTALL_DROPBOX_BACKUP}" = 1 ];
  then
    (crontab -l 2>/dev/null; echo "15 4 * * * cd /usr/local/bin/enginescript/enginescript/cron; bash dropbox-backups.sh >/dev/null 2>&1") | crontab -
  else
    # Do nothing!
    echo "Skipping Dropbox Uploader cron install"
fi

# Update WP-CLI & Packages (daily)
(crontab -l 2>/dev/null; echo "45 4 * * * cd /usr/local/bin/enginescript/enginescript/cron; bash wp-cli-update.sh >/dev/null 2>&1") | crontab -

# Reset Ownership & Permissions for WordPress (daily)
(crontab -l 2>/dev/null; echo "0 5 * * * cd /usr/local/bin/enginescript/enginescript/cron; bash permissions.sh >/dev/null 2>&1") | crontab -

# Check WordPress Directories Against Checksums (daily)
(crontab -l 2>/dev/null; echo "15 5 * * * cd /usr/local/bin/enginescript/enginescript/cron; bash checksums.sh >/dev/null 2>&1") | crontab -

# Backup Nginx Configuration (daily)
(crontab -l 2>/dev/null; echo "0 6 * * * cd /usr/local/bin/enginescript/enginescript/cron; bash nginx-backup.sh >/dev/null 2>&1") | crontab -

# Backup PHP Configuration (daily)
(crontab -l 2>/dev/null; echo "15 6 * * * cd /usr/local/bin/enginescript/enginescript/cron; bash php-backup.sh >/dev/null 2>&1") | crontab -
