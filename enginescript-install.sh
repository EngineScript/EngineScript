#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "ALERT:"
    echo "EngineScript should be executed as the root user."
    exit
fi

#----------------------------------------------------------------------------
# Start Main Script

# dos2unix
# In-case you uploaded the options file using a basic Windows text editor
dos2unix /home/EngineScript/enginescript-install-options.txt

# Permissions
# In-case you changed any files and changed Permissions
find /usr/local/bin/enginescript -type d,f -exec chmod 755 {} \;
chown -R root:root /usr/local/bin/enginescript
find /usr/local/bin/enginescript -type f -iname "*.sh" -exec chmod +x {} \;

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Reboot Warning
echo -e "\nATTENTION:\n\nServer needs to reboot at the end of this script.\nEnter command es.menu after reboot to continue.\n\nScript will continue in 5 seconds..." | boxes -a c -d shell -p a1l2
sleep 5

if [ "${SERVER_MEMORY_TOTAL_80}" -lt 1000 ];
  then
    echo "WARNING: Total server memory is low."
    echo "It is recommended that a server running EngineScript has at least 2GB total memory."
    echo "EngineScript will attempt to configure memory settings that will work for a 1GB server, but performance is not guaranteed."
    echo "You may need to manually change memory limits in PHP and MariaDB."
    sleep 10
  else
    echo "Memory Test: 80% of total server memory: ${SERVER_MEMORY_TOTAL_80}"
fi

# Configuration File Check
echo -e "${BOLD}\n\n--------------------\nConfiguration Review\n--------------------${NORMAL}"
echo -e "${BOLD}\nServer Information:${NORMAL}"
echo "Variables File Date = $VARIABLES_DATE"
echo "Script Run Date = $DT"
echo "CPU Count = $CPU_COUNT"
echo "32bit or 64bit = $BIT_TYPE"
echo "Server Memory = $SERVER_MEMORY_TOTAL_100"
echo "IP Address = $IP_ADDRESS"
echo "Linux Version = $UBUNTU_TYPE $UBUNTU_VERSION $UBUNTU_CODENAME"
echo -e "${BOLD}\nEngineScript Install Options:${NORMAL}"
echo "AUTOMATIC_LOSSLESS_IMAGE_OPTIMIZATION = $AUTOMATIC_LOSSLESS_IMAGE_OPTIMIZATION"
echo "AUTOMATIC_ENGINESCRIPT_UPDATES = $AUTOMATIC_ENGINESCRIPT_UPDATES"
echo "INSTALL_ADMINER = $INSTALL_ADMINER"
echo "INSTALL_PHPMYADMIN = $INSTALL_PHPMYADMIN"
echo "INSTALL_WEBMIN = $INSTALL_WEBMIN"
echo "SHOW_ENGINESCRIPT_HEADER = $SHOW_ENGINESCRIPT_HEADER"
echo "DAILY_LOCAL_DATABASE_BACKUP = $DAILY_LOCAL_DATABASE_BACKUP"
echo "HOURLY_LOCAL_DATABASE_BACKUP = $HOURLY_LOCAL_DATABASE_BACKUP"
echo "WEEKLY_LOCAL_WPCONTENT_BACKUP = $WEEKLY_LOCAL_WPCONTENT_BACKUP"
echo "INSTALL_S3_BACKUP = $INSTALL_S3_BACKUP"
echo "DAILY_S3_DATABASE_BACKUP = $DAILY_S3_DATABASE_BACKUP"
echo "HOURLY_S3_DATABASE_BACKUP = $HOURLY_S3_DATABASE_BACKUP"
echo "WEEKLY_S3_WPCONTENT_BACKUP = $WEEKLY_S3_WPCONTENT_BACKUP"
echo "INSTALL_DROPBOX_BACKUP = $INSTALL_DROPBOX_BACKUP"
echo "DAILY_DROPBOX_DATABASE_BACKUP = $DAILY_DROPBOX_DATABASE_BACKUP"
echo "HOURLY_DROPBOX_DATABASE_BACKUP = $HOURLY_DROPBOX_DATABASE_BACKUP"
echo "WEEKLY_DROPBOX_WPCONTENT_BACKUP = $WEEKLY_DROPBOX_WPCONTENT_BACKUP"
echo -e "${BOLD}\nUser Credentials:${NORMAL}"
echo "S3_BUCKET_NAME = $S3_BUCKET_NAME"
echo "CF_GLOBAL_API_KEY = $CF_GLOBAL_API_KEY"
echo "CF_ACCOUNT_EMAIL = $CF_ACCOUNT_EMAIL"
echo "NGINX_USERNAME = $NGINX_USERNAME"
echo "NGINX_PASSWORD = $NGINX_PASSWORD"
echo "MARIADB_ADMIN_PASSWORD = $MARIADB_ADMIN_PASSWORD"
echo "PHPMYADMIN_USERNAME = $PHPMYADMIN_USERNAME"
echo "PHPMYADMIN_PASSWORD = $PHPMYADMIN_PASSWORD"
echo "WEBMIN_USERNAME = $WEBMIN_USERNAME"
echo "WEBMIN_PASSWORD = $WEBMIN_PASSWORD"
echo "WP_ADMIN_EMAIL = $WP_ADMIN_EMAIL"
echo "WP_ADMIN_USERNAME = $WP_ADMIN_USERNAME"
echo "WP_ADMIN_PASSWORD = $WP_ADMIN_PASSWORD"
echo "PUSHBULLET_TOKEN = $PUSHBULLET_TOKEN"
echo "WORDFENCE_CLI_TOKEN = $WORDFENCE_CLI_TOKEN"
echo "WPSCANAPI = $WPSCANAPI"
echo -e "\n"
sleep 5

# Check S3 Install
if [ "$INSTALL_S3_BACKUP" = 1 ] && [ "$S3_BUCKET_NAME" = PLACEHOLDER ];
	then
    echo -e "\nWARNING:\n\nYou have set INSTALL_S3_BACKUP=1 but have not properly set S3_BUCKET_NAME.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change S3_BUCKET_NAME to show your bucket name instead of PLACEHOLDER\nYou can also disabled S3 cloud backup by setting INSTALL_S3_BACKUP=0\n"
    exit
fi

# Check Cloudflare Global API Key
if [ "$CF_GLOBAL_API_KEY" = PLACEHOLDER ] && [ "$CF_ACCOUNT_EMAIL" = PLACEHOLDER ];
	then
    echo -e "\nWARNING:\n\nCF_GLOBAL_API_KEY is to PLACEHOLDER. EngineScript requires this be set prior to installation.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change CF_GLOBAL_API_KEY to the correct value.\n"
    exit
fi

# Check Cloudflare Account Email
if [ "$CF_ACCOUNT_EMAIL" = PLACEHOLDER ];
	then
    echo -e "\nWARNING:\n\nCF_ACCOUNT_EMAIL is to PLACEHOLDER. EngineScript requires this be set prior to installation.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change CF_ACCOUNT_EMAIL to the correct value.\n"
    exit
fi

# Check MariaDB Password
if [ "$MARIADB_ADMIN_PASSWORD" = PLACEHOLDER ];
	then
    echo -e "\nWARNING:\n\nMARIADB_ADMIN_PASSWORD is set to PLACEHOLDER. EngineScript requires this be set to a unique value.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change MARIADB_ADMIN_PASSWORD to something more secure.\n"
    exit
fi

# Check phpMyAdmin Username
if [ "$PHPMYADMIN_USERNAME" = PLACEHOLDER ];
	then
    echo -e "\nWARNING:\n\nPHPMYADMIN_USERNAME is set to PLACEHOLDER. EngineScript requires this be set to a unique value.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change PHPMYADMIN_USERNAME to something more secure.\n"
    exit
fi

# Check phpMyAdmin Password
if [ "$PHPMYADMIN_PASSWORD" = PLACEHOLDER ];
	then
    echo -e "\nWARNING:\nPHPMYADMIN_PASSWORD is set to PLACEHOLDER. EngineScript requires this be set to a unique value.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change PHPMYADMIN_PASSWORD to something more secure.\n"
    exit
fi

# Check WordPress Admin Email
if [ "$WP_ADMIN_EMAIL" = PLACEHOLDER@PLACEHOLDER.com ];
	then
    echo -e "\nWARNING:\n\nWP_ADMIN_EMAIL is set to PLACEHOLDER@PLACEHOLDER.com. EngineScript requires this be set to a unique value.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change WP_ADMIN_EMAIL to a real email address.\n"
    exit
fi

# Check/fix WordPress Recovery Email
if [ "$WP_RECOVERY_EMAIL" = PLACEHOLDER@PLACEHOLDER.com ];
	then
    sed -i "s|PLACEHOLDER@PLACEHOLDER\.com|${WP_ADMIN_EMAIL}|g" /home/EngineScript/enginescript-install-options.txt
fi

# Check WordPress Admin Username
if [ "$WP_ADMIN_USERNAME" = PLACEHOLDER ];
	then
    echo -e "\nWARNING:\n\nWP_ADMIN_USERNAME is set to PLACEHOLDER. EngineScript requires this be set to a unique value.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change WP_ADMIN_USERNAME to something more secure.\n"
    exit
fi

# Check WordPress Admin Password
if [ "$WP_ADMIN_PASSWORD" = PLACEHOLDER ];
	then
    echo -e "\nWARNING:\n\nWP_ADMIN_PASSWORD is set to PLACEHOLDER. EngineScript requires this be set to a unique value.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change WP_ADMIN_PASSWORD to something more secure.\n"
    exit
fi

# Install Check
source /home/EngineScript/install-log.txt

# Repositories
if [ "${REPOS}" = 1 ];
  then
    echo "REPOS script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/repositories/repositories-install.sh
    echo "REPOS=1" >> /home/EngineScript/install-log.txt
fi

# Remove Preinstalled Software
if [ "${REMOVES}" = 1 ];
  then
    echo "REMOVES script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/removes/remove-preinstalled.sh
    echo "REMOVES=1" >> /home/EngineScript/install-log.txt
fi

# Block Unwanted Packages
if [ "${BLOCK}" = 1 ];
  then
    echo "BLOCK script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/block/package-block.sh
    echo "BLOCK=1" >> /home/EngineScript/install-log.txt
fi

# Enabled Ubuntu Pro Apt Updates
if [ "${UBUNTU_PRO_TOKEN}" != PLACEHOLDER ];
  then
    pro attach ${UBUNTU_PRO_TOKEN}
fi

# Update & Upgrade
/usr/local/bin/enginescript/scripts/functions/enginescript-apt-update.sh

# Install Dependencies
if [ "${DEPENDS}" = 1 ];
  then
    echo "DEPENDS script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/depends/depends-install.sh
    echo "DEPENDS=1" >> /home/EngineScript/install-log.txt
fi

# ACME.sh
if [ "${ACME}" = 1 ];
  then
    echo "ACME.sh script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/acme/acme-install.sh
    echo "ACME=1" >> /home/EngineScript/install-log.txt
fi

# GCC
if [ "${GCC}" = 1 ];
  then
    echo "GCC script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/gcc/gcc-install.sh
    echo "GCC=1" >> /home/EngineScript/install-log.txt
fi

# OpenSSL
if [ "${OPENSSL}" = 1 ];
  then
    echo "OPENSSL script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/openssl/openssl-install.sh
    echo "OPENSSL=1" >> /home/EngineScript/install-log.txt
fi

# Jemalloc
#if [ "${JEMALLOC}" = 1 ];
#  then
#    echo "JEMALLOC script has already run."
#  else
#    /usr/local/bin/enginescript/scripts/install/jemalloc/jemalloc-install.sh
#    echo "JEMALLOC=1" >> /home/EngineScript/install-log.txt
#fi

# Swap
if [ "${SWAP}" = 1 ];
  then
    echo "SWAP script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/swap/swap-install.sh
    echo "SWAP=1" >> /home/EngineScript/install-log.txt
fi

# Kernel Tweaks
if [ "${KERNEL_TWEAKS}" = 1 ];
  then
    echo "KERNEL TWEAKS script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/kernel/kernel-tweaks-install.sh
    echo "KERNEL_TWEAKS=1" >> /home/EngineScript/install-log.txt
fi

# Kernel Samepage Merging
if [ "${KSM}" = 1 ];
  then
    echo "KSM script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/kernel/ksm.sh
    echo "KSM=1" >> /home/EngineScript/install-log.txt
fi

# Raising System File Limits
if [ "${SFL}" = 1 ];
  then
    echo "SYSTEM FILE LIMITS script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/system-misc/file-limits.sh
    echo "SFL=1" >> /home/EngineScript/install-log.txt
fi

# NTP
if [ "${NTP}" = 1 ];
  then
    echo "NTP script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/systemd/timesyncd.sh
    echo "NTP=1" >> /home/EngineScript/install-log.txt
fi

# THP
# https://stackoverflow.com/a/53470169
#if [ "${THP}" = 1 ];
  #then
    #echo "THP script has already run."
  #else
    #/usr/local/bin/enginescript/scripts/install/systemd/thp.sh
    #echo "THP=1" >> /home/EngineScript/install-log.txt
#fi

# Python
#if [ "${PYTHON}" = 1 ];
#  then
#    echo "PYTHON script has already run."
#  else
#    /usr/local/bin/enginescript/scripts/install/python/python-install.sh
#    echo "PYTHON=1" >> /home/EngineScript/install-log.txt
#fi

# PCRE
if [ "${PCRE}" = 1 ];
  then
    echo "PCRE script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/pcre/pcre-install.sh
    echo "PCRE=1" >> /home/EngineScript/install-log.txt
fi

# zlib
if [ "${ZLIB}" = 1 ];
  then
    echo "ZLIB script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/zlib/zlib-install.sh
    echo "ZLIB=1" >> /home/EngineScript/install-log.txt
fi

# liburing
if [ "${LIBURING}" = 1 ];
  then
    echo "LIBURING script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/liburing/liburing-install.sh
    echo "LIBURING=1" >> /home/EngineScript/install-log.txt
fi

# UFW
if [ "${UFW}" = 1 ];
  then
    echo "UFW script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/ufw/ufw-install.sh
    echo "UFW=1" >> /home/EngineScript/install-log.txt
fi

# Cron
if [ "${CRON}" = 1 ];
  then
    echo "CRON script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/cron/cron-install.sh
    echo "CRON=1" >> /home/EngineScript/install-log.txt
fi

# MariaDB
if [ "${MARIADB}" = 1 ];
  then
    echo "MARIADB script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/mariadb/mariadb-install.sh
fi

# PHP
if [ "${PHP}" = 1 ];
  then
    echo "PHP script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/php/php-install.sh
fi

# Redis
if [ "${REDIS}" = 1 ];
  then
    echo "REDIS script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/redis/redis-install.sh
fi

# Nginx
if [ "${NGINX}" = 1 ];
  then
    echo "NGINX script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/nginx/nginx-install.sh
fi

# Tools
if [ "${TOOLS}" = 1 ];
  then
    echo "TOOLS script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/tools/tools-install.sh
    echo "TOOLS=1" >> /home/EngineScript/install-log.txt
fi

# Cleanup
/usr/local/bin/enginescript/scripts/functions/php-clean.sh
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh

# Server Reboot
clear

# Display Install Info
/usr/local/bin/enginescript/scripts/functions/alias/alias-server-info.sh

# Reboot Notice
echo -e "${BOLD}Server needs to reboot.${NORMAL}\n\nEnter command ${BOLD}es.menu${NORMAL} after reboot to continue.\n" | boxes -a c -d shell -p a1l2
sleep 10
clear

echo -e "Server rebooting now...\n\n${NORMAL}When reconnected, use command ${BOLD}es.menu${NORMAL} to start EngineScript.\nSelect option 1 to create a new vhost configuration on your server.\n\n${BOLD}Bye! Manually reconnect in 30 seconds.\n" | boxes -a c -d shell -p a1l2
shutdown -r now
