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

source /etc/enginescript/install-state.conf
if [[ "${NTP}" = 1 ]]; then
    echo "NTP script has already run"
    exit 0
fi

# Network Time Protocol (NTP). Ubuntu 26.04 keeps time with chrony (with NTS, authenticated time)
# instead of systemd-timesyncd: where chrony is installed, it stays in charge. Otherwise (Ubuntu
# 24.04) systemd-timesyncd syncs with Cloudflare's and Ubuntu's time servers.
if dpkg-query -W -f='${Status}' chrony 2> /dev/null | grep -q 'ok installed'; then
  echo "chrony keeps the time on this server; leaving it as it is."
  systemctl enable --now chrony 2> /dev/null || true
else
  if ! dpkg-query -W -f='${Status}' systemd-timesyncd 2> /dev/null | grep -q 'ok installed'; then
    apt install -qy systemd-timesyncd
  fi
  cp -rf /usr/local/bin/enginescript/config/etc/systemd/timesyncd.conf /etc/systemd/timesyncd.conf
  chmod 644 /etc/systemd/timesyncd.conf
  timedatectl set-ntp true
  systemctl restart systemd-timedated
  systemctl restart systemd-timesyncd
fi

# Mark the installation as complete
set_install_state "NTP" "1"
echo "NTP completed successfully. Script done."
