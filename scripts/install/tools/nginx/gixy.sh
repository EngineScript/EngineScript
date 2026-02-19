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

# GIXY-NEXT (maintained fork of Gixy)
# https://github.com/MegaManSec/Gixy-Next
# Uses pipx to install in an isolated virtual environment (PEP 668 compliance)
apt install -y pipx
pipx install gixy-next
pipx ensurepath

echo ""
echo ""
echo "============================================================="
echo ""
echo "  ${BOLD}Gixy-Next installed.${NORMAL}"
echo ""
echo "  To run a scan of your Nginx configuration:"
echo "  gixy /etc/nginx/nginx.conf"
echo "  gixy /etc/nginx/sites-enabled/YOURDOMAIN.TLD.conf"
echo "  Example: gixy /etc/nginx/sites-enabled/wordpresstesting.com.conf"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 3
