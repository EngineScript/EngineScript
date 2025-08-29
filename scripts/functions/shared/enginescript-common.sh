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
            echo -e "Some text be displayed that just contains general information. Logged output does not always indicate an error."
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

# Enhanced input validation functions
# Prompts user with timeout and exit options for basic continuation
function prompt_continue() {
    local prompt_text="${1:-Press [Enter] to continue or type 'exit' to abort}"
    local timeout_seconds="${2:-300}"  # 5 minute default timeout
    
    while true; do
        echo -e "\n${prompt_text}"
        if read -t "${timeout_seconds}" -p "> " user_input; then
            case "${user_input,,}" in  # Convert to lowercase
                ""|"y"|"yes"|"continue")
                    return 0
                    ;;
                "exit"|"quit"|"abort"|"stop")
                    echo -e "\nExiting script as requested."
                    exit 1
                    ;;
                *)
                    echo "Invalid input. Please press Enter to continue or type 'exit' to abort."
                    ;;
            esac
        else
            echo -e "\nTimeout reached (${timeout_seconds}s). Exiting script."
            exit 1
        fi
    done
}

# Prompts user for yes/no confirmation with validation and timeout
function prompt_yes_no() {
    local prompt_text="$1"
    local default_value="${2:-""}"  # Optional default (y/n)
    local timeout_seconds="${3:-300}"  # 5 minute default timeout
    
    local prompt_suffix=""
    if [[ -n "$default_value" ]]; then
        case "${default_value,,}" in
            "y"|"yes") prompt_suffix=" [Y/n/exit]" ;;
            "n"|"no") prompt_suffix=" [y/N/exit]" ;;
        esac
    else
        prompt_suffix=" [y/n/exit]"
    fi
    
    while true; do
        echo -e "\n${prompt_text}${prompt_suffix}"
        if read -t "${timeout_seconds}" -p "> " user_input; then
            # Use default if empty input and default is set
            if [[ -z "$user_input" && -n "$default_value" ]]; then
                user_input="$default_value"
            fi
            
            case "${user_input,,}" in
                "y"|"yes")
                    return 0  # True/Yes
                    ;;
                "n"|"no") 
                    return 1  # False/No
                    ;;
                "exit"|"quit"|"abort"|"stop")
                    echo -e "\nExiting script as requested."
                    exit 1
                    ;;
                "")
                    if [[ -z "$default_value" ]]; then
                        echo "Please enter 'y' for yes, 'n' for no, or 'exit' to abort."
                    else
                        echo "Please enter 'y', 'n', or 'exit'."
                    fi
                    ;;
                *)
                    echo "Invalid input. Please enter 'y' for yes, 'n' for no, or 'exit' to abort."
                    ;;
            esac
        else
            echo -e "\nTimeout reached (${timeout_seconds}s). Exiting script."
            exit 1
        fi
    done
}

# Prompts user for text input with validation and timeout
function prompt_input() {
    local prompt_text="$1"
    local default_value="${2:-""}"
    local timeout_seconds="${3:-300}"  # 5 minute default timeout
    local validation_pattern="${4:-""}"  # Optional regex pattern
    local allow_empty="${5:-false}"  # Whether to allow empty input
    
    local prompt_suffix=""
    if [[ -n "$default_value" ]]; then
        prompt_suffix=" [${default_value}]"
    fi
    
    while true; do
        echo -e "\n${prompt_text}${prompt_suffix}"
        echo "Type 'exit' to abort the script."
        if read -t "${timeout_seconds}" -p "> " user_input; then
            case "${user_input,,}" in
                "exit"|"quit"|"abort"|"stop")
                    echo -e "\nExiting script as requested."
                    exit 1
                    ;;
                "")
                    if [[ -n "$default_value" ]]; then
                        echo "$default_value"
                        return 0
                    elif [[ "$allow_empty" == "true" ]]; then
                        echo ""
                        return 0
                    else
                        echo "Input cannot be empty. Please enter a value or type 'exit' to abort."
                    fi
                    ;;
                *)
                    # Validate against pattern if provided
                    if [[ -n "$validation_pattern" ]]; then
                        if [[ "$user_input" =~ $validation_pattern ]]; then
                            echo "$user_input"
                            return 0
                        else
                            echo "Invalid input format. Please try again or type 'exit' to abort."
                        fi
                    else
                        echo "$user_input"
                        return 0
                    fi
                    ;;
            esac
        else
            echo -e "\nTimeout reached (${timeout_seconds}s). Exiting script."
            exit 1
        fi
    done
}

# Domain name validation function
function validate_domain() {
    local domain="$1"
    local domain_regex="^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$"
    
    if [[ "$domain" =~ $domain_regex ]]; then
        return 0
    else
        return 1
    fi
}

# Email validation function
function validate_email() {
    local email="$1"
    local email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    
    if [[ "$email" =~ $email_regex ]]; then
        return 0
    else
        return 1
    fi
}

# URL validation function
function validate_url() {
    local url="$1"
    local url_regex="^https?://[a-zA-Z0-9.-]+[a-zA-Z0-9](/.*)?$"
    
    if [[ "$url" =~ $url_regex ]]; then
        return 0
    else
        return 1
    fi
}

# Set permissions for EngineScript frontend directories and files
function set_enginescript_frontend_permissions() {
    # Set permissions for /var/www/admin/enginescript
    find /var/www/admin/enginescript -type d -print0 | sudo xargs -0 chmod 0755
    find /var/www/admin/enginescript -type f -print0 | sudo xargs -0 chmod 0644
    chown -R www-data:www-data /var/www/admin/enginescript

    # Set permissions for /etc/enginescript
    find /etc/enginescript -type d -print0 | sudo xargs -0 chmod 0755
    find /etc/enginescript -type f -print0 | sudo xargs -0 chmod 0644
    chown -R www-data:www-data /etc/enginescript
}

# Set permissions for Nginx directories and files
function set_nginx_permissions() {
    chown -R www-data:www-data /etc/nginx
    chown -R www-data:www-data /tmp/nginx_proxy
    chown -R www-data:www-data /usr/lib/nginx/modules
    chown -R www-data:www-data /var/cache/nginx
    chown -R www-data:www-data /var/lib/nginx
    chown -R www-data:www-data /var/log/domains
    chown -R www-data:www-data /var/log/nginx
    chown -R www-data:www-data /var/www
    chmod 775 /var/cache/nginx
    chmod 755 /var/log/nginx
    chmod 755 /var/log/domains

    # Set proper permissions for SSL certificates
    if [ -d "/etc/nginx/ssl" ]; then
        chown -R root:www-data /etc/nginx/ssl
        chmod -R 750 /etc/nginx/ssl
        find /etc/nginx/ssl -name "*.key" -exec chmod 640 {} \;
        find /etc/nginx/ssl -name "*.crt" -exec chmod 644 {} \;
        find /etc/nginx/ssl -name "*.pem" -exec chmod 644 {} \;
    fi
}

# Set permissions for PHP directories and files
function set_php_permissions() {
    find "/var/log/php" -type d,f -exec chmod 775 {} \;
    find "/var/log/opcache" -type d,f -exec chmod 775 {} \;
    find "/etc/php" -type d,f -exec chmod 775 {} \;
    chmod 775 /var/cache/opcache
    chmod 775 /var/cache/php-sessions
    chmod 775 /var/cache/wsdlcache
    chown -R www-data:www-data /var/cache/opcache
    chown -R www-data:www-data /var/cache/php-sessions
    chown -R www-data:www-data /var/cache/wsdlcache
    chown -R www-data:www-data /var/log/opcache
    chown -R www-data:www-data /var/log/php
    chown -R www-data:www-data /etc/php
}

# Check if all required EngineScript installation components are completed
# Returns 0 if all components are installed, exits with error if incomplete
function check_installation_completion() {
    local install_log="/var/log/EngineScript/install-log.txt"
    local missing_components=()
    local quiet_mode="${1:-false}"  # Optional parameter for quiet mode
    
    # Source the install log if it exists
    if [[ -f "$install_log" ]]; then
        source "$install_log" 2>/dev/null || true
    else
        if [[ "$quiet_mode" != "true" ]]; then
            echo "ERROR: Installation log not found at $install_log"
            echo "This indicates EngineScript installation was never started or completed."
            echo "Please run the full installation script first."
        fi
        return 1
    fi
    
    # Define all required installation components
    local required_components=(
        "REPOS" "REMOVES" "BLOCK" "UBUNTU_PRO" "DEPENDS" "CRON" "ACME" 
        "GCC" "OPENSSL" "SWAP" "KERNEL_TWEAKS" "KSM" "SFL" "NTP" 
        "PCRE" "ZLIB" "LIBURING" "UFW" "MARIADB" "PHP" "REDIS" "NGINX" "TOOLS"
    )
    
    # Check each required component
    for component in "${required_components[@]}"; do
        local var_name="$component"
        local var_value="${!var_name:-0}"
        
        if [[ "$var_value" != "1" ]]; then
            missing_components+=("$component")
        fi
    done
    
    # Return results based on mode
    if [[ ${#missing_components[@]} -eq 0 ]]; then
        if [[ "$quiet_mode" != "true" ]]; then
            echo "✅ SUCCESS: All EngineScript components are installed and completed."
        fi
        return 0
    else
        if [[ "$quiet_mode" != "true" ]]; then
            echo "❌ ERROR: EngineScript installation is incomplete."
            echo "❌ The following components are missing or failed to complete:"
            echo ""
            for component in "${missing_components[@]}"; do
                echo "   - $component"
            done
            echo ""
            echo "RESOLUTION:"
            echo "1. Run the full EngineScript installation script to complete setup"
            echo "2. Check /var/log/EngineScript/install-error-log.txt for specific errors"
            echo "3. Use 'es.debug' command to generate a complete diagnostic report"
            echo ""
        fi
        return 1
    fi
}

# Verify installation completion with error handling for scripts that require it
function verify_installation_completion() {
    local script_name="${1:-Unknown script}"
    
    echo "============================================================="
    echo "Verifying EngineScript Installation Completion..."
    echo "============================================================="
    
    if check_installation_completion; then
        echo "✅ Installation verification passed. Proceeding with $script_name..."
        echo ""
        return 0
    else
        echo ""
        echo "$script_name cannot proceed until all components are properly installed."
        exit 1
    fi
}
