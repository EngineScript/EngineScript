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



#----------------------------------------------------------------------------------
# Start Main Script

# nxgtop
pip3 install ngxtop

echo ""
echo ""
echo "============================================================="
echo ""
echo "  ${BOLD}ngxtop installed.${NORMAL}"
echo ""
echo "  Scan your logs:"
echo "  ngxtop"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 3
