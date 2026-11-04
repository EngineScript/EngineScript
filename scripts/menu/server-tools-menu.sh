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

# Wait for a key before the menu redraws
pause() {
  echo ""
  read -n 1 -s -r -p "Press any key to continue"
  echo ""
  echo ""
}

# Run a tool, or say how to install it: servers set up before a tool was added get it from
# Update Software > Update Server Tools
run_tool() {
  local tool="$1"
  shift
  if ! command -v "${tool}" > /dev/null 2>&1; then
    echo "${tool} is not installed. Install it with: es.menu > Update Software > Update Server Tools"
    return 1
  fi
  "$@"
}

# Whether each service EngineScript runs is active
show_service_status() {
  local service
  echo ""
  for service in nginx "php${PHP_VER}-fpm" mariadb redis-server cron ufw fail2ban; do
    printf '  %-18s %s\n' "${service}" "$(systemctl is-active "${service}" 2> /dev/null)"
  done
}

# Main Menu
while true
  do
    clear
    echo -e "Server Tools" | boxes -a c -d shell -p a1l2
    echo ""
    echo ""
    PS3='Please enter your choice: '
    secoptions=(
      "Disk Usage (ncdu)"
      "Display Server Info"
      "Firewall Status (UFW)"
      "List Sites"
      "Live Resource Monitor (htop)"
      "Network Traffic (vnstat)"
      "Nginx Configuration Security Check (Gixy-Next)"
      "Restart Services (Nginx, PHP-FPM, Redis)"
      "Security Audit (Lynis)"
      "Service Status"
      "SSH Login Bans (fail2ban)"
      "Exit Server Tools"
    )
    select secopt in "${secoptions[@]}"
    do
      case $secopt in
        "Disk Usage (ncdu)")
          # -x stays on the root filesystem
          run_tool ncdu ncdu -x /
          break
          ;;
        "Display Server Info")
          /usr/local/bin/enginescript/scripts/functions/alias/alias-server-info.sh
          echo ""
          echo "Done!"
          pause
          break
          ;;
        "Firewall Status (UFW)")
          run_tool ufw ufw status verbose
          pause
          break
          ;;
        "List Sites")
          /usr/local/bin/enginescript/scripts/functions/alias/alias-sites.sh
          pause
          break
          ;;
        "Live Resource Monitor (htop)")
          run_tool htop htop
          break
          ;;
        "Network Traffic (vnstat)")
          run_tool vnstat vnstat
          pause
          break
          ;;
        "Nginx Configuration Security Check (Gixy-Next)")
          run_tool gixy gixy /etc/nginx/nginx.conf
          pause
          break
          ;;
        "Restart Services (Nginx, PHP-FPM, Redis)")
          /usr/local/bin/enginescript/scripts/functions/alias/alias-restart.sh
          pause
          break
          ;;
        "Security Audit (Lynis)")
          echo "The audit takes a minute or two; the full report is saved in /var/log/lynis-report.dat."
          run_tool lynis lynis audit system --quick
          pause
          break
          ;;
        "Service Status")
          show_service_status
          pause
          break
          ;;
        "SSH Login Bans (fail2ban)")
          if run_tool fail2ban-client fail2ban-client status sshd; then
            echo ""
            echo "To lift a ban: fail2ban-client set sshd unbanip <address>"
          fi
          pause
          break
          ;;
        "Exit Server Tools")
          exit
          ;;
        *) echo "Invalid option.";;
      esac
    done
  done
