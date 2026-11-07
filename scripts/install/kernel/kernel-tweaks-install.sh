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

source /etc/enginescript/install-state.conf
if [[ "${KERNEL_TWEAKS}" = 1 ]]; then
    echo "KERNEL_TWEAKS script has already run"
    exit 0
fi

# Kernel Tweaks
install_enginescript_sysctl

# Mark the installation as complete
set_install_state "KERNEL_TWEAKS" "1"
echo "Kernel Tweaks completed successfully. Script done."
