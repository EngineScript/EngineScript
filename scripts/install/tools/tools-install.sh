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


#----------------------------------------------------------------------------------
# Start Main Script


#------------------------------------------------
# Media Tools
#------------------------------------------------

# Return to /usr/src
cd /usr/src

# pngout
/usr/local/bin/enginescript/scripts/install/tools/media/pngout.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "pngout"

# zImageOptimizer
/usr/local/bin/enginescript/scripts/install/tools/media/zimageoptimizer.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "zImageOptimizer"


#------------------------------------------------
# MySQL Tools
#------------------------------------------------

# Adminer
if [[ "${INSTALL_ADMINER}" == "1" ]];
  then
    echo "Installing Adminer"
    /usr/local/bin/enginescript/scripts/install/tools/mysql/adminer.sh 2>> /tmp/enginescript_install_errors.log
    print_last_errors
    debug_pause "Adminer"
  else
    echo "Skipping Adminer install"
fi

# MYSQLTuner
/usr/local/bin/enginescript/scripts/install/tools/mysql/mysqltuner.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "MYSQLTuner"

# phpMyAdmin
if [[ "${INSTALL_PHPMYADMIN}" == "1" ]];
  then
    echo "Installing phpMyAdmin"
    /usr/local/bin/enginescript/scripts/install/tools/mysql/phpmyadmin.sh 2>> /tmp/enginescript_install_errors.log
    print_last_errors
    debug_pause "phpMyAdmin"
  else
    echo "Skipping phpMyAdmin install"
fi


#------------------------------------------------
# Nginx Tools
#------------------------------------------------


#------------------------------------------------
# PHP Tools
#------------------------------------------------

# OpCache-GUI
#/usr/local/bin/enginescript/scripts/install/tools/php/opcache-gui.sh


#------------------------------------------------
# Security Tools
#------------------------------------------------

# ClamAV
#/usr/local/bin/enginescript/scripts/install/tools/security/clamav.sh

# Maldet
#/usr/local/bin/enginescript/scripts/install/tools/security/maldet.sh

# PHP Malware Finder
/usr/local/bin/enginescript/scripts/install/tools/security/php-malware-finder.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "PHP Malware Finder"

# Wordfence CLI Malware Scanner
/usr/local/bin/enginescript/scripts/install/tools/security/wordfence-cli.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Wordfence CLI"

# WPScan
/usr/local/bin/enginescript/scripts/install/tools/security/wpscan.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "WPScan"


#------------------------------------------------
# Frontend Tools
#------------------------------------------------

# Admin Control Panel
/usr/local/bin/enginescript/scripts/install/tools/frontend/admin-control-panel.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Admin Control Panel"

# Install phpinfo
/usr/local/bin/enginescript/scripts/install/tools/frontend/phpinfo-install.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "phpinfo"

# Install phpSysinfo
/usr/local/bin/enginescript/scripts/install/tools/frontend/phpsysinfo-install.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "phpSysinfo"

# Install Tiny File Manager
/usr/local/bin/enginescript/scripts/install/tools/frontend/tiny-file-manager-install.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Tiny File Manager"

# Install UptimeRobot API
/usr/local/bin/enginescript/scripts/install/tools/frontend/uptimerobit-api-install.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "UptimeRobot API"

# Update configuration files from main credentials file
echo "Updating configuration files with user credentials..."
/usr/local/bin/enginescript/scripts/functions/shared/update-config-files.sh

# Set permissions for EngineScript frontend directories
set_enginescript_frontend_permissions


#------------------------------------------------
# System Tools
#------------------------------------------------

# Testssl.sh
/usr/local/bin/enginescript/scripts/install/tools/system/testssl-install.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Testssl.sh"


#------------------------------------------------
# WordPress Tools
#------------------------------------------------

# WP-CLI
/usr/local/bin/enginescript/scripts/install/tools/wordpress/wp-cli.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "WP-CLI"


#------------------------------------------------
# Cloud Backups
#
# We're doing this at the end because it requires a bit of user input
# and we don't want to stop the rest of the install process.
#------------------------------------------------

# Amazon AWS CLI
if [[ "${INSTALL_S3_BACKUP}" == "1" ]];
  then
    echo "Installing Amazon CLI"
    echo "Please follow the instructions in the script that is about to run."
    sleep 5
    /usr/local/bin/enginescript/scripts/install/tools/system/amazon-s3-install.sh 2>> /tmp/enginescript_install_errors.log
    print_last_errors
    debug_pause "Amazon AWS CLI"
  else
    echo "Skipping Amazon CLI install"
fi

# Return to /usr/src
cd /usr/src
