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

echo -e "\nRunning Backup Script\n"

# Databases, wp-config.php, wp-content, and the EngineScript configuration, whatever the
# BACKUP_* frequencies are; copies go to Amazon S3 when BACKUP_S3=1
bash /usr/local/bin/enginescript/scripts/functions/backup/enginescript-backup.sh now

echo -e "\nBackup Script Done\n"
