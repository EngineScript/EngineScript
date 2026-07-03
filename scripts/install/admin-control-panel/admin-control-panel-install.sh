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
if [[ "${ADMIN_CONTROL_PANEL}" = 1 ]]; then
    echo "ADMIN_CONTROL_PANEL script has already run"
    exit 0
fi

# Admin Control Panel
/usr/local/bin/enginescript/scripts/install/tools/frontend/admin-control-panel-install.sh 2>> /tmp/enginescript_install_errors.log
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
/usr/local/bin/enginescript/scripts/install/tools/frontend/uptimerobot-api-install.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "UptimeRobot API"

# Update configuration files from main credentials file
echo "Updating configuration files with user credentials..."
/usr/local/bin/enginescript/scripts/functions/shared/update-config-files.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Admin Control Panel Configuration"

# Set permissions for EngineScript frontend directories
set_enginescript_frontend_permissions

# Return to /usr/src
return_to_src

set_install_state "ADMIN_CONTROL_PANEL" "1"
