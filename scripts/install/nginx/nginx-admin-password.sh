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

clear
echo ""
echo "----------------------------------------------------------"
echo "${BOLD}Nginx Admin Authentication:${NORMAL}"
echo "----------------------------------------------------------"

# Set Restricted Access Password
printf "%s:%s\n" "${ADMIN_CONTROL_PANEL_USERNAME}" "$(openssl passwd -apr1 "${ADMIN_CONTROL_PANEL_PASSWORD}")" >> /etc/nginx/restricted-access/.htpasswd
