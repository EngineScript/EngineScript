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

# Intro Warning
echo ""
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo "|   Domain Removal                                    |"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""
echo -e "WARNING: This script will remove a site from your installation.\n\n${BOLD}This removal is irreversible and everything will be destroyed, including backups.${NORMAL}\nPlease be 100% sure of your choice before continuing with this process.\n\n"
sleep 1

# Enhanced confirmation with timeout and exit option
if ! prompt_yes_no "Are you sure you want to remove a domain from your server?" "n" 300; then
    echo "Exiting domain removal script."
    exit 0
fi
echo "Continuing with domain removal..."

# Domain Input
echo "For the domain name, enter only the domain portion (e.g., 'wordpresstesting')."
echo "Note: lowercase text only, no spaces or special characters. Do not include https:// or www."
echo ""
echo "Then, select a valid TLD from the provided list."
echo ""

# Prompt for domain name
while true; do
  read -p "Enter the domain name (e.g., 'wordpresstesting'): " DOMAIN_NAME
  if [[ "$DOMAIN_NAME" =~ ^[a-z0-9-]+$ ]]; then
    echo "You entered: ${DOMAIN_NAME}"
    break
  else
    echo "Invalid domain name. Only lowercase letters, numbers, and hyphens are allowed."
  fi
done

# Prompt for TLD
echo ""
echo "Select a valid TLD from the list below:"
VALID_TLDS=(
    # Common gTLDs
    "com" "net" "org" "info" "biz" "name" "pro" "int"

    # Popular gTLDs
    "io" "dev" "app" "tech" "ai" "cloud" "store" "online" "site" "xyz" "club"
    "design" "media" "agency" "solutions" "services" "digital" "studio" "live"
    "blog" "news" "shop" "art" "finance" "health" "law" "marketing" "software"

    # Country-code TLDs (ccTLDs)
    "us" "uk" "ca" "au" "de" "fr" "es" "it" "nl" "se" "no" "fi" "dk" "jp" "cn"
    "in" "br" "ru" "za" "mx" "ar" "ch" "at" "be" "pl" "gr" "pt" "tr" "kr" "hk"
    "sg" "id" "my" "th" "ph" "vn" "nz" "ie" "il" "sa" "ae" "eg" "ng" "ke" "gh"
    "co.uk"
)
select TLD in "${VALID_TLDS[@]}"; do
  if [[ -n "$TLD" ]]; then
    echo "You selected: ${TLD}"
    break
  else
    echo "Invalid selection. Please choose a valid TLD from the list."
  fi
done

# Combine domain name and TLD
DOMAIN="${DOMAIN_NAME}.${TLD}"
echo ""
echo "Full domain: ${DOMAIN}"

# Logging
LOG_FILE="/var/log/EngineScript/vhost-remove.log"
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "Starting domain removal for ${DOMAIN} at $(date)"

# Remove domain from site list
# Check for the domain enclosed in quotes, matching the format in sites.sh
if grep -Fxq "\"${DOMAIN}\"" /home/EngineScript/sites-list/sites.sh
then
  echo -e "${BOLD}Site List Removal Check: Passed\n\n${NORMAL}Removing ${DOMAIN} from site list...\n\n"
  # Use grep -v to remove the line containing the quoted domain
  grep -v "\"${DOMAIN}\"" /home/EngineScript/sites-list/sites.sh > /home/EngineScript/sites-list/sites.sh.old && mv /home/EngineScript/sites-list/sites.sh.old /home/EngineScript/sites-list/sites.sh
else
  echo -e "${BOLD}Site List Removal Check: Failed\n\n${NORMAL}${DOMAIN} was not found on the site list.\n\n"
fi

# Remove MySQL credentials
if test -f "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
then
  echo -e "${BOLD}MySQL Credentials Removal Check: Passed\n\n${NORMAL}Removing MySQL credentials for ${DOMAIN}...\n\n"
  source "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
  sudo mariadb -e "DROP DATABASE ${DB};"
  sudo mariadb -e "DROP USER '${USR}'@'localhost';"
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

# The site's Redis database number is free again: new sites take the lowest number no other
# site's wp-config.php uses, so nothing changes in redis.conf.

# Reload Nginx (the site's vhost is gone) and PHP-FPM (drops the site's code from OPcache).
# Redis keeps running: Redis Object Cache shows an error page on every site while Redis is
# unreachable, and the site's keys are already deleted.
echo "Reloading Nginx and PHP-FPM..."
if nginx -t > /dev/null 2>&1; then
  systemctl reload nginx
else
  echo "Error: nginx -t failed after removing ${DOMAIN}; Nginx was not reloaded. Check with: nginx -t" >&2
fi
if systemctl is-active --quiet "php${PHP_VER}-fpm"; then
  systemctl reload "php${PHP_VER}-fpm"
fi
echo ""

# Summary
echo "----------------------------------------------------------"
echo "Domain removal completed for ${DOMAIN}."
echo "Please verify that all associated files, directories, and configurations have been removed."
echo "----------------------------------------------------------"

sleep 5
