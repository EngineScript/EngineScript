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

# Create Swap File
fallocate -l 2G /swapfile
mkswap /swapfile
echo "Setting correct swapfile permissions: cmod 0600"
sudo chmod 0600 /swapfile
swapon /swapfile

# Backup Previous Config
cp -p /etc/fstab /etc/fstab.bak

# Enable Swap File During Restart
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
echo "Ignore any swap errors listed above."
echo "Swap file will be enabled once the server has restarted."
