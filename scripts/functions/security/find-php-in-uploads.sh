#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
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
select d in *; do test -n "$d" && break; echo ">>> Invalid Selection"; done
cd "$d"/html && echo "Locating .php files in the uploads directory. Scan may take a bit, standby for results."
echo -e "\n\nThis could indicate a security issue and/or risk on your server.\nNot everything is dangerous, so research thoroughly before taking any action.\n\nFound the following .php files:"
find ./wp-content/uploads -name "*.php"

# Ask user to acknowledge that the scan has completed before moving on
echo ""
echo ""
read -n 1 -s -r -p "Press any key to continue"
echo ""
echo ""
