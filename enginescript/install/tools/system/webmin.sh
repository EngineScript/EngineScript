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

# Webmin

# Set Webmin Config
cp -p /usr/local/bin/enginescript/etc/webmin/config /etc/webmin/config
cp -p /usr/local/bin/enginescript/etc/webmin/miniserv.conf /etc/webmin/miniserv.conf

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}Webmin installed.${NORMAL}"
echo ""
echo "Point your browser to:"
echo "https://${IP_ADDRESS}/enginescript/webmin"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 5
