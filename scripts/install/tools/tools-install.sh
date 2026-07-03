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


#----------------------------------------------------------------------------------
# Start Main Script

source /etc/enginescript/install-state.conf
if [[ "${TOOLS}" = 1 ]]; then
    echo "TOOLS script has already run"
    exit 0
fi


#------------------------------------------------
# Media Tools
#------------------------------------------------

# Return to /usr/src
return_to_src

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

#------------------------------------------------
# Nginx Tools
#------------------------------------------------


#------------------------------------------------
# PHP Tools
#------------------------------------------------

# OPcache GUI
#/usr/local/bin/enginescript/scripts/install/tools/php/opcache-gui.sh


#------------------------------------------------
# Security Tools
#------------------------------------------------

# ClamAV
#/usr/local/bin/enginescript/scripts/install/tools/security/clamav.sh

# Maldet
#/usr/local/bin/enginescript/scripts/install/tools/security/maldet.sh

# Wordfence CLI Malware Scanner
/usr/local/bin/enginescript/scripts/install/tools/security/wordfence-cli.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Wordfence CLI"

# WPScan
/usr/local/bin/enginescript/scripts/install/tools/security/wpscan.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "WPScan"


#------------------------------------------------
# System Tools
#------------------------------------------------

# Testssl.sh
/usr/local/bin/enginescript/scripts/install/tools/system/testssl-install.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Testssl.sh"


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
return_to_src

# Mark the installation as complete
set_install_state "TOOLS" "1"
echo "Tools completed successfully. Script done."
