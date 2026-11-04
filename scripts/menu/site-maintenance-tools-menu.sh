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

# Ask a yes/no question; true for yes. Usage: confirm <question> [default y|n]
confirm() {
  local answer
  if [[ "${2:-n}" == "y" ]]; then
    read -r -p "$1 [Y/n] " answer
    [[ ! "${answer}" =~ ^[Nn] ]]
  else
    read -r -p "$1 [y/N] " answer
    [[ "${answer}" =~ ^[Yy] ]]
  fi
}

# Update one site's WordPress core, database, plugins, themes, and translations (for_each_site).
# Every step runs even if one fails, so one broken plugin does not hold up the rest.
update_wordpress() {
  local status=0
  run_as_www_data wp core update || status=1
  run_as_www_data wp core update-db || status=1
  run_as_www_data wp plugin update --all || status=1
  run_as_www_data wp theme update --all || status=1
  run_as_www_data wp language core update || status=1
  run_as_www_data wp language plugin update --all || status=1
  run_as_www_data wp language theme update --all || status=1
  return "${status}"
}

# Delete one site's expired transients, and its post revisions when CLEAN_REVISIONS=1 (for_each_site)
clean_up_database() {
  local status=0 ids
  run_as_www_data wp transient delete --expired || status=1
  if [[ "${CLEAN_REVISIONS}" == "1" ]]; then
    ids="$(run_as_www_data wp post list --post_type=revision --format=ids)" || status=1
    if [[ -n "${ids}" ]]; then
      # shellcheck disable=SC2086 # one argument per ID
      run_as_www_data wp post delete ${ids} --force --quiet || status=1
      echo "Deleted $(wc -w <<< "${ids}") revision(s)."
    else
      echo "No revisions to delete."
    fi
  fi
  return "${status}"
}

# Main Menu
while true
  do
    clear
    echo -e "Site Maintenance Tools" | boxes -a c -d shell -p a1l2
    echo ""
    echo ""
    PS3='Please enter your choice: '
    secoptions=(
      "Clean Up Databases (All Domains)"
      "Clear Caches (All Domains)"
      "Fix Permissions (All Domains)"
      "Optimize Images (All Domains)"
      "Run WP-Cron Now (All Domains)"
      "Update WordPress, Plugins, and Themes (All Domains)"
      "WP-CLI Doctor (Site Health Check)"
      "Exit Site Maintenance Tools"
    )
    select secopt in "${secoptions[@]}"
    do
      case $secopt in
        "Clean Up Databases (All Domains)")
          echo "This deletes every site's expired transients. It can also delete every post revision"
          echo "(the saved earlier versions of posts and pages); those cannot be restored afterwards."
          CLEAN_REVISIONS=0
          confirm "Delete post revisions too?" && CLEAN_REVISIONS=1
          for_each_site clean_up_database
          pause
          break
          ;;
        "Clear Caches (All Domains)")
          echo "Clearing all caches..."
          /usr/local/bin/enginescript/scripts/functions/alias/alias-cache.sh
          echo ""
          echo "Done!"
          echo ""
          read -n 1 -s -r -p "Press any key to continue"
          echo ""
          echo ""
          break
          ;;
        "Fix Permissions (All Domains)")
          echo "Fixing permissions for all domains..."
          /usr/local/bin/enginescript/scripts/functions/cron/permissions.sh
          echo ""
          echo "Done!"
          echo ""
          read -n 1 -s -r -p "Press any key to continue"
          echo ""
          echo ""
          break
          ;;
        "Optimize Images (All Domains)")
          echo "Optimizing images in /uploads directory for all domains..."
          /usr/local/bin/enginescript/scripts/functions/cron/optimize-images.sh
          echo ""
          echo "Done!"
          echo ""
          read -n 1 -s -r -p "Press any key to continue"
          echo ""
          echo ""
          break
          ;;
        "Run WP-Cron Now (All Domains)")
          echo "Running the WP-Cron events that are due on every site..."
          if bash /usr/local/bin/enginescript/scripts/functions/cron/wp-cron.sh; then
            echo ""
            echo "Done!"
          fi
          pause
          break
          ;;
        "Update WordPress, Plugins, and Themes (All Domains)")
          if confirm "Back up every site's database first (recommended)?" y \
            && ! bash /usr/local/bin/enginescript/scripts/functions/backup/enginescript-backup.sh database-daily; then
            echo ""
            echo "The backup had errors (see /var/log/EngineScript/enginescript-backup.log)."
            if ! confirm "Update anyway?"; then
              pause
              break
            fi
          fi
          for_each_site update_wordpress
          pause
          break
          ;;
        "WP-CLI Doctor (Site Health Check)")
          /usr/local/bin/enginescript/scripts/functions/security/wp-cli-doctor.sh
          break
          ;;
        "Exit Site Maintenance Tools")
          exit
          ;;
        *) echo "Invalid option.";;
      esac
    done
  done
