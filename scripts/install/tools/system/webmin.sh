#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
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

# Webmin

# Add Webmin Repository
wget -qO - https://download.webmin.com/jcameron-key.asc --no-check-certificate | sudo apt-key add -
sudo sh -c 'echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list'

# Install
apt update
apt install -qy webmin

# Create Logs
mkdir -p /var/log/webmin
touch /var/log/webmin/miniserv.log
touch /var/log/webmin/miniserv.error.log
chmod 775 /var/log/webmin

# Logrotate
cp -rf /usr/local/bin/enginescript/etc/logrotate.d/webmin /etc/logrotate.d/webmin

# Set Webmin Config
cp -rf /usr/local/bin/enginescript/etc/webmin/config /etc/webmin/config
cp -rf /usr/local/bin/enginescript/etc/webmin/miniserv.conf /etc/webmin/miniserv.conf

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}Webmin installed.${NORMAL}"
echo ""
echo "Point your browser to:"
echo "https://${IP_ADDRESS}:32792"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 5
