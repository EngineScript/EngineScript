#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 22.04 (jammy)
#----------------------------------------------------------------------------

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "ALERT:"
    echo "EngineScript should be executed as the root user."
    exit
fi

# Check if Ubuntu is 22.04. If not, exit.
UBUNTU_CODENAME="$(lsb_release -sc)"

if [ "${UBUNTU_CODENAME}" != jammy ];
  then
    echo "ALERT:"
    echo "EngineScript does not support Ubuntu ${UBUNTU_CODENAME}. We recommend using 22.04 jammy"
    exit
fi

#----------------------------------------------------------------------------
# Start Main Script

# Enginescript is and always will be a personal project that I started as a means to increase my
# understanding of Linux and hosting technology. Rather than trying to obfuscate the code to make
# things harder to comprehend, I've attempted to keep things relatively clear so that others can
# learn in the future.
#
# My first real attempts at doing anything on my own involved countless hours of reading, failures,
# and scouring the internet to see how others were doing things. Much of my original inspiration is
# solely due to the amazing work of George Liu, creater of Centminmod. His work showed a lot of
# people, myself included, just how cool (and complicated) hosting technology can be.
#
# Hopefully, EngineScript has some things that you may find useful. You should know that the path
# forward from here is a neverending one. I wish you luck on your journey into Linux, Nginx,
# WordPress, and whatever else interests you.
#
#
# ---WARNING---
# EngineScript does a lot of hand-holding when it comes to site and database creation.
# We've tried to find a balance between user autonomy and system automation. Unfortunately,
# this automation sometimes comes at the expense of security. EngineScript automatically
# generates and stores many passwords for you, this includes storing mysql database credentials.
# If you have a problem with this but aren't comfortable with manually changes things in the
# script or within MySQL once the script has run, I would advise you to stop here and search out
# a different solution other than EngineScript.
#
# Finally, EngineScript is very experimental in nature. We use a lot of bleeding-edge technology.
# This includes using the Nginx Mainline branch instead of the Stable branch. We also use a number
# of PPAs from developers that supply packages outside of the standard Ubuntu repositories. Some of
# these packages include backports, some of them are just more up-to-date. If you're looking for
# the most secure server environment possible, EngineScript is probably not what you're looking for.

sed -i "s/#\$nrconf{restart} = 'i';/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf

# Install Required Packages for Script
apt update
apt install -y boxes dos2unix git nano pwgen software-properties-common tzdata unattended-upgrades
apt full-upgrade -y
apt dist-upgrade -y

# EngineScript Git Clone
rm -rf /usr/local/bin/enginescript
git clone --depth 1 https://github.com/EngineScript/EngineScript.git -b master /usr/local/bin/enginescript

# EngineScript Permissions
find /usr/local/bin/enginescript -type d,f -exec chmod 755 {} \;
chown -R root:root /usr/local/bin/enginescript
find /usr/local/bin/enginescript -type f -iname "*.sh" -exec chmod +x {} \;

# Create EngineScript Home Directory
mkdir -p /home/EngineScript/config-backups/nginx
mkdir -p /home/EngineScript/config-backups/php
mkdir -p /home/EngineScript/mysql-credentials
mkdir -p /home/EngineScript/site-backups
mkdir -p /home/EngineScript/sites-list
touch /home/EngineScript/install-log.txt

# Create EngineScript Aliases
source /home/EngineScript/install-log.txt
if [ "${ALIAS}" = 1 ];
  then
    echo "ALIAS script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/alias/enginescript-alias-install.sh
    echo "ALIAS=1" >> /home/EngineScript/install-log.txt
fi

# Cleanup
apt-get remove 'apache2.*' 'php7\.0.*' 'php7\.1.*' 'php7\.2.*' 'php7\.3.*' 'php7\.4.*' 'php8\.0.*' -y

# Update & Upgrade
apt update
apt upgrade -y

# Remove old downloads
rm -rf /usr/src/*.tar.gz*

# Remove old packages
apt clean -y
apt autoremove --purge -y
apt autoclean -y

# Webmin Key
cd /usr/local/src
wget https://download.webmin.com/jcameron-key.asc --no-check-certificate
apt-key add jcameron-key.asc

if [ -f "/home/EngineScript/enginescript-install-options.txt" ]
  then
    echo ""
    echo ""
    echo ""
    echo "Initial setup is complete."
    echo "Change the options in /home/EngineScript/enginescript-install-options.txt"
    echo "Edit the file and upload via FTP or run command \"nano /home/EngineScript/enginescript-install-options.txt\""
    echo ""
    echo "After changing options file, run \"bash /usr/local/bin/enginescript/scripts-install.sh\""
    echo ""
    echo ""
  else
    cp -rf /usr/local/bin/enginescript/home/enginescript-install-options.txt /home/EngineScript/enginescript-install-options.txt
    echo ""
    echo ""
    echo ""
    echo "Initial setup is complete."
    echo "Change the options in /home/EngineScript/enginescript-install-options.txt"
    echo "Edit the file and upload via FTP or run command \"nano /home/EngineScript/enginescript-install-options.txt\""
    echo ""
    echo "After changing options file, run \"bash /usr/local/bin/enginescript/scripts-install.sh\""
    echo ""
    echo ""
fi

echo -e "Server needs to restart" | boxes -a c -d shell -p a1l2
echo "Server will restart in 10 seconds"
sleep 10
echo "Restarting..."
shutdown -r now
