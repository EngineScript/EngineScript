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

# Main Menu
while true
  do
    clear
    echo -e "Security Tools" | boxes -a c -d shell -p a1l2
    echo ""
    echo ""
    PS3='Please enter your choice: '
    secoptions=(
      "Find PHP Files in Uploads Folders (All Domains)"
      "Verify WordPress Core Files (All Domains)"
      "Wordfence CLI Malware Scan"
      "Wordfence CLI Remediate Infected Files (After Malware Scan)"
      "Wordfence CLI Vulnerability Scan"
      "WP-CLI Doctor"
      "WPScan Vulnerability Scan"
      "Exit Security Tools"
    )
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
        "WP-CLI Doctor")
          /usr/local/bin/enginescript/scripts/functions/security/wp-cli-doctor.sh
          break
          ;;
        "WPScan Vulnerability Scan")
          /usr/local/bin/enginescript/scripts/functions/security/wpscan.sh
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
