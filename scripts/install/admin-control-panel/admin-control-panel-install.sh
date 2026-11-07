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

# Set to 1 by any step that fails. The panel is recorded as installed only when every step
# succeeded, so a failed step runs again on the next install.
INSTALL_FAILED=0

# Admin Control Panel
run_step "Admin Control Panel" /usr/local/bin/enginescript/scripts/install/tools/frontend/admin-control-panel-install.sh || INSTALL_FAILED=1

# Install phpinfo
run_step "phpinfo" /usr/local/bin/enginescript/scripts/install/tools/frontend/phpinfo-install.sh || INSTALL_FAILED=1

# Install phpSysinfo
run_step "phpSysinfo" /usr/local/bin/enginescript/scripts/install/tools/frontend/phpsysinfo-install.sh || INSTALL_FAILED=1

# Install Tiny File Manager
run_step "Tiny File Manager" /usr/local/bin/enginescript/scripts/install/tools/frontend/tiny-file-manager-install.sh || INSTALL_FAILED=1

# Install UptimeRobot API
run_step "UptimeRobot API" /usr/local/bin/enginescript/scripts/install/tools/frontend/uptimerobot-api-install.sh || INSTALL_FAILED=1

# Update configuration files from main credentials file
echo "Updating configuration files with user credentials..."
run_step "Admin Control Panel Configuration" /usr/local/bin/enginescript/scripts/functions/shared/update-config-files.sh || INSTALL_FAILED=1

# Set permissions for EngineScript frontend directories
set_enginescript_frontend_permissions

# Return to /usr/src
return_to_src

if [[ "${INSTALL_FAILED}" == "1" ]]; then
    echo "Error: An Admin Control Panel step failed (see the errors above). It will run again on the next install." >&2
    exit 1
fi
