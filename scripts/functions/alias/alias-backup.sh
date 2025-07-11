#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt



#----------------------------------------------------------------------------------
# Start Main Script

echo -e "\nRunning Backup Script\n"

/usr/local/bin/enginescript/scripts/functions/backup/daily-database-backup.sh
/usr/local/bin/enginescript/scripts/functions/backup/weekly-wp-content-backup.sh

echo -e "\nBackup Script Done\n"
