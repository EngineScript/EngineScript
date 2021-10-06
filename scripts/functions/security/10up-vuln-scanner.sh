#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
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

cd /var/www/sites
printf "Please select the site you want to scan for vulnerabilities:\n"
select d in */; do test -n "$d" && break; echo ">>> Invalid Selection"; done
cd "$d"html && echo "10up Vulnerability Scanner is running. Scan may take a bit, standby for results."
wp vuln status --allow-root

# Ask user to acknowledge that the scan has completed before moving on
echo ""
echo ""
read -n 1 -s -r -p "Press any key to continue"
echo ""
echo ""
