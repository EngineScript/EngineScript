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

# Maldet Install
cd /usr/local/src
wget https://www.rfxn.com/downloads/maldetect-current.tar.gz --no-check-certificate
tar -xvf maldetect-current.tar.gz
cd maldetect-1.6.4/
./install.sh
echo "/sys" >> /usr/local/maldetect/ignore_paths

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}ClamAV Anti-Virus installed.${NORMAL}"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 5
