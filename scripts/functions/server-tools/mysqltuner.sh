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

perl /usr/local/bin/mysqltuner/mysqltuner.pl

# Ask user to acknowledge that the scan has completed before moving on
echo ""
echo ""
read -n 1 -s -r -p "Press any key to continue"
echo ""
echo ""
