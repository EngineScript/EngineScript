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


#----------------------------------------------------------------------------------
# Start Main Script

# Remove PHP session files older than 6 hours
find /var/cache/php-sessions -type f -mmin +360 -delete > /dev/null 2>&1

# Remove EngineScript's own leftover temporary files older than 6 hours. systemd-tmpfiles clears
# the rest of /tmp after 30 days; the services' private temp folders and other programs' files
# are not ours to touch.
find /tmp -maxdepth 1 -type f \( -name 'enginescript*' -o -name '*_db_import.sql' \
  -o -name 'analyze_all_tables.*' -o -name 'cloudflare-ipv[46]' -o -name 'tinyfilemanager-*' \) \
  -mmin +360 -delete > /dev/null 2>&1
