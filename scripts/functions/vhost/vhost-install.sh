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

# Source shared vhost functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-shared-vhost.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-shared-vhost.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# Check if services are running
check_required_services

# Intro Warning
echo ""
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo "|   Domain Creation                                   |"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""
echo "WARNING: Do not run this script on a site that already exists."
echo "If you do, things will break."
echo ""
sleep 1

# Domain Input
echo "For the domain name, enter only the domain portion (e.g., 'wordpresstesting')."
echo "Note: lowercase text only, no spaces or special characters. Do not include https:// or www."
echo ""
echo "Then, select a valid TLD from the provided list."
echo ""

# Prompt for domain name
while true; do
  read -p "Enter the domain name (e.g., 'wordpresstesting'): " DOMAIN_NAME
  if [[ "$DOMAIN_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
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

    # Common multi-part public suffixes
    "co.uk" "co.jp" "com.au" "co.nz" "com.sg" "com.my" "com.br" "com.mx" "co.za" "com.tr" "com.hk"
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
sleep 2

# Verify if the domain is already configured
if grep -Fxq "${DOMAIN}" /home/EngineScript/sites-list/sites.sh; then
  echo -e "\n\n${BOLD}Preinstallation Check: Failed${NORMAL}\n\n${DOMAIN} is already installed.${NORMAL}\n\nIf you believe this is an error, please remove the domain by using the ${BOLD}es.menu${NORMAL} command and selecting the Server & Site Tools option\n\n"
  exit 1
else
  echo "${BOLD}Preinstallation Check: Passed${NORMAL}"
fi

# Logging
LOG_FILE="/var/log/EngineScript/vhost-install.log"
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "Starting domain installation for ${DOMAIN} at $(date)"

# WordPress Installation Choice
echo ""
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo "|   Installation Type                                  |"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""
echo "You can install this domain with or without WordPress."
echo ""
echo "  With WordPress:    Full LEMP stack with WordPress, database,"
echo "                     plugins, Redis caching, and backups."
echo ""
echo "  Without WordPress: Nginx vhost, SSL certificates, and a"
echo "                     placeholder page. No database or CMS."
echo ""

if prompt_yes_no "Would you like to install WordPress on this domain?" "y" 300; then
  INSTALL_WORDPRESS="1"
  echo "WordPress will be installed on ${DOMAIN}."
else
  INSTALL_WORDPRESS="0"
  echo "Skipping WordPress. A placeholder page will be installed on ${DOMAIN}."
fi
echo ""
sleep 1

# Continue the installation

# Cloudflare API Settings
# Set Cloudflare settings for the domain using the Cloudflare API
configure_cloudflare_settings "${DOMAIN}"

# Create nginx vhost configuration files
create_nginx_vhost "${DOMAIN}"

# Create and install SSL certificates
create_ssl_certificate "${DOMAIN}"

# Print date for logs
echo "System Date: $(date)"

# Create backup directories
create_backup_directories "${DOMAIN}"

# Site Root
mkdir -p "/var/www/sites/${DOMAIN}/html"
cd "/var/www/sites/${DOMAIN}/html"

# Create domain log directories and files
create_domain_logs "${DOMAIN}"

if [[ "${INSTALL_WORDPRESS}" == "1" ]]; then
  #----------------------------------------------------------------------------------
  # WordPress Installation Path
  #----------------------------------------------------------------------------------

  # Domain Creation Variables
  PREFIX="${RAND_CHAR2}"
  domain_input="${DOMAIN}" && domain_without_tld="${domain_input%.*}" && database_name="${domain_without_tld}_${RAND_CHAR4}"
  database_user="${RAND_CHAR16}"
  database_password="${RAND_CHAR32}"

  # Domain Database Credentials
  echo "DB=\"${database_name}\"" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
  echo "USR=\"${database_user}\"" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
  echo "PSWD=\"${database_password}\"" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
  echo "" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"

  source "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"

  echo "Randomly generated MySQL database credentials for ${DOMAIN}."

  if ! sudo mariadb -e "CREATE DATABASE ${DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"; then
    echo "Error: Failed to create database '${DB}' for domain '${DOMAIN}'." >&2
    exit 1
  fi

  if ! sudo mariadb -e "CREATE USER '${USR}'@'localhost' IDENTIFIED BY '${PSWD}';"; then
    echo "Error: Failed to create MariaDB user '${USR}' for domain '${DOMAIN}'." >&2
    exit 1
  fi

  if ! sudo mariadb -e "GRANT ALL ON ${DB}.* TO '${USR}'@'localhost'; FLUSH PRIVILEGES;"; then
    echo "Error: Failed to grant privileges on database '${DB}' to user '${USR}'." >&2
    exit 1
  fi

  # Download WordPress using WP-CLI
  wp core download --allow-root
  if ! wp plugin delete hello --allow-root; then
    echo "Warning: Failed to delete default 'hello' plugin via WP-CLI. Continuing if plugin is already absent."
  fi

  # Create Extra WordPress Directories
  # WordPress often doesn't include these directories by default, despite them being used or checked in the Health Check plugin.
  create_extra_wp_dirs "${DOMAIN}"

  # Create wp-config.php
  cp -rf /usr/local/bin/enginescript/config/var/www/wordpress/wp-config.php "/var/www/sites/${DOMAIN}/html/wp-config.php"
  sed -i "s|SEDWPDB|${DB}|g" "/var/www/sites/${DOMAIN}/html/wp-config.php"
  sed -i "s|SEDWPUSER|${USR}|g" "/var/www/sites/${DOMAIN}/html/wp-config.php"
  sed -i "s|SEDWPPASS|${PSWD}|g" "/var/www/sites/${DOMAIN}/html/wp-config.php"
  sed -i "s|SEDPREFIX|${PREFIX}|g" "/var/www/sites/${DOMAIN}/html/wp-config.php"
  sed -i "s|SEDURL|${DOMAIN}|g" "/var/www/sites/${DOMAIN}/html/wp-config.php"

  # Configure Redis for WordPress
  configure_redis "${DOMAIN}" "/var/www/sites/${DOMAIN}/html/wp-config.php"

  # WP Salt Creation
  fetch_wp_salts "/var/www/sites/${DOMAIN}/html/wp-config.php"

  # Configure wp-config.php settings
  configure_wpconfig_settings "${DOMAIN}" "/var/www/sites/${DOMAIN}/html/wp-config.php"

  # Create robots.txt file
  create_robots_txt "${DOMAIN}" "/var/www/sites/${DOMAIN}/html"

  # WP File Permissions
  find "/var/www/sites/${DOMAIN}" -type d -print0 | sudo xargs -0 chmod 0755
  find "/var/www/sites/${DOMAIN}" -type f -print0 | sudo xargs -0 chmod 0644
  chown -R www-data:www-data "/var/www/sites/${DOMAIN}"
  chmod +x "/var/www/sites/${DOMAIN}/html/wp-cron.php"
  chmod 600 "/var/www/sites/${DOMAIN}/html/wp-config.php"

  # WP-CLI Finalizing Install
  clear
  echo "============================================="
  echo "Finalizing ${DOMAIN} Install:"
  echo "============================================="

  # WP-CLI Install WordPress
  cd "/var/www/sites/${DOMAIN}/html"
  wp core install --admin_user="${WP_ADMIN_USERNAME}" --admin_password="${WP_ADMIN_PASSWORD}" --admin_email="${WP_ADMIN_EMAIL}" --url="https://${DOMAIN}" --title='New Site' --skip-email --allow-root

  # Install and activate required WordPress plugins
  install_required_wp_plugins

  # Install extra WordPress plugins if enabled
  if [[ "${INSTALL_EXTRA_WP_PLUGINS}" == "1" ]]; then
      install_extra_wp_plugins
  else
      echo "Skipping extra WordPress plugins installation (disabled in config)..."
  fi

  # Install EngineScript custom plugins if enabled
  install_enginescript_custom_plugins "${DOMAIN}"

  # Clear WordPress caches, transients, and rewrite rules
  clear_wordpress_caches

  # Enable Redis Cache via WP-CLI
  if wp plugin is-active redis-cache --allow-root; then
    echo "Enabling Redis object cache..."
    wp redis enable --allow-root
  else
    echo "Warning: Redis Cache plugin not active. Skipping 'wp redis enable'."
  fi

  # WP-CLI set permalink structure for FastCGI Cache
  wp option get permalink_structure --allow-root
  wp option update permalink_structure '/%category%/%postname%/' --allow-root
  flush_wordpress_rewrites

  # Setting Permissions Again
  # For whatever reason, using WP-CLI to install plugins with --allow-root reassigns
  # the ownership of the /uploads, /upgrade, and plugin directories to root:root.
  cd "/var/www/sites/${DOMAIN}"
  chown -R www-data:www-data "/var/www/sites/${DOMAIN}"
  chmod +x "/var/www/sites/${DOMAIN}/html/wp-cron.php"
  find "/var/www/sites/${DOMAIN}" -type d -print0 | sudo xargs -0 chmod 0755
  find "/var/www/sites/${DOMAIN}" -type f -print0 | sudo xargs -0 chmod 0644
  chmod 600 "/var/www/sites/${DOMAIN}/html/wp-config.php"

  clear

  # Perform site backup
  perform_site_backup "${DOMAIN}" "/var/www/sites/${DOMAIN}/html"

  # Display final credentials summary
  display_credentials_summary "${DOMAIN}" "${DB}" "${PREFIX}" "${USR}" "${PSWD}"

else
  #----------------------------------------------------------------------------------
  # Non-WordPress Installation Path (Placeholder Page)
  #----------------------------------------------------------------------------------

  echo "Installing placeholder page for ${DOMAIN}..."

  # Install placeholder page
  cp -f /usr/local/bin/enginescript/config/var/www/placeholder/index.html "/var/www/sites/${DOMAIN}/html/index.html"
  sed -i "s|YOURDOMAIN|${DOMAIN}|g" "/var/www/sites/${DOMAIN}/html/index.html"

  # Set file permissions
  find "/var/www/sites/${DOMAIN}" -type d -print0 | sudo xargs -0 chmod 0755
  find "/var/www/sites/${DOMAIN}" -type f -print0 | sudo xargs -0 chmod 0644
  chown -R www-data:www-data "/var/www/sites/${DOMAIN}"

  # Backup nginx vhost and SSL keys
  BACKUP_DATE_HOUR=$(date +%m-%d-%Y-%H)
  gzip -cf "/etc/nginx/sites-enabled/${DOMAIN}.conf" > "/home/EngineScript/site-backups/${DOMAIN}/nginx/${BACKUP_DATE_HOUR}-nginx-vhost.conf.gz"
  tar -zcf "/home/EngineScript/site-backups/${DOMAIN}/ssl-keys/${BACKUP_DATE_HOUR}-ssl-keys.gz" "/etc/nginx/ssl/${DOMAIN}"

  clear

  echo ""
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo "|${BOLD} Domain Summary (No WordPress)${NORMAL}                       |"
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo ""
  echo "${BOLD}URL:${NORMAL}               ${DOMAIN}"
  echo ""
  echo "Site root:         /var/www/sites/${DOMAIN}/html"
  echo "Nginx vhost:       /etc/nginx/sites-enabled/${DOMAIN}.conf"
  echo "SSL certificates:  /etc/nginx/ssl/${DOMAIN}/"
  echo "Backups:           /home/EngineScript/site-backups/${DOMAIN}/"
  echo ""
  echo "A placeholder page has been installed. Replace"
  echo "/var/www/sites/${DOMAIN}/html/index.html with your own content."
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo ""
  sleep 3
fi

# Restart Services
/usr/local/bin/enginescript/scripts/functions/alias/alias-restart.sh

echo ""
echo "============================================================="
echo ""
echo "        Domain setup completed."
echo ""
echo "        Your domain should be available now at:"
echo "        https://${DOMAIN}"
echo ""
echo "        Returning to main menu in 5 seconds."
echo ""
echo "============================================================="
echo ""
sleep 3
