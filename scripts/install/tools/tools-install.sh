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

#------------------------------------------------
# Media Tools
#------------------------------------------------

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

# PHPinfo.php
/usr/local/bin/enginescript/scripts/install/tools/php/phpinfo.sh

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

# phpSysinfo
#/usr/local/bin/enginescript/scripts/install/tools/system/phpsysinfo.sh

# Testssl.sh
/usr/local/bin/enginescript/scripts/install/tools/system/testssl-install.sh

# Webmin
if [ "${INSTALL_WEBMIN}" = 1 ];
  then
    echo "Installing Webmin"
    /usr/local/bin/enginescript/scripts/install/tools/system/webmin.sh
  else
    echo "Skipping Webmin install"
fi

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

# Dropbox_uploader
if [ "${INSTALL_DROPBOX_BACKUP}" = 1 ];
  then
    echo "Installing Dropbox Uploader"
    echo "Please follow the instructions in the script that is about to run."
    sleep 5
    /usr/local/bin/enginescript/scripts/install/tools/system/dropbox-uploader.sh
  else
    echo "Skipping Dropbox Uploader install"
fi

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
