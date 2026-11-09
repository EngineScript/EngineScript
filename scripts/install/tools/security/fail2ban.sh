#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript settings and shared functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# fail2ban: bans an address after repeated failed SSH logins. Only the SSH jail is on: the
# sites only answer requests that come through Cloudflare.
# python3-systemd lets fail2ban read SSH's log from the systemd journal.
apt-get install -qy fail2ban python3-systemd

install_enginescript_fail2ban_config

systemctl enable fail2ban
systemctl restart fail2ban

print_install_banner "fail2ban (SSH)"
