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

# Whether each service EngineScript runs is active
show_service_status() {
  local service
  echo ""
  for service in nginx "php${PHP_VER}-fpm" mariadb redis-server cron ufw fail2ban; do
    printf '  %-18s %s\n' "${service}" "$(systemctl is-active "${service}" 2> /dev/null)"
  done
}

# EngineScript's cron jobs, and how each one's last run ended (from run-job.sh's logs)
show_cron_jobs() {
  local log runs=""
  echo ""
  echo "EngineScript's cron jobs:"
  print_or_none "$(crontab -l 2> /dev/null | grep -F '/usr/local/bin/enginescript/')"
  echo ""
  echo "The last run of each scheduled job:"
  for log in /var/log/EngineScript/cron-*.log; do
    [[ -f "${log}" ]] || continue
    runs+="$(printf '%-28s %s' "$(basename "${log}" .log | sed 's/^cron-//')" "$(grep -E 'Finished with exit status|Skipped' "${log}" | tail -n 1)")"$'\n'
  done
  print_or_none "${runs%$'\n'}"
}

# Failed services, and the system log's errors since the last boot
show_failures() {
  echo ""
  echo "Failed services:"
  print_or_none "$(systemctl --failed --no-pager --no-legend 2> /dev/null)"
  echo ""
  echo "Errors in the system log since the last boot (the latest 40):"
  print_or_none "$(journalctl -p err -b --no-pager -q -n 40 2> /dev/null)"
}

# Test the Nginx configuration, and reload Nginx only if the test passes
test_and_reload_nginx() {
  echo ""
  if nginx -t; then
    systemctl reload nginx && echo "" && echo "Nginx reloaded."
  else
    echo ""
    echo "Nginx was not reloaded: fix the errors above first."
  fi
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
      "Cron Jobs and Last Runs"
      "Disk Usage (ncdu)"
      "Display Server Info"
      "Failed Services and Recent Errors"
      "Nginx Configuration Test and Reload"
      "Restart Services (Nginx, PHP-FPM, Redis)"
      "Service Status"
      "Exit Server Tools"
    )
    select secopt in "${secoptions[@]}"
    do
      case $secopt in
        "Cron Jobs and Last Runs")
          show_cron_jobs
          pause
          break
          ;;
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
        "Failed Services and Recent Errors")
          show_failures
          pause
          break
          ;;
        "Nginx Configuration Test and Reload")
          test_and_reload_nginx
          pause
          break
          ;;
        "Restart Services (Nginx, PHP-FPM, Redis)")
          /usr/local/bin/enginescript/scripts/functions/alias/alias-restart.sh
          pause
          break
          ;;
        "Service Status")
          show_service_status
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
