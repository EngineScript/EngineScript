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

# GIXY
pip3 install gixy

echo ""
echo ""
echo "============================================================="
echo ""
echo "  ${BOLD}GIXY installed.${NORMAL}"
echo ""
echo "  To run a scan of your Nginx configuration:"
echo "  gixy /etc/nginx/nginx.conf"
echo "  gixy /etc/nginx/sites-enabled/yourdomain.com.conf"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 3
