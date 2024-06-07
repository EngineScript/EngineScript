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

# Webmin

# Check Webmin Username
if [ "$WEBMIN_USERNAME" = PLACEHOLDER ];
	then
    echo -e "\nWARNING:\n\nWEBMIN_USERNAME is set to PLACEHOLDER. EngineScript requires this be set to a unique value.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change WEBMIN_USERNAME to something more secure.\n"
    exit
fi

# Check Webmin Password
if [ "$WEBMIN_PASSWORD" = PLACEHOLDER ];
	then
    echo -e "\nWARNING:\n\nWEBMIN_PASSWORD is set to PLACEHOLDER. EngineScript requires this be set to a unique value.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change WEBMIN_PASSWORD to something more secure.\n"
    exit
fi

# Add User
useradd -m -s /bin/bash -c "Administrative User" ${WEBMIN_USERNAME} ; echo -e "${WEBMIN_PASSWORD}\n${WEBMIN_PASSWORD}" | passwd ${WEBMIN_USERNAME}

# Remove Password Expiration
chage -I -1 -m 0 -M 99999 -E -1 root
chage -I -1 -m 0 -M 99999 -E -1 ${WEBMIN_USERNAME}

# Set Sudo
usermod -aG sudo "${WEBMIN_USERNAME}"
echo "User account ${BOLD}${WEBMIN_USERNAME}${NORMAL} has been created." | boxes -a c -d shell -p a1l2

# Add Webmin Repository
wget -qO - https://download.webmin.com/jcameron-key.asc --no-check-certificate | sudo apt-key add -
sudo sh -c 'echo "deb https://download.webmin.com/download/repository sarge contrib" > /etc/apt/sources.list.d/webmin.list'

# Install
apt update --allow-releaseinfo-change -y
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
