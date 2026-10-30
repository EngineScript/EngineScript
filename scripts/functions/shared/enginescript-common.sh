#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------
# Shared Virtual Host Functions
# This file contains common functions used by both vhost-install.sh and vhost-import.sh
#----------------------------------------------------------------------------------


# Debug pause function
# Prompts the user to continue if DEBUG_INSTALL is set and not 0/empty
function debug_pause() {
    if [[ "${DEBUG_INSTALL}" == "1" ]]; then
        local last_step=${1:-"Unknown step"}
        while true; do
            echo -e "\n[DEBUG] Completed step: ${last_step}"
            echo -e "[DEBUG] Press Enter to continue, or type 'exit' to stop the install."
            echo -e "Some displayed text may contain only general information. Logged output does not always indicate an error."
            echo -e "\nIf you encountered errors above, you can copy the error text for a GitHub bug report."
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


# ----------------------------------------------------------------
# Print errors from the last script section if any
function print_last_errors() {
    # Always append errors to persistent log if any
    if [[ -s /tmp/enginescript_install_errors.log ]]; then
        cat /tmp/enginescript_install_errors.log >> /var/log/EngineScript/install-error-log.log
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


# ----------------------------------------------------------------
# Normalize and update EngineScript installation state.
function set_install_state() {
    local flag_name="$1"
    local flag_value="${2:-1}"
    local state_file="${ENGINESCRIPT_INSTALL_STATE_FILE:-/etc/enginescript/install-state.conf}"
    local state_dir
    local tmp_file

    if [[ ! "${flag_name}" =~ ^[A-Z0-9_]+$ ]]; then
        echo "Error: Invalid install-state flag name: ${flag_name}" >&2
        return 1
    fi

    if [[ "${flag_value}" != "0" && "${flag_value}" != "1" ]]; then
        echo "Error: Invalid install-state value for ${flag_name}: ${flag_value}" >&2
        return 1
    fi

    state_dir="$(dirname "${state_file}")"
    mkdir -p "${state_dir}" || return 1
    touch "${state_file}" || return 1
    chmod 644 "${state_file}"

    tmp_file="$(mktemp)" || return 1
    awk -v key="${flag_name}" -v assignment="${flag_name}=${flag_value}" '
        BEGIN { replaced = 0 }
        $0 ~ "^" key "=" {
            if (replaced == 0) {
                print assignment
                replaced = 1
            }
            next
        }
        { print }
        END {
            if (replaced == 0) {
                print assignment
            }
        }
    ' "${state_file}" > "${tmp_file}" || {
        rm -f "${tmp_file}"
        return 1
    }

    cat "${tmp_file}" > "${state_file}" || {
        rm -f "${tmp_file}"
        return 1
    }
    rm -f "${tmp_file}"
}


# ----------------------------------------------------------------
# Ensure install-state.conf contains every install flag with a 0/1 value.
function initialize_install_state_file() {
    local state_file="${ENGINESCRIPT_INSTALL_STATE_FILE:-/etc/enginescript/install-state.conf}"
    local install_state_flags=(
        "ALIAS"
        "REPOS"
        "REMOVES"
        "BLOCK"
        "UBUNTU_PRO"
        "DEPENDS"
        "CRON"
        "ACME"
        "GCC"
        "OPENSSL"
        "SWAP"
        "KERNEL_TWEAKS"
        "THP"
        "SFL"
        "NTP"
        "DO_CONSOLE"
        "PCRE"
        "ZLIB"
        "LIBURING"
        "UFW"
        "MARIADB"
        "PHP"
        "REDIS"
        "NGINX"
        "PHPMYADMIN"
        "ADMIN_CONTROL_PANEL"
        "WP_CLI"
        "TOOLS"
    )
    local flag_name
    local current_value

    mkdir -p "$(dirname "${state_file}")" || return 1
    touch "${state_file}" || return 1
    chmod 644 "${state_file}"

    for flag_name in "${install_state_flags[@]}"; do
        current_value="$(
            awk -F= -v key="${flag_name}" '$1 == key { value = $2; found = 1 } END { if (found == 1) print value }' "${state_file}"
        )"

        if [[ "${current_value}" != "1" ]]; then
            current_value="0"
        fi

        set_install_state "${flag_name}" "${current_value}" || return 1
    done
}


# ----------------------------------------------------------------
# Clear Nginx cache directory
function clear_nginx_cache() {
    echo "Clearing Nginx FastCGI cache"
    
    if [ -d "/var/cache/nginx" ]; then
        # Delete cache files while preserving directory structure
        find /var/cache/nginx -type f -delete 2>/dev/null || {
            echo "Error: Failed to clear Nginx cache."
            return 1
        }
        
        # Signal Nginx to reload cache state
        if command -v nginx >/dev/null 2>&1; then
            nginx -s reload 2>/dev/null || true
        fi
        
        echo "Nginx cache cleared successfully."
    else
        echo "Warning: Nginx cache directory not found at /var/cache/nginx."
        return 1
    fi
}


# ----------------------------------------------------------------
# Clear PHP OPcache directory
function clear_opcache() {
    echo "Clearing PHP OPcache"
    rm -rf /var/cache/opcache/* || {
        echo "Error: Failed to clear PHP OPcache."
    }
}


# ----------------------------------------------------------------
# Clear Redis object cache
function clear_redis_cache() {
    echo "Clearing Redis object cache"
    redis-cli FLUSHALL ASYNC || {
        echo "Error: Failed to clear Redis cache."
    }
}


# ----------------------------------------------------------------
# Flush WordPress cache (single site)
function flush_wordpress_cache() {
    echo "Flushing WordPress cache"
    wp cache flush --allow-root || {
        echo "Error: Failed to flush WordPress cache."
    }
}


# ----------------------------------------------------------------
# Flush WordPress rewrite rules (single site)
function flush_wordpress_rewrites() {
    echo "Flushing WordPress rewrite rules"
    wp rewrite flush --hard --allow-root || {
        echo "Error: Failed to flush WordPress rewrite rules."
    }
}


# ----------------------------------------------------------------
# Delete WordPress transients (single site)
function clear_wordpress_transients() {
    echo "Deleting WordPress Transients"
    wp transient delete --all --allow-root || {
        echo "Error: Failed to delete WordPress transients."
    }
}


# ----------------------------------------------------------------
# Purge Nginx cache for a single site using Nginx Helper plugin
function purge_nginx_helper_cache() {
    echo "Purging Nginx Cache via Nginx Helper Plugin"
    wp nginx-helper purge-all --allow-root || {
        echo "Error: Failed to purge Nginx cache via plugin."
    }
}


# ----------------------------------------------------------------
# Clear EngineScript API cache directory (/var/cache/enginescript/api)
function clear_api_cache() {
    echo "Clearing EngineScript API cache"
    local cache_dir="/var/cache/enginescript/api"

    if [ -d "${cache_dir}" ]; then
        find "${cache_dir}" -type f -name '*.json' -delete 2>/dev/null || {
            echo "Error: Failed to clear API cache at ${cache_dir}."
            return 1
        }
        echo "API cache cleared successfully"
    else
        echo "Warning: API cache directory not found at ${cache_dir}"
        return 1
    fi
}


# ----------------------------------------------------------------
# Clear all WordPress caches for a single site (cache + rewrites)
function clear_wordpress_caches() {
    clear_wordpress_transients
    flush_wordpress_cache
    flush_wordpress_rewrites
    purge_nginx_helper_cache
}


# ----------------------------------------------------------------
# Clear WordPress transients for all sites
function clear_all_transients() {
    # Source sites list
    if [[ -f /home/EngineScript/sites-list/sites.sh ]]; then
        source /home/EngineScript/sites-list/sites.sh
        for site in "${SITES[@]}"; do
            echo "Deleting ${site} Transients"
            cd "/var/www/sites/$site/html" || {
                echo "Error: Failed to change directory to /var/www/sites/$site/html"
                continue
            }
            clear_wordpress_transients
        done
    else
        echo "Error: Sites list not found at /home/EngineScript/sites-list/sites.sh"
    fi
}


# ----------------------------------------------------------------
# Purge Nginx cache for all sites using Nginx Helper plugin
function purge_all_nginx_helper_caches() {
    # Source sites list
    if [[ -f /home/EngineScript/sites-list/sites.sh ]]; then
        source /home/EngineScript/sites-list/sites.sh
        for site in "${SITES[@]}"; do
            echo "Purging Nginx Cache for ${site}"
            cd "/var/www/sites/$site/html" || {
                echo "Error: Failed to change directory to /var/www/sites/$site/html"
                continue
            }
            purge_nginx_helper_cache
        done
    else
        echo "Error: Sites list not found at /home/EngineScript/sites-list/sites.sh"
    fi
}


# ----------------------------------------------------------------
# Clear WordPress caches for all sites (cache + rewrites)
function clear_all_wordpress_caches() {
    # Source sites list
    if [[ -f /home/EngineScript/sites-list/sites.sh ]]; then
        source /home/EngineScript/sites-list/sites.sh
        for site in "${SITES[@]}"; do
            echo "Clearing WordPress caches for ${site}"
            cd "/var/www/sites/$site/html" || {
                echo "Error: Failed to change directory to /var/www/sites/$site/html"
                continue
            }
            clear_wordpress_caches
        done
    else
        echo "Error: Sites list not found at /home/EngineScript/sites-list/sites.sh"
    fi
}


# ----------------------------------------------------------------
# Clear all system caches (Nginx, OPcache, Redis)
function clear_all_system_caches() {
    clear_api_cache
    clear_nginx_cache
    clear_opcache
    clear_redis_cache
}


# ----------------------------------------------------------------
# List the PHP-FPM versions installed on this server (for example "8.4"), newest first
# Any installed version is listed, including versions EngineScript no longer supports, so a
# server on such a version can still be detected and switched with php-update.sh.
function get_installed_php_versions() {
    local line
    local pattern='^php([0-9]+\.[0-9]+)-fpm install ok installed$'
    local versions=()

    if ! command -v dpkg-query > /dev/null 2>&1; then
        return 0
    fi
    while IFS= read -r line; do
        if [[ "${line}" =~ ${pattern} ]]; then
            versions+=("${BASH_REMATCH[1]}")
        fi
    done < <(dpkg-query -W -f='${Package} ${Status}\n' 'php*-fpm' 2> /dev/null || true)

    if [[ ${#versions[@]} -gt 0 ]]; then
        printf '%s\n' "${versions[@]}" | sort -rV
    fi
}


# ----------------------------------------------------------------
# Print the PHP-FPM version this server runs, or nothing when PHP-FPM is not installed
# With more than one installed (during a PHP version switch), a running version is preferred,
# then the newest.
function get_installed_php_version() {
    local versions=()
    local ver

    mapfile -t versions < <(get_installed_php_versions)
    if [[ ${#versions[@]} -eq 0 ]]; then
        return 0
    fi
    for ver in "${versions[@]}"; do
        if systemctl is-active --quiet "php${ver}-fpm" 2> /dev/null; then
            echo "${ver}"
            return 0
        fi
    done
    echo "${versions[0]}"
}


# ----------------------------------------------------------------
# Resolve the PHP version EngineScript works with
#
# PHP_CONFIGURED_VER is the version the install options select: PHP_VERSION_OVERRIDE when it
# names a supported version, otherwise the default PHP_VER. New installs use it, and
# php-update.sh uses it as the target when no version is given.
#
# PHP_VER is the version installed on this server, when PHP-FPM is installed. Scripts that
# configure an existing server (for example the Nginx update, which writes the PHP-FPM socket
# path) must use the version that is actually installed: the default changing in a later
# EngineScript release must not point Nginx at a PHP-FPM socket that does not exist. Changing
# versions is an explicit step: php-update.sh, or es.menu > Update Software > Switch PHP Version.
function resolve_php_version() {
    local ver installed

    PHP_CONFIGURED_VER="${PHP_VER:-}"
    if [[ -n "${PHP_VERSION_OVERRIDE:-}" ]]; then
        for ver in "${SUPPORTED_PHP_VERSIONS[@]}"; do
            if [[ "${PHP_VERSION_OVERRIDE}" == "${ver}" ]]; then
                PHP_CONFIGURED_VER="${PHP_VERSION_OVERRIDE}"
                break
            fi
        done
    fi

    installed="$(get_installed_php_version)"
    PHP_VER="${installed:-${PHP_CONFIGURED_VER}}"
}

# Resolve the PHP version (installed version, override, or default)
resolve_php_version


# ----------------------------------------------------------------
# Function to restart a service
function restart_service() {
    local service_name="$1"
    echo "Restarting ${service_name}"
    service "${service_name}" restart || {
        echo "Error: Failed to restart ${service_name}."
    }
}


# ----------------------------------------------------------------
# Function to restart PHP-FPM service
function restart_php_fpm() {
    if systemctl is-active --quiet "php${PHP_VER}-fpm"; then
        restart_service "php${PHP_VER}-fpm"
        return
    fi
    echo "Error: No active PHP-FPM service found."
}


# ----------------------------------------------------------------
# Print the PHP-FPM socket that /etc/nginx/globals/php-fpm.conf passes PHP requests to
function get_nginx_php_socket() {
    sed -n 's|^[[:space:]]*fastcgi_pass[[:space:]]*unix:\([^;[:space:]]*\);.*|\1|p' /etc/nginx/globals/php-fpm.conf 2> /dev/null | head -1
}


# ----------------------------------------------------------------
# Check that PHP-FPM runs PHP, by sending one FastCGI request straight to its socket
# (php-fpm-check.php). Works without any site, and is not affected by the FastCGI cache.
# Usage: php_fpm_answers "8.5"
function php_fpm_answers() {
    local ver="$1"
    local socket="/run/php/php${ver}-fpm.sock"
    local check_dir="/run/enginescript-php-check"
    local output

    if [[ ! -S "${socket}" ]]; then
        return 1
    fi
    mkdir -p "${check_dir}"
    chmod 755 "${check_dir}"
    printf '<?php echo "enginescript-php-ok ", PHP_VERSION;\n' > "${check_dir}/check.php"
    chmod 644 "${check_dir}/check.php"
    output="$(php /usr/local/bin/enginescript/scripts/functions/shared/php-fpm-check.php "${socket}" "${check_dir}/check.php" 2> /dev/null)"
    rm -rf "${check_dir}"
    [[ "${output}" == "enginescript-php-ok ${ver}."* ]]
}


# ----------------------------------------------------------------
# Print the sites on this server that do not work through Nginx and PHP, one per line
#
# A site fails on a gateway error (502 or 504: Nginx could not reach PHP-FPM), on 500 (a fatal
# PHP error, such as a plugin that does not run on a new PHP version, or an Nginx error), or with
# no response. 503 is not counted: WordPress answers 503 in maintenance mode. The query string
# bypasses the FastCGI cache, so a cached page cannot hide a PHP-FPM that does not answer. Prints
# nothing when every site answers or there are no sites. Callers compare the result with a list
# taken before a change, so a site that was already failing does not count against the change.
function get_sites_without_php() {
    local sites_file="${ES_SITES_LIST:-/home/EngineScript/sites-list/sites.sh}"
    local site code

    if [[ ! -f "${sites_file}" ]]; then
        return 0
    fi
    local SITES=()
    # shellcheck source=/dev/null
    source "${sites_file}"

    for site in "${SITES[@]}"; do
        code="$(curl -sk -o /dev/null -w '%{http_code}' --max-time 20 \
            --resolve "${site}:443:127.0.0.1" "https://${site}/?enginescript-check=${RANDOM}")"
        if [[ "${code}" == "000" || "${code}" == "500" || "${code}" == "502" || "${code}" == "504" ]]; then
            echo "${site}"
        fi
    done
}


# ----------------------------------------------------------------
# Print the WordPress sites on this server that cannot reach their database, one per line
#
# Runs a query with each site's own credentials from wp-config.php (WP-CLI), so it checks the
# account WordPress uses. Sites without wp-config.php (no WordPress) are skipped. Prints nothing
# when every site reaches its database or there are no sites. Callers compare the result with a
# list taken before a change, as with get_sites_without_php.
function get_sites_without_database() {
    local sites_file="/home/EngineScript/sites-list/sites.sh"
    local site site_root

    if [[ ! -f "${sites_file}" ]]; then
        return 0
    fi
    local SITES=()
    # shellcheck source=/dev/null
    source "${sites_file}"

    for site in "${SITES[@]}"; do
        site_root="/var/www/sites/${site}/html"
        if [[ ! -f "${site_root}/wp-config.php" ]]; then
            continue
        fi
        if ! timeout 60 wp db query "SELECT 1" --path="${site_root}" --allow-root --skip-plugins --skip-themes > /dev/null 2>&1; then
            echo "${site}"
        fi
    done
}


# ----------------------------------------------------------------
# Print the sites in the second list that are not in the first (newline-separated lists)
# Usage: newly_failing_sites "${FAILING_BEFORE}" "${FAILING_AFTER}"
function newly_failing_sites() {
    local before="$1"
    local after="$2"
    local site

    while IFS= read -r site; do
        if [[ -n "${site}" ]] && ! grep -qxF -- "${site}" <<< "${before}"; then
            echo "${site}"
        fi
    done <<< "${after}"
}


# ----------------------------------------------------------------
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


# ----------------------------------------------------------------
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


# ----------------------------------------------------------------
# Prompts user for text input with validation and timeout.
# Prints only the answer on stdout, so callers capture it with $(...); messages go to stderr.
# Inside $(...), the exit on "exit" or a timeout ends only that subshell: callers check the status.
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
        echo -e "\n${prompt_text}${prompt_suffix}" >&2
        echo "Type 'exit' to abort the script." >&2
        if read -t "${timeout_seconds}" -p "> " user_input; then
            case "${user_input,,}" in
                "exit"|"quit"|"abort"|"stop")
                    echo -e "\nExiting script as requested." >&2
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
                        echo "Input cannot be empty. Please enter a value or type 'exit' to abort." >&2
                    fi
                    ;;
                *)
                    # Validate against pattern if provided
                    if [[ -n "$validation_pattern" ]]; then
                        if [[ "$user_input" =~ $validation_pattern ]]; then
                            echo "$user_input"
                            return 0
                        else
                            echo "Invalid input format. Please try again or type 'exit' to abort." >&2
                        fi
                    else
                        echo "$user_input"
                        return 0
                    fi
                    ;;
            esac
        else
            echo -e "\nTimeout reached (${timeout_seconds}s). Exiting script." >&2
            exit 1
        fi
    done
}


# ----------------------------------------------------------------
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


# ----------------------------------------------------------------
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


# ----------------------------------------------------------------
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


# ----------------------------------------------------------------
# Set permissions for EngineScript frontend directories and files
function set_enginescript_frontend_permissions() {
    # Set permissions for /var/www/admin/control-panel (dashboard)
    if [ -d "/var/www/admin/control-panel" ]; then
        find /var/www/admin/control-panel -type d -print0 | sudo xargs -0 chmod 0755
        find /var/www/admin/control-panel -type f -print0 | sudo xargs -0 chmod 0644
        chown -R www-data:www-data /var/www/admin/control-panel
    fi

    # Set permissions for /var/www/admin/tools (phpMyAdmin, TinyFileManager, etc.)
    if [ -d "/var/www/admin/tools" ]; then
        find /var/www/admin/tools -type d -print0 | sudo xargs -0 chmod 0755
        find /var/www/admin/tools -type f -print0 | sudo xargs -0 chmod 0644
        chown -R www-data:www-data /var/www/admin/tools
    fi

    # Set permissions for /etc/enginescript
    find /etc/enginescript -type d -print0 | sudo xargs -0 chmod 0755
    find /etc/enginescript -type f -print0 | sudo xargs -0 chmod 0644
    chown -R www-data:www-data /etc/enginescript

    # Ensure API cache directory has correct owner and permissions
    if [ -d "/var/cache/enginescript/api" ]; then
        chown -R www-data:www-data /var/cache/enginescript/api
        chmod -R 775 /var/cache/enginescript/api
    fi
}


# ----------------------------------------------------------------
# Set permissions for Nginx directories and files
#
# The Nginx configuration belongs to root. The Nginx master process runs as root and loads
# it (including any load_module line), so it must not be writable by www-data, the user PHP
# and the Nginx worker processes run as. TLS private keys are readable by root only.
function set_nginx_permissions() {
    # Configuration: root-owned, directories 755, files 644
    if [[ -d /etc/nginx ]]; then
        chown -R root:root /etc/nginx
        find /etc/nginx -type d -exec chmod 755 {} +
        find /etc/nginx -type f -exec chmod 644 {} +
    fi

    # TLS certificates and keys: only root needs them (the master process reads them)
    if [[ -d /etc/nginx/ssl ]]; then
        find /etc/nginx/ssl -type d -exec chmod 700 {} +
        find /etc/nginx/ssl -type f \( -name '*.key' -o -name 'key.pem' \) -exec chmod 600 {} +
    fi

    # Admin basic-auth password file: the worker processes (www-data) read it on each request
    if [[ -d /etc/nginx/restricted-access ]]; then
        chown -R root:www-data /etc/nginx/restricted-access
        chmod 750 /etc/nginx/restricted-access
        find /etc/nginx/restricted-access -type f -exec chmod 640 {} +
    fi

    # Modules are loaded by the master process as root
    if [[ -d /usr/lib/nginx/modules ]]; then
        chown -R root:root /usr/lib/nginx/modules
    fi

    # Runtime directories the worker processes and PHP write to
    chown -R www-data:www-data /var/cache/nginx
    chown -R www-data:www-data /var/lib/nginx
    chown -R www-data:www-data /var/www
    chmod 775 /var/cache/nginx

    # Logs: the directories belong to root, so www-data cannot replace a log file with a
    # symlink that the root master process would then open and chown (CVE-2016-1247). The
    # log files stay owned by www-data: the worker processes reopen them after rotation, and
    # PHP writes the WordPress debug log in each site's directory.
    local log_dir
    for log_dir in /var/log/nginx /var/log/domains; do
        if [[ -d "${log_dir}" ]]; then
            find "${log_dir}" -type d -exec chown root:root {} + -exec chmod 755 {} +
            find "${log_dir}" -type f -exec chown www-data:adm {} + -exec chmod 640 {} +
        fi
    done
}


# ----------------------------------------------------------------
# Give existing sites' certificates a reload command.
#
# Sites created before acme.sh was given --reloadcmd renew their certificates without
# reloading Nginx, which keeps serving the old certificate until something else reloads it.
# Re-running --install-cert with the same paths saves the reload command for future renewals
# (and reloads Nginx once). Sites that already have a reload command are left alone.
function migrate_acme_reload_commands() {
    local acme="/root/.acme.sh/acme.sh"
    local sites_file="/home/EngineScript/sites-list/sites.sh"
    local domain domain_conf

    if [[ ! -x "${acme}" || ! -f "${sites_file}" ]]; then
        return 0
    fi

    local SITES=()
    # shellcheck source=/dev/null
    source "${sites_file}"

    for domain in "${SITES[@]}"; do
        domain_conf="/root/.acme.sh/${domain}_ecc/${domain}.conf"
        if [[ ! -f "${domain_conf}" || ! -d "/etc/nginx/ssl/${domain}" ]]; then
            continue
        fi
        if grep -q "^Le_ReloadCmd='..*'" "${domain_conf}"; then
            continue
        fi
        echo "Adding a certificate reload command for ${domain}..."
        "${acme}" --install-cert -d "${domain}" --ecc \
            --cert-file "/etc/nginx/ssl/${domain}/cert.pem" \
            --key-file "/etc/nginx/ssl/${domain}/key.pem" \
            --fullchain-file "/etc/nginx/ssl/${domain}/fullchain.pem" \
            --ca-file "/etc/nginx/ssl/${domain}/ca.pem" \
            --reloadcmd "systemctl reload nginx" \
            || echo "Warning: Could not add a certificate reload command for ${domain}." >&2
        secure_nginx_ssl_directory "/etc/nginx/ssl/${domain}"
    done
}


# ----------------------------------------------------------------
# Restrict one site's TLS directory to root (used right after a certificate is installed)
function secure_nginx_ssl_directory() {
    local ssl_dir="$1"

    if [[ ! -d "${ssl_dir}" ]]; then
        return 0
    fi

    chown -R root:root "${ssl_dir}"
    chmod 700 "${ssl_dir}"
    find "${ssl_dir}" -type f -exec chmod 644 {} +
    find "${ssl_dir}" -type f \( -name '*.key' -o -name 'key.pem' \) -exec chmod 600 {} +
}


# ----------------------------------------------------------------
# Toggle a commented configuration directive on or off while preserving indentation
function set_commented_directive_state() {
    local file_path="$1"
    local directive_pattern="$2"
    local enable_state="${3:-0}"

    if [[ ! -f "${file_path}" ]]; then
        return 0
    fi

    if [[ "${enable_state}" == "1" ]]; then
        sed -Ei "s|^([[:space:]]*)#(${directive_pattern})(.*)$|\\1\\2\\3|" "${file_path}"
    else
        sed -Ei "s|^([[:space:]]*)(${directive_pattern})(.*)$|\\1#\\2\\3|" "${file_path}"
    fi
}


# ----------------------------------------------------------------
# Normalize legacy HTTP/3 listen directives to the current form.
# "reuseport" may appear only once per address and port, so only the default
# server keeps "quic reuseport"; every other vhost uses "listen 443 quic;".
# "multipath" (Multipath TCP) does not apply to QUIC (UDP) listeners.
function normalize_nginx_http3_listen_directives() {
    local file_path="$1"

    if [[ ! -f "${file_path}" ]]; then
        return 0
    fi

    sed -Ei \
        -e 's|^([[:space:]]*#?listen 443 default_server )(multipath )?quic reuseport;|\1quic reuseport;|' \
        -e 's|^([[:space:]]*#?listen \[::\]:443 default_server )(multipath )?quic reuseport;|\1quic reuseport;|' \
        -e 's|^([[:space:]]*#?listen 443 )(multipath )?quic reuseport;|\1quic;|' \
        -e 's|^([[:space:]]*#?listen \[::\]:443 )(multipath )?quic reuseport;|\1quic;|' \
        "${file_path}"
}


# ----------------------------------------------------------------
# Keep Nginx HTTP/3 directives aligned with INSTALL_HTTP3 across all managed configs
function sync_nginx_http3_config() {
    local http3_enabled="${INSTALL_HTTP3:-0}"
    local early_hints_protocol_gate="\$http2"
    local quic_gso_enabled=0
    local nullglob_was_set=0
    local file_path
    local site_config_files=()

    if [[ "${http3_enabled}" != "1" ]]; then
        http3_enabled=0
    else
        early_hints_protocol_gate="\$http2\$http3"
    fi

    # http3_max_concurrent_streams and http3_stream_buffer_size stay commented
    # (Nginx defaults) and are left for manual tuning.
    set_commented_directive_state "/etc/nginx/nginx.conf" "http3 on;" "${http3_enabled}"
    set_commented_directive_state "/etc/nginx/nginx.conf" "quic_bpf on;" "${http3_enabled}"
    set_commented_directive_state "/etc/nginx/nginx.conf" "quic_retry on;" "${http3_enabled}"

    if [[ "${http3_enabled}" == "1" ]] && command -v ethtool >/dev/null 2>&1 && ethtool -k eth0 2>/dev/null | grep -q "tx-gso-robust: on"; then
        quic_gso_enabled=1
    fi
    set_commented_directive_state "/etc/nginx/nginx.conf" "quic_gso on;" "${quic_gso_enabled}"

    set_commented_directive_state "/etc/nginx/globals/response-headers.conf" "add_header Alt-Svc" "${http3_enabled}"
    set_commented_directive_state "/etc/nginx/globals/response-headers.conf" "add_header x-quic" "${http3_enabled}"
    if [[ -f "/etc/nginx/globals/map-cache.conf" ]]; then
        sed -Ei "s|^([[:space:]]*navigate[[:space:]]+).*;|\\1${early_hints_protocol_gate};|" "/etc/nginx/globals/map-cache.conf"
    fi

    normalize_nginx_http3_listen_directives "/etc/nginx/admin/admin.localhost.conf"
    set_commented_directive_state "/etc/nginx/admin/admin.localhost.conf" "listen 443 default_server quic reuseport;" "${http3_enabled}"
    set_commented_directive_state "/etc/nginx/admin/admin.localhost.conf" "listen \[::\]:443 default_server quic reuseport;" "${http3_enabled}"

    if shopt -q nullglob; then
        nullglob_was_set=1
    else
        shopt -s nullglob
    fi

    site_config_files=(
        /etc/nginx/sites-available/your-domain.conf
        /etc/nginx/sites-enabled/*.conf
        /etc/nginx/admin/admin.*.conf
    )

    if [[ "${nullglob_was_set}" == "0" ]]; then
        shopt -u nullglob
    fi

    for file_path in "${site_config_files[@]}"; do
        normalize_nginx_http3_listen_directives "${file_path}"
        set_commented_directive_state "${file_path}" "listen 443 quic;" "${http3_enabled}"
        set_commented_directive_state "${file_path}" "listen \[::\]:443 quic;" "${http3_enabled}"
    done
}


# ----------------------------------------------------------------
# Bring existing site and admin vhost files up to date with template changes.
#
# Vhost files are copied from the templates once, when a site is created, so later template
# changes never reach them on their own. Put new rules in the shared includes
# (/etc/nginx/globals) whenever possible; add a step here only when a vhost file itself must
# change. Every step must be safe to run again on an already-updated file.
# Runs on every Nginx install and update (nginx-misc.sh) and when a vhost is created.
function migrate_nginx_vhosts() {
    local nullglob_was_set=0
    local file_path
    local vhost_files=()

    if shopt -q nullglob; then
        nullglob_was_set=1
    else
        shopt -s nullglob
    fi
    vhost_files=(/etc/nginx/sites-enabled/*.conf /etc/nginx/admin/admin.*.conf)
    if [[ "${nullglob_was_set}" == "0" ]]; then
        shopt -u nullglob
    fi

    for file_path in "${vhost_files[@]}"; do
        # 2026-10: QUIC listeners. Only the default server keeps "reuseport"; no "multipath".
        normalize_nginx_http3_listen_directives "${file_path}"

        # 2026-10: admin subdomain vhosts keep their own security headers instead of merging in
        # the site-wide headers from nginx.conf (add_header_inherit merge), which would send
        # conflicting duplicates such as two X-Frame-Options values.
        if [[ "${file_path}" == /etc/nginx/admin/admin.*.conf && "${file_path}" != "/etc/nginx/admin/admin.localhost.conf" ]] \
            && ! grep -q "add_header_inherit" "${file_path}"; then
            sed -i '/^[[:space:]]*server_name admin\./a\  add_header_inherit on;' "${file_path}"
        fi

        # 2026-10: admin vhosts drop the "/services" rewrite. Nothing calls it: the control
        # panel reaches the same endpoint as /api/services/status.
        if [[ "${file_path}" == /etc/nginx/admin/admin.*.conf ]] && grep -q '^  location /services {$' "${file_path}"; then
            # Delete the comment, the block, and the blank line after the block.
            sed -i -e '/^  # Direct service endpoints (legacy support)$/d' \
                -e '/^  location \/services {$/,/^  }$/{/^  }$/!d;N;s/^  }\n//;/^$/d}' "${file_path}"
        fi

        # 2026-10: admin vhosts run only the control panel's api.php. Its other PHP files
        # (classes and controllers) answer 404 instead of running.
        if [[ "${file_path}" == /etc/nginx/admin/admin.*.conf ]] && grep -q '^  # PHP processing for control panel root$' "${file_path}"; then
            # Replace the comment and the block after it, up to the block's closing brace.
            sed -i '/^  # PHP processing for control panel root$/,/^  }$/c\
  # Control panel API: the only PHP file in the control panel that runs\
  location = /api.php {\
    include /etc/nginx/globals/php-fpm-admin.conf;\
  }\
\
  # Other PHP files in the control panel (classes and controllers that api.php\
  # loads) are not entry points: answer 404 rather than run or serve them.\
  location ~ \\.php$ {\
    return 404;\
  }' "${file_path}"
        fi

        # 2026-10: admin vhosts pass PHP through php-fpm-admin.conf (no FastCGI cache, no
        # WordPress cookie handling, no fallback to /index.php) instead of the sites' php-fpm.conf.
        # That file comes with an Nginx install or update: until then, keep (or put back)
        # php-fpm.conf, or a site created in between would make nginx -t fail.
        if [[ "${file_path}" == /etc/nginx/admin/admin.*.conf ]]; then
            if [[ -f /etc/nginx/globals/php-fpm-admin.conf ]]; then
                if grep -q 'include /etc/nginx/globals/php-fpm\.conf;' "${file_path}"; then
                    sed -i 's|include /etc/nginx/globals/php-fpm\.conf;|include /etc/nginx/globals/php-fpm-admin.conf;|' "${file_path}"
                fi
            elif grep -q 'include /etc/nginx/globals/php-fpm-admin\.conf;' "${file_path}"; then
                sed -i 's|include /etc/nginx/globals/php-fpm-admin\.conf;|include /etc/nginx/globals/php-fpm.conf;|' "${file_path}"
            fi
        fi

        # 2026-10: admin vhosts answer unknown paths with 404 instead of the dashboard page.
        # shellcheck disable=SC2016 # $uri is an Nginx variable, matched literally
        if [[ "${file_path}" == /etc/nginx/admin/admin.*.conf ]] && grep -qx '    try_files $uri $uri/ /index.html;' "${file_path}"; then
            sed -i -e '/^  # EngineScript Control Panel - Default Location (Landing Page)$/a\
  # The dashboard has no client-side routes, so an unknown path answers 404.' \
                -e 's|^    try_files \$uri \$uri/ /index\.html;$|    try_files $uri $uri/ =404;|' "${file_path}"
        fi

        # 2026-10: site vhosts log failed requests (status 400 and up) to their own log instead of
        # no access log at all. The $es_failed_request map is in nginx.conf, which only an Nginx
        # install or update replaces: until then, keep (or put back) "access_log off;", or a site
        # created in between would make nginx -t fail.
        if [[ "${file_path}" == /etc/nginx/sites-enabled/*.conf ]]; then
            local domain
            domain="$(basename "${file_path}" .conf)"
            # $es_failed_request is an Nginx variable, matched literally
            # shellcheck disable=SC2016
            if grep -q 'es_failed_request' /etc/nginx/nginx.conf 2> /dev/null; then
                if grep -qx '  access_log off;' "${file_path}"; then
                    mkdir -p "/var/log/domains/${domain}"
                    sed -i "s|^  access_log off;\$|  # Failed requests only (status 400 and up), written in batches\n  access_log /var/log/domains/${domain}/${domain}-nginx-failed.log main buffer=32k flush=5s if=\$es_failed_request;|" "${file_path}"
                fi
            elif grep -q 'if=\$es_failed_request' "${file_path}"; then
                sed -i -e '/^  # Failed requests only (status 400 and up), written in batches$/d' \
                    -e 's|^  access_log .*if=\$es_failed_request;$|  access_log off;|' "${file_path}"
            fi
        fi
    done
}


# ----------------------------------------------------------------
# Set permissions for PHP directories and files
#
# The PHP-FPM master process runs as root and loads the configuration and every extension it
# lists, so /etc/php must not be writable by www-data, the user the PHP workers run as.
function set_php_permissions() {
    # Configuration: root-owned, directories 755, files 644
    if [[ -d /etc/php ]]; then
        chown -R root:root /etc/php
        find /etc/php -type d -exec chmod 755 {} +
        find /etc/php -type f -exec chmod 644 {} +
    fi

    # Older installs logged to /var/log/php (see migrate_php_fpm_log_path). The FPM master
    # writes its log as root, so a root-owned directory keeps www-data from replacing the log
    # with a symlink.
    if [[ -d /var/log/php ]]; then
        chown root:root /var/log/php
        chmod 755 /var/log/php
        find /var/log/php -type f -exec chown root:adm {} + -exec chmod 640 {} +
    fi

    chmod 775 /var/cache/opcache
    chmod 775 /var/cache/php-sessions
    chmod 775 /var/cache/wsdlcache
    chown -R www-data:www-data /var/cache/opcache
    chown -R www-data:www-data /var/cache/php-sessions
    chown -R www-data:www-data /var/cache/wsdlcache
}


# ----------------------------------------------------------------
# Set permissions for Redis directories and files
#
# www-data is in the redis group so PHP can use Redis's socket. The socket needs nothing here:
# Redis creates it from unixsocketperm (770) on every start, in /run/redis, which systemd
# creates. The configuration and its directory are root-owned so neither www-data nor Redis
# itself can change or replace it (CONFIG REWRITE renames a new file over it), and the data and
# log files are not writable by the redis group. Redis's unit creates files with UMask 0007
# (group-writable), so this also runs from the daily permissions cron.
function set_redis_permissions() {
    if [[ -d /etc/redis ]]; then
        chown -R root:redis /etc/redis
        chmod u=rwx,g=rxs,o= /etc/redis
        find /etc/redis -mindepth 1 -type d -exec chmod 750 {} +
        find /etc/redis -type f -exec chmod 640 {} +
    fi
    if [[ -d /var/lib/redis ]]; then
        chown redis:redis /var/lib/redis
        chmod 750 /var/lib/redis
        find /var/lib/redis -mindepth 1 -type d -exec chmod 750 {} +
        find /var/lib/redis -type f -exec chown redis:redis {} + -exec chmod 640 {} +
    fi
    if [[ -d /var/log/redis ]]; then
        chown redis:adm /var/log/redis
        chmod u=rwx,g=rxs,o= /var/log/redis
        find /var/log/redis -type f -exec chown redis:adm {} + -exec chmod 640 {} +
    fi
}


# ----------------------------------------------------------------
# Redis systemd override: if memory runs out, the kernel's OOM killer picks a PHP-FPM worker
# (replaced at once) before Redis (-300), and Redis before MariaDB (-600). Losing Redis shows
# Redis Object Cache's error page on every site until it restarts.
function install_redis_service_override() {
    mkdir -p /etc/systemd/system/redis-server.service.d
    cat > /etc/systemd/system/redis-server.service.d/enginescript.conf << 'EOF'
[Service]
OOMScoreAdjust=-300
EOF
    systemctl daemon-reload
}


# ----------------------------------------------------------------
# Load a redis.conf in a throwaway Redis (own socket, no TCP, temporary directory) and stop it.
# Returns 0 when it answered PING. Its output and log go to the file given as the second argument
# (Redis prints configuration errors on stderr, not in its log).
function test_redis_conf() {
    local candidate="$1" output="$2" test_dir test_pid ok=1

    test_dir="$(mktemp -d)"
    chown redis:redis "${test_dir}"
    chmod 644 "${candidate}"
    # The root-owned output file is opened by this shell on purpose; Redis only writes to it
    # shellcheck disable=SC2024
    sudo -u redis redis-server "${candidate}" --port 0 --unixsocket "${test_dir}/test.sock" --daemonize no \
        --supervised no --logfile "${test_dir}/test.log" --dir "${test_dir}" --pidfile "${test_dir}/test.pid" > "${output}" 2>&1 &
    test_pid=$!
    for _ in $(seq 1 20); do
        if [[ "$(redis-cli -s "${test_dir}/test.sock" PING 2> /dev/null)" == "PONG" ]]; then ok=0; break; fi
        kill -0 "${test_pid}" 2> /dev/null || break
        sleep 0.25
    done
    redis-cli -s "${test_dir}/test.sock" SHUTDOWN NOSAVE > /dev/null 2>&1
    wait "${test_pid}" 2> /dev/null
    cat "${test_dir}/test.log" >> "${output}" 2> /dev/null
    rm -rf "${test_dir}"
    return "${ok}"
}


# ----------------------------------------------------------------
# Apply the shared tuning plan to an installed Redis without restarting it
#
# Rebuilds /etc/redis/redis.conf from the repo template with the plan's maxmemory, keeping the
# server's current "databases" count (it doubles when every number is taken). The new file is
# loaded by a throwaway Redis on a temporary socket first; if that fails, nothing changes.
# maxmemory and activedefrag are applied to the running Redis with CONFIG SET; settings that
# need a restart (io-threads) take effect at Redis's next restart. Redis Object Cache shows an
# error page on every site while Redis is down, so this never restarts it.
function apply_redis_tuning() {
    local conf=/etc/redis/redis.conf template=/usr/local/bin/enginescript/config/etc/redis/redis.conf
    local sock=/run/redis/redis-server.sock candidate test_output databases maxmemory defrag=yes

    [[ -f "${conf}" && -f "${template}" ]] || return 0
    tuning_load
    maxmemory="$(tuning_get REDIS_MAXMEMORY_MB)"
    [[ -n "${maxmemory}" ]] || { echo "Error: No Redis maxmemory in the tuning plan." >&2; return 1; }
    databases="$(awk '$1 == "databases" {print $2; exit}' "${conf}")"
    [[ "${databases}" =~ ^[0-9]+$ ]] && (( databases > REDIS_MIN_DATABASES )) || databases="${REDIS_MIN_DATABASES}"

    candidate="$(mktemp)"
    test_output="$(mktemp)"
    sed -e "s|SEDREDISMAXMEM|${maxmemory}|g" -e "s|^databases .*|databases ${databases}|" "${template}" > "${candidate}"
    if cmp -s "${candidate}" "${conf}"; then
        rm -f "${candidate}" "${test_output}"
        return 0
    fi

    if ! test_redis_conf "${candidate}" "${test_output}"; then
        # Ubuntu's own Redis package is built without the jemalloc that active defragmentation
        # needs and refuses "activedefrag yes"; keep the rest of the plan on those servers
        if grep -q 'Active defragmentation cannot be enabled' "${test_output}"; then
            sed -i 's|^activedefrag yes$|activedefrag no|' "${candidate}"
            defrag=no
            if cmp -s "${candidate}" "${conf}"; then
                rm -f "${candidate}" "${test_output}"
                return 0
            fi
        fi
        if [[ "${defrag}" == "yes" ]] || ! test_redis_conf "${candidate}" "${test_output}"; then
            echo "Error: The new redis.conf did not load in a test instance; kept the current one." >&2
            tail -5 "${test_output}" >&2
            rm -f "${candidate}" "${test_output}"
            return 1
        fi
    fi
    rm -f "${test_output}"

    cp -p "${conf}" "${conf}.bak"
    mv -f "${candidate}" "${conf}"
    set_redis_permissions
    if [[ -S "${sock}" ]]; then
        redis-cli -s "${sock}" CONFIG SET maxmemory "${maxmemory}mb" > /dev/null
        redis-cli -s "${sock}" CONFIG SET activedefrag "${defrag}" > /dev/null
    fi
    echo "Redis: applied the tuning plan (maxmemory ${maxmemory} MB) without a restart."
    if [[ "${defrag}" == "no" ]]; then
        echo "Redis: this Redis cannot run active defragmentation (Ubuntu's own package), so it stays off."
        echo "       EngineScript installs Redis from packages.redis.io, which supports it."
    fi
}


# ----------------------------------------------------------------
# Set the OOM killer priority of a running service's processes (its systemd override applies
# from its next start). Usage: set_running_oom_score_adj <process name> <score>
function set_running_oom_score_adj() {
    local pid
    for pid in $(pgrep -x "$1"); do
        echo "$2" > "/proc/${pid}/oom_score_adj" 2> /dev/null || true
    done
}


# ----------------------------------------------------------------
# Apply the shared tuning plan to an installed MariaDB without restarting it
#
# Builds the new my.cnf from the repo template in a staging file (mariadb-tune.sh), checks it
# with mariadbd --help --verbose, installs it, and applies every setting MariaDB can change while
# running with SET GLOBAL. aria_pagecache_buffer_size, innodb_log_buffer_size, and
# innodb_open_files take effect at MariaDB's next restart. The previous file is kept as
# /etc/mysql/my.cnf.enginescript-previous.
function apply_mariadb_tuning() {
    local staged=/etc/mysql/my.cnf.enginescript-new check rc io_max statement failed=0

    [[ -e /etc/mysql/my.cnf ]] && command -v mariadbd > /dev/null 2>&1 || return 0
    cp -f /usr/local/bin/enginescript/config/etc/mysql/my.cnf "${staged}"
    install -d -o mysql -g mysql -m 750 /var/lib/mysql-files
    if ! /usr/local/bin/enginescript/scripts/install/mariadb/mariadb-tune.sh "${staged}" 2>> /tmp/enginescript_install_errors.log; then
        echo "Error: Tuning the new MariaDB configuration failed; kept the current one." >&2
        rm -f "${staged}"
        return 1
    fi
    check="$(mariadbd --defaults-file="${staged}" --help --verbose 2>&1 > /dev/null)"
    rc=$?
    if [[ "${rc}" -ne 0 ]] || grep -q '\[ERROR\]' <<< "${check}"; then
        echo "Error: The new MariaDB configuration failed its check; kept the current one:" >&2
        grep -E '\[(ERROR|Warning)\]' <<< "${check}" | head -5 >&2
        rm -f "${staged}"
        return 1
    fi
    if cmp -s "${staged}" /etc/mysql/my.cnf; then
        rm -f "${staged}"
        return 0
    fi

    # cp writes through /etc/mysql/my.cnf, the MariaDB packages' link to mariadb.cnf
    cp -fL /etc/mysql/my.cnf /etc/mysql/my.cnf.enginescript-previous
    cp -f "${staged}" /etc/mysql/my.cnf
    rm -f "${staged}"

    tuning_load
    io_max=$(( $(tuning_get MARIADB_IO_CAPACITY) * 2 ))
    (( io_max < 2000 )) && io_max=2000
    for statement in \
        "SET GLOBAL max_connections = $(tuning_get MARIADB_MAX_CONNECTIONS)" \
        "SET GLOBAL tmp_table_size = $(( $(tuning_get MARIADB_TMP_TABLE_MB) * 1048576 ))" \
        "SET GLOBAL max_heap_table_size = $(( $(tuning_get MARIADB_TMP_TABLE_MB) * 1048576 ))" \
        "SET GLOBAL table_open_cache = $(tuning_get MARIADB_TABLE_CACHE)" \
        "SET GLOBAL table_definition_cache = $(tuning_get MARIADB_TABLE_CACHE)" \
        "SET GLOBAL innodb_io_capacity_max = ${io_max}" \
        "SET GLOBAL innodb_io_capacity = $(tuning_get MARIADB_IO_CAPACITY)" \
        "SET GLOBAL innodb_flush_neighbors = 0" \
        "SET GLOBAL innodb_log_file_size = $(( $(tuning_get MARIADB_LOG_FILE_MB) * 1048576 ))" \
        "SET GLOBAL innodb_buffer_pool_size = $(( $(tuning_get MARIADB_BUFFER_POOL_MB) * 1048576 ))"; do
        if ! mariadb -e "${statement}" 2>> /tmp/enginescript_install_errors.log; then
            echo "Warning: MariaDB refused \"${statement}\"; it applies at MariaDB's next restart." >&2
            failed=1
        fi
    done
    set_running_oom_score_adj mariadbd -600
    if (( failed == 0 )); then
        echo "MariaDB: applied the tuning plan (buffer pool $(tuning_get MARIADB_BUFFER_POOL_MB) MB) without a restart."
    else
        echo "MariaDB: installed the tuning plan; the settings above apply at MariaDB's next restart."
    fi
}


# ----------------------------------------------------------------
# Apply the shared tuning plan's Nginx values to the running nginx.conf
#
# Patches the FastCGI cache index and disk limit, and the October 2026 tuning (cache inactive
# 3h with min_free, keepalive_timeout 900s, open_file_cache_errors off, worker_connections 4096,
# worker_rlimit_nofile 16384), tests with nginx -t, and reloads; the previous file is restored if
# the test or the reload fails. Other template changes arrive with the next Nginx update.
function apply_nginx_tuning() {
    local conf=/etc/nginx/nginx.conf backup

    [[ -f "${conf}" ]] && command -v nginx > /dev/null 2>&1 || return 0
    tuning_load
    backup="$(mktemp)"
    cp -p "${conf}" "${backup}"
    sed -i -E \
        -e "s|keys_zone=EngineScriptWP:[0-9]+m|keys_zone=EngineScriptWP:$(tuning_get NGINX_CACHE_ZONE_MB)m|" \
        -e "s|(fastcgi_cache_path [^;]*) inactive=[0-9]+[a-z]|\1 inactive=3h|" \
        -e "s|(fastcgi_cache_path [^;]*) max_size=[0-9]+m|\1 max_size=$(tuning_get NGINX_CACHE_MAX_MB)m|" \
        -e "/fastcgi_cache_path/{/min_free=/!s| use_temp_path=| min_free=1g use_temp_path=|}" \
        -e "s|^([[:space:]]*)keepalive_timeout [0-9]+s?;|\1keepalive_timeout 900s;|" \
        -e "s|^([[:space:]]*)open_file_cache_errors on;|\1open_file_cache_errors off;|" \
        -e "s|^([[:space:]]*)worker_connections [0-9]+;|\1worker_connections 4096;|" \
        -e "s|^worker_rlimit_nofile [0-9]+;|worker_rlimit_nofile 16384;|" \
        "${conf}"
    if cmp -s "${conf}" "${backup}"; then
        rm -f "${backup}"
        return 0
    fi
    if ! nginx -t > /dev/null 2>&1; then
        cp -p "${backup}" "${conf}"
        echo "Error: nginx -t failed with the tuned nginx.conf; restored the previous one." >&2
        nginx -t 2>&1 | tail -3 >&2
        rm -f "${backup}"
        return 1
    fi
    # A stopped Nginx reads the new file when it starts. If the reload fails, the previous file
    # is restored, so the next re-tune applies the plan again instead of finding nothing to change.
    if systemctl is-active --quiet nginx && ! systemctl reload nginx; then
        cp -p "${backup}" "${conf}"
        echo "Error: Nginx did not reload with the tuned nginx.conf; restored the previous one." >&2
        rm -f "${backup}"
        return 1
    fi
    echo "Nginx: applied the tuning plan (cache index $(tuning_get NGINX_CACHE_ZONE_MB) MB, cache limit $(tuning_get NGINX_CACHE_MAX_MB) MB)."
    rm -f "${backup}"
}


# ----------------------------------------------------------------
# Redis database numbers of the sites
#
# Each site uses its own Redis database (WP_REDIS_DATABASE in its wp-config.php), so the Redis
# Object Cache plugin's "flush cache" (FLUSHDB) empties only that site's cache. "databases" in
# redis.conf sets how many exist (128; each costs about 6 KB). A new site gets the lowest number
# no other site uses, so removing a site frees its number. ES_REDIS_CONF and ES_SITES_ROOT
# override the paths (for tests).
REDIS_MIN_DATABASES=128

# Print the number of databases redis.conf sets
function get_redis_database_count() {
    awk '$1 == "databases" {print $2; exit}' "${ES_REDIS_CONF:-/etc/redis/redis.conf}"
}

# Print the Redis database number a wp-config.php sets (nothing when it sets none)
function get_site_redis_database() {
    sed -n "s/^[[:space:]]*define([[:space:]]*['\"]WP_REDIS_DATABASE['\"][[:space:]]*,[[:space:]]*\([0-9]\{1,\}\)[[:space:]]*).*/\1/p" "$1" | head -n 1
}

# Print "<number> <wp-config.php>" for every site that sets a Redis database
function list_site_redis_databases() {
    local wp_config number
    for wp_config in "${ES_SITES_ROOT:-/var/www/sites}"/*/html/wp-config.php; do
        [[ -f "${wp_config}" ]] || continue
        number="$(get_site_redis_database "${wp_config}")"
        if [[ -n "${number}" ]]; then
            echo "${number} ${wp_config}"
        fi
    done
}

# Set "databases" in redis.conf and restart Redis (which empties every site's object cache:
# the setting cannot change while Redis runs)
function set_redis_database_count() {
    sed -i "s/^databases[[:space:]]\{1,\}[0-9]\{1,\}[[:space:]]*$/databases $1/" "${ES_REDIS_CONF:-/etc/redis/redis.conf}"
    restart_service "redis-server"
}

# Give a site (its wp-config.php) the lowest Redis database number that no other site uses. When
# every number is taken, the number of databases is doubled.
function assign_site_redis_database() {
    local wp_config="$1" count number site_config
    local -A taken=()

    count="$(get_redis_database_count)"
    if [[ ! "${count}" =~ ^[0-9]+$ ]]; then
        echo "Error: No 'databases' setting in ${ES_REDIS_CONF:-/etc/redis/redis.conf}; the site keeps its Redis database number." >&2
        return 1
    fi

    while read -r number site_config; do
        if [[ "${site_config}" != "${wp_config}" ]]; then
            taken["${number}"]=1
        fi
    done < <(list_site_redis_databases)

    for ((number = 0; number < count; number++)); do
        [[ -z "${taken[${number}]:-}" ]] && break
    done
    if (( number >= count )); then
        echo "All ${count} Redis databases are in use. Raising the number of databases to $((count * 2)); Redis restarts, which empties every site's object cache."
        set_redis_database_count $((count * 2))
    fi

    sed -i "s/^\([[:space:]]*define([[:space:]]*['\"]WP_REDIS_DATABASE['\"][[:space:]]*,[[:space:]]*\)[0-9]\{1,\}/\1${number}/" "${wp_config}"
    if [[ "$(get_site_redis_database "${wp_config}")" != "${number}" ]]; then
        echo "Error: Could not set WP_REDIS_DATABASE in ${wp_config}." >&2
        return 1
    fi
    echo "Redis database ${number}: ${wp_config}"
}

# Delete one site's keys from Redis, for a site being removed, without restarting Redis or
# touching other sites' caches. Redis Object Cache names keys
# "<WP_REDIS_PREFIX><table prefix without _-:$ at its ends>:<group>:<key>", so the match is
# exact even where two sites still share a database number.
function flush_site_redis_cache() {
    local wp_config="$1" number salt table_prefix pattern
    local -a cli=(redis-cli -s /run/redis/redis-server.sock)

    [[ -f "${wp_config}" ]] || return 0
    number="$(get_site_redis_database "${wp_config}")"
    salt="$(sed -n "s/^[[:space:]]*define([[:space:]]*['\"]WP_REDIS_PREFIX['\"][[:space:]]*,[[:space:]]*['\"]\([^'\"]*\)['\"].*/\1/p" "${wp_config}" | head -n 1)"
    table_prefix="$(sed -n "s/^[[:space:]]*\$table_prefix[[:space:]]*=[[:space:]]*['\"]\([^'\"]*\)['\"].*/\1/p" "${wp_config}" | head -n 1)"
    table_prefix="$(sed -e 's/^[-_:$]*//' -e 's/[-_:$]*$//' <<< "${table_prefix}")"
    if [[ ! "${number}" =~ ^[0-9]+$ || ! "${salt}" =~ ^[A-Za-z0-9_.-]+$ || ! "${table_prefix}" =~ ^[A-Za-z0-9_]*$ ]]; then
        echo "No usable Redis database or key prefix in ${wp_config}; nothing deleted from Redis."
        return 0
    fi
    pattern="${salt}${table_prefix}:*"
    "${cli[@]}" -n "${number}" --scan --pattern "${pattern}" | xargs -r -n 500 "${cli[@]}" -n "${number}" UNLINK > /dev/null
    echo "Deleted the site's Redis keys (${pattern}) from database ${number}."
}

# Existing servers: at least REDIS_MIN_DATABASES databases, and every site on its own number.
# Earlier versions numbered sites by the site count, so a site added after a removal could share
# a number with another site. The first site (in directory order) keeps a shared number; the
# others move to free numbers, which only empties their object cache.
function migrate_redis_databases() {
    local count number wp_config
    local -a moves=()
    local -A taken=()

    [[ -f "${ES_REDIS_CONF:-/etc/redis/redis.conf}" ]] || return 0
    count="$(get_redis_database_count)"
    [[ "${count}" =~ ^[0-9]+$ ]] || return 0

    if (( count < REDIS_MIN_DATABASES )); then
        echo "Raising the number of Redis databases from ${count} to ${REDIS_MIN_DATABASES}..."
        set_redis_database_count "${REDIS_MIN_DATABASES}"
        count="${REDIS_MIN_DATABASES}"
    fi

    while read -r number wp_config; do
        if (( number < count )) && [[ -z "${taken[${number}]:-}" ]]; then
            taken["${number}"]=1
        else
            moves+=("${wp_config}")
        fi
    done < <(list_site_redis_databases)

    for wp_config in "${moves[@]}"; do
        echo "Moving a site that shared its Redis database (or used one out of range) to a free one:"
        assign_site_redis_database "${wp_config}"
    done
}

# Existing servers: FLUSHDB and FLUSHALL (the Redis Object Cache plugin's and the control panel's
# cache buttons) free memory in the background instead of blocking Redis for every site
# (lazyfree-lazy-user-flush). Added after lazyfree-lazy-user-del unless the file already sets
# it, and applied to the running Redis, which can change it without a restart.
function migrate_redis_lazy_user_flush() {
    local redis_conf="${ES_REDIS_CONF:-/etc/redis/redis.conf}"

    [[ -f "${redis_conf}" ]] || return 0
    grep -q '^lazyfree-lazy-user-flush[[:space:]]' "${redis_conf}" && return 0

    echo "Redis: freeing memory in the background on cache flushes (lazyfree-lazy-user-flush)..."
    if grep -q '^lazyfree-lazy-user-del[[:space:]]' "${redis_conf}"; then
        sed -i '/^lazyfree-lazy-user-del[[:space:]]/a lazyfree-lazy-user-flush yes' "${redis_conf}"
    else
        echo "lazyfree-lazy-user-flush yes" >> "${redis_conf}"
    fi
    if [[ "$(redis-cli -s /run/redis/redis-server.sock CONFIG SET lazyfree-lazy-user-flush yes 2> /dev/null)" != "OK" ]]; then
        echo "Redis is not running; the setting applies when it starts."
    fi
}


# ----------------------------------------------------------------
# Resolve the backup settings
#
# The install options set BACKUP_DATABASE_FREQUENCY (off | hourly | daily),
# BACKUP_FILES_FREQUENCY (off | daily | weekly), BACKUP_CONFIG_FREQUENCY (off | daily), their
# retention, and the Amazon S3 settings. Options files written before these settings existed
# keep working: their per-type switches (HOURLY_LOCAL_DATABASE_BACKUP,
# DAILY_LOCAL_DATABASE_BACKUP, WEEKLY_LOCAL_WPCONTENT_BACKUP, INSTALL_S3_BACKUP and the S3
# switches) are translated here. Invalid values fall back to the defaults with a warning.
function resolve_backup_settings() {
    if [[ -z "${BACKUP_DATABASE_FREQUENCY:-}" ]]; then
        if [[ "${HOURLY_LOCAL_DATABASE_BACKUP:-0}" == "1" ]]; then
            BACKUP_DATABASE_FREQUENCY="hourly"
        elif [[ "${DAILY_LOCAL_DATABASE_BACKUP:-0}" == "1" ]]; then
            BACKUP_DATABASE_FREQUENCY="daily"
        else
            BACKUP_DATABASE_FREQUENCY="off"
        fi
    fi
    if [[ -z "${BACKUP_FILES_FREQUENCY:-}" ]]; then
        if [[ "${WEEKLY_LOCAL_WPCONTENT_BACKUP:-0}" == "1" ]]; then
            BACKUP_FILES_FREQUENCY="weekly"
        else
            BACKUP_FILES_FREQUENCY="off"
        fi
    fi
    BACKUP_CONFIG_FREQUENCY="${BACKUP_CONFIG_FREQUENCY:-daily}"
    if [[ -z "${BACKUP_S3:-}" ]]; then
        BACKUP_S3=0
        if [[ "${INSTALL_S3_BACKUP:-0}" == "1" ]] && [[ "${DAILY_S3_DATABASE_BACKUP:-0}" == "1" \
            || "${HOURLY_S3_DATABASE_BACKUP:-0}" == "1" || "${WEEKLY_S3_WPCONTENT_BACKUP:-0}" == "1" ]]; then
            BACKUP_S3=1
        fi
    fi
    BACKUP_S3_INCLUDE_CONFIG="${BACKUP_S3_INCLUDE_CONFIG:-0}"
    # Empty: EngineScript never deletes anything from S3
    BACKUP_S3_KEEP_DAYS="${BACKUP_S3_KEEP_DAYS:-}"

    case "${BACKUP_DATABASE_FREQUENCY}" in off|hourly|daily) ;; *)
        echo "Warning: BACKUP_DATABASE_FREQUENCY='${BACKUP_DATABASE_FREQUENCY}' is not off, hourly, or daily; using daily." >&2
        BACKUP_DATABASE_FREQUENCY="daily" ;; esac
    case "${BACKUP_FILES_FREQUENCY}" in off|daily|weekly) ;; *)
        echo "Warning: BACKUP_FILES_FREQUENCY='${BACKUP_FILES_FREQUENCY}' is not off, daily, or weekly; using weekly." >&2
        BACKUP_FILES_FREQUENCY="weekly" ;; esac
    case "${BACKUP_CONFIG_FREQUENCY}" in off|daily) ;; *)
        echo "Warning: BACKUP_CONFIG_FREQUENCY='${BACKUP_CONFIG_FREQUENCY}' is not off or daily; using daily." >&2
        BACKUP_CONFIG_FREQUENCY="daily" ;; esac
    [[ "${BACKUP_S3}" == "1" ]] || BACKUP_S3=0
    [[ "${BACKUP_S3_INCLUDE_CONFIG}" == "1" ]] || BACKUP_S3_INCLUDE_CONFIG=0

    local setting default
    for setting in BACKUP_DATABASE_KEEP_DAYS:30 BACKUP_FILES_KEEP_COPIES:4 BACKUP_CONFIG_KEEP_DAYS:30; do
        default="${setting#*:}"
        setting="${setting%%:*}"
        if [[ -z "${!setting:-}" ]]; then
            printf -v "${setting}" '%s' "${default}"
        elif [[ ! "${!setting}" =~ ^[1-9][0-9]*$ ]]; then
            echo "Warning: ${setting}='${!setting}' is not a whole number above 0; using ${default}." >&2
            printf -v "${setting}" '%s' "${default}"
        fi
    done
    if [[ -n "${BACKUP_S3_KEEP_DAYS}" && ! "${BACKUP_S3_KEEP_DAYS}" =~ ^[1-9][0-9]*$ ]]; then
        echo "Warning: BACKUP_S3_KEEP_DAYS='${BACKUP_S3_KEEP_DAYS}' is not a whole number above 0; S3 backups are not deleted." >&2
        BACKUP_S3_KEEP_DAYS=""
    fi
}


# ----------------------------------------------------------------
# Install the backup scheduler cron job
#
# enginescript-backup.sh runs every hour and reads the backup frequencies from the install
# options, so changing a setting needs no cron change. Older installs had a separate cron job
# per backup script; those are replaced. Safe to run again.
function install_backup_cron() {
    local scheduler="5 * * * * cd /usr/local/bin/enginescript/scripts/functions/backup; bash enginescript-backup.sh scheduled >/dev/null 2>&1"
    local legacy='daily-database-backup\.sh|hourly-database-backup\.sh|weekly-wp-content-backup\.sh'
    local current

    current="$(crontab -l 2> /dev/null)" || current=""
    if ! grep -qE "${legacy}" <<< "${current}" && grep -qxF "${scheduler}" <<< "${current}"; then
        return 0
    fi
    echo "Installing the backup scheduler cron job (replaces the separate backup jobs)..."
    {
        grep -vE "${legacy}" <<< "${current}" | grep -vxF "${scheduler}" | sed '/^$/d'
        echo "${scheduler}"
    } | crontab -
}


# ----------------------------------------------------------------
# Remove the control panel's API cache sweep cron job
#
# The job deleted the panel's API cache files every minute. Cache entries expire on their own
# after 60 seconds (BaseController::CACHE_TTL), so the job and its script were removed. Safe to
# run again.
function remove_api_cache_sweep_cron() {
    local current

    current="$(crontab -l 2> /dev/null)" || return 0
    if grep -qF 'sweep-api-cache.sh' <<< "${current}"; then
        echo "Removing the API cache sweep cron job..."
        grep -vF 'sweep-api-cache.sh' <<< "${current}" | crontab -
    fi
}


# ----------------------------------------------------------------
# Set permissions for /home/EngineScript
#
# It holds the install options (the MariaDB root password, the Cloudflare API key, admin
# passwords), database and configuration backups (including TLS private keys), and site
# database credentials. Only root uses it, so nothing else may read it.
function set_enginescript_home_permissions() {
    if [[ -d /home/EngineScript ]]; then
        chown root:root /home/EngineScript
        chmod 700 /home/EngineScript
    fi
    if [[ -f /home/EngineScript/enginescript-install-options.txt ]]; then
        chmod 600 /home/EngineScript/enginescript-install-options.txt
    fi
}


# ----------------------------------------------------------------
# Move the PHP-FPM log back to the package default
#
# EngineScript used to set error_log = /var/log/php/phpX.Y-fpm.log, which no logrotate file
# covers, so the log grew without limit. The PHP package logs to /var/log/phpX.Y-fpm.log and
# rotates it with its own logrotate file. This changes only the error_log line of existing
# installs, tests the configuration, and reloads PHP-FPM.
function migrate_php_fpm_log_path() {
    local conf ver old_log
    for conf in /etc/php/*/fpm/php-fpm.conf; do
        [[ -f "${conf}" ]] || continue
        ver="$(basename "$(dirname "$(dirname "${conf}")")")"
        old_log="/var/log/php/php${ver}-fpm.log"
        grep -q "^error_log = ${old_log}$" "${conf}" || continue

        echo "Moving the PHP ${ver} FPM log to /var/log/php${ver}-fpm.log..."
        cp -p "${conf}" "${conf}.pre-log-migration"
        sed -i "s|^error_log = ${old_log}$|error_log = /var/log/php${ver}-fpm.log|" "${conf}"
        if ! "php-fpm${ver}" -t > /dev/null 2>&1; then
            echo "Error: php-fpm${ver} -t failed; kept the previous PHP-FPM log setting." >&2
            mv -f "${conf}.pre-log-migration" "${conf}"
            continue
        fi
        rm -f "${conf}.pre-log-migration"

        # A reload (graceful restart) rereads php-fpm.conf and opens the new log
        if systemctl is-active --quiet "php${ver}-fpm"; then
            systemctl reload "php${ver}-fpm"
        fi
        if [[ -f "${old_log}" ]]; then
            mv -f "${old_log}" "${old_log}.old"
        fi
    done
}


# ----------------------------------------------------------------
# Install EngineScript's kernel settings and apply them
#
# Installs config/etc/sysctl.d/60-enginescript.conf (root-only writable) and the kernel TLS
# module (Nginx uses kTLS), then applies all sysctl files. Settings removed from the file in
# October 2026 keep their old value until the next reboot, so the ones with fixed defaults that
# mattered are reset now: the local port range (1024 - 65535 let outgoing connections take
# MariaDB's and Redis's ports), the Unix datagram queue (50 cut systemd's 512), the IP fragment
# limits (a 2018 workaround), ECN, and the default socket buffers. The others (file-max,
# nr_open, inotify, the network budget) return to their defaults at the next reboot.
function install_enginescript_sysctl() {
    local conf=/etc/sysctl.d/60-enginescript.conf
    cp -f /usr/local/bin/enginescript/config/etc/sysctl.d/60-enginescript.conf "${conf}"
    chown root:root "${conf}"
    chmod 644 "${conf}"

    echo tls > /etc/modules-load.d/tls.conf
    modprobe tls 2> /dev/null || true

    sysctl -w net.ipv4.ip_local_port_range="32768 60999" > /dev/null 2>&1
    sysctl -w net.unix.max_dgram_qlen=512 > /dev/null 2>&1
    sysctl -w net.ipv4.ipfrag_high_thresh=4194304 net.ipv4.ipfrag_low_thresh=3145728 > /dev/null 2>&1
    sysctl -w net.ipv6.ip6frag_high_thresh=4194304 net.ipv6.ip6frag_low_thresh=3145728 > /dev/null 2>&1
    sysctl -w net.ipv4.tcp_ecn=2 > /dev/null 2>&1
    sysctl -w net.core.rmem_default=212992 net.core.wmem_default=212992 > /dev/null 2>&1

    sysctl --system > /dev/null 2>> /tmp/enginescript_install_errors.log || true
}


# ----------------------------------------------------------------
# Turn off Kernel Samepage Merging on servers that installed it
#
# EngineScript installed ksmtuned for Netdata, which marks its memory mergeable. Netdata is no
# longer installed, and Nginx, PHP-FPM, MariaDB, and Redis never mark memory mergeable (tested:
# no "mg" regions), so KSM had nothing to merge and only cost CPU when ksmtuned started it.
function disable_ksm() {
    local unit
    for unit in ksmtuned.service ksm.service; do
        if systemctl list-unit-files "${unit}" 2> /dev/null | grep -q "^${unit}"; then
            systemctl disable --now "${unit}" > /dev/null 2>&1
        fi
    done
    if [[ -w /sys/kernel/mm/ksm/run ]] && [[ "$(cat /sys/kernel/mm/ksm/run)" != "0" ]]; then
        echo 0 > /sys/kernel/mm/ksm/run
    fi
}


# ----------------------------------------------------------------
# Install igbinary explicitly for every installed PHP version
#
# Redis Object Cache serializes with it (WP_REDIS_IGBINARY). Existing servers only have it as a
# dependency of php-redis, marked automatically installed, so apt autoremove would remove it if
# php-redis ever stopped requiring it. Installing it by name marks it manually installed, and
# adds it where it is missing (then PHP-FPM reloads to load the extension).
function ensure_php_igbinary() {
    local ver
    while IFS= read -r ver; do
        [[ -n "${ver}" ]] || continue
        if dpkg-query -W -f='${Status}' "php${ver}-igbinary" 2> /dev/null | grep -q 'install ok installed'; then
            apt-mark manual "php${ver}-igbinary" > /dev/null
            continue
        fi
        echo "Installing php${ver}-igbinary..."
        if apt-get install -y -qq "php${ver}-igbinary" > /dev/null; then
            if systemctl is-active --quiet "php${ver}-fpm"; then
                systemctl reload "php${ver}-fpm"
            fi
        else
            echo "Error: Installing php${ver}-igbinary failed." >&2
        fi
    done < <(get_installed_php_versions)
}


# ----------------------------------------------------------------
# Turn off PHP's session upload progress on existing installs
#
# session.upload_progress writes data from any upload request into a PHP session file, a known
# step in attacks that include session files, and WordPress does not use it. php.ini from the
# repo only reaches a server on a PHP install or version switch, so this sets
# session.upload_progress.enabled = Off in each installed version's PHP-FPM php.ini, tests the
# configuration, and reloads PHP-FPM. ES_PHP_ETC overrides /etc/php (for tests).
function migrate_php_upload_progress() {
    local ini ver
    for ini in "${ES_PHP_ETC:-/etc/php}"/*/fpm/php.ini; do
        [[ -f "${ini}" ]] || continue
        grep -qiE '^[[:space:]]*session\.upload_progress\.enabled[[:space:]]*=[[:space:]]*"?(off|0|false|no)"?[[:space:]]*$' "${ini}" && continue
        ver="$(basename "$(dirname "$(dirname "${ini}")")")"

        echo "Turning off session upload progress for PHP ${ver}..."
        cp -p "${ini}" "${ini}.pre-upload-progress"
        if grep -qE '^[[:space:]]*session\.upload_progress\.enabled[[:space:]]*=' "${ini}"; then
            sed -i -E 's/^[[:space:]]*session\.upload_progress\.enabled[[:space:]]*=.*/session.upload_progress.enabled = Off/' "${ini}"
        elif grep -qE '^;[[:space:]]*session\.upload_progress\.enabled[[:space:]]*=' "${ini}"; then
            sed -i -E '0,/^;[[:space:]]*session\.upload_progress\.enabled[[:space:]]*=.*/s//session.upload_progress.enabled = Off/' "${ini}"
        elif grep -q '^\[Session\]' "${ini}"; then
            sed -i '/^\[Session\]/a session.upload_progress.enabled = Off' "${ini}"
        else
            echo "session.upload_progress.enabled = Off" >> "${ini}"
        fi

        if ! "php-fpm${ver}" -t > /dev/null 2>&1; then
            echo "Error: php-fpm${ver} -t failed; kept the previous php.ini." >&2
            mv -f "${ini}.pre-upload-progress" "${ini}"
            continue
        fi
        rm -f "${ini}.pre-upload-progress"

        # A reload (graceful restart) starts new workers with the changed php.ini
        if systemctl is-active --quiet "php${ver}-fpm"; then
            systemctl reload "php${ver}-fpm"
        fi
    done
}


# ----------------------------------------------------------------
# Check if all required EngineScript installation steps are completed
# Returns 0 if all installation steps are marked complete, returns 1 if incomplete
function check_installation_completion() {
    local install_log="${ENGINESCRIPT_INSTALL_STATE_FILE:-/etc/enginescript/install-state.conf}"
    local install_options="${ENGINESCRIPT_INSTALL_OPTIONS_FILE:-/home/EngineScript/enginescript-install-options.txt}"
    local missing_steps=()
    local install_log_found="false"
    local quiet_mode="${1:-false}"  # Optional parameter to suppress success output
    local wp_cli_bin="${ENGINESCRIPT_WP_CLI_BIN:-/usr/local/bin/wp}"
    local admin_control_panel_path="${ENGINESCRIPT_ADMIN_CONTROL_PANEL_PATH:-/var/www/admin/control-panel/index.html}"
    local phpmyadmin_path="${ENGINESCRIPT_PHPMYADMIN_PATH:-/var/www/admin/tools/phpmyadmin/config.inc.php}"

    if [[ -f "$install_options" ]]; then
        # shellcheck disable=SC1090
        source "$install_options" 2>/dev/null || true
    fi

    initialize_install_state_file

    # Keep this in the same order as the run_install_step calls in enginescript-install.sh.
    local installation_steps=(
        "REPOS|Install Repositories"
        "REMOVES|Remove Preinstalled Software"
        "BLOCK|Block Unwanted Packages"
        "UBUNTU_PRO|Ubuntu Pro Setup"
        "DEPENDS|Install Dependencies"
        "CRON|Cron"
        "ACME|ACME.sh"
        "GCC|GCC"
        "OPENSSL|OpenSSL"
        "SWAP|Swap"
        "KERNEL_TWEAKS|Kernel Tweaks"
        "THP|Transparent Huge Pages"
        "SFL|Raising System File Limits"
        "NTP|NTP"
    )

    if [[ "${INSTALL_DIGITALOCEAN_REMOTE_CONSOLE:-0}" = "1" ]]; then
        installation_steps+=("DO_CONSOLE|DigitalOcean Remote Console")
    fi

    installation_steps+=(
        "PCRE|PCRE"
        "ZLIB|zlib"
        "LIBURING|liburing"
        "UFW|UFW"
        "MARIADB|MariaDB"
        "PHP|PHP"
        "REDIS|Redis"
        "NGINX|Nginx"
    )

    if [[ "${INSTALL_PHPMYADMIN:-0}" = "1" ]]; then
        installation_steps+=("PHPMYADMIN|phpMyAdmin")
    fi

    installation_steps+=(
        "ADMIN_CONTROL_PANEL|Admin Control Panel"
        "WP_CLI|WP-CLI"
        "TOOLS|Tools"
    )

    # Source the install log if it exists. If it does not exist, every step is incomplete.
    if [[ -f "$install_log" ]]; then
        # shellcheck disable=SC1090
        source "$install_log" 2>/dev/null || true
        install_log_found="true"
    fi

    # Backfill older installs where WP-CLI was completed as part of TOOLS.
    if [[ "${WP_CLI:-0}" != "1" ]] && [[ "${TOOLS:-0}" = "1" ]] && [[ -x "${wp_cli_bin}" ]]; then
        set_install_state "WP_CLI" "1"
        WP_CLI=1
    fi

    # Backfill older installs where frontend/admin tools were completed as part of TOOLS.
    if [[ "${ADMIN_CONTROL_PANEL:-0}" != "1" ]] && [[ "${TOOLS:-0}" = "1" ]] && [[ -f "${admin_control_panel_path}" ]]; then
        set_install_state "ADMIN_CONTROL_PANEL" "1"
        ADMIN_CONTROL_PANEL=1
    fi

    if [[ "${PHPMYADMIN:-0}" != "1" ]] && [[ "${TOOLS:-0}" = "1" ]] && [[ "${INSTALL_PHPMYADMIN:-0}" = "1" ]] && [[ -f "${phpmyadmin_path}" ]]; then
        set_install_state "PHPMYADMIN" "1"
        PHPMYADMIN=1
    fi

    # Check each installation step for its completion marker.
    local step_definition
    for step_definition in "${installation_steps[@]}"; do
        local var_name="${step_definition%%|*}"
        local step_name="${step_definition#*|}"
        local var_value="${!var_name:-0}"

        if [[ "$install_log_found" != "true" || "$var_value" != "1" ]]; then
            missing_steps+=("${var_name}|${step_name}")
        fi
    done

    # Return results based on mode
    if [[ ${#missing_steps[@]} -eq 0 ]]; then
        if [[ "$quiet_mode" != "true" ]]; then
            echo "✅ SUCCESS: All EngineScript installation steps are marked complete."
        fi
        return 0
    else
        if [[ "$install_log_found" != "true" ]]; then
            echo "ERROR: Installation log not found at $install_log"
            echo "This indicates EngineScript installation was never started or completed."
        else
            echo "❌ ERROR: EngineScript installation is incomplete."
        fi

        echo "❌ The following installation steps are not marked complete:"
        echo ""
        for step_definition in "${missing_steps[@]}"; do
            local var_name="${step_definition%%|*}"
            local step_name="${step_definition#*|}"
            echo "   - ${var_name}: ${step_name}"
        done
        echo ""

        if [[ "$quiet_mode" != "true" ]]; then
            echo "RESOLUTION:"
            echo "1. Run the full EngineScript installation script to complete setup"
            echo "2. Check /var/log/EngineScript/install-error-log.log for specific errors"
            echo "3. Use 'es.debug' command to generate a complete diagnostic report"
            echo ""
        fi
        return 1
    fi
}


# ----------------------------------------------------------------
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


# ----------------------------------------------------------------
# Detect server location and hosting provider via ipinfo.io
# Logs results to /var/log/EngineScript/server-location.log
# Sets SERVER_ASN_ORG global variable for provider detection
# Always uses IPv4 with 5-second timeouts
function detect_server_location() {
    local log_file="/var/log/EngineScript/server-location.log"
    local -a curl_opts=(
        -4s
        --max-time
        5
        --connect-timeout
        5
    )

    echo -e "${BOLD}Server Location Info:${NORMAL}"

    # Fetch geo data (city, region, country, timezone)
    local geo_data
    geo_data=$(curl "${curl_opts[@]}" https://ipinfo.io/geo 2>/dev/null)

    if [[ -n "${geo_data}" ]]; then
        # Parse and display geo fields (exclude ip, phone, postal, loc, readme)
        echo "${geo_data}" | sed -e 's|[{}]||g' -e 's/\(^"\|"\)//g' -e 's|,||g' | grep -Eiv 'ip:|phone|postal|loc|readme' | while IFS= read -r line; do
            line="${line#"${line%%[![:space:]]*}"}"
            if [[ -n "${line}" ]]; then
                echo "  ${line}"
            fi
        done
    else
        echo "  Unable to retrieve server location (ipinfo.io unreachable)"
    fi

    # Fetch ASN/organization info
    SERVER_ASN_ORG=$(curl "${curl_opts[@]}" https://ipinfo.io/org 2>/dev/null)

    if [[ -n "${SERVER_ASN_ORG}" ]]; then
        echo "  ASN: ${SERVER_ASN_ORG}"
    else
        SERVER_ASN_ORG=""
        echo "  ASN: Unable to retrieve"
    fi

    # Log results
    {
        echo "# EngineScript Server Location - Detected at install time"
        echo "# Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        if [[ -n "${geo_data}" ]]; then
            echo "${geo_data}" | sed -e 's|[{}]||g' -e 's/\(^"\|"\)//g' -e 's|,||g' | grep -Eiv 'readme' | while IFS= read -r line; do
                line=$(echo "${line}" | sed 's/^[[:space:]]*//')
                if [[ -n "${line}" ]]; then
                    echo "${line}"
                fi
            done
        fi
        echo "ASN: ${SERVER_ASN_ORG:-Unknown}"
    } > "${log_file}" 2>/dev/null || true

    echo ""
}


# ----------------------------------------------------------------
# Auto-detect DigitalOcean hosting and enable DO features
# Must be called after detect_server_location() sets SERVER_ASN_ORG
# Updates install options file and in-memory variables when DO is detected
function auto_detect_digitalocean() {
    local options_file="/home/EngineScript/enginescript-install-options.txt"

    # Check if ASN contains DIGITALOCEAN (case-insensitive)
    if [[ "${SERVER_ASN_ORG,,}" == *"digitalocean"* ]]; then
        echo -e "${BOLD}✅ DigitalOcean hosting detected${NORMAL} (${SERVER_ASN_ORG})"
        echo "   Enabling DigitalOcean agents automatically..."
        echo ""

        # Enable Remote Console if currently disabled
        if [[ "${INSTALL_DIGITALOCEAN_REMOTE_CONSOLE}" != "1" ]]; then
            sed -i 's/^INSTALL_DIGITALOCEAN_REMOTE_CONSOLE=0/INSTALL_DIGITALOCEAN_REMOTE_CONSOLE=1/' "${options_file}"
            INSTALL_DIGITALOCEAN_REMOTE_CONSOLE=1
            echo "   → INSTALL_DIGITALOCEAN_REMOTE_CONSOLE = 1 (auto-enabled)"
        else
            echo "   → INSTALL_DIGITALOCEAN_REMOTE_CONSOLE = 1 (already enabled)"
        fi

        # Enable Metrics Agent if currently disabled
        if [[ "${INSTALL_DIGITALOCEAN_METRICS_AGENT}" != "1" ]]; then
            sed -i 's/^INSTALL_DIGITALOCEAN_METRICS_AGENT=0/INSTALL_DIGITALOCEAN_METRICS_AGENT=1/' "${options_file}"
            INSTALL_DIGITALOCEAN_METRICS_AGENT=1
            echo "   → INSTALL_DIGITALOCEAN_METRICS_AGENT = 1 (auto-enabled)"
        else
            echo "   → INSTALL_DIGITALOCEAN_METRICS_AGENT = 1 (already enabled)"
        fi

        echo ""
    fi
}


# ----------------------------------------------------------------
# Read total memory (MB) from /proc/meminfo
function read_total_memory_mb() {
    awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo ""
}


# ----------------------------------------------------------------
# Read CPU thread count
function read_cpu_count() {
    nproc --all 2>/dev/null || echo ""
}


# ----------------------------------------------------------------
# Validate total memory is readable and numeric; assign to output variable
# Usage: require_total_memory_readable "OUTPUT_VAR"
function require_total_memory_readable() {
    local output_var="${1:-MEMORY_TOTAL_MB}"
    local memory_total_mb

    memory_total_mb="$(read_total_memory_mb)"
    if ! [[ "${memory_total_mb}" =~ ^[0-9]+$ ]] || [[ "${memory_total_mb}" -le 0 ]]; then
        echo "Error: Unable to determine total memory from /proc/meminfo; cannot continue." >&2
        exit 1
    fi

    printf -v "${output_var}" '%s' "${memory_total_mb}"
}


# ----------------------------------------------------------------
# Validate CPU count is readable and numeric; assign to output variable
# Usage: require_cpu_count_readable "OUTPUT_VAR"
function require_cpu_count_readable() {
    local output_var="${1:-CPU_COUNT}"
    local cpu_count

    cpu_count="$(read_cpu_count)"
    if ! [[ "${cpu_count}" =~ ^[0-9]+$ ]] || [[ "${cpu_count}" -le 0 ]]; then
        echo "Error: Unable to determine CPU count via nproc; cannot continue." >&2
        exit 1
    fi

    printf -v "${output_var}" '%s' "${cpu_count}"
}


# ----------------------------------------------------------------
# Validate both total memory and CPU count and assign to caller variables
# Usage: require_basic_system_resources "MEM_OUTPUT_VAR" "CPU_OUTPUT_VAR"
function require_basic_system_resources() {
    local memory_output_var="${1:-MEMORY_TOTAL_MB}"
    local cpu_output_var="${2:-CPU_COUNT}"

    require_total_memory_readable "${memory_output_var}"
    require_cpu_count_readable "${cpu_output_var}"
}


# ----------------------------------------------------------------
# Validate that a configuration variable is not still set to PLACEHOLDER
# Exits with warning if the variable value is "PLACEHOLDER"
# Usage: validate_not_placeholder "VARIABLE_NAME" "$VARIABLE_VALUE" ["custom message"]
function validate_not_placeholder() {
    local var_name="$1"
    local var_value="$2"
    local custom_msg="${3:-""}"

    if [[ "$var_value" = "PLACEHOLDER" ]]; then
        if [[ -n "$custom_msg" ]]; then
            echo -e "\nWARNING:\n\n${custom_msg}\n"
        else
            echo -e "\nWARNING:\n\n${var_name} is set to PLACEHOLDER. EngineScript requires this to be set to a unique value.\nPlease return to the config file with the ${BOLD}es.config${NORMAL} command and change ${var_name} to the correct value.\n"
        fi
        exit 1
    fi
}


# ----------------------------------------------------------------
# Run an idempotent install step: skip if already completed, otherwise execute
# Usage: run_install_step "FLAG_NAME" "/path/to/script.sh" "Step Description"
function run_install_step() {
    local flag_name="$1"
    local script_path="$2"
    local step_desc="$3"
    local flag_value="${!flag_name:-0}"

    if [[ "${flag_value}" = 1 ]]; then
        echo "${flag_name} script has already run."
    else
        "${script_path}" 2>> /tmp/enginescript_install_errors.log
    fi
    print_last_errors
    debug_pause "${step_desc}"
}


# ----------------------------------------------------------------
# Verify a systemd service is running after installation
# Exits on failure
# Usage: verify_service_running "service_name" "Display Name"
function verify_service_running() {
    local service_name="$1"
    local display_name="${2:-${service_name}}"
    local status

    status="$(systemctl is-active "${service_name}")"
    if [[ "${status}" == "active" ]]; then
        echo "PASSED: ${display_name} is running."
    else
        echo "FAILED: ${display_name} not running. Please diagnose this issue before proceeding."
        exit 1
    fi
}


# ----------------------------------------------------------------
# Remove a directory if it exists (clean before fresh install)
# Usage: clean_directory "/path/to/directory"
function clean_directory() {
    local dir_path="$1"

    if [[ -d "${dir_path}" ]]; then
        rm -rf "${dir_path}"
    fi
}


# ----------------------------------------------------------------
# Replace a directory with a complete new copy: the old one is moved aside, the new one renamed
# into its place, and the old one removed. If the rename fails, the old one is put back. Both
# must be on the same filesystem, so the renames are instant. Returns 1 on failure.
# Usage: replace_directory "/var/www/admin/.control-panel-new.abc123" "/var/www/admin/control-panel"
function replace_directory() {
    local new_dir="$1"
    local target_dir="$2"
    local old_dir="${new_dir}.old"

    if [[ -e "${target_dir}" ]]; then
        mv -T "${target_dir}" "${old_dir}" || return 1
    fi
    if ! mv -T "${new_dir}" "${target_dir}"; then
        if [[ -e "${old_dir}" ]]; then
            mv -T "${old_dir}" "${target_dir}"
        fi
        return 1
    fi
    rm -rf "${old_dir}"
}


# ----------------------------------------------------------------
# Download a file and extract a tarball
# Usage: download_and_extract "URL" "/path/to/output.tar.gz" [extract_dir]
function download_and_extract() {
    local url="$1"
    local output_file="$2"
    local extract_dir="${3:-$(dirname "${output_file}")}"

    curl -fsSL --proto '=https' -o "${output_file}" "${url}" || {
        echo "Error: Failed to download ${url}"
        return 1
    }
    tar -xzf "${output_file}" -C "${extract_dir}" || {
        echo "Error: Failed to extract ${output_file}"
        return 1
    }
}


# ----------------------------------------------------------------
# Print a formatted installation completion banner
# Usage: print_install_banner "Tool Name" [sleep_seconds]
function print_install_banner() {
    local tool_name="$1"
    local sleep_seconds="${2:-5}"

    echo ""
    echo ""
    echo "============================================================="
    echo ""
    echo "${BOLD}${tool_name} installed.${NORMAL}"
    echo ""
    echo "============================================================="
    echo ""
    echo ""

    if [[ "${sleep_seconds}" -gt 0 ]]; then
        sleep "${sleep_seconds}"
    fi
}


# ----------------------------------------------------------------
# Clone a git repository, removing any existing directory first
# Usage: git_clone_fresh "https://repo.url" "/destination/path" [extra_args...]
function git_clone_fresh() {
    local repo_url="$1"
    local dest_path="$2"
    shift 2

    clean_directory "${dest_path}"
    git clone "$@" "${repo_url}" "${dest_path}"
}


# ----------------------------------------------------------------
# Download a file over HTTPS (redirects to plain HTTP are refused)
# Usage: safe_wget "URL" "/destination/path"
function safe_wget() {
    local url="$1"
    local dest="$2"

    curl -fsSL --proto '=https' -o "${dest}" "${url}" || {
        echo "Error: Failed to download ${url}"
        return 1
    }
}


# ----------------------------------------------------------------
# Safely return to /usr/src
function return_to_src() {
    cd /usr/src || { echo "Error: Failed to change to /usr/src" >&2; exit 1; }
}


# ----------------------------------------------------------------
# CPU target for compiled software (Nginx, Brotli, zlib-rs).
# Prints x86-64-v3 (AVX2, BMI1/BMI2, FMA, MOVBE) when this CPU supports it, otherwise x86-64-v2.
# A fixed level is used instead of -march=native: a native build uses every instruction of the
# build machine's CPU, so moving the server to other hardware (live migration, snapshot restore,
# resize) can stop the program with "illegal instruction".
function get_x86_64_level() {
    if /lib64/ld-linux-x86-64.so.2 --help 2>/dev/null | grep -q "x86-64-v3 (supported"; then
        echo "x86-64-v3"
    else
        echo "x86-64-v2"
    fi
}


# ----------------------------------------------------------------
# Get the array of base PHP packages to install for a given PHP version
# Usage:
# mapfile -t php_packages < <(get_php_packages_array "8.4")
function get_php_packages_array() {
    local target_ver="$1"
    local packages=(
        "php${target_ver}"
        "php${target_ver}-bcmath"
        "php${target_ver}-common"
        "php${target_ver}-curl"
        "php${target_ver}-fpm"
        "php${target_ver}-gd"
        # igbinary: Redis Object Cache's serializer (WP_REDIS_IGBINARY). php-redis currently pulls
        # it in as a dependency; listed so it does not depend on that.
        "php${target_ver}-igbinary"
        "php${target_ver}-imagick"
        "php${target_ver}-intl"
        "php${target_ver}-mbstring"
        "php${target_ver}-mysql"
        "php${target_ver}-redis"
        "php${target_ver}-ssh2"
        "php${target_ver}-xml"
        "php${target_ver}-zip"
    )

    # PHP 8.5+ has opcache built-in; older versions need the separate package
    local php_major="${target_ver%%.*}"
    local php_minor="${target_ver#*.}"
    local php_ver_int=$((php_major * 10 + php_minor))
    if (( php_ver_int < 85 )); then
        packages+=(
            "php${target_ver}-opcache"
        )
    fi

    printf '%s\n' "${packages[@]}"
}


# ----------------------------------------------------------------
# Get the array of expanded PHP packages to install for a given PHP version
# Usage:
# mapfile -t expanded_php_packages < <(get_expanded_php_packages_array "8.4")
function get_expanded_php_packages_array() {
    local target_ver="$1"
    local packages=(
        "php${target_ver}-soap"
        "php${target_ver}-sqlite3"
    )
    printf '%s\n' "${packages[@]}"
}


# ----------------------------------------------------------------
# Shared tuning plan (memory budget for Nginx, PHP-FPM, MariaDB, and Redis)
# shellcheck source=enginescript-tuning.sh
source "$(dirname "${BASH_SOURCE[0]}")/enginescript-tuning.sh"
