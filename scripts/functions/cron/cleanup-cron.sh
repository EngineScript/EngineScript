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

# Removes stuck lock files (older than 6 hours)
# Credit SlickStack for the idea.
/usr/bin/find /tmp/*.lock -mmin +360 -delete > /dev/null 2>&1

# Remove PHP session files older than 6 hours
find /var/cache/php-sessions -type f -mmin +360 -delete > /dev/null 2>&1

# Clean any leftover files in /tmp older than 6 hours
find /tmp -type f -mmin +360 -delete > /dev/null 2>&1
