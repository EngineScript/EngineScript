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

# phpMyAdmin

# The new version is downloaded and unpacked beside the installed one, with its config.inc.php,
# and swapped in only when complete: a failed download leaves the installed phpMyAdmin working.
if [[ ! -f /var/www/admin/tools/phpmyadmin/config.inc.php ]]; then
    echo "Error: /var/www/admin/tools/phpmyadmin/config.inc.php is missing, so phpMyAdmin was not updated." >&2
    exit 1
fi
run_step "phpMyAdmin Download and Extract" install_beside /var/www/admin/tools/phpmyadmin "phpMyAdmin" build_phpmyadmin \
    || { echo "Error: phpMyAdmin was not updated; the installed version still works. See /var/log/EngineScript/install-error-log.log." >&2; exit 1; }
chown -R www-data:www-data /var/www/admin/tools/phpmyadmin

# Post-Install Cleanup
run_step "phpMyAdmin Cleanup" run_enginescript_cleanup

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}phpMyAdmin updated to version ${PHPMYADMIN_VER}.${NORMAL}"
echo ""
echo "============================================================="
echo ""
echo ""

set_install_state "PHPMYADMIN" "1"
sleep 5
