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

# EngineScript settings and shared functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh" >&2; exit 1; }

# Reboot Warning
echo -e "\nATTENTION:\n\nThe server needs to reboot at the end of this script.\nEnter the es.menu command after rebooting to continue.\n\nThe script will continue in 5 seconds..." | boxes -a c -d shell -p a1l2
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

# Detect server location and hosting provider
detect_server_location

# Auto-detect DigitalOcean and enable features if applicable
auto_detect_digitalocean

echo -e "${BOLD}\nEngineScript Install Options:${NORMAL}"
print_install_settings
echo -e "${BOLD}\nUser Credentials:${NORMAL}"
print_install_credentials
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
if [[ "${BACKUP_S3}" = 1 ]]; then
    validate_not_placeholder "S3_BUCKET_NAME" "$S3_BUCKET_NAME" "You have set BACKUP_S3=1 but have not properly set S3_BUCKET_NAME.\nPlease return to the config file with the ${BOLD}es.config${NORMAL} command and change S3_BUCKET_NAME to show your bucket name instead of PLACEHOLDER.\nYou can also disable S3 cloud backup by setting BACKUP_S3=0."
fi

# Check Cloudflare Credentials
validate_not_placeholder "CF_GLOBAL_API_KEY" "$CF_GLOBAL_API_KEY" "CF_GLOBAL_API_KEY is set to PLACEHOLDER. EngineScript requires this to be set before installation.\nPlease return to the config file with the ${BOLD}es.config${NORMAL} command and change CF_GLOBAL_API_KEY to the correct value."
validate_not_placeholder "CF_ACCOUNT_EMAIL" "$CF_ACCOUNT_EMAIL" "CF_ACCOUNT_EMAIL is set to PLACEHOLDER. EngineScript requires this to be set before installation.\nPlease return to the config file with the ${BOLD}es.config${NORMAL} command and change CF_ACCOUNT_EMAIL to the correct value."

# Check Credentials
validate_not_placeholder "MARIADB_ADMIN_PASSWORD" "$MARIADB_ADMIN_PASSWORD"
validate_not_placeholder "PHPMYADMIN_USERNAME" "$PHPMYADMIN_USERNAME"
validate_not_placeholder "PHPMYADMIN_PASSWORD" "$PHPMYADMIN_PASSWORD"
validate_not_placeholder "FILEMANAGER_USERNAME" "$FILEMANAGER_USERNAME"
validate_not_placeholder "FILEMANAGER_PASSWORD" "$FILEMANAGER_PASSWORD"
validate_not_placeholder "WP_ADMIN_EMAIL" "$WP_ADMIN_EMAIL" "WP_ADMIN_EMAIL is set to PLACEHOLDER. EngineScript requires this to be set to a unique value.\nPlease return to the config file with the ${BOLD}es.config${NORMAL} command and change WP_ADMIN_EMAIL to a real email address."

# Check/fix WordPress Recovery Email
if [[ "$WP_RECOVERY_EMAIL" = PLACEHOLDER ]]; then
    sed -i "s|PLACEHOLDER@PLACEHOLDER\.com|${WP_ADMIN_EMAIL}|g" /home/EngineScript/enginescript-install-options.txt
fi

validate_not_placeholder "WP_ADMIN_USERNAME" "$WP_ADMIN_USERNAME"
validate_not_placeholder "WP_ADMIN_PASSWORD" "$WP_ADMIN_PASSWORD"

# Install Check: the install steps' flags, read as data (initialize_install_state_file loads them)
initialize_install_state_file

# A new server is built to the current setup, so the one-time upgrades for servers installed by
# earlier versions are recorded as done here, before the first step, and never run. Only a new
# install records them: es.install run again, to carry on an install or on a finished server,
# must not mark an upgrade that has not run yet.
if ! install_has_started; then
    /usr/local/bin/enginescript/scripts/functions/auto-upgrade/normal-auto-upgrade.sh --record-all
fi

# Repositories
run_install_step "REPOS" "/usr/local/bin/enginescript/scripts/install/repositories/repositories-install.sh" "Install Repositories"

# Remove Preinstalled Software
run_install_step "REMOVES" "/usr/local/bin/enginescript/scripts/install/removes/remove-preinstalled.sh" "Remove Preinstalled Software"

# Block Unwanted Packages
run_install_step "BLOCK" "/usr/local/bin/enginescript/scripts/install/block/package-block.sh" "Block Unwanted Packages"

# Ubuntu Pro Setup
run_install_step "UBUNTU_PRO" "/usr/local/bin/enginescript/scripts/install/ubuntu-pro/ubuntu-pro-install.sh" "Ubuntu Pro Setup"

# Update & Upgrade
run_step "Update & Upgrade" /usr/local/bin/enginescript/scripts/functions/enginescript-apt-update.sh

# Install Dependencies
run_install_step "DEPENDS" "/usr/local/bin/enginescript/scripts/install/depends/depends-install.sh" "Install Dependencies"

# Cron
run_install_step "CRON" "/usr/local/bin/enginescript/scripts/install/cron/cron-install.sh" "Cron"

# ACME.sh
run_install_step "ACME" "/usr/local/bin/enginescript/scripts/install/acme/acme-install.sh" "ACME.sh"

# GCC
run_install_step "GCC" "/usr/local/bin/enginescript/scripts/install/gcc/gcc-install.sh" "GCC"

# Swap
run_install_step "SWAP" "/usr/local/bin/enginescript/scripts/install/swap/swap-install.sh" "Swap"

# Kernel Tweaks
run_install_step "KERNEL_TWEAKS" "/usr/local/bin/enginescript/scripts/install/kernel/kernel-tweaks-install.sh" "Kernel Tweaks"

# Transparent Huge Pages
run_install_step "THP" "/usr/local/bin/enginescript/scripts/install/systemd/thp.sh" "Transparent Huge Pages"

# Raising System File Limits
run_install_step "SFL" "/usr/local/bin/enginescript/scripts/install/system-misc/file-limits.sh" "Raising System File Limits"

# NTP
run_install_step "NTP" "/usr/local/bin/enginescript/scripts/install/systemd/timesyncd.sh" "NTP"

# DigitalOcean Remote Console (optional)
if [[ "${INSTALL_DIGITALOCEAN_REMOTE_CONSOLE}" = "1" ]]; then
  run_install_step "DO_CONSOLE" "/usr/local/bin/enginescript/scripts/install/system-misc/digitalocean-software-install.sh" "DigitalOcean Remote Console"
fi

# liburing
run_install_step "LIBURING" "/usr/local/bin/enginescript/scripts/install/liburing/liburing-install.sh" "liburing"

# UFW
run_install_step "UFW" "/usr/local/bin/enginescript/scripts/install/ufw/ufw-install.sh" "UFW"

# MariaDB
run_install_step "MARIADB" "/usr/local/bin/enginescript/scripts/install/mariadb/mariadb-install.sh" "MariaDB"

# PHP
run_install_step "PHP" "/usr/local/bin/enginescript/scripts/install/php/php-install.sh" "PHP"

# Redis
run_install_step "REDIS" "/usr/local/bin/enginescript/scripts/install/redis/redis-install.sh" "Redis"

# Nginx (the build fetches the OpenSSL, PCRE2, and zlib sources it compiles in)
run_install_step "NGINX" "/usr/local/bin/enginescript/scripts/install/nginx/nginx-install.sh" "Nginx"

# phpMyAdmin (optional)
if [[ "${INSTALL_PHPMYADMIN}" = "1" ]]; then
  run_install_step "PHPMYADMIN" "/usr/local/bin/enginescript/scripts/install/phpmyadmin/phpmyadmin-install.sh" "phpMyAdmin"
else
  echo "Skipping phpMyAdmin install"
fi

# Admin Control Panel
run_install_step "ADMIN_CONTROL_PANEL" "/usr/local/bin/enginescript/scripts/install/admin-control-panel/admin-control-panel-install.sh" "Admin Control Panel"

# WP-CLI
run_install_step "WP_CLI" "/usr/local/bin/enginescript/scripts/install/wp-cli/wp-cli-install.sh" "WP-CLI"

# Tools
run_install_step "TOOLS" "/usr/local/bin/enginescript/scripts/install/tools/tools-install.sh" "Tools"

# Cleanup
run_enginescript_cleanup

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
    echo "🎉 All required core components have been installed and verified."
    echo ""
    echo "Installation Summary:"
    echo "✅ System repositories and dependencies"
    echo "✅ Security and firewall configuration"  
    echo "✅ Core services (MariaDB, PHP, Redis, Nginx)"
    echo "✅ Admin control panel and admin tools"
    echo "✅ WordPress command line tooling"
    echo "✅ SSL/TLS and build environment"
    echo "✅ System optimization and tools"
    echo ""
else
    # No reboot: it would clear the list of missing steps above, and the install is not done
    echo "⚠️  WARNING: Installation verification detected some incomplete components."
    echo "⚠️  This may indicate errors during installation that need attention."
    echo ""
    echo "RECOMMENDATION:"
    echo "1. Review /var/log/EngineScript/install-error-log.log for any errors"
    echo "2. Use the 'es.debug' command to generate a diagnostic report"
    echo "3. Run 'es.install' again to complete the missing components"
    echo ""
    echo "The server was not rebooted; it reboots when an install completes."
    exit 1
fi

echo "============================================================="
echo ""

# Server Reboot
clear

# Display Install Info
/usr/local/bin/enginescript/scripts/functions/alias/alias-server-info.sh

# Reboot Notice
echo -e "${BOLD}The server needs to reboot.${NORMAL}\n\nEnter the ${BOLD}es.menu${NORMAL} command after rebooting to continue.\n" | boxes -a c -d shell -p a1l2
sleep 10
clear

echo -e "The server is rebooting now...\n\n${NORMAL}After reconnecting, use the ${BOLD}es.menu${NORMAL} command to start EngineScript.\nSelect option 1 to create a new vhost configuration on your server.\n\n${BOLD}Bye! Manually reconnect in 30 seconds.\n" | boxes -a c -d shell -p a1l2
shutdown -r now
