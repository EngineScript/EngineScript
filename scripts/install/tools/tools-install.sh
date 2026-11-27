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

# The tools are optional: one that fails is listed at the end (run_tool), and the install
# carries on. One installed without its configuration is listed too (report_tools_not_configured).
TOOLS_NOT_INSTALLED=()
TOOLS_NOT_CONFIGURED=()

#------------------------------------------------
# Media Tools
#------------------------------------------------

# Return to /usr/src
return_to_src

# pngout
run_tool "pngout" /usr/local/bin/enginescript/scripts/install/tools/media/pngout.sh

# zImageOptimizer
run_tool "zImageOptimizer" /usr/local/bin/enginescript/scripts/install/tools/media/zimageoptimizer.sh


#------------------------------------------------
# MySQL Tools
#------------------------------------------------

# Adminer
if [[ "${INSTALL_ADMINER}" == "1" ]];
  then
    echo "Installing Adminer"
    run_tool "Adminer" /usr/local/bin/enginescript/scripts/install/tools/mysql/adminer.sh
  else
    echo "Adminer: skipped (INSTALL_ADMINER=0)"
fi

# MYSQLTuner
run_tool "MYSQLTuner" /usr/local/bin/enginescript/scripts/install/tools/mysql/mysqltuner.sh

#------------------------------------------------
# Nginx Tools
#------------------------------------------------

# Gixy-Next: Nginx configuration security checker
run_tool "Gixy-Next" /usr/local/bin/enginescript/scripts/install/tools/nginx/gixy.sh

#------------------------------------------------
# Security Tools
#------------------------------------------------

# ClamAV
#/usr/local/bin/enginescript/scripts/install/tools/security/clamav.sh

# Maldet
#/usr/local/bin/enginescript/scripts/install/tools/security/maldet.sh

# fail2ban: bans addresses after repeated failed SSH logins
run_tool "fail2ban" /usr/local/bin/enginescript/scripts/install/tools/security/fail2ban.sh

# Lynis: security audit
run_tool "Lynis" /usr/local/bin/enginescript/scripts/install/tools/security/lynis.sh

# Wordfence CLI Malware Scanner
run_tool "Wordfence CLI" /usr/local/bin/enginescript/scripts/install/tools/security/wordfence-cli.sh

# WPScan
run_tool "WPScan" /usr/local/bin/enginescript/scripts/install/tools/security/wpscan.sh


#------------------------------------------------
# System Tools
#------------------------------------------------

# Testssl.sh
run_tool "Testssl.sh" /usr/local/bin/enginescript/scripts/install/tools/system/testssl-install.sh


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
    run_tool "Amazon AWS CLI" /usr/local/bin/enginescript/scripts/install/tools/system/amazon-s3-install.sh
    if aws_cli_not_configured; then
      TOOLS_NOT_CONFIGURED+=("Amazon AWS CLI: aws configure (S3 backups fail until then)")
    fi
  else
    echo "Skipping Amazon CLI install"
fi

# Return to /usr/src
return_to_src

# List the tools that were not installed. fail2ban protects SSH, so the next EngineScript update
# tries it again: a new install records the install_fail2ban upgrade as done, and forgetting
# that record makes the update run it.
report_tools_not_installed
report_tools_not_configured
if printf '%s\n' "${TOOLS_NOT_INSTALLED[@]}" | grep -q '^fail2ban: '; then
  source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-upgrades.sh \
    && forget_upgrade_done install_fail2ban \
    && echo "The next EngineScript update tries to install fail2ban again."
fi

echo "Tools completed. Script done."
