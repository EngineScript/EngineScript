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

# Update System Software and Tools

# Update Adminer
if [[ "${INSTALL_ADMINER}" == "1" ]];
  then
    echo "Updating Adminer"
    /usr/local/bin/enginescript/scripts/install/tools/mysql/adminer.sh 2>> "${ES_STEP_ERROR_LOG}"
  else
    echo "Skipping Adminer update"
fi
print_last_errors
debug_pause "Adminer"

# Install or update fail2ban (servers installed before it was added get it here)
run_step "fail2ban" /usr/local/bin/enginescript/scripts/install/tools/security/fail2ban.sh

# Install or update Gixy-Next
run_step "Gixy-Next" /usr/local/bin/enginescript/scripts/install/tools/nginx/gixy.sh

# Update liburing to the version in enginescript-variables.txt
run_step "liburing" /usr/local/bin/enginescript/scripts/install/liburing/liburing-install.sh

# Install or update Lynis
run_step "Lynis" /usr/local/bin/enginescript/scripts/install/tools/security/lynis.sh

# Update MYSQLTuner
run_step "MYSQLTuner" /usr/local/bin/enginescript/scripts/install/tools/mysql/mysqltuner.sh

# Update phpMyAdmin
if [[ "${INSTALL_PHPMYADMIN}" == "1" ]];
  then
    echo "Updating phpMyAdmin"
    /usr/local/bin/enginescript/scripts/update/phpmyadmin-update.sh 2>> "${ES_STEP_ERROR_LOG}"
  else
    echo "Skipping phpMyAdmin update"
fi
print_last_errors
debug_pause "phpMyAdmin"

# Update WP-CLI
run_step "WP-CLI" /usr/local/bin/enginescript/scripts/update/wp-cli-update.sh

# Update WP-Scan
run_step "WP-Scan" gem update wpscan --no-document

# Update zImageOptimizer
run_step "zImageOptimizer" /usr/local/bin/enginescript/scripts/install/tools/media/zimageoptimizer.sh

# zlib is compiled into Nginx, so the Nginx update fetches its current version

# Cleanup
run_step "Cleanup" run_enginescript_cleanup

echo ""
echo "============================================================="
echo ""
echo "${BOLD}EngineScript has been updated.${NORMAL}"
echo ""
echo "This update includes:"
echo "  - Adminer (if enabled)"
echo "  - fail2ban"
echo "  - Gixy-Next"
echo "  - liburing"
echo "  - Lynis"
echo "  - MYSQLTuner"
echo "  - phpMyAdmin (if enabled)"
echo "  - WP-CLI"
echo "    - WP-CLI Packages"
echo "  - WP-Scan"
echo "  - zImageOptimizer"
echo ""
echo "============================================================="
echo ""
