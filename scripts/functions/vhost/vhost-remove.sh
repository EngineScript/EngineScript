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

# Source shared database credential functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-db-credentials.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-db-credentials.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# Intro Warning
echo ""
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo "|   Domain Removal                                    |"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""
echo -e "WARNING: This script will remove a site from your installation.\n\n${BOLD}This removal is irreversible and everything will be destroyed, including backups.${NORMAL}\nPlease be 100% sure of your choice before continuing with this process.\n\n"
sleep 1

# Domain selection: a site on the server's list, or a domain typed in, for a site that was only
# partly set up or is no longer on the list
SITES_LIST="/home/EngineScript/sites-list/sites.sh"
SITES=()
if [[ -f "${SITES_LIST}" ]]; then
  # shellcheck source=/dev/null
  source "${SITES_LIST}"
fi
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
if ! prompt_yes_no "Remove ${DOMAIN} and everything that belongs to it, including its backups?" "n" 300; then
  echo "Exiting domain removal script."
  exit 0
fi

# Logging
LOG_FILE="/var/log/EngineScript/vhost-remove.log"
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "Starting domain removal for ${DOMAIN} at $(date)"

# Remove the site's staging copy first: it uses the site's certificate, which goes below
if [[ -f "/etc/nginx/sites-enabled/staging.${DOMAIN}.conf" || -d "/var/www/sites/staging.${DOMAIN}" \
    || -f "/home/EngineScript/staging-credentials/staging.${DOMAIN}.txt" ]]; then
  echo "Removing the staging copy of ${DOMAIN}..."
  bash /usr/local/bin/enginescript/scripts/functions/vhost/vhost-staging.sh delete "${DOMAIN}"
fi

# Remove domain from site list
# Check for the domain enclosed in quotes, matching the format in sites.sh
if grep -Fxq "\"${DOMAIN}\"" "${SITES_LIST}"
then
  echo -e "${BOLD}Site List Removal Check: Passed\n\n${NORMAL}Removing ${DOMAIN} from site list...\n\n"
  # Remove only the line that is exactly the quoted domain (fixed string: a dot is not a wildcard)
  grep -vxF "\"${DOMAIN}\"" "${SITES_LIST}" > "${SITES_LIST}.new" && mv "${SITES_LIST}.new" "${SITES_LIST}"
else
  echo -e "${BOLD}Site List Removal Check: Failed\n\n${NORMAL}${DOMAIN} was not found on the site list.\n\n"
fi

# Remove MySQL credentials
if test -f "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
then
  echo -e "${BOLD}MySQL Credentials Removal Check: Passed\n\n${NORMAL}Removing MySQL credentials for ${DOMAIN}...\n\n"
  source "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
  if validate_db_identifier "${DB}" "${DOMAIN}"; then
    mariadb -e "DROP DATABASE IF EXISTS \`${DB}\`;"
  fi
  if [[ "${USR}" =~ ^[A-Za-z0-9_]+$ ]]; then
    mariadb -e "DROP USER IF EXISTS '${USR}'@'localhost';"
  else
    echo "Warning: Invalid database user name '${USR}' in /home/EngineScript/mysql-credentials/${DOMAIN}.txt; the user was not dropped." >&2
  fi
  rm -f "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
else
  echo -e "${BOLD}MySQL Credentials Check: Failed\n\n${NORMAL}${DOMAIN} did not have MySQL credentials.\n\n"
fi

# Remove Nginx vhosts
for VHOST in "/etc/nginx/sites-enabled/${DOMAIN}.conf" "/etc/nginx/admin/admin.${DOMAIN}.conf"; do
  if test -f "${VHOST}"; then
    echo -e "${BOLD}Nginx Vhost Removal Check: Passed\n\n${NORMAL}Removing ${VHOST}...\n\n"
    rm -rf "${VHOST}"
  else
    echo -e "${BOLD}Nginx Vhost Removal Check: Failed\n\n${NORMAL}${VHOST} did not exist.\n\n"
  fi
done

# Remove the certificate from acme.sh first: its renewal job would otherwise keep renewing it and
# installing it into /etc/nginx/ssl/${DOMAIN}/ again
if [[ -d "/root/.acme.sh/${DOMAIN}_ecc" ]]; then
  echo -e "${BOLD}acme.sh Certificate Removal Check: Passed\n\n${NORMAL}Removing ${DOMAIN} from acme.sh...\n\n"
  /root/.acme.sh/acme.sh --remove -d "${DOMAIN}" --ecc \
    || echo "Warning: acme.sh could not remove ${DOMAIN} from its renewal list; its folder is removed below." >&2
  rm -rf "/root/.acme.sh/${DOMAIN}_ecc"
else
  echo -e "${BOLD}acme.sh Certificate Removal Check: Failed\n\n${NORMAL}${DOMAIN} did not have an acme.sh certificate.\n\n"
fi

# Remove SSL certificates
if [[ -d "/etc/nginx/ssl/${DOMAIN}" ]];
then
  echo -e "${BOLD}SSL Certificates Removal Check: Passed\n\n${NORMAL}Removing SSL certificates for ${DOMAIN}...\n\n"
  rm -rf "/etc/nginx/ssl/${DOMAIN}"
else
  echo -e "${BOLD}SSL Certificates Removal Check: Failed\n\n${NORMAL}${DOMAIN} did not have SSL Certificates.\n\n"
fi

# Delete the site's Redis keys (read from its wp-config.php, so before the files go)
flush_site_redis_cache "/var/www/sites/${DOMAIN}/html/wp-config.php"

# Remove main directory
if [[ -d "/var/www/sites/${DOMAIN}" ]];
then
  echo -e "${BOLD}Main Directory Removal Check: Passed\n\n${NORMAL}Removing main directory for ${DOMAIN}...\n\n"
  rm -rf "/var/www/sites/${DOMAIN}"
else
  echo -e "${BOLD}Main Directory Removal Check: Failed\n\n${NORMAL}${DOMAIN} did not have a main directory.\n\n"
fi

# Remove backup directory
if [[ -d "/home/EngineScript/site-backups/${DOMAIN}" ]];
then
  echo -e "${BOLD}Backup Directory Removal Check: Passed\n\n${NORMAL}Removing backup directory for ${DOMAIN}...\n\n"
  rm -rf "/home/EngineScript/site-backups/${DOMAIN}"
else
  echo -e "${BOLD}Backup Directory Removal Check: Failed\n\n${NORMAL}${DOMAIN} did not have a backup directory.\n\n"
fi

# Remove log directory
if [[ -d "/var/log/domains/${DOMAIN}" ]];
then
  echo -e "${BOLD}Log Directory Removal Check: Passed\n\n${NORMAL}Removing log directory for ${DOMAIN}...\n\n"
  rm -rf "/var/log/domains/${DOMAIN}"
else
  echo -e "${BOLD}Log Directory Removal Check: Failed\n\n${NORMAL}${DOMAIN} did not have a log directory.\n\n"
fi
# The admin subdomain's logs, and their rotated copies, are kept beside the log directories
rm -f "/var/log/domains/admin.${DOMAIN}-nginx-"*.log*

# The site's Redis database number is free again: new sites take the lowest number no other
# site's wp-config.php uses, so nothing changes in redis.conf.

# Delete the site's cached pages, so the domain does not serve them if it is set up again
clear_site_nginx_cache "${DOMAIN}"

# Reload Nginx (the site's vhost is gone) and PHP-FPM (drops the site's code from OPcache).
# Redis keeps running; the site's keys are already deleted.
reload_web_services
echo ""

# Summary
echo "----------------------------------------------------------"
echo "Domain removal completed for ${DOMAIN}."
echo "Please verify that all associated files, directories, and configurations have been removed."
if [[ -d "/home/EngineScript/temp/site-export/${DOMAIN}" ]]; then
  echo "Site exports made with Export Domain were kept: /home/EngineScript/temp/site-export/${DOMAIN}/"
fi
echo "----------------------------------------------------------"

sleep 5
