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

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh


#----------------------------------------------------------------------------------
# Start Main Script

# ClamAV Scan Message
echo "Virus Scan started"
echo "ClamAV will scan your /var/www/sites directory. This include all WordPress installations, themes, uploads, etc."
echo ""
echo "ClamAV automatically checks for the latest version daily."
echo ""
echo "To scan a different directory on your server, using command ${BOLD}clamscan -ir /DIRECTORY${NORMAL}."
echo ""
echo "Scan logs can be found at ${BOLD}/var/log/clamav/virus-scan.log${NORMAL}."
echo "Depending on the size of your web directories, virus scan may take a while."

# ClamAV Scan
clamscan -ir /var/www/sites
