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

# Show the last 30 lines of a log, or say it has not been written yet
# Usage: show_log <name> <file>
show_log() {
  clear
  echo "${BOLD}Showing last 30 lines of $1.${NORMAL}" | boxes -a c -d shell -p a1l2
  if [[ -f "$2" ]]; then
    tail -n30 "$2"
  else
    echo "$2 has not been written yet."
  fi
  echo ""
  read -n 1 -s -r -p "Press any key to continue"
}

# Ask which cron job's log to show (run-job.sh writes one per job)
show_cron_log() {
  local log job jobs=()
  for log in /var/log/EngineScript/cron-*.log; do
    [[ -f "${log}" ]] || continue
    job="${log##*/cron-}"
    jobs+=("${job%.log}")
  done
  if [[ "${#jobs[@]}" -eq 0 ]]; then
    show_log "the cron job logs" /var/log/EngineScript/cron-JOB.log
    return
  fi
  local PS3="Choose a job: "
  select job in "${jobs[@]}" "Cancel"; do
    [[ "${job}" == "Cancel" ]] && return
    if [[ -n "${job}" ]]; then
      show_log "the ${job} cron job's log" "/var/log/EngineScript/cron-${job}.log"
      return
    fi
    echo "Invalid option."
  done
}

# The warnings and suggestions of the last Lynis audit (Server Tools > Security Audit)
show_lynis_report() {
  local report=/var/log/lynis-report.dat
  clear
  echo "${BOLD}Showing the last Lynis security audit.${NORMAL}" | boxes -a c -d shell -p a1l2
  if [[ ! -f "${report}" ]]; then
    echo "There is no Lynis report yet. Run one with: es.menu > Server Tools > Security Audit (Lynis)"
  else
    echo "Finished $(sed -n 's/^report_datetime_end=//p' "${report}"); hardening index $(sed -n 's/^hardening_index=//p' "${report}") of 100."
    echo ""
    echo "Warnings:"
    awk -F'|' '/^warning\[\]=/ { sub(/^warning\[\]=/, "", $1); print "  " $1 ": " $2; n++ } END { if (!n) print "  none" }' "${report}"
    echo ""
    echo "Suggestions:"
    awk -F'|' '/^suggestion\[\]=/ { sub(/^suggestion\[\]=/, "", $1); print "  " $1 ": " $2; n++ } END { if (!n) print "  none" }' "${report}"
    echo ""
    echo "The full log of the audit is in /var/log/lynis.log."
  fi
  echo ""
  read -n 1 -s -r -p "Press any key to continue"
}

# Main Menu
while true
  do
    clear
    echo -e "Server Logs" | boxes -a c -d shell -p a1l2
    echo ""
    echo "Select an option to view the last 30 lines of logs."
    echo ""
    PS3='Please enter your choice: '
    secoptions=(
      "Domains"
      "MariaDB"
      "Nginx"
      "PHP"
      "Redis"
      "Syslog"
      "Backup Log"
      "Cron Job Logs"
      "Domain Create Log"
      "Domain Import Log"
      "Domain Remove Log"
      "SSH Login Bans (fail2ban)"
      "Security Audit Report (Lynis)"
      "EngineScript Install Error Log"
      "API Error Log"
      "Exit Server Logs"
    )
    select secopt in "${secoptions[@]}"
    do
      case "$secopt" in
        "Domains")
          /usr/local/bin/enginescript/scripts/functions/logs/domain-logs.sh
          break
          ;;
        "MariaDB")
          show_log "MariaDB error log" /var/log/mysql/mysql-error.log
          break
          ;;
        "Nginx")
          show_log "Nginx error log" /var/log/nginx/nginx.error.log
          break
          ;;
        "PHP")
          show_log "PHP error log" "/var/log/php${PHP_VER}-fpm.log"
          break
          ;;
        "Redis")
          show_log "Redis error log" /var/log/redis/redis-server.log
          break
          ;;
        "Syslog")
          show_log "Syslog" /var/log/syslog
          break
          ;;
        "Backup Log")
          show_log "the backup log" /var/log/EngineScript/enginescript-backup.log
          break
          ;;
        "Cron Job Logs")
          show_cron_log
          break
          ;;
        "Domain Create Log")
          show_log "the domain create log" /var/log/EngineScript/vhost-install.log
          break
          ;;
        "Domain Import Log")
          show_log "the domain import log" /var/log/EngineScript/vhost-import.log
          break
          ;;
        "Domain Remove Log")
          show_log "the domain remove log" /var/log/EngineScript/vhost-remove.log
          break
          ;;
        "SSH Login Bans (fail2ban)")
          show_log "the fail2ban log" /var/log/fail2ban.log
          break
          ;;
        "Security Audit Report (Lynis)")
          show_lynis_report
          break
          ;;
        "EngineScript Install Error Log")
          show_log "EngineScript install-error-log.log" /var/log/EngineScript/install-error-log.log
          break
          ;;
        "API Error Log")
          show_log "EngineScript API error log" /var/log/EngineScript/enginescript-api.log
          break
          ;;
        "Exit Server Logs")
          exit
          ;;
        *) echo "Invalid option.";;
      esac
    done
  done
