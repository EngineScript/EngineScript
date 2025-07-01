#!/usr/bin/env bash

# EngineScript Common Functions Library
# Shared functions used across multiple EngineScript components
# This library consolidates commonly duplicated functions to maintain consistency

# Debug pause function
# Prompts the user to continue if DEBUG_INSTALL is set and not 0/empty
function debug_pause() {
    if [[ "${DEBUG_INSTALL}" == "1" ]]; then
        local last_step=${1:-"Unknown step"}
        while true; do
            echo -e "\n[DEBUG] Completed step: ${last_step}"
            echo -e "[DEBUG] Press Enter to continue, or type 'exit' to stop the install."
            echo -e "If you encountered errors above, you can copy the error text for a GitHub bug report."
            echo -e "For more server details, run: es.debug"
            read -p "[DEBUG] Continue or exit? (Enter/exit): " user_input
            if [[ -z "$user_input" ]]; then
                break
            elif [[ "$user_input" =~ ^[Ee][Xx][Ii][Tt]$ ]]; then
                echo -e "\nExiting install script as requested."
                exit 1
            else
                echo "Please press Enter to continue or type 'exit' to stop."
            fi
        done
    fi
}

# Print errors from the last script section if any
function print_last_errors() {
    # Always append errors to persistent log if any
    if [[ -s /tmp/enginescript_install_errors.log ]]; then
        cat /tmp/enginescript_install_errors.log >> /var/log/EngineScript/install-error-log.txt
    fi
    # Only show errors to user if debug mode is enabled
    if [[ "${DEBUG_INSTALL}" == "1" ]] && [[ -s /tmp/enginescript_install_errors.log ]]; then
        echo -e "\n\n===============================================================\n"
        echo -e "${BOLD}[ERRORS DETECTED IN LAST STEP]${NORMAL}"
        cat /tmp/enginescript_install_errors.log
        echo -e "${BOLD}[END OF ERRORS]${NORMAL}\n\n"
        echo -e "If you encounter errors and want to submit a GitHub issue, please run: es.debug"
    fi
    # Always clear the temp log for the next step
    > /tmp/enginescript_install_errors.log
}

# Function to clear cache from a directory
function clear_cache() {
    local cache_path="$1"
    echo "Clearing ${cache_path} Cache"
    rm -rf "${cache_path}"/* || {
        echo "Error: Failed to clear ${cache_path} cache."
    }
}

# Function to restart a service
function restart_service() {
    local service_name="$1"
    echo "Restarting ${service_name}"
    service "${service_name}" restart || {
        echo "Error: Failed to restart ${service_name}."
    }
}

# Function to restart PHP-FPM service
function restart_php_fpm() {
    local php_versions=("8.1" "8.2" "8.3" "8.4")
    for version in "${php_versions[@]}"; do
        if systemctl is-active --quiet "php${version}-fpm"; then
            restart_service "php${version}-fpm"
            return
        fi
    done
    echo "Error: No active PHP-FPM service found."
}
