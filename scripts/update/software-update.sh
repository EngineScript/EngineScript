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

# Update System Software and Tools

# Update Adminer
if [[ "${INSTALL_ADMINER}" == "1" ]];
  then
    echo "Updating Adminer"
    /usr/local/bin/enginescript/scripts/install/tools/mysql/adminer.sh 2>> /tmp/enginescript_install_errors.log
  else
    echo "Skipping Adminer update"
fi
print_last_errors
debug_pause "Adminer"

# Install or update fail2ban (servers installed before it was added get it here)
/usr/local/bin/enginescript/scripts/install/tools/security/fail2ban.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "fail2ban"

# Install or update Gixy-Next
/usr/local/bin/enginescript/scripts/install/tools/nginx/gixy.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Gixy-Next"

# Update liburing
/usr/local/bin/enginescript/scripts/install/liburing/liburing-install.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "liburing"

# Install or update Lynis
/usr/local/bin/enginescript/scripts/install/tools/security/lynis.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Lynis"

# Update MYSQLTuner
/usr/local/bin/enginescript/scripts/install/tools/mysql/mysqltuner.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "MYSQLTuner"

# Update phpMyAdmin
if [[ "${INSTALL_PHPMYADMIN}" == "1" ]];
  then
    echo "Updating phpMyAdmin"
    /usr/local/bin/enginescript/scripts/update/phpmyadmin-update.sh 2>> /tmp/enginescript_install_errors.log
  else
    echo "Skipping phpMyAdmin update"
fi
print_last_errors
debug_pause "phpMyAdmin"

# Update WP-CLI
/usr/local/bin/enginescript/scripts/update/wp-cli-update.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "WP-CLI"

# Update WP-Scan
gem update wpscan --no-document 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "WP-Scan"

# Update zImageOptimizer
/usr/local/bin/enginescript/scripts/install/tools/media/zimageoptimizer.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "zImageOptimizer"

# Update Zlib
/usr/local/bin/enginescript/scripts/install/zlib/zlib-install.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Zlib"

# Cleanup
run_enginescript_cleanup 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Cleanup"

echo ""
echo "============================================================="
echo ""
echo "${BOLD}EngineScript has been updated.${NORMAL}"
echo ""
echo "This update includes:"
echo "  - Adminer (if enabled)"
echo "  - liburing"
echo "  - MYSQLTuner"
echo "  - PHP Malware Finder"
echo "  - phpMyAdmin (if enabled)"
echo "  - WP-CLI"
echo "    - WP-CLI Packages"
echo "  - WP-Scan"
echo "  - zImageOptimizer"
echo "  - zlib"
echo ""
echo "============================================================="
echo ""
