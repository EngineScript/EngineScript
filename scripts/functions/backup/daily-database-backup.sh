#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# Runs the daily database and wp-config.php backup with enginescript-backup.sh.
# Older installs have a cron job for this script; EngineScript updates replace those jobs with
# the backup scheduler (install_backup_cron), which reads the backup frequencies each hour.
exec bash /usr/local/bin/enginescript/scripts/functions/backup/enginescript-backup.sh database-daily
