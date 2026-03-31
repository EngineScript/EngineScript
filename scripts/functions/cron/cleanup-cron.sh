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
source /home/EngineScript/enginescript-install-options.txt

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# Removes stuck lock files (older than 6 hours)
# Credit SlickStack for the idea.
find /tmp -maxdepth 1 -name '*.lock' -mmin +360 -delete 2>/dev/null

# Remove PHP session files older than 6 hours
find /var/cache/php-sessions -type f -mmin +360 -delete > /dev/null 2>&1

# Clean any leftover files in /tmp older than 6 hours
find /tmp -type f -mmin +360 -delete > /dev/null 2>&1
