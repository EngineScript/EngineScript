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

# EngineScript Git Clone
rm -rf /usr/local/bin/enginescript
sleep 2
git clone --depth 1 https://github.com/EngineScript/EngineScript.git -b master /usr/local/bin/enginescript
sleep 2

# EngineScript Permissions
find /usr/local/bin/enginescript -type d,f -exec chmod 755 {} \;
chown -R root:root /usr/local/bin/enginescript

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}EngineScript has been updated.${NORMAL}"
echo ""
echo "This update includes:"
echo "    - EngineScript"
echo ""
echo "============================================================="
echo ""
echo ""
