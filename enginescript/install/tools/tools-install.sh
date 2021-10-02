#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 20.04 (focal)
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
/usr/local/bin/enginescript/enginescript/install/tools/media/pngout.sh

# zImageOptimizer
/usr/local/bin/enginescript/enginescript/install/tools/media/zimageoptimizer.sh

#------------------------------------------------
# MySQL Tools
#------------------------------------------------

# Adminer
/usr/local/bin/enginescript/enginescript/install/tools/mysql/adminer.sh

# MYSQLTuner
/usr/local/bin/enginescript/enginescript/install/tools/mysql/mysqltuner.sh

# phpMyAdmin
/usr/local/bin/enginescript/enginescript/install/tools/mysql/phpmyadmin.sh

# Tuning-Primer
#/usr/local/bin/enginescript/enginescript/install/tools/mysql/tuning-primer.sh

#------------------------------------------------
# Nginx Tools
#------------------------------------------------

#------------------------------------------------
# PHP Tools
#------------------------------------------------

# OpCache-GUI
/usr/local/bin/enginescript/enginescript/install/tools/php/opcache-gui.sh

# OpCache-Status
/usr/local/bin/enginescript/enginescript/install/tools/php/opcache-status.sh

# PHPinfo.php
/usr/local/bin/enginescript/enginescript/install/tools/php/phpinfo.sh

#------------------------------------------------
# Security Tools
#------------------------------------------------

# ClamAV
/usr/local/bin/enginescript/enginescript/install/tools/security/clamav.sh

# PHP Malware Finder
/usr/local/bin/enginescript/enginescript/install/tools/security/php-malware-finder.sh

#------------------------------------------------
# System Tools
#------------------------------------------------

# Dropbox_uploader
if [ "${INSTALL_DROPBOX_BACKUP}" = 1 ];
  then
    echo "Installing Dropbox Uploader"
    echo "Please follow the instructions in the script that is about to run."
    sleep 5
    /usr/local/bin/enginescript/enginescript/install/tools/system/dropbox_uploader.sh
  else
    echo "Skipping Dropbox Uploader install"
fi

# phpSysinfo
/usr/local/bin/enginescript/enginescript/install/tools/system/phpsysinfo.sh

# Webmin
/usr/local/bin/enginescript/enginescript/install/tools/system/webmin.sh

#------------------------------------------------
# WordPress Tools
#------------------------------------------------

# WP-CLI
/usr/local/bin/enginescript/enginescript/install/tools/wordpress/wp-cli.sh

# WPScan
/usr/local/bin/enginescript/enginescript/install/tools/wordpress/wpscan.sh
