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
if [[ "${SFL}" = 1 ]]; then
    echo "SFL script has already run"
    exit 0
fi

# Function to update file limits
update_file_limits() {
    local limit_value=$1
    local limits_file="/etc/security/limits.conf"
    local pam_file="/etc/pam.d/common-session"

    echo "Updating file limits to ${limit_value}"

    # Check and update /etc/security/limits.conf
    if ! grep -qFx -- "* hard nofile ${limit_value}" "${limits_file}"; then
        echo "* hard nofile ${limit_value}" >> "${limits_file}" || {
            echo "Error: Failed to update ${limits_file}"
        }
    fi

    if ! grep -qFx -- "* soft nofile ${limit_value}" "${limits_file}"; then
        echo "* soft nofile ${limit_value}" >> "${limits_file}" || {
            echo "Error: Failed to update ${limits_file}"
        }
    fi

    if ! grep -qFx -- "root hard nofile ${limit_value}" "${limits_file}"; then
        echo "root hard nofile ${limit_value}" >> "${limits_file}" || {
            echo "Error: Failed to update ${limits_file}"
        }
    fi

    if ! grep -qFx -- "root soft nofile ${limit_value}" "${limits_file}"; then
        echo "root soft nofile ${limit_value}" >> "${limits_file}" || {
            echo "Error: Failed to update ${limits_file}"
        }
    fi

    # Check and update /etc/pam.d/common-session
    if ! grep -qFx -- "session required pam_limits.so" "${pam_file}"; then
        echo "session required pam_limits.so" >> "${pam_file}" || {
            echo "Error: Failed to update ${pam_file}"
        }
    fi
}

# Update file limits
update_file_limits 60556

echo "File limits updated successfully."

# Mark the installation as complete
echo "SFL=1" >> /etc/enginescript/install-state.conf
