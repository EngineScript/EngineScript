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

clear
echo ""
echo "----------------------------------------------------------"
echo "${BOLD}Nginx Admin Authentication:${NORMAL}"
echo ""
echo "Please note: We've self-signed an SSL certificate for your IP address."
echo "We want to protect the admin area by requesting login credentials from all visitors"
echo "You'll get an untrusted SSL warning in your browser when visiting your server IP."
echo "Set a rule within your browser to allow access anyway."
echo ""

# Set Restricted Access Password
printf "${NGINX_USERNAME}:`openssl passwd -apr1 ${NGINX_PASSWORD}`\n" >> /etc/nginx/restricted-access/.htpasswd
