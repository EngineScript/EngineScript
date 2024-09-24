#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "ALERT:"
    echo "EngineScript should be executed as the root user."
    exit
fi

LINUX_TYPE=`echo $(lsb_release -i | cut -d':' -f 2)`
UBUNTU_RELEASE=`echo $(lsb_release -c | cut -d':' -f 2)`
# Testing alternate verification method
#if [[ ${LINUX_TYPE} != "Ubuntu" ]] || ! [[ $osver =~ ^(jammy|noble)$ ]];

if [ ${LINUX_TYPE} != "Ubuntu" ]
  then
    echo "EngineScript does not support ${LINUX_TYPE}. Please use Ubuntu 22.04 or 24.04"
  else
	   echo "$LINUX_TYPE"
  fi

# Check if Ubuntu is LTS Release (22.04 or 24.04). If not, exit.
UBUNTU_VERSION="$(lsb_release -sr)"
Jammy=22.04
Noble=24.04

if (( $(bc <<<"$UBUNTU_VERSION != $Jammy && $UBUNTU_VERSION != $Noble") ));
  then
    echo "ALERT:"
    echo "EngineScript does not support Ubuntu ${UBUNTU_VERSION}. We recommend using an Ubuntu LTS release (version 22.04 or 24.04)"
    exit
  else
    echo "Current Ubuntu Version: ${UBUNTU_VERSION}"
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
apt update --allow-releaseinfo-change -y
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
#mkdir -p /home/EngineScript/zImageOptimizer-time-marker
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
apt update --allow-releaseinfo-change -y
apt upgrade -y

# Set Time Zone
dpkg-reconfigure tzdata

# Set Unattended Upgrades
dpkg-reconfigure unattended-upgrades

# HWE
apt install --install-recommends linux-generic-hwe-${UBUNTU_VERSION} -y

apt update --allow-releaseinfo-change -y
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
    clear
    echo -e "\n\n"
    echo -e "Initial setup is complete.\n\n"
    echo -e "Proceed to: Step 2 - Edit Options File\n\nhttps://github.com/EngineScript/EngineScript#step-2---edit-options-file\n\n"
  else
    cp -rf /usr/local/bin/enginescript/home/enginescript-install-options.txt /home/EngineScript/enginescript-install-options.txt
    clear
    echo -e "\n\n"
    echo -e "Initial setup is complete.\n\n"
    echo -e "Proceed to: Step 2 - Edit Options File\n\nhttps://github.com/EngineScript/EngineScript#step-2---edit-options-file\n\n"
fi

echo -e "Server needs to restart" | boxes -a c -d shell -p a1l2
echo "Server will restart in 10 seconds"
sleep 10
echo "Restarting..."
shutdown -r now
