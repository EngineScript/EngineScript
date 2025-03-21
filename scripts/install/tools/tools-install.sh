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

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" -ne 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit 1
fi

#----------------------------------------------------------------------------------
# Start Main Script

#------------------------------------------------
# Media Tools
#------------------------------------------------

# Return to /usr/src
cd /usr/src

# pngout
/usr/local/bin/enginescript/scripts/install/tools/media/pngout.sh

# zImageOptimizer
/usr/local/bin/enginescript/scripts/install/tools/media/zimageoptimizer.sh

#------------------------------------------------
# MySQL Tools
#------------------------------------------------

# Adminer
if [ "${INSTALL_ADMINER}" = 1 ];
  then
    echo "Installing Adminer"
    /usr/local/bin/enginescript/scripts/install/tools/mysql/adminer.sh
  else
    echo "Skipping Adminer install"
fi

# MYSQLTuner
/usr/local/bin/enginescript/scripts/install/tools/mysql/mysqltuner.sh

# phpMyAdmin
if [ "${INSTALL_PHPMYADMIN}" = 1 ];
  then
    echo "Installing phpMyAdmin"
    /usr/local/bin/enginescript/scripts/install/tools/mysql/phpmyadmin.sh
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
/usr/local/bin/enginescript/scripts/install/tools/security/php-malware-finder.sh

# Wordfence CLI Malware Scanner
/usr/local/bin/enginescript/scripts/install/tools/security/wordfence-cli.sh

# WPScan
/usr/local/bin/enginescript/scripts/install/tools/security/wpscan.sh

#------------------------------------------------
# System Tools
#------------------------------------------------

# Admin Control Panel
/usr/local/bin/enginescript/scripts/install/tools/system/admin-control-panel.sh

# Testssl.sh
/usr/local/bin/enginescript/scripts/install/tools/system/testssl-install.sh

#------------------------------------------------
# WordPress Tools
#------------------------------------------------

# WP-CLI
/usr/local/bin/enginescript/scripts/install/tools/wordpress/wp-cli.sh

#------------------------------------------------
# Cloud Backups
#
# We're doing this at the end because it requires a bit of user input
# and we don't want to stop the rest of the install process.
#------------------------------------------------

# Amazon AWS CLI
if [ "${INSTALL_S3_BACKUP}" = 1 ];
  then
    echo "Installing Amazon CLI"
    echo "Please follow the instructions in the script that is about to run."
    sleep 5
    /usr/local/bin/enginescript/scripts/install/tools/system/amazon-s3-install.sh
  else
    echo "Skipping Amazon CLI install"
fi

# Return to /usr/src
cd /usr/src
