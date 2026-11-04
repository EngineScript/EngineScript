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

# The PHP files in every site's uploads folder (the daily scan only reports which sites have any)
show_php_in_uploads() {
  local SITES=() site uploads found
  if [[ -f /home/EngineScript/sites-list/sites.sh ]]; then
    # shellcheck source=/dev/null
    source /home/EngineScript/sites-list/sites.sh
  fi
  if [[ "${#SITES[@]}" -eq 0 ]]; then
    echo "There are no sites on this server yet."
    return
  fi
  echo "PHP files in an uploads folder can be a sign of a break-in. Not every one is harmful (some"
  echo "plugins keep PHP there), so look into each before deleting anything."
  for site in "${SITES[@]}"; do
    uploads="/var/www/sites/${site}/html/wp-content/uploads"
    echo ""
    echo "${BOLD}${site}${NORMAL}"
    if [[ ! -d "${uploads}" ]]; then
      echo "  No uploads folder."
      continue
    fi
    found="$(find_php_in_uploads "${uploads}")"
    if [[ -n "${found}" ]]; then
      printf '  %s\n' "${found//$'\n'/$'\n'  }"
    else
      echo "  None found."
    fi
  done
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

# Main Menu
site_options=(
  "Find PHP Files in Uploads Folders (All Domains)"
  "Verify WordPress Core Files (All Domains)"
  "Wordfence CLI Malware Scan"
  "Wordfence CLI Remediate Infected Files (After Malware Scan)"
  "Wordfence CLI Vulnerability Scan"
  "WPScan Vulnerability Scan"
)
server_options=(
  "Firewall Status (UFW)"
  "Login History (SSH)"
  "Nginx Configuration Security Check (Gixy-Next)"
  "Open Ports and Listening Services"
  "Security Audit (Lynis)"
  "SSH Login Bans (fail2ban)"
)
while true
  do
    clear
    echo -e "Security Tools" | boxes -a c -d shell -p a1l2
    echo ""
    echo "Options 1-${#site_options[@]} scan the WordPress sites; options $(( ${#site_options[@]} + 1 ))-$(( ${#site_options[@]} + ${#server_options[@]} )) check the server."
    echo ""
    PS3='Please enter your choice: '
    secoptions=("${site_options[@]}" "${server_options[@]}" "Exit Security Tools")
    select secopt in "${secoptions[@]}"
    do
      case $secopt in
        "Find PHP Files in Uploads Folders (All Domains)")
          show_php_in_uploads
          pause
          break
          ;;
        "Verify WordPress Core Files (All Domains)")
          echo "Comparing every site's WordPress core files with the checksums WordPress.org publishes..."
          for_each_site run_as_www_data wp core verify-checksums
          pause
          break
          ;;
        "Wordfence CLI Malware Scan")
          /usr/local/bin/enginescript/scripts/functions/security/wordfence-cli-malware-scan.sh
          break
          ;;
        "Wordfence CLI Remediate Infected Files (After Malware Scan)")
          /usr/local/bin/enginescript/scripts/functions/security/wordfence-cli-remediate.sh
          break
          ;;
        "Wordfence CLI Vulnerability Scan")
          /usr/local/bin/enginescript/scripts/functions/security/wordfence-cli-vuln-scan.sh
          break
          ;;
        "WPScan Vulnerability Scan")
          /usr/local/bin/enginescript/scripts/functions/security/wpscan.sh
          break
          ;;
        "Firewall Status (UFW)")
          run_tool ufw ufw status verbose
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
        "Open Ports and Listening Services")
          show_open_ports
          pause
          break
          ;;
        "Security Audit (Lynis)")
          echo "The audit takes a minute or two; the full report is saved in /var/log/lynis-report.dat."
          run_tool lynis lynis audit system --quick
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
        #"Linux Malware Detect (server scanner)")
        #  /usr/local/bin/enginescript/scripts/functions/security/maldet.sh
        #  break
        #  ;;
        #"Clam Antivirus (server scanner)")
        #  /usr/local/bin/enginescript/scripts/functions/security/clamscan.sh
        #  break
        #  ;;
        "Exit Security Tools")
          exit
          ;;
        *) echo "Invalid option.";;
      esac
    done
  done
