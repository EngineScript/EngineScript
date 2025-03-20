#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------

set -e

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "ALERT:"
    echo "EngineScript should be executed as the root user."
    exit 1
fi

# Check if the server is running on a 64-bit environment. If not, exit.
BIT_TYPE=$(uname -m)

if [ ${BIT_TYPE} != 'x86_64' ];
  then
    echo "EngineScript requires a 64-bit environment to run optimally."
    exit 1
fi

# Check if the server is running Ubuntu
LINUX_TYPE=$(lsb_release -i | cut -d':' -f 2 | tr -d '[:space:]')

if [ "$LINUX_TYPE" != "Ubuntu" ]; then
  echo "EngineScript does not support $LINUX_TYPE. Please use Ubuntu 22.04 or 24.04"
  exit 1
else
  echo "Detected Linux Type: $LINUX_TYPE"
fi

# Check if Ubuntu is LTS Release (22.04 or 24.04). If not, exit.
UBUNTU_VERSION="$(lsb_release -sr)"
Jammy=22.04
Noble=24.04

if (( $(bc <<<"$UBUNTU_VERSION != $Jammy && $UBUNTU_VERSION != $Noble") )); then
  echo "ALERT:"
  echo "EngineScript does not support Ubuntu $UBUNTU_VERSION. We recommend using an Ubuntu LTS release (version 22.04 or 24.04)"
  exit 1
else
  echo "Current Ubuntu Version: $UBUNTU_VERSION"
fi

#----------------------------------------------------------------------------
# Start Main Script

# Install Required Packages for Script
apt update --allow-releaseinfo-change -y

core_packages="apt bash boxes cron coreutils curl dos2unix git gzip nano openssl pwgen sed software-properties-common tar tzdata unattended-upgrades unzip zip"

apt install -qy $core_packages || {
  echo "Error: Unable to install one or more packages. Exiting..."
  exit 1
}

# Check for required commands
required_commands=("apt" "boxes" "dos2unix" "git" "nano" "wget")
for cmd in "${required_commands[@]}"; do
  if ! command -v $cmd &> /dev/null; then
    echo "Error: $cmd is not installed. Please install it and try again."
    exit 1
  fi
done

sed -i "s/#\$nrconf{restart} = 'i';/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf

# Upgrade Software
apt upgrade -y

# Return to /usr/src
cd /usr/src

# Remove existing EngineScript directory if it exists
if [ -d "/usr/local/bin/enginescript" ]; then
  rm -rf /usr/local/bin/enginescript
fi

# EngineScript Git Clone
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
mkdir -p /var/log/EngineScript
touch /var/log/EngineScript/install-log.txt
touch /var/log/EngineScript/vhost-install.log
touch /var/log/EngineScript/vhost-remove.log

# Return to /usr/src
cd /usr/src

# Create EngineScript Aliases
source /var/log/EngineScript/install-log.txt
if [ "${ALIAS}" = 1 ];
  then
    echo "ALIAS script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/alias/enginescript-alias-install.sh
    echo "ALIAS=1" >> /var/log/EngineScript/install-log.txt
fi

# Cleanup
apt-get remove 'apache2.*' 'php7\.0.*' 'php7\.1.*' 'php7\.2.*' 'php7\.3.*' 'php7\.4.*' 'php8\.0.*' 'php8\.1.*' 'php8\.2.*' 'php8\.3.*' -y

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

if [ -f "/home/EngineScript/enginescript-install-options.txt" ]; then
  clear
  echo -e "\n\nInitial setup is complete.\n\nProceed to: Step 2 - Edit Options File\n\nhttps://github.com/EngineScript/EngineScript#step-2---edit-options-file\n\n"
else
  cp -rf /usr/local/bin/enginescript/config/home/enginescript-install-options.txt /home/EngineScript/enginescript-install-options.txt
  clear
  echo -e "\n\nInitial setup is complete.\n\nProceed to: Step 2 - Edit Options File\n\nhttps://github.com/EngineScript/EngineScript#step-2---edit-options-file\n\n"
fi

echo -e "Server needs to restart" | boxes -a c -d shell -p a1l2
echo "Server will restart in 10 seconds"
sleep 10
echo "Restarting..."
shutdown -r now
