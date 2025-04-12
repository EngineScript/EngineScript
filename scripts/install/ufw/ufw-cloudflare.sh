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

# Add UFW Rules for Cloudflare
# Credit: https://github.com/Paul-Reed/cloudflare-ufw

echo "Adding UFW rules for Cloudflare IPs (TCP & UDP)..."
# Allow all TCP and UDP traffic from Cloudflare IPs (no ports restriction)
# Using brace expansion for conciseness
for cfip in $(curl -s https://www.cloudflare.com/ips-v{4,6}); do
  ufw allow proto tcp from "$cfip" comment 'Cloudflare IP (TCP)' > /dev/null
  ufw allow proto udp from "$cfip" comment 'Cloudflare IP (UDP)' > /dev/null
done

echo "Reloading UFW rules..."
ufw reload > /dev/null
echo "UFW rules updated for Cloudflare."
