#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript settings and shared functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script


#------------------------------------------------
# Media Tools
#------------------------------------------------

# Return to /usr/src
return_to_src

# pngout
run_step "pngout" /usr/local/bin/enginescript/scripts/install/tools/media/pngout.sh

# zImageOptimizer
run_step "zImageOptimizer" /usr/local/bin/enginescript/scripts/install/tools/media/zimageoptimizer.sh


#------------------------------------------------
# MySQL Tools
#------------------------------------------------

# Adminer
if [[ "${INSTALL_ADMINER}" == "1" ]];
  then
    echo "Installing Adminer"
    run_step "Adminer" /usr/local/bin/enginescript/scripts/install/tools/mysql/adminer.sh
  else
    echo "Skipping Adminer install"
fi

# MYSQLTuner
run_step "MYSQLTuner" /usr/local/bin/enginescript/scripts/install/tools/mysql/mysqltuner.sh

#------------------------------------------------
# Nginx Tools
#------------------------------------------------

# Gixy-Next: Nginx configuration security checker
run_step "Gixy-Next" /usr/local/bin/enginescript/scripts/install/tools/nginx/gixy.sh

#------------------------------------------------
# Security Tools
#------------------------------------------------

# ClamAV
#/usr/local/bin/enginescript/scripts/install/tools/security/clamav.sh

# Maldet
#/usr/local/bin/enginescript/scripts/install/tools/security/maldet.sh

# fail2ban: bans addresses after repeated failed SSH logins
run_step "fail2ban" /usr/local/bin/enginescript/scripts/install/tools/security/fail2ban.sh

# Lynis: security audit
run_step "Lynis" /usr/local/bin/enginescript/scripts/install/tools/security/lynis.sh

# Wordfence CLI Malware Scanner
run_step "Wordfence CLI" /usr/local/bin/enginescript/scripts/install/tools/security/wordfence-cli.sh

# WPScan
run_step "WPScan" /usr/local/bin/enginescript/scripts/install/tools/security/wpscan.sh


#------------------------------------------------
# System Tools
#------------------------------------------------

# Testssl.sh
run_step "Testssl.sh" /usr/local/bin/enginescript/scripts/install/tools/system/testssl-install.sh


#------------------------------------------------
# Cloud Backups
#
# We're doing this at the end because it requires a bit of user input
# and we don't want to stop the rest of the install process.
#------------------------------------------------

# Amazon AWS CLI
resolve_backup_settings
if [[ "${BACKUP_S3}" == "1" ]];
  then
    echo "Installing Amazon CLI"
    echo "Please follow the instructions in the script that is about to run."
    sleep 5
    run_step "Amazon AWS CLI" /usr/local/bin/enginescript/scripts/install/tools/system/amazon-s3-install.sh
  else
    echo "Skipping Amazon CLI install"
fi

# Return to /usr/src
return_to_src

echo "Tools completed successfully. Script done."
