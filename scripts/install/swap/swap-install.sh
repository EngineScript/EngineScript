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

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" -ne 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit 1
fi

#----------------------------------------------------------------------------------
# Start Main Script

# Create Swap File
fallocate -l 3G /swapfile
mkswap /swapfile
echo "Setting correct swapfile permissions: cmod 0600"
sudo chmod 0600 /swapfile
swapon /swapfile

# Backup Previous Config
cp -rf /etc/fstab /etc/fstab.bak

# Enable Swap File During Restart
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
echo "Ignore any swap errors listed above."
echo "Swap file will be enabled once the server has restarted."
