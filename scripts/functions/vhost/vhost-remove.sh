#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript settings and shared functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh" >&2; exit 1; }

# Source shared database credential functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-db-credentials.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-db-credentials.sh" >&2; exit 1; }

# Source shared vhost functions library (remove_site)
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-shared-vhost.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-shared-vhost.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# One site change at a time: two at once would race on the site list and Redis numbers
acquire_lock "sites" || exit 1

# Intro Warning
echo ""
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo "|   Domain Removal                                    |"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""
echo -e "WARNING: This script will remove a site from your installation.\n\n${BOLD}This removal is irreversible: the site's files, database, and settings are destroyed.${NORMAL}
You choose below whether its local backups go too.\nPlease be 100% sure of your choice before continuing with this process.\n\n"
sleep 1

# Domain selection: a site on the server's list, or a domain typed in, for a site that was only
# partly set up or is no longer on the list
es_sites
OTHER_DOMAIN="Type a domain that is not on this list"
echo ""
PS3="Choose the domain to remove: "
select DOMAIN in "${SITES[@]}" "${OTHER_DOMAIN}" "Cancel"; do
  if [[ "${DOMAIN}" == "Cancel" ]]; then
    echo "Exiting domain removal script."
    exit 0
  elif [[ "${DOMAIN}" == "${OTHER_DOMAIN}" ]]; then
    while true; do
      read -r -p "Enter the full domain (e.g., 'wordpresstesting.com'): " DOMAIN
      if validate_site_domain "${DOMAIN}"; then
        break
      fi
      echo "Invalid domain. Enter it in lowercase without https:// or www, for example wordpresstesting.com."
    done
    break
  elif [[ -n "${DOMAIN}" ]]; then
    break
  fi
  echo "Invalid selection."
done

# Confirm the exact domain before anything is removed
echo ""
echo "Domain to remove: ${BOLD}${DOMAIN}${NORMAL}"
if ! prompt_yes_no "Remove ${DOMAIN} and everything that belongs to it?" "n" 300; then
  echo "Exiting domain removal script."
  exit 0
fi

# The site's local backups: delete them too (the default), or keep them. They include site
# archives, which Import Domain can set the site up from again. Copies on Amazon S3 are never
# touched here.
BACKUP_DIR="/home/EngineScript/site-backups/${DOMAIN}"
REMOVE_SITE_KEEP_BACKUPS=0
if [[ -d "${BACKUP_DIR}" ]]; then
  echo ""
  echo "${DOMAIN} has local backups in ${BACKUP_DIR} ($(du -sh "${BACKUP_DIR}" 2> /dev/null | cut -f1))."
  echo "They include site archives that Import Domain can set the site up from again."
  echo "Copies on Amazon S3, if any, are not touched either way."
  if ! prompt_yes_no "Delete these local backups too? Answer n to keep them." "y" 300; then
    REMOVE_SITE_KEEP_BACKUPS=1
  fi
fi
export REMOVE_SITE_KEEP_BACKUPS

# Logging
LOG_FILE="/var/log/EngineScript/vhost-remove.log"
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "Starting domain removal for ${DOMAIN} at $(date)"

remove_site "${DOMAIN}"
echo ""

# Summary
echo "----------------------------------------------------------"
echo "Domain removal completed for ${DOMAIN}."
echo "Please verify that all associated files, directories, and configurations have been removed."
if [[ "${REMOVE_SITE_KEEP_BACKUPS}" == "1" ]]; then
  echo "The site's local backups were kept: ${BACKUP_DIR}/"
  echo "To set the site up again from one, copy its site archive into /home/EngineScript/temp/site-import and run Import Domain."
fi
if [[ -d "/home/EngineScript/temp/site-export/${DOMAIN}" ]]; then
  echo "Site exports made with Export Domain were kept: /home/EngineScript/temp/site-export/${DOMAIN}/"
fi
echo "----------------------------------------------------------"

sleep 5
