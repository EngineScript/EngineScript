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

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh


#----------------------------------------------------------------------------------
# Start Main Script

# Network Time Protocol (NTP)
cp -rf /usr/local/bin/enginescript/config/etc/systemd/timesyncd.conf /etc/systemd/timesyncd.conf
chmod 644 /etc/systemd/timesyncd.conf
timedatectl set-ntp true
systemctl restart systemd-timedated
systemctl restart systemd-timesyncd
#systemctl status systemd-timesyncd
