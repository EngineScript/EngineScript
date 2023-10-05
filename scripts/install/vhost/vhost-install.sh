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

# Check if services are running
echo -e "\n\n${BOLD}Running Services Check:${NORMAL}\n"

# MariaDB Service Check
STATUS="$(systemctl is-active mariadb)"
if [ "${STATUS}" = "active" ]; then
    echo "PASSED: MariaDB is running."
else
    echo "FAILED: MariaDB not running. Please diagnose this issue before proceeding."
    exit 1
fi

# MySQL Service Check
STATUS="$(systemctl is-active mysql)"
if [ "${STATUS}" = "active" ]; then
    echo "PASSED: MySQL is running."
else
    echo "FAILED: MySQL not running. Please diagnose this issue before proceeding."
    exit 1
fi

# Nginx Service Check
STATUS="$(systemctl is-active nginx)"
if [ "${STATUS}" = "active" ]; then
    echo "PASSED: Nginx is running."
else
    echo "FAILED: Nginx not running. Please diagnose this issue before proceeding."
    exit 1
fi

# PHP Service Check
STATUS="$(systemctl is-active php${PHP_VER}-fpm)"
if [ "${STATUS}" = "active" ]; then
    echo "PASSED: PHP ${PHP_VER} is running."
else
    echo "FAILED: PHP ${PHP_VER} not running. Please diagnose this issue before proceeding."
    exit 1
fi

# Redis Service Check
STATUS="$(systemctl is-active redis)"
if [ "${STATUS}" = "active" ]; then
    echo "PASSED: Redis is running."
else
    echo "FAILED: Redis not running. Please diagnose this issue before proceeding."
    exit 1
fi

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
echo "For domain name, enter only the domain without https:// or trailing /"
echo "note:   lowercase text only"
echo ""
echo "Examples:    yourdomain.com"
echo "             yourdomain.net"
echo ""
read -p "Enter Domain name: " DOMAIN
echo ""
echo "You entered:  ${DOMAIN}"

# Check to see if this site is already configured
if grep -Fxq "${DOMAIN}" /home/EngineScript/sites-list/sites.sh
then
  echo -e "\n\n${BOLD}Preinstallation Check: Failed${NORMAL}\n\n${DOMAIN} is already installed.${NORMAL}\n\nIf you believe this is an error, please remove the domain by using the ${BOLD}es.menu${NORMAL} command and selecting the Server & Site Tools option\n\n"
  exit 1
else
  echo "${BOLD}Preinstallation Check: Passed${NORMAL}"
fi

# Continue the installation

# Store SQL credentials
echo "SITE_URL=\"${DOMAIN}\"" >> /home/EngineScript/mysql-credentials/${DOMAIN}.txt

# Add Domain to Site List
sed -i "\/SITES\=(/a\
\"$DOMAIN\"" /home/EngineScript/sites-list/sites.sh

# Create Nginx Vhost File
cp -rf /usr/local/bin/enginescript/etc/nginx/sites-available/yourdomain.com.conf /etc/nginx/sites-enabled/${DOMAIN}.conf
sed -i "s|yourdomain.com|${DOMAIN}|g" /etc/nginx/sites-enabled/${DOMAIN}.conf

# HTTP3
if [ "${INSTALL_HTTP3}" = 1 ];
  then
    sed -i "s|#listen 443 quic|#listen 443 quic|g" /etc/nginx/sites-enabled/${DOMAIN}.conf
fi

if [ "${INSTALL_HTTP3}" = 1 ];
  then
    sed -i "s|#listen [::]:443 quic|listen [::]:443 quic|g" /etc/nginx/sites-enabled/${DOMAIN}.conf
fi

# Create Origin Certificate
mkdir -p /etc/nginx/ssl/${DOMAIN}

# Final Cloudflare SSL Steps
clear

echo ""
echo "Go to the Cloudflare Dashboard."
echo "  1. Select your site."
echo "  2. Click on the SSL/TLS tab."
echo ""
echo "Click on the Overview section."
echo "  1. Set the SSL mode to Full (Strict)"
echo ""
echo "Still in the SSL/TLS tab, click on the Edge Certificates section."
echo "  1.  Set Always Use HTTPS to Off (Important: This can cause redirect loops)."
echo "  2.  We recommend enabling HSTS. Turning off HSTS will make your site unreachable until the Max-Age time expires. This is a setting you want to set once and leave on forever."
echo "  3.  Set Minimum TLS Version to TLS 1.3."
echo "  4.  Enable Opportunistic Encryption"
echo "  5.  Enable TLS 1.3"
echo "  6.  Enable Automatic HTTPS Rewrites"
echo ""
echo "Still in the SSL/TLS tab, click on the Origin Server section."
echo "  1.  Set Authenticated Origin Pulls to On."
echo ""
echo "Click on the Network tab."
echo "  1.  Enable HTTP/2"
echo "  2.  Enable HTTP/3 (with QUIC)"
echo "  3.  Enable 0-RTT Connection Resumption"
echo "  4.  Enable IPv6 Compatibility"
echo "  5.  Enable gRPC"
echo "  6.  Enable WebSockets"
echo "  7.  Enable Onion Routing"
echo "  8.  Set Pseudo IPv4 to Add Header"
echo "  9.  Enable IP Geolocation"
echo ""

while true;
  do
    read -p "When finished, enter ${BOLD}y${NORMAL} to continue to the next step: " y
      case $y in
        [Yy]* )
          echo "Let's continue";
          sleep 1;
          break
          ;;
        * ) echo "Please answer y";;
      esac
  done

# Cloudflare Keys
export CF_Key="${CF_GLOBAL_API_KEY}"
export CF_Email="${CF_ACCOUNT_EMAIL}"

/root/.acme.sh/acme.sh --issue --dns dns_cf --server letsencrypt --ocsp -d ${DOMAIN} -d *.${DOMAIN} -k ec-384

/root/.acme.sh/acme.sh --install-cert -d ${DOMAIN} --ecc \
--cert-file /etc/nginx/ssl/${DOMAIN}/cert.pem \
--key-file /etc/nginx/ssl/${DOMAIN}/key.pem \
--fullchain-file /etc/nginx/ssl/${DOMAIN}/fullchain.pem \
--ca-file /etc/nginx/ssl/${DOMAIN}/ca.pem

# Print verion and date for logs
echo "EngineScript Date: ${VARIABLES_DATE}"
echo "System Date: `date`"

# Domain Creation Variables
PREFIX="${RAND_CHAR2}"
sand="${DOMAIN}" && SANDOMAIN="${sand%.*}" && SDB="ES_${SANDOMAIN}_${RAND_CHAR4}"
SUSR="${RAND_CHAR16}"
SPS="${RAND_CHAR32}"

# Domain Database Credentials
echo "DB=\"${SDB}\"" >> /home/EngineScript/mysql-credentials/${DOMAIN}.txt
echo "USR=\"${SUSR}\"" >> /home/EngineScript/mysql-credentials/${DOMAIN}.txt
echo "PSWD=\"${SPS}\"" >> /home/EngineScript/mysql-credentials/${DOMAIN}.txt
echo "" >> /home/EngineScript/mysql-credentials/${DOMAIN}.txt

source /home/EngineScript/mysql-credentials/${DOMAIN}.txt

echo "Randomly generated MySQL database credentials for ${SITE_URL}."

sudo mysql -u root -p${MARIADB_ADMIN_PASSWORD} -e "CREATE DATABASE ${DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -u root -p${MARIADB_ADMIN_PASSWORD} -e "CREATE USER '${USR}'@'localhost' IDENTIFIED BY '${PSWD}';"
sudo mysql -u root -p${MARIADB_ADMIN_PASSWORD} -e "GRANT ALL ON ${DB}.* TO '${USR}'@'localhost'; FLUSH PRIVILEGES;"

# Backup Dir Creation
mkdir -p /home/EngineScript/site-backups/${SITE_URL}/database
mkdir -p /home/EngineScript/site-backups/${SITE_URL}/database/daily
mkdir -p /home/EngineScript/site-backups/${SITE_URL}/database/hourly
mkdir -p /home/EngineScript/site-backups/${SITE_URL}/nginx
mkdir -p /home/EngineScript/site-backups/${SITE_URL}/ssl-keys
mkdir -p /home/EngineScript/site-backups/${SITE_URL}/wp-config
mkdir -p /home/EngineScript/site-backups/${SITE_URL}/wp-content
mkdir -p /home/EngineScript/site-backups/${SITE_URL}/wp-uploads

# Site Root
mkdir -p /var/www/sites/${SITE_URL}/html
cd /var/www/sites/${SITE_URL}/html

# Domain Logs
mkdir -p /var/log/domains/${SITE_URL}
touch /var/log/domains/${SITE_URL}/${SITE_URL}-wp-error.log
chown -R www-data:www-data /var/log/domains/${SITE_URL}

# Download WordPress using WP-CLI
wp core download --allow-root
rm -f /var/www/sites/${SITE_URL}/html/wp-content/plugins/hello.php

# Create wp-config.php
cp -rf /usr/local/bin/enginescript/var/www/wordpress/wp-config.php /var/www/sites/${SITE_URL}/html/wp-config.php
sed -i "s|SEDWPDB|${DB}|g" /var/www/sites/${SITE_URL}/html/wp-config.php
sed -i "s|SEDWPUSER|${USR}|g" /var/www/sites/${SITE_URL}/html/wp-config.php
sed -i "s|SEDWPPASS|${PSWD}|g" /var/www/sites/${SITE_URL}/html/wp-config.php
sed -i "s|SEDPREFIX|${PREFIX}|g" /var/www/sites/${SITE_URL}/html/wp-config.php
sed -i "s|SEDURL|${SITE_URL}|g" /var/www/sites/${SITE_URL}/html/wp-config.php
REDISPREFIX="$(echo ${DOMAIN::5})" && sed -i "s|SEDREDISPREFIX|${REDISPREFIX}|g" /var/www/sites/${SITE_URL}/html/wp-config.php

# WP Salt Creation
SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
STRING='put your unique phrase here'
printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s /var/www/sites/${SITE_URL}/html/wp-config.php

# WP Scan API Token
sed -i "s|SEDWPSCANAPI|${WPSCANAPI}|g" /var/www/sites/${SITE_URL}/html/wp-config.php

# Create robots.txt
cp -rf /usr/local/bin/enginescript/var/www/wordpress/robots.txt /var/www/sites/${SITE_URL}/html/robots.txt
sed -i "s|SEDURL|${SITE_URL}|g" /var/www/sites/${SITE_URL}/html/robots.txt

# WP File Permissions
find /var/www/sites/${SITE_URL} -type d -print0 | sudo xargs -0 chmod 0755
find /var/www/sites/${SITE_URL} -type f -print0 | sudo xargs -0 chmod 0644
chown -R www-data:www-data /var/www/sites/${SITE_URL}
chmod +x /var/www/sites/${SITE_URL}/html/wp-cron.php
chmod 600 /var/www/sites/${SITE_URL}/html/wp-config.php

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
cd /var/www/sites/${SITE_URL}/html
wp core install --admin_user=${WP_ADMIN_USERNAME} --admin_password=${WP_ADMIN_PASSWORD} --admin_email=${WP_ADMIN_EMAIL} --url=https://${SITE_URL} --title='New Site' --skip-email --allow-root

# WP-CLI Install Plugins
wp plugin install autodescription --allow-root
wp plugin install mariadb-health-checks --allow-root
wp plugin install nginx-helper --allow-root
wp plugin install php-compatibility-checker --allow-root
wp plugin install redis-cache --allow-root
wp plugin install theme-check --allow-root
wp plugin install wp-cloudflare-page-cache --allow-root
wp plugin install wp-mail-smtp --allow-root

# WP-CLI Activate Plugins
wp plugin activate nginx-helper --allow-root
wp plugin activate redis-cache --allow-root
wp plugin activate wp-cloudflare-page-cache --allow-root
wp plugin activate wp-mail-smtp --allow-root

# WP-CLI Enable Plugins
wp redis enable --allow-root

# WP-CLI set permalink structure for FastCGI Cache
wp option get permalink_structure --allow-root
wp option update permalink_structure '/%category%/%postname%/' --allow-root

# Setting Permissions Again
# For whatever reason, using WP-CLI to install plugins with --allow-root reassigns
# the ownership of the /uploads, /upgrade, and plugin directories to root:root.
cd /var/www/sites/${SITE_URL}
chown -R www-data:www-data /var/www/sites/${SITE_URL}
chmod +x /var/www/sites/${SITE_URL}/html/wp-cron.php
find /var/www/sites/${SITE_URL} -type d -print0 | sudo xargs -0 chmod 0755
find /var/www/sites/${SITE_URL} -type f -print0 | sudo xargs -0 chmod 0644
chmod 600 /var/www/sites/${SITE_URL}/html/wp-config.php

clear

# Display Plugin Notes
echo ""
echo ""
echo "We've downloaded some recommended plugins for you."
echo ""
echo "${BOLD}Downloaded (Not activated or configured):${NORMAL}"
echo "  - MariaDB Health Checks"
echo "  - PHP Compatibility Checker"
echo "  - The SEO Framework"
echo "  - Theme Check"
echo ""
echo "------------------------------------------------------------------------------"
echo ""
echo "These plugins have been activated. You'll still need to configure them in WordPress."
echo ""
echo "${BOLD}Downloaded (Activated but require additional configuration):${NORMAL}"
echo "  - Nginx Helper"
echo "  - Super Page Cache for Cloudflare"
echo "  - WP Mail SMTP by WPForms"
echo "  - WP OPcache"
echo ""
echo "------------------------------------------------------------------------------"
echo ""
echo "These plugins have been activated and fully configured. No additional configuration is needed."
echo ""
echo "${BOLD}Downloaded (Activated and fully configured):${NORMAL}"
echo "  - Redis Object Cache"
echo ""

sleep 10

# Backup
echo ""
echo "Backup script will now run for all sites on this server."
echo ""

# Date
NOW=$(date +%m-%d-%Y-%H)

# Filenames
DATABASE_FILE="${NOW}-database.sql";
NGINX_FILE="${NOW}-nginx-vhost.conf.gz";
PHP_FILE="${NOW}-php.tar.gz";
SSL_FILE="${NOW}-ssl-keys.gz";
UPLOADS_FILE="${NOW}-uploads.tar.gz";
VHOST_FILE="${NOW}-nginx-vhost.conf.gz";
WPCONFIG_FILE="${NOW}-wp-config.php.gz";
WPCONTENT_FILE="${NOW}-wp-content.gz";

cd "/var/www/sites/${SITE_URL}/html"

# Backup database
wp db export "/home/EngineScript/site-backups/${SITE_URL}/database/daily/$DATABASE_FILE" --add-drop-table --allow-root

# Compress database file
gzip -f "/home/EngineScript/site-backups/${SITE_URL}/database/daily/$DATABASE_FILE"

# Backup uploads directory
#tar -zcf "/home/EngineScript/site-backups/${SITE_URL}/wp-uploads/$UPLOADS_FILE" wp-content/uploads

# Backup uploads, themes, and plugins
tar -zcf "/home/EngineScript/site-backups/${SITE_URL}/wp-content/$WPCONTENT_FILE" wp-content

# Nginx vhost backup
gzip -cf "/etc/nginx/sites-enabled/${SITE_URL}.conf" > /home/EngineScript/site-backups/${SITE_URL}/nginx/$VHOST_FILE

# SSL keys backup
tar -zcf "/home/EngineScript/site-backups/${SITE_URL}/ssl-keys/$SSL_FILE" /etc/nginx/ssl/${SITE_URL}

# wp-config.php backup
gzip -cf "/var/www/sites/${SITE_URL}/html/wp-config.php" > /home/EngineScript/site-backups/${SITE_URL}/wp-config/$WPCONFIG_FILE

# Remove old backups
find /home/EngineScript/site-backups/${SITE_URL}/database/daily -type f -mtime +7 | xargs rm -fR
find /home/EngineScript/site-backups/${SITE_URL}/nginx -type f -mtime +7 | xargs rm -fR
find /home/EngineScript/site-backups/${SITE_URL}/ssl-keys -type f -mtime +7 | xargs rm -fR
find /home/EngineScript/site-backups/${SITE_URL}/wp-config -type f -mtime +7 | xargs rm -fR
find /home/EngineScript/site-backups/${SITE_URL}/wp-content -type f -mtime +15 | xargs rm -fR
find /home/EngineScript/site-backups/${SITE_URL}/wp-uploads -type f -mtime +15  | xargs rm -fR

echo "Backup: Complete"
clear

echo ""
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo "|${BOLD}Backups${NORMAL}:                             |"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo "For your records:"
echo "-------------------------------------------------------"
echo ""
echo "${BOLD}URL:${NORMAL}               ${SITE_URL}"
echo "-----------------"
echo "${BOLD}Database:${NORMAL}          ${DB}"
echo "${BOLD}Site Prefix${NORMAL}        ${PREFIX}"
echo "${BOLD}DB User:${NORMAL}           ${USR}"
echo "${BOLD}DB Password:${NORMAL}       ${PSWD}"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""
echo "MySQL Root and Domain login credentials backed up to:"
echo "/home/EngineScript/mysql-credentials/${SITE_URL}"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""
echo "Origin Certificate and Private Key have been backed up to:"
echo "/home/EngineScript/site-backups/${SITE_URL}/ssl-keys"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""
echo "Domain Vhost .conf file backed up to:"
echo "/home/EngineScript/site-backups/${SITE_URL}/nginx"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""
echo "WordPress wp-config.php file backed up to:"
echo "/home/EngineScript/site-backups/${SITE_URL}/wp-config"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""

sleep 5

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
sleep 5
