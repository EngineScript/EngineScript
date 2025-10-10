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

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh

# Source shared vhost functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-shared-vhost.sh


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

# Domain Creation Variables
PREFIX="${RAND_CHAR2}"
sand="${DOMAIN}" && SANDOMAIN="${sand%.*}" && SDB="${SANDOMAIN}_${RAND_CHAR4}"
SUSR="${RAND_CHAR16}"
SPS="${RAND_CHAR32}"

# Domain Database Credentials
echo "DB=\"${SDB}\"" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
echo "USR=\"${SUSR}\"" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
echo "PSWD=\"${SPS}\"" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
echo "" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"

source "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"

echo "Randomly generated MySQL database credentials for ${SITE_URL}."

sudo mariadb -e "CREATE DATABASE ${DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mariadb -e "CREATE USER '${USR}'@'localhost' IDENTIFIED BY '${PSWD}';"
sudo mariadb -e "GRANT ALL ON ${DB}.* TO '${USR}'@'localhost'; FLUSH PRIVILEGES;"
sudo mariadb -e "GRANT ALL ON mysql.* TO '${USR}'@'localhost'; FLUSH PRIVILEGES;"

# Create backup directories
create_backup_directories "${SITE_URL}"

# Site Root
mkdir -p "/var/www/sites/${SITE_URL}/html"
cd "/var/www/sites/${SITE_URL}/html"

# Create domain log directories and files
create_domain_logs "${SITE_URL}"

# Download WordPress using WP-CLI
wp core download --allow-root
rm -f "/var/www/sites/${SITE_URL}/html/wp-content/plugins/hello.php"

# Create Extra WordPress Directories
# WordPress often doesn't include these directories by default, despite them being used or checked in the Health Check plugin.
create_extra_wp_dirs "${SITE_URL}"

# Create wp-config.php
cp -rf /usr/local/bin/enginescript/config/var/www/wordpress/wp-config.php "/var/www/sites/${SITE_URL}/html/wp-config.php"
sed -i "s|SEDWPDB|${DB}|g" "/var/www/sites/${SITE_URL}/html/wp-config.php"
sed -i "s|SEDWPUSER|${USR}|g" "/var/www/sites/${SITE_URL}/html/wp-config.php"
sed -i "s|SEDWPPASS|${PSWD}|g" "/var/www/sites/${SITE_URL}/html/wp-config.php"
sed -i "s|SEDPREFIX|${PREFIX}|g" "/var/www/sites/${SITE_URL}/html/wp-config.php"
sed -i "s|SEDURL|${SITE_URL}|g" "/var/www/sites/${SITE_URL}/html/wp-config.php"

# Configure Redis for WordPress
configure_redis "${SITE_URL}" "/var/www/sites/${SITE_URL}/html/wp-config.php"

# WP Salt Creation
SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
STRING='put your unique phrase here'
printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s "/var/www/sites/${SITE_URL}/html/wp-config.php"

# Configure wp-config.php settings
configure_wpconfig_settings "${SITE_URL}" "/var/www/sites/${SITE_URL}/html/wp-config.php"

# Create robots.txt file
create_robots_txt "${SITE_URL}" "/var/www/sites/${SITE_URL}/html"

# WP File Permissions
find "/var/www/sites/${SITE_URL}" -type d -print0 | sudo xargs -0 chmod 0755
find "/var/www/sites/${SITE_URL}" -type f -print0 | sudo xargs -0 chmod 0644
chown -R www-data:www-data "/var/www/sites/${SITE_URL}"
chmod +x "/var/www/sites/${SITE_URL}/html/wp-cron.php"
chmod 600 "/var/www/sites/${SITE_URL}/html/wp-config.php"

# WP-CLI Finalizing Install
clear
echo "============================================="
echo "Finalizing ${SITE_URL} Install:"
echo "============================================="

# Ask user to continue install
#while true;
  #do
    #read -p "When ready, enter y to begin finalizing ${SITE_URL}: " y
      #case $y in
        #[Yy]* )
          #echo "Let's continue";
          #sleep 1;
          #break
          #;;
        #* ) echo "Please answer y";;
      #esac
  #done

# WP-CLI Install WordPress
cd "/var/www/sites/${SITE_URL}/html"
wp core install --admin_user="${WP_ADMIN_USERNAME}" --admin_password="${WP_ADMIN_PASSWORD}" --admin_email="${WP_ADMIN_EMAIL}" --url="https://${SITE_URL}" --title='New Site' --skip-email --allow-root

clear_wordpress_caches

# Install and activate required WordPress plugins
install_required_wp_plugins

# Install extra WordPress plugins if enabled
if [[ "${INSTALL_EXTRA_WP_PLUGINS}" == "1" ]]; then
    install_extra_wp_plugins
else
    echo "Skipping extra WordPress plugins installation (disabled in config)..."
fi

# Install EngineScript custom plugins if enabled
install_enginescript_custom_plugins "${SITE_URL}"

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
cd "/var/www/sites/${SITE_URL}"
chown -R www-data:www-data "/var/www/sites/${SITE_URL}"
chmod +x "/var/www/sites/${SITE_URL}/html/wp-cron.php"
find "/var/www/sites/${SITE_URL}" -type d -print0 | sudo xargs -0 chmod 0755
find "/var/www/sites/${SITE_URL}" -type f -print0 | sudo xargs -0 chmod 0644
chmod 600 "/var/www/sites/${SITE_URL}/html/wp-config.php"

clear

# Perform site backup
perform_site_backup "${SITE_URL}" "/var/www/sites/${SITE_URL}/html"

# Display final credentials summary
display_credentials_summary "${SITE_URL}" "${DB}" "${PREFIX}" "${USR}" "${PSWD}"

# Restart Services
/usr/local/bin/enginescript/scripts/functions/alias/alias-restart.sh

echo ""
echo "============================================================="
echo ""
echo "        Domain setup completed."
echo ""
echo "        Your domain should be available now at:"
echo "        https://${SITE_URL}"
echo ""
echo "        Returning to main menu in 5 seconds."
echo ""
echo "============================================================="
echo ""
sleep 3
