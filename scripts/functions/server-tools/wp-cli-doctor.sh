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

cd /var/www/sites
printf "Please select the site you want to scan for issues\n"
select d in */; do test -n "$d" && break; echo ">>> Invalid Selection"; done
cd "$d"html && echo "WP-CLI Doctor is running. Scan may take a bit, standby for results."
/usr/local/src/wp doctor check --allow-root

# Ask user to acknowledge that the scan has completed before moving on
echo ""
echo ""
read -n 1 -s -r -p "Press any key to continue"
echo ""
echo ""
