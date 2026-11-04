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

# Print a line, or "none" when the text is empty
print_or_none() {
  if [[ -n "$1" ]]; then
    printf '  %s\n' "${1//$'\n'/$'\n'  }"
  else
    echo "  none"
  fi
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

# Recent logins, and failed SSH logins over the last week
show_logins() {
  echo ""
  echo "Recent logins:"
  print_or_none "$(last -n 15 -w 2> /dev/null | sed '/^$/d; /^wtmp begins/d')"
  echo ""
  echo "Failed SSH logins in the last 7 days (the latest 20):"
  print_or_none "$(journalctl -u ssh -u sshd --since '7 days ago' --no-pager -q 2> /dev/null | grep -E 'Failed password|Invalid user|authentication failure' | tail -n 20)"
}

# Every socket that accepts connections; UFW decides which of them are reachable from outside
show_open_ports() {
  echo ""
  echo "Listening sockets (UFW decides which are reachable from outside: see Firewall Status):"
  ss -tulpn
}

# Package updates waiting, a pending reboot, and services still running replaced libraries
show_pending_updates() {
  local stamp=/var/lib/apt/periodic/update-success-stamp
  [[ -f "${stamp}" ]] || stamp=/var/cache/apt/pkgcache.bin
  echo ""
  echo "Package updates waiting (as of the last package list refresh, $(date -r "${stamp}" '+%Y-%m-%d %H:%M' 2> /dev/null)):"
  print_or_none "$(apt list --upgradable 2> /dev/null | tail -n +2)"
  echo ""
  if [[ -f /var/run/reboot-required ]]; then
    echo "A reboot is needed, for:"
    print_or_none "$(cat /var/run/reboot-required.pkgs 2> /dev/null)"
  else
    echo "No reboot is needed."
  fi
  if command -v needrestart > /dev/null 2>&1; then
    echo ""
    echo "Services still running replaced libraries (restart them to load the update):"
    print_or_none "$(needrestart -b -r l 2> /dev/null | sed -n 's/^NEEDRESTART-SVC: //p')"
  fi
}

# One certificate's expiry date and the days left
show_certificate() {
  local label="$1" cert="$2" end
  if ! end="$(openssl x509 -enddate -noout -in "${cert}" 2> /dev/null)"; then
    printf '  %-44s no certificate at %s\n' "${label}" "${cert}"
    return
  fi
  end="${end#notAfter=}"
  printf '  %-44s expires %s (%s days)\n' "${label}" "$(date -d "${end}" '+%Y-%m-%d')" \
    "$(( ($(date -d "${end}" +%s) - $(date +%s)) / 86400 ))"
}

# The certificate of every site, and the Cloudflare certificate that origin pulls are checked with
show_certificates() {
  local SITES=() site
  if [[ -f /home/EngineScript/sites-list/sites.sh ]]; then
    # shellcheck source=/dev/null
    source /home/EngineScript/sites-list/sites.sh
  fi
  echo ""
  echo "Site certificates (acme.sh renews them on its own before they expire):"
  [[ "${#SITES[@]}" -eq 0 ]] && echo "  No sites yet."
  for site in "${SITES[@]}"; do
    show_certificate "${site}" "/etc/nginx/ssl/${site}/fullchain.pem"
  done
  echo ""
  show_certificate "Cloudflare origin pull CA" /etc/nginx/ssl/cloudflare/origin-pull-ca.pem
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
      "Firewall Status (UFW)"
      "List Sites"
      "Login History (SSH)"
      "Nginx Configuration Security Check (Gixy-Next)"
      "Nginx Configuration Test and Reload"
      "Open Ports and Listening Services"
      "Pending Updates and Reboot Check"
      "Restart Services (Nginx, PHP-FPM, Redis)"
      "Security Audit (Lynis)"
      "Service Status"
      "SSH Login Bans (fail2ban)"
      "SSL Certificate Expiry"
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
        "Login History (SSH)")
          show_logins
          pause
          break
          ;;
        "Nginx Configuration Security Check (Gixy-Next)")
          run_tool gixy gixy /etc/nginx/nginx.conf
          pause
          break
          ;;
        "Nginx Configuration Test and Reload")
          test_and_reload_nginx
          pause
          break
          ;;
        "Open Ports and Listening Services")
          show_open_ports
          pause
          break
          ;;
        "Pending Updates and Reboot Check")
          show_pending_updates
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
        "SSL Certificate Expiry")
          show_certificates
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
