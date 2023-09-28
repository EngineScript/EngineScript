#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 22.04 (jammy)
#----------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit
fi

#----------------------------------------------------------------------------
# Start Main Script

# Main Menu
while true
  do
    clear
    echo -e "Security Tools" | boxes -a c -d shell -p a1l2
    echo ""
    echo ""
    PS3='Please enter your choice: '
    secoptions=("10up WP-CLI Vulnerability Scan" "PHP Malware Finder" "Wordfence CLI Malware Scan" "WPScan Vulnerability Scan" "Exit Security Tools")
    select secopt in "${secoptions[@]}"
    do
      case $secopt in
        "10up WP-CLI Vulnerability Scan")
          /usr/local/bin/enginescript/scripts/functions/security/10up-vuln-scanner.sh
          break
          ;;
        "PHP Malware Finder")
          /usr/local/bin/enginescript/scripts/functions/security/php-malware-finder.sh
          break
          ;;
        "Wordfence CLI Malware Scan")
          /usr/local/bin/enginescript/scripts/functions/security/wordfence-cli.sh
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
