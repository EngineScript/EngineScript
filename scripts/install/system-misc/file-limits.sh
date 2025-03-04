#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" -ne 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit 1
fi

#----------------------------------------------------------------------------------
# Start Main Script

# Function to update file limits
update_file_limits() {
    local limit_value=$1
    local limits_file="/etc/security/limits.conf"
    local pam_file="/etc/pam.d/common-session"

    echo "Updating file limits to ${limit_value}"

    # Check and update /etc/security/limits.conf
    if ! grep -q "* hard nofile ${limit_value}" ${limits_file}; then
        echo "* hard nofile ${limit_value}" >> ${limits_file} || {
            echo "Error: Failed to update ${limits_file}"
        }
    fi

    if ! grep -q "* soft nofile ${limit_value}" ${limits_file}; then
        echo "* soft nofile ${limit_value}" >> ${limits_file} || {
            echo "Error: Failed to update ${limits_file}"
        }
    fi

    if ! grep -q "root hard nofile ${limit_value}" ${limits_file}; then
        echo "root hard nofile ${limit_value}" >> ${limits_file} || {
            echo "Error: Failed to update ${limits_file}"
        }
    fi

    if ! grep -q "root soft nofile ${limit_value}" ${limits_file}; then
        echo "root soft nofile ${limit_value}" >> ${limits_file} || {
            echo "Error: Failed to update ${limits_file}"
        }
    fi

    # Check and update /etc/pam.d/common-session
    if ! grep -q "session required pam_limits.so" ${pam_file}; then
        echo "session required pam_limits.so" >> ${pam_file} || {
            echo "Error: Failed to update ${pam_file}"
        }
    fi
}

# Update file limits
update_file_limits 60556

echo "File limits updated successfully."
