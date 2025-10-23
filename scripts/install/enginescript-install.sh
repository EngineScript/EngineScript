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
if [[ "${EUID}" -ne 0 ]];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit 1
fi

#----------------------------------------------------------------------------
# Start Main Script

# dos2unix
# In-case you uploaded the options file using a basic Windows text editor
dos2unix /home/EngineScript/enginescript-install-options.txt

# Convert line endings
dos2unix /usr/local/bin/enginescript/*

# Set directory and file permissions to 755
find /usr/local/bin/enginescript -type d,f -exec chmod 755 {} \;

# Set ownership
chown -R root:root /usr/local/bin/enginescript

# Make shell scripts executable
find /usr/local/bin/enginescript -type f -iname "*.sh" -exec chmod +x {} \;

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh

# Reboot Warning
echo -e "\nATTENTION:\n\nServer needs to reboot at the end of this script.\nEnter command es.menu after reboot to continue.\n\nScript will continue in 5 seconds..." | boxes -a c -d shell -p a1l2
sleep 5

if [[ "${SERVER_MEMORY_TOTAL_80}" -lt 1000 ]];
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
echo "Script Run Date = $DT"
echo "CPU Count = $CPU_COUNT"
echo "32bit or 64bit = $BIT_TYPE"
echo "Server Memory = $SERVER_MEMORY_TOTAL_100"
echo "IP Address = $IP_ADDRESS"
echo "Linux Version = $UBUNTU_TYPE $UBUNTU_VERSION $UBUNTU_CODENAME"
echo -e "${BOLD}\nEngineScript Install Options:${NORMAL}"
echo "AUTOMATIC_LOSSLESS_IMAGE_OPTIMIZATION = $AUTOMATIC_LOSSLESS_IMAGE_OPTIMIZATION"
echo "ENGINESCRIPT_AUTO_UPDATE = $ENGINESCRIPT_AUTO_UPDATE"
echo "ADMIN_SUBDOMAIN = $ADMIN_SUBDOMAIN"
echo "INSTALL_ADMINER = $INSTALL_ADMINER"
echo "INSTALL_PHPMYADMIN = $INSTALL_PHPMYADMIN"
echo "SHOW_ENGINESCRIPT_HEADER = $SHOW_ENGINESCRIPT_HEADER"
echo "DAILY_LOCAL_DATABASE_BACKUP = $DAILY_LOCAL_DATABASE_BACKUP"
echo "HOURLY_LOCAL_DATABASE_BACKUP = $HOURLY_LOCAL_DATABASE_BACKUP"
echo "WEEKLY_LOCAL_WPCONTENT_BACKUP = $WEEKLY_LOCAL_WPCONTENT_BACKUP"
echo "INSTALL_S3_BACKUP = $INSTALL_S3_BACKUP"
echo "DAILY_S3_DATABASE_BACKUP = $DAILY_S3_DATABASE_BACKUP"
echo "HOURLY_S3_DATABASE_BACKUP = $HOURLY_S3_DATABASE_BACKUP"
echo "WEEKLY_S3_WPCONTENT_BACKUP = $WEEKLY_S3_WPCONTENT_BACKUP"
echo -e "${BOLD}\nUser Credentials:${NORMAL}"
echo "S3_BUCKET_NAME = $S3_BUCKET_NAME"
echo "CF_GLOBAL_API_KEY = $CF_GLOBAL_API_KEY"
echo "CF_ACCOUNT_EMAIL = $CF_ACCOUNT_EMAIL"
echo "ADMIN_CONTROL_PANEL_USERNAME = $ADMIN_CONTROL_PANEL_USERNAME"
echo "ADMIN_CONTROL_PANEL_PASSWORD = $ADMIN_CONTROL_PANEL_PASSWORD"
echo "MARIADB_ADMIN_PASSWORD = $MARIADB_ADMIN_PASSWORD"
echo "PHPMYADMIN_USERNAME = $PHPMYADMIN_USERNAME"
echo "PHPMYADMIN_PASSWORD = $PHPMYADMIN_PASSWORD"
echo "FILEMANAGER_USERNAME = $FILEMANAGER_USERNAME"
echo "FILEMANAGER_PASSWORD = $FILEMANAGER_PASSWORD"
echo "UPTIMEROBOT_API_KEY = $UPTIMEROBOT_API_KEY"
echo "WP_ADMIN_EMAIL = $WP_ADMIN_EMAIL"
echo "WP_ADMIN_USERNAME = $WP_ADMIN_USERNAME"
echo "WP_ADMIN_PASSWORD = $WP_ADMIN_PASSWORD"
echo "PUSHBULLET_TOKEN = $PUSHBULLET_TOKEN"
echo "WORDFENCE_CLI_TOKEN = $WORDFENCE_CLI_TOKEN"
echo "WPSCANAPI = $WPSCANAPI"
echo -e "\n"
sleep 5

# Warn if EngineScript automatic updates are disabled
if [[ "${ENGINESCRIPT_AUTO_UPDATE}" = "0" ]]; then
  echo -e "\n${BOLD}WARNING: EngineScript Automatic Updates are DISABLED.${NORMAL}\n"
  echo -e "You will need to manually apply updates to the EngineScript application and configuration files if updates are released in the future."
  while true; do
    read -p "Would you like to enable automatic updates now? (y/n/exit): " yn_auto_update
    case $yn_auto_update in
      [Yy]* )
        sed -i 's/^ENGINESCRIPT_AUTO_UPDATE=0/ENGINESCRIPT_AUTO_UPDATE=1/' /home/EngineScript/enginescript-install-options.txt
        ENGINESCRIPT_AUTO_UPDATE=1
        if grep -q '^ENGINESCRIPT_AUTO_EMERGENCY_UPDATES=0' /home/EngineScript/enginescript-install-options.txt; then
          sed -i 's/^ENGINESCRIPT_AUTO_EMERGENCY_UPDATES=0/ENGINESCRIPT_AUTO_EMERGENCY_UPDATES=1/' /home/EngineScript/enginescript-install-options.txt
          ENGINESCRIPT_AUTO_EMERGENCY_UPDATES=1
          echo -e "\nEmergency auto updates have also been enabled.\n"
        fi
        echo -e "\nAutomatic updates have been enabled.\n"
        sleep 2
        break
        ;;
      [Nn]* )
        echo -e "\nAutomatic updates remain disabled.\n"
        sleep 2
        break
        ;;
      [Ee][Xx][Ii][Tt]* )
        echo -e "\nExiting install script as requested.\n"
        exit 1
        ;;
      * ) echo "Please answer yes, no, or exit.";;
    esac
  done
fi

# Check S3 Install
if [[ "$INSTALL_S3_BACKUP" = 1 ]] && [[ "$S3_BUCKET_NAME" = PLACEHOLDER ]];
	then
    echo -e "\nWARNING:\n\nYou have set INSTALL_S3_BACKUP=1 but have not properly set S3_BUCKET_NAME.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change S3_BUCKET_NAME to show your bucket name instead of PLACEHOLDER\nYou can also disabled S3 cloud backup by setting INSTALL_S3_BACKUP=0\n"
    exit
fi

# Check Cloudflare Global API Key
if [[ "$CF_GLOBAL_API_KEY" = PLACEHOLDER ]] && [[ "$CF_ACCOUNT_EMAIL" = PLACEHOLDER ]];
	then
    echo -e "\nWARNING:\n\nCF_GLOBAL_API_KEY is to PLACEHOLDER. EngineScript requires this be set prior to installation.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change CF_GLOBAL_API_KEY to the correct value.\n"
    exit
fi

# Check Cloudflare Account Email
if [[ "$CF_ACCOUNT_EMAIL" = PLACEHOLDER ]];
	then
    echo -e "\nWARNING:\n\nCF_ACCOUNT_EMAIL is to PLACEHOLDER. EngineScript requires this be set prior to installation.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change CF_ACCOUNT_EMAIL to the correct value.\n"
    exit
fi

# Check MariaDB Password
if [[ "$MARIADB_ADMIN_PASSWORD" = PLACEHOLDER ]];
	then
    echo -e "\nWARNING:\n\nMARIADB_ADMIN_PASSWORD is set to PLACEHOLDER. EngineScript requires this be set to a unique value.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change MARIADB_ADMIN_PASSWORD to something more secure.\n"
    exit
fi

# Check phpMyAdmin Username
if [[ "$PHPMYADMIN_USERNAME" = PLACEHOLDER ]];
	then
    echo -e "\nWARNING:\n\nPHPMYADMIN_USERNAME is set to PLACEHOLDER. EngineScript requires this be set to a unique value.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change PHPMYADMIN_USERNAME to something more secure.\n"
    exit
fi

# Check phpMyAdmin Password
if [[ "$PHPMYADMIN_PASSWORD" = PLACEHOLDER ]];
	then
    echo -e "\nWARNING:\nPHPMYADMIN_PASSWORD is set to PLACEHOLDER. EngineScript requires this be set to a unique value.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change PHPMYADMIN_PASSWORD to something more secure.\n"
    exit
fi

# Check File Manager Username
if [[ "$FILEMANAGER_USERNAME" = PLACEHOLDER ]];
	then
    echo -e "\nWARNING:\n\nFILEMANAGER_USERNAME is set to PLACEHOLDER. EngineScript requires this be set to a unique value.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change FILEMANAGER_USERNAME to something more secure.\n"
    exit
fi

# Check File Manager Password
if [[ "$FILEMANAGER_PASSWORD" = PLACEHOLDER ]];
	then
    echo -e "\nWARNING:\n\nFILEMANAGER_PASSWORD is set to PLACEHOLDER. EngineScript requires this be set to a unique value.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change FILEMANAGER_PASSWORD to something more secure.\n"
    exit
fi

# Check WordPress Admin Email
if [[ "$WP_ADMIN_EMAIL" = PLACEHOLDER ]];
	then
    echo -e "\nWARNING:\n\nWP_ADMIN_EMAIL is set to PLACEHOLDER. EngineScript requires this be set to a unique value.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change WP_ADMIN_EMAIL to a real email address.\n"
    exit
fi

# Check/fix WordPress Recovery Email
if [[ "$WP_RECOVERY_EMAIL" = PLACEHOLDER ]];
	then
    sed -i "s|PLACEHOLDER@PLACEHOLDER\.com|${WP_ADMIN_EMAIL}|g" /home/EngineScript/enginescript-install-options.txt
fi

# Check WordPress Admin Username
if [[ "$WP_ADMIN_USERNAME" = PLACEHOLDER ]];
	then
    echo -e "\nWARNING:\n\nWP_ADMIN_USERNAME is set to PLACEHOLDER. EngineScript requires this be set to a unique value.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change WP_ADMIN_USERNAME to something more secure.\n"
    exit
fi

# Check WordPress Admin Password
if [[ "$WP_ADMIN_PASSWORD" = PLACEHOLDER ]];
	then
    echo -e "\nWARNING:\n\nWP_ADMIN_PASSWORD is set to PLACEHOLDER. EngineScript requires this be set to a unique value.\nPlease return to the config file with command ${BOLD}es.config${NORMAL} and change WP_ADMIN_PASSWORD to something more secure.\n"
    exit
fi

# Install Check
source /var/log/EngineScript/install-log.log

# Repositories
if [[ "${REPOS}" = 1 ]];
  then
    echo "REPOS script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/repositories/repositories-install.sh 2>> /tmp/enginescript_install_errors.log
    echo "REPOS=1" >> /var/log/EngineScript/install-log.log
fi
print_last_errors
debug_pause "Install Repositories"

# Remove Preinstalled Software
if [[ "${REMOVES}" = 1 ]];
  then
    echo "REMOVES script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/removes/remove-preinstalled.sh 2>> /tmp/enginescript_install_errors.log
    echo "REMOVES=1" >> /var/log/EngineScript/install-log.log
fi
print_last_errors
debug_pause "Remove Preinstalled Software"

# Block Unwanted Packages
if [[ "${BLOCK}" = 1 ]];
  then
    echo "BLOCK script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/block/package-block.sh 2>> /tmp/enginescript_install_errors.log
    echo "BLOCK=1" >> /var/log/EngineScript/install-log.log
fi
print_last_errors
debug_pause "Block Unwanted Packages"

# Ubuntu Pro Setup
if [[ "${UBUNTU_PRO}" = 1 ]];
  then
    echo "UBUNTU_PRO script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/ubuntu-pro/ubuntu-pro-install.sh 2>> /tmp/enginescript_install_errors.log
    echo "UBUNTU_PRO=1" >> /var/log/EngineScript/install-log.log
fi
print_last_errors
debug_pause "Ubuntu Pro Setup"

# Update & Upgrade
/usr/local/bin/enginescript/scripts/functions/enginescript-apt-update.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Update & Upgrade"

# Install Dependencies
if [[ "${DEPENDS}" = 1 ]];
  then
    echo "DEPENDS script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/depends/depends-install.sh 2>> /tmp/enginescript_install_errors.log
fi
print_last_errors
debug_pause "Install Dependencies"

# Cron
if [[ "${CRON}" = 1 ]];
  then
    echo "CRON script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/cron/cron-install.sh 2>> /tmp/enginescript_install_errors.log
    echo "CRON=1" >> /var/log/EngineScript/install-log.log
fi
print_last_errors
debug_pause "Cron"

# ACME.sh
if [[ "${ACME}" = 1 ]];
  then
    echo "ACME.sh script has already run"
  else
    /usr/local/bin/enginescript/scripts/install/acme/acme-install.sh 2>> /tmp/enginescript_install_errors.log
    echo "ACME=1" >> /var/log/EngineScript/install-log.log
fi
print_last_errors
debug_pause "ACME.sh"

# GCC
if [[ "${GCC}" = 1 ]];
  then
    echo "GCC script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/gcc/gcc-install.sh 2>> /tmp/enginescript_install_errors.log
    echo "GCC=1" >> /var/log/EngineScript/install-log.log
fi
print_last_errors
debug_pause "GCC"

# OpenSSL
if [[ "${OPENSSL}" = 1 ]];
  then
    echo "OPENSSL script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/openssl/openssl-install.sh 2>> /tmp/enginescript_install_errors.log
    echo "OPENSSL=1" >> /var/log/EngineScript/install-log.log
fi
print_last_errors
debug_pause "OpenSSL"

# Swap
if [[ "${SWAP}" = 1 ]];
  then
    echo "SWAP script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/swap/swap-install.sh 2>> /tmp/enginescript_install_errors.log
    echo "SWAP=1" >> /var/log/EngineScript/install-log.log
fi
print_last_errors
debug_pause "Swap"

# Kernel Tweaks
if [[ "${KERNEL_TWEAKS}" = 1 ]];
  then
    echo "KERNEL TWEAKS script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/kernel/kernel-tweaks-install.sh 2>> /tmp/enginescript_install_errors.log
    echo "KERNEL_TWEAKS=1" >> /var/log/EngineScript/install-log.log
fi
print_last_errors
debug_pause "Kernel Tweaks"

# Kernel Samepage Merging
if [[ "${KSM}" = 1 ]];
  then
    echo "KSM script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/kernel/ksm.sh 2>> /tmp/enginescript_install_errors.log
    echo "KSM=1" >> /var/log/EngineScript/install-log.log
fi
print_last_errors
debug_pause "Kernel Samepage Merging"

# Raising System File Limits
if [[ "${SFL}" = 1 ]];
  then
    echo "SYSTEM FILE LIMITS script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/system-misc/file-limits.sh 2>> /tmp/enginescript_install_errors.log
    echo "SFL=1" >> /var/log/EngineScript/install-log.log
fi
print_last_errors
debug_pause "Raising System File Limits"

# NTP
if [[ "${NTP}" = 1 ]];
  then
    echo "NTP script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/systemd/timesyncd.sh 2>> /tmp/enginescript_install_errors.log
    echo "NTP=1" >> /var/log/EngineScript/install-log.log
fi
print_last_errors
debug_pause "NTP"

# DigitalOcean Remote Console (optional)
if [[ "${INSTALL_DIGITALOCEAN_REMOTE_CONSOLE}" = "1" ]]; then
  if [[ "${DO_CONSOLE}" = 1 ]];
    then
      echo "DigitalOcean Remote Console script has already run."
    else
      /usr/local/bin/enginescript/scripts/install/system-misc/digitalocean-software-install.sh 2>> /tmp/enginescript_install_errors.log
      echo "DO_CONSOLE=1" >> /var/log/EngineScript/install-log.log
  fi
  print_last_errors
  debug_pause "DigitalOcean Remote Console"
fi

# PCRE
if [[ "${PCRE}" = 1 ]];
  then
    echo "PCRE script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/pcre/pcre-install.sh 2>> /tmp/enginescript_install_errors.log
    echo "PCRE=1" >> /var/log/EngineScript/install-log.log
fi
print_last_errors
debug_pause "PCRE"

# zlib
if [[ "${ZLIB}" = 1 ]];
  then
    echo "ZLIB script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/zlib/zlib-install.sh 2>> /tmp/enginescript_install_errors.log
    echo "ZLIB=1" >> /var/log/EngineScript/install-log.log
fi
print_last_errors
debug_pause "zlib"

# liburing
if [[ "${LIBURING}" = 1 ]];
  then
    echo "LIBURING script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/liburing/liburing-install.sh 2>> /tmp/enginescript_install_errors.log
    echo "LIBURING=1" >> /var/log/EngineScript/install-log.log
fi
print_last_errors
debug_pause "liburing"

# UFW
if [[ "${UFW}" = 1 ]];
  then
    echo "UFW script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/ufw/ufw-install.sh 2>> /tmp/enginescript_install_errors.log
    echo "UFW=1" >> /var/log/EngineScript/install-log.log
fi
print_last_errors
debug_pause "UFW"

# MariaDB
if [[ "${MARIADB}" = 1 ]];
  then
    echo "MARIADB script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/mariadb/mariadb-install.sh 2>> /tmp/enginescript_install_errors.log
fi
print_last_errors
debug_pause "MariaDB"

# PHP
if [[ "${PHP}" = 1 ]];
  then
    echo "PHP script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/php/php-install.sh 2>> /tmp/enginescript_install_errors.log
fi
print_last_errors
debug_pause "PHP"

# Redis
if [[ "${REDIS}" = 1 ]];
  then
    echo "REDIS script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/redis/redis-install.sh 2>> /tmp/enginescript_install_errors.log
fi
print_last_errors
debug_pause "Redis"

# Nginx
if [[ "${NGINX}" = 1 ]];
  then
    echo "NGINX script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/nginx/nginx-install.sh 2>> /tmp/enginescript_install_errors.log
fi
print_last_errors
debug_pause "Nginx"

# Tools
if [[ "${TOOLS}" = 1 ]];
  then
    echo "TOOLS script has already run."
  else
    /usr/local/bin/enginescript/scripts/install/tools/tools-install.sh 2>> /tmp/enginescript_install_errors.log
    echo "TOOLS=1" >> /var/log/EngineScript/install-log.log
fi
print_last_errors
debug_pause "Tools"

# --------------------------------------------------------
# Final Installation Completion Verification
echo ""
echo "============================================================="
echo "Final Installation Verification"
echo "============================================================="
echo ""

# Verify all components completed successfully
if check_installation_completion "true"; then
    echo "🎉 SUCCESS: EngineScript installation completed successfully!"
    echo "🎉 All 24 core components have been installed and verified."
    echo ""
    echo "Installation Summary:"
    echo "✅ System repositories and dependencies"
    echo "✅ Security and firewall configuration"  
    echo "✅ Core services (MariaDB, PHP, Redis, Nginx)"
    echo "✅ SSL/TLS and build environment"
    echo "✅ System optimization and tools"
    echo ""
else
    echo "⚠️  WARNING: Installation verification detected some incomplete components."
    echo "⚠️  This may indicate errors during installation that need attention."
    echo ""
    echo "RECOMMENDATION:"
    echo "1. Review /var/log/EngineScript/install-error-log.log for any errors"
    echo "2. Use 'es.debug' command after reboot to generate a diagnostic report"
    echo "3. Consider re-running the installation script to complete missing components"
    echo ""
fi

echo "============================================================="
echo ""

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
