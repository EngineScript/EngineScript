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

echo "Clam Antivirus is running. Scan may take a long time, be patient. Standby for results."
sudo clamscan --infected --recursive --leave-temps --scan-archive=no --exclude-dir="^/sys" --exclude-dir="^/tmp" --exclude-dir="^/root/.wp-cli/packages/vendor/pantheon-systems/" --exclude-dir="^/usr/local/maldetect" --exclude-dir="^var/lib/clamav" --exclude-dir="^/usr/local/src" --exclude-dir="^/usr/local/bin/php-malware-finder" /

# Ask user to acknowledge that the scan has completed before moving on
echo ""
echo ""
read -n 1 -s -r -p "Press any key to continue"
echo ""
echo ""
