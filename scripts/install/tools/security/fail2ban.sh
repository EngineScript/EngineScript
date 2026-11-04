#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt || { echo "Error: Failed to source /usr/local/bin/enginescript/enginescript-variables.txt" >&2; exit 1; }
source /home/EngineScript/enginescript-install-options.txt || { echo "Error: Failed to source /home/EngineScript/enginescript-install-options.txt" >&2; exit 1; }

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# fail2ban: bans an address after repeated failed SSH logins. Only the SSH jail is on: the
# sites only answer requests that come through Cloudflare.
# python3-systemd lets fail2ban read SSH's log from the systemd journal.
apt install -qy fail2ban python3-systemd

cp -f /usr/local/bin/enginescript/config/etc/fail2ban/jail.d/enginescript.conf /etc/fail2ban/jail.d/enginescript.conf
chmod 644 /etc/fail2ban/jail.d/enginescript.conf

systemctl enable fail2ban
systemctl restart fail2ban

print_install_banner "fail2ban (SSH)"
