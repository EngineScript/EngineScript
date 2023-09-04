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
/usr/local/src/wordfence scan --output-path /home/EngineScript/wordfence-scan-results/wordfence-cli-scan-results.csv /usr/src

# Ask user to acknowledge that the scan has completed before moving on
echo ""
echo ""
echo "scan results will be located at:"
echo "/home/EngineScript/wordfence-scan-results/wordfence-cli-scan-results.csv"
echo ""
read -n 1 -s -r -p "Press any key to continue"
echo ""
echo ""