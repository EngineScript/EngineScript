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
echo ""
echo "Please note: We've self-signed an SSL certificate for your IP address."
echo "We want to protect the Admin Control Panel by requesting login credentials from all visitors"
echo "You'll get an untrusted SSL warning in your browser when visiting your server IP."
echo "Set a rule within your browser to allow access anyway."
echo ""

# Set Restricted Access Password
printf "%s:%s\n" "${ADMIN_CONTROL_PANEL_USERNAME}" "$(openssl passwd -apr1 "${ADMIN_CONTROL_PANEL_PASSWORD}")" >> /etc/nginx/restricted-access/.htpasswd
