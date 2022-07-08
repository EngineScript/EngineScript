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

# Add UFW Rules for Cloudflare
# Credit: https://github.com/simnix/cloudflare-ufw/

# Retrieve IPs
curl -s https://www.cloudflare.com/ips-v4 -o /tmp/cf_ips
echo "" >> /tmp/cf_ips
curl -s https://www.cloudflare.com/ips-v6 >> /tmp/cf_ips

# Allow all traffic from Cloudflare IPs (no ports restriction)
for cfip in `cat /tmp/cf_ips`; do ufw allow proto tcp from $cfip comment 'Cloudflare IP'; done

ufw reload > /dev/null

# OTHER EXAMPLE RULES
# Retrict to port 80 (HTTP)
#for cfip in `cat /tmp/cf_ips`; do ufw allow proto tcp from $cfip to any port 80/tcp comment 'Cloudflare IP'; done

# Restrict to port 443 (HTTPS)
#for cfip in `cat /tmp/cf_ips`; do ufw allow from proto tcp $cfip to any port 443/tcp comment 'Cloudflare IP'; done

# Restrict to port 2048 (Railgun)
#for cfip in `cat /tmp/cf_ips`; do ufw allow proto tcp from $cfip to any port 2048/tcp comment 'Cloudflare IP'; done

# Restrict to ports 80, 443, 2048
#for cfip in `cat /tmp/cf_ips`; do ufw allow proto tcp from $cfip to any port 80,443,2048/tcp comment 'Cloudflare IP'; done
