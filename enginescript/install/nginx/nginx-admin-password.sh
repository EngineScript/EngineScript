#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/VisiStruct/EngineScript
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

clear
echo ""
echo ""
echo "----------------------------------------------------------"
echo "${BOLD}Admin Authentication:${NORMAL}"
echo ""
echo "To access the admin area of your server, you'll visit https://${IP_ADDRESS}"
echo ""
echo "Please note: We've self-signed an SSL certificate for your IP address."
echo "You'll get an untrusted SSL warning in your browser when visiting your server IP."
echo "Set a rule within your browser to allow access anyway."
echo ""
echo "We want to protect the admin area by requesting login credentials from all visitors"
echo ""
echo "We've set the default username to ${BOLD}admin${NORMAL}."
echo ""
echo "Now it's your turn to set the password..."
echo ""
echo ""

# Set Restricted Access Password
printf "${NGINX_USERNAME}:`openssl passwd -apr1 ${NGINX_PASSWORD}`\n" >> /etc/nginx/restricted-access/.htpasswd
