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
source /usr/local/bin/enginescript/scripts-variables.txt
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

# Run Cloudflare Script and Write .conf File
/usr/local/bin/enginescript/scripts/install/nginx/nginx-cloudflare-ip-updater.sh

# Create Cloudflare Origin Pull Cert
#/usr/local/bin/enginescript/scripts/install/nginx/nginx-cloudflare-origin-cert.sh

# Cloudflare Origin Pull Certificate Note
echo ""
echo ""
echo "Please note, Cloudflare's Origin Pull Certificate has an expiration date."
#echo "We've set a monthly cronjob to retrive the latest certificate."
echo ""
echo "Current Certificate expiration:"
echo "$(openssl x509 -startdate -enddate -noout -in /etc/nginx/ssl/cloudflare/origin-pull-ca.pem)"
echo ""
echo ""

sleep 5
