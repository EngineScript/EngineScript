#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Author:       Peter Downey
# Company:      VisiStruct
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

# UFW Allow Rules
ufw allow 22 comment 'SSH'
ufw allow 53 comment 'DNS'
ufw allow 67 comment 'DHCP'
ufw allow 68 comment 'DHCP'
ufw allow 80 comment 'HTTP'
ufw allow out 123/udp 'NTP'
ufw allow 443 comment 'HTTPS'
ufw allow 1022 comment 'Backup SSH port during dist upgrade'
ufw allow 2048 comment 'RAILGUN'
ufw allow 32792 comment 'WEBMIN'

# UFW Reject Rules
ufw reject 23 comment 'Unencrypted traffic not allowed'
ufw reject 1194 comment 'VPN traffic not allowed'

# UFW General Rules
ufw logging low
ufw default allow outgoing
ufw default deny incoming
