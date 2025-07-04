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



#----------------------------------------------------------------------------------
# Start Main Script

# UFW Allow Rules
ufw allow 22 comment 'SSH'
ufw allow 53 comment 'DNS'
ufw allow 67 comment 'DHCP'
ufw allow 68 comment 'DHCP'
ufw allow 80 comment 'HTTP'
ufw allow 123/udp comment 'NTP'
ufw allow 443 comment 'HTTPS'
ufw allow 1022 comment 'Backup SSH port during dist upgrade'
ufw allow 2048 comment 'RAILGUN'
ufw allow 53682 comment 'RCLONE'


# UFW Reject Rules
ufw reject 23 comment 'Unencrypted traffic not allowed'
ufw reject 1194 comment 'VPN traffic not allowed'

# UFW General Rules
ufw default allow outgoing
ufw default deny incoming
ufw logging low
