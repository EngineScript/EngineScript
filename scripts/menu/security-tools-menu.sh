#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" -ne 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit 1
fi

#----------------------------------------------------------------------------------
# Start Main Script

# Main Menu
while true
  do
    clear
    echo -e "Security Tools" | boxes -a c -d shell -p a1l2
    echo ""
    echo ""
    PS3='Please enter your choice: '
    secoptions=("10up WP-CLI Vulnerability Scan" "Find PHP Files in Uploads Directory" "PHP Malware Finder" "Wordfence CLI Malware Scan" "Wordfence CLI Remediate Infected Files (After Malware Scan)" "Wordfence CLI Vulnerability Scan" "WP-CLI Doctor" "WPScan Vulnerability Scan" "Exit Security Tools")
    select secopt in "${secoptions[@]}"
    do
      case $secopt in
        "10up WP-CLI Vulnerability Scan")
          /usr/local/bin/enginescript/scripts/functions/security/10up-vuln-scanner.sh
          break
          ;;
        "Find PHP Files in Uploads Directory")
          /usr/local/bin/enginescript/scripts/functions/security/find-php-in-uploads.sh
          break
          ;;
        "PHP Malware Finder")
          /usr/local/bin/enginescript/scripts/functions/security/php-malware-finder.sh
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
        *) echo invalid option;;
      esac
    done
  done
