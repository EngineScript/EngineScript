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

ENGINESCRIPT_REPO="/usr/local/bin/enginescript"
ENGINESCRIPT_COMMIT="unknown"
ENGINESCRIPT_BRANCH="unknown"
ENGINESCRIPT_BRANCH_LABEL="unknown branch"

if git -C "${ENGINESCRIPT_REPO}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    ENGINESCRIPT_COMMIT="$(git -C "${ENGINESCRIPT_REPO}" rev-parse --short=12 HEAD 2>/dev/null || echo "unknown")"
    ENGINESCRIPT_BRANCH="$(git -C "${ENGINESCRIPT_REPO}" symbolic-ref --short HEAD 2>/dev/null || echo "detached")"

    case "${ENGINESCRIPT_BRANCH}" in
      "update-software-versions")
        ENGINESCRIPT_BRANCH_LABEL="testing branch (update-software-versions)"
        ;;
      "master")
        ENGINESCRIPT_BRANCH_LABEL="main branch (master)"
        ;;
      "detached")
        ENGINESCRIPT_BRANCH_LABEL="detached HEAD"
        ;;
      *)
        ENGINESCRIPT_BRANCH_LABEL="branch (${ENGINESCRIPT_BRANCH})"
        ;;
    esac
fi

# Main Menu
while true
  do
    clear

    echo ""
    echo "==============================================================="
    echo "EngineScript - Menu"
    echo "==============================================================="
    echo ""
    echo "EngineScript Commit: ${ENGINESCRIPT_COMMIT}"
    echo "EngineScript Branch: ${ENGINESCRIPT_BRANCH_LABEL}"
    echo ""
    echo "Admin Control Panels:"
    echo "via Domain: https://admin.YOURDOMAIN.TLD"
    echo ""
    echo "Helpful Commands:"
    echo "es.config  - Open the configuration file in Nano"
    echo "es.debug   - Display debug information for EngineScript"
    echo "es.help    - Display EngineScript commands and locations"
    echo "es.menu    - Open EngineScript menu"
    echo "es.restart - Restart Nginx and PHP-FPM"
    echo "es.update  - Update and upgrade your server using APT"
    echo ""
    echo "---------------------------------------------------------------"
    echo ""
    echo "What would you like to do?"
    echo ""

    PS3='Please enter your choice: '
    options=(
      "Domain Configuration Tools"
      "Backup Tools"
      "Site Maintenance Tools"
      "Database Tools"
      "Security Tools"
      "Server Tools"
      "EngineScript Tools"
      "View Server Logs"
      "Update Software"
      "Exit EngineScript"
    )
    select opt in "${options[@]}"
    do
      case $opt in
        "Domain Configuration Tools")
          /usr/local/bin/enginescript/scripts/menu/domain-configuration-tools-menu.sh
          break
          ;;
        "Backup Tools")
          /usr/local/bin/enginescript/scripts/menu/backup-tools-menu.sh
          break
          ;;
        "Site Maintenance Tools")
          /usr/local/bin/enginescript/scripts/menu/site-maintenance-tools-menu.sh
          break
          ;;
        "Database Tools")
          /usr/local/bin/enginescript/scripts/menu/database-tools-menu.sh
          break
          ;;
        "Security Tools")
          /usr/local/bin/enginescript/scripts/menu/security-tools-menu.sh
          break
          ;;
        "Server Tools")
          /usr/local/bin/enginescript/scripts/menu/server-tools-menu.sh
          break
          ;;
        "EngineScript Tools")
          /usr/local/bin/enginescript/scripts/menu/enginescript-tools-menu.sh
          break
          ;;
        "View Server Logs")
          /usr/local/bin/enginescript/scripts/menu/logs-menu.sh
          break
          ;;
        "Update Software")
          /usr/local/bin/enginescript/scripts/menu/update-menu.sh
          break
          ;;
        "Exit EngineScript")
          exit
          ;;
        *) echo "Invalid option.";;
      esac
    done
  done
