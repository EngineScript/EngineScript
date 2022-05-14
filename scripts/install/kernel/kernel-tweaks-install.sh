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

# Kernel Tweaks
cp -rf /usr/local/bin/enginescript/etc/sysctl.d/60-enginescript.conf /etc/sysctl.d/60-enginescript.conf
chown -R root:root /etc/sysctl.d/60-enginescript.conf
chmod 0664 /etc/sysctl.d/60-enginescript.conf

# Enable Kernel Tweaks
sysctl -e -p /etc/sysctl.d/60-enginescript.conf
sysctl --system
