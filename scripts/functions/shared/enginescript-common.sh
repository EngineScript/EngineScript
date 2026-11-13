#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------
# Shared Functions
# Common functions for every EngineScript script: install steps and state, services, caches,
# sites, and logging. Prompts, permissions, Cloudflare, and the tuning appliers are in their
# own files, loaded below.
#----------------------------------------------------------------------------------


# The parts of the shared functions, each in its own file next to this one. The one-time
# upgrades (enginescript-upgrades.sh) are loaded only by normal-auto-upgrade.sh.
# shellcheck source=scripts/functions/shared/enginescript-cloudflare.sh
source "$(dirname "${BASH_SOURCE[0]}")/enginescript-cloudflare.sh" || return 1
# shellcheck source=scripts/functions/shared/enginescript-prompts.sh
source "$(dirname "${BASH_SOURCE[0]}")/enginescript-prompts.sh" || return 1
# shellcheck source=scripts/functions/shared/enginescript-permissions.sh
source "$(dirname "${BASH_SOURCE[0]}")/enginescript-permissions.sh" || return 1
# shellcheck source=scripts/functions/shared/enginescript-tuning-apply.sh
source "$(dirname "${BASH_SOURCE[0]}")/enginescript-tuning-apply.sh" || return 1


# The errors of the install or update step that is running. print_last_errors adds them to
# /var/log/EngineScript/install-error-log.log and empties this file for the next step.
ES_STEP_ERROR_LOG="/var/log/EngineScript/step-errors.log"


# ----------------------------------------------------------------
# Messages: log prints, warn and die print to stderr, and die stops the script. Scripts with a
# log file of their own (backup, staging) define their own log and die.
function log() {
    echo "$*"
}

function warn() {
    echo "Warning: $*" >&2
}

function die() {
    echo "Error: $*" >&2
    exit 1
}


# ----------------------------------------------------------------
# Run one install or update step. Its errors go to the step error log, print_last_errors then
# adds them to the install error log (and shows them in debug mode), and debug mode pauses after
# a step that succeeded. Returns the command's exit status, so a caller can add "|| die".
# Usage: run_step "<label>" <command> [arguments]
function run_step() {
    local label="$1" status=0
    shift
    mkdir -p "$(dirname "${ES_STEP_ERROR_LOG}")"
    "$@" 2>> "${ES_STEP_ERROR_LOG}" || status=$?
    print_last_errors
    if [[ "${status}" -eq 0 ]]; then
        debug_pause "${label}"
    fi
    return "${status}"
}


# Debug pause function
# With DEBUG_INSTALL=1, waits after a step until the user presses Enter, or types 'exit' to stop.
# It talks to the terminal directly: the install and update scripts send stderr to the error log,
# a cron job sends stdout to its log, and stdin can be a file a loop is reading. With no terminal,
# as in cron, it does not pause.
function debug_pause() {
    if [[ "${DEBUG_INSTALL}" != "1" ]]; then
        return 0
    fi

    local last_step="${1:-Unknown step}"
    local user_input

    if ! { : > /dev/tty; } 2> /dev/null; then
        echo "[DEBUG] Completed step: ${last_step} (no terminal, so not pausing)"
        return 0
    fi

    {
        echo ""
        echo "[DEBUG] Completed step: ${last_step}"
        echo "[DEBUG] Press Enter to continue, or type 'exit' to stop."
        echo "Some displayed text may contain only general information. Logged output does not always indicate an error."
        echo ""
        echo "If you encountered errors above, you can copy the error text for a GitHub bug report."
        echo "For more server details, run: es.debug"
    } > /dev/tty

    while true; do
        printf '%s' "[DEBUG] Continue or exit? (Enter/exit): " > /dev/tty
        # The end of input (Ctrl+D, or the terminal closing) continues, as Enter does
        if ! IFS= read -r user_input < /dev/tty; then
            echo "" 2> /dev/null > /dev/tty
            return 0
        fi
        if [[ -z "${user_input}" ]]; then
            return 0
        elif [[ "${user_input}" =~ ^[Ee][Xx][Ii][Tt]$ ]]; then
            echo "Stopping as requested." > /dev/tty
            # The pause often runs in a script that another script started, where exit alone would
            # end only that script and its caller would carry on. An interrupt to the process group
            # stops every script of the run, as Ctrl+C does.
            kill -INT 0
            exit 1
        else
            echo "Please press Enter to continue or type 'exit' to stop." > /dev/tty
        fi
    done
}


# ----------------------------------------------------------------
# Print errors from the last script section if any
function print_last_errors() {
    # Always append errors to persistent log if any
    if [[ -s "${ES_STEP_ERROR_LOG}" ]]; then
        cat "${ES_STEP_ERROR_LOG}" >> /var/log/EngineScript/install-error-log.log
    fi
    # Only show errors to user if debug mode is enabled
    if [[ "${DEBUG_INSTALL}" == "1" ]] && [[ -s "${ES_STEP_ERROR_LOG}" ]]; then
        echo -e "\n\n===============================================================\n"
        echo -e "${BOLD}[ERRORS DETECTED IN LAST STEP]${NORMAL}"
        cat "${ES_STEP_ERROR_LOG}"
        echo -e "${BOLD}[END OF ERRORS]${NORMAL}\n\n"
        echo -e "If you encounter errors and want to submit a GitHub issue, please run: es.debug"
    fi
    # Always clear the step log for the next step
    if [[ -e "${ES_STEP_ERROR_LOG}" ]]; then
        : > "${ES_STEP_ERROR_LOG}"
    fi
}


# ----------------------------------------------------------------
# The install state: /etc/enginescript/install-state.conf holds one FLAG=0 or FLAG=1 line per
# install step (1 = done). ENGINESCRIPT_INSTALL_STATE_FILE overrides the path (for tests).
#
# The file is data. It is read line by line and never sourced, and only the flags below are
# loaded: before November 2026 the web server user owned its folder, so on a server with a hacked
# site the file may hold anything.
ENGINESCRIPT_INSTALL_STATE_FLAGS=(
    "ALIAS"
    "REPOS"
    "REMOVES"
    "BLOCK"
    "UBUNTU_PRO"
    "DEPENDS"
    "CRON"
    "ACME"
    "GCC"
    "SWAP"
    "KERNEL_TWEAKS"
    "THP"
    "SFL"
    "NTP"
    "DO_CONSOLE"
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

# Set every install flag (REPOS, NGINX, ...) to 0 or 1 from install-state.conf. A flag the file
# does not have is 0, and so is every flag when there is no file (then it returns 1). Lines that
# are not exactly FLAG=0 or FLAG=1, and flags not in ENGINESCRIPT_INSTALL_STATE_FLAGS, are
# ignored; when a flag has several lines, the last one counts.
function load_install_state() {
    local state_file="${ENGINESCRIPT_INSTALL_STATE_FILE:-/etc/enginescript/install-state.conf}"
    local state_flag state_line

    for state_flag in "${ENGINESCRIPT_INSTALL_STATE_FLAGS[@]}"; do
        printf -v "${state_flag}" '%s' "0"
    done
    if [[ ! -f "${state_file}" ]]; then
        return 1
    fi
    while IFS= read -r state_line || [[ -n "${state_line}" ]]; do
        if [[ ! "${state_line}" =~ ^([A-Z0-9_]+)=([01])$ ]]; then
            continue
        fi
        state_flag="${BASH_REMATCH[1]}"
        if [[ " ${ENGINESCRIPT_INSTALL_STATE_FLAGS[*]} " == *" ${state_flag} "* ]]; then
            printf -v "${state_flag}" '%s' "${BASH_REMATCH[2]}"
        fi
    done < "${state_file}"
}

# True once es.install has finished at least one step (ALIAS is setup.sh's own flag). Call
# load_install_state first.
function install_has_started() {
    local state_flag
    for state_flag in "${ENGINESCRIPT_INSTALL_STATE_FLAGS[@]}"; do
        if [[ "${state_flag}" != "ALIAS" && "${!state_flag:-0}" == "1" ]]; then
            return 0
        fi
    done
    return 1
}

# Set one flag in install-state.conf. The new file is written beside the old one and moved into
# place, so a link at that path is replaced, never written through. Lines that are not FLAG=0
# or FLAG=1 are dropped.
# Usage: set_install_state <FLAG> [0|1]
function set_install_state() {
    local flag_name="$1"
    local flag_value="${2:-1}"
    local state_file="${ENGINESCRIPT_INSTALL_STATE_FILE:-/etc/enginescript/install-state.conf}"
    local state_dir
    local tmp_file
    local current_file="/dev/null"

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
    if [[ -f "${state_file}" && ! -L "${state_file}" ]]; then
        current_file="${state_file}"
    fi

    tmp_file="$(mktemp "${state_dir}/.install-state.XXXXXX")" || return 1
    awk -v key="${flag_name}" -v assignment="${flag_name}=${flag_value}" '
        BEGIN { replaced = 0 }
        !/^[A-Z0-9_]+=[01]$/ { next }
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
    ' "${current_file}" > "${tmp_file}" && chmod 644 "${tmp_file}" && mv -fT "${tmp_file}" "${state_file}" || {
        rm -f "${tmp_file}"
        return 1
    }
}


# ----------------------------------------------------------------
# Ensure install-state.conf holds every install flag with a 0 or 1 value, and load the flags
# (load_install_state). Root takes over /etc/enginescript first (set_enginescript_etc_permissions).
# Flags of steps that no longer exist (OPENSSL, PCRE, ZLIB: the Nginx build fetches those sources)
# stay in older files, unused; anything that is not a FLAG=0 or FLAG=1 line is removed. The file is
# only rewritten when it changes.
function initialize_install_state_file() {
    local state_file="${ENGINESCRIPT_INSTALL_STATE_FILE:-/etc/enginescript/install-state.conf}"
    local state_dir
    local tmp_file
    local state_flag

    state_dir="$(dirname "${state_file}")"
    mkdir -p "${state_dir}" || return 1
    if [[ "${state_dir}" == "${ES_ETC_DIR:-/etc/enginescript}" ]]; then
        set_enginescript_etc_permissions || return 1
    fi
    load_install_state || true

    tmp_file="$(mktemp "${state_dir}/.install-state.XXXXXX")" || return 1
    {
        for state_flag in "${ENGINESCRIPT_INSTALL_STATE_FLAGS[@]}"; do
            echo "${state_flag}=${!state_flag}"
        done
        if [[ -f "${state_file}" && ! -L "${state_file}" ]]; then
            awk -F= -v known=" ${ENGINESCRIPT_INSTALL_STATE_FLAGS[*]} " \
                '/^[A-Z0-9_]+=[01]$/ && index(known, " " $1 " ") == 0' "${state_file}"
        fi
    } > "${tmp_file}" || {
        rm -f "${tmp_file}"
        return 1
    }

    if [[ -f "${state_file}" && ! -L "${state_file}" ]] && cmp -s "${tmp_file}" "${state_file}"; then
        rm -f "${tmp_file}"
        return 0
    fi
    chmod 644 "${tmp_file}" && mv -fT "${tmp_file}" "${state_file}" || {
        rm -f "${tmp_file}"
        return 1
    }
}


# ----------------------------------------------------------------
# Delete one site's pages from the Nginx FastCGI cache; every other site keeps its pages.
# Each cache file holds its key ("KEY: httpsGETexample.com/...", fastcgi_cache_key in
# globals/php-fpm.conf). Used when a site is removed or set up, so a domain that is set up again
# does not serve the cached pages of the site it had before. Pages cached for www.<domain>, the
# address of an imported site that kept www, go too.
# Usage: clear_site_nginx_cache <domain>
function clear_site_nginx_cache() {
    local domain="$1"
    local cache_dir="${ES_NGINX_CACHE_DIR:-/var/cache/nginx}"

    if [[ -z "${domain}" || ! -d "${cache_dir}" ]]; then
        return 0
    fi
    grep -rlaZ -E "^KEY: [a-z]+[A-Z]+(www\\.)?${domain//./\\.}/" "${cache_dir}" 2> /dev/null | xargs -0 -r rm -f
}


# ----------------------------------------------------------------
# Reload Nginx (after nginx -t) and PHP-FPM, after a site's vhost was added or removed. Redis
# keeps running and every other site keeps its caches: Redis Object Cache shows an error page on
# every site while Redis is unreachable. Returns 1 when Nginx was not reloaded.
# Usage: reload_web_services
function reload_web_services() {
    echo "Reloading Nginx and PHP-FPM..."
    if ! nginx -t > /dev/null 2>&1; then
        echo "Error: nginx -t failed; Nginx was not reloaded. Check with: nginx -t" >&2
        return 1
    fi
    if ! systemctl reload nginx; then
        echo "Error: Nginx could not be reloaded. Check with: systemctl status nginx" >&2
        return 1
    fi
    if systemctl is-active --quiet "php${PHP_VER}-fpm"; then
        systemctl reload "php${PHP_VER}-fpm"
    fi
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
# Clear PHP OPcache. It is kept in PHP-FPM's memory, so a reload clears it; requests in progress
# finish first. php.ini leaves the file cache in /var/cache/opcache off; the folder is emptied
# in case it was turned on.
function clear_opcache() {
    echo "Clearing PHP OPcache"
    rm -rf /var/cache/opcache/* || {
        echo "Error: Failed to clear the OPcache file cache." >&2
    }
    if systemctl is-active --quiet "php${PHP_VER}-fpm"; then
        systemctl reload "php${PHP_VER}-fpm" || {
            echo "Error: Failed to reload PHP-FPM, so OPcache was not cleared."
        }
    fi
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
    run_as_www_data wp cache flush || {
        echo "Error: Failed to flush WordPress cache."
    }
}


# ----------------------------------------------------------------
# Flush WordPress rewrite rules (single site). Not --hard: that only writes .htaccess, which Nginx
# does not read, and warns that it cannot.
function flush_wordpress_rewrites() {
    echo "Flushing WordPress rewrite rules"
    run_as_www_data wp rewrite flush || {
        echo "Error: Failed to flush WordPress rewrite rules."
    }
}


# ----------------------------------------------------------------
# Delete WordPress transients (single site)
function clear_wordpress_transients() {
    echo "Deleting WordPress Transients"
    run_as_www_data wp transient delete --all || {
        echo "Error: Failed to delete WordPress transients."
    }
}


# ----------------------------------------------------------------
# Purge Nginx cache for a single site using Nginx Helper plugin
function purge_nginx_helper_cache() {
    echo "Purging Nginx Cache via Nginx Helper Plugin"
    run_as_www_data wp nginx-helper purge-all || {
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
# Clear WordPress caches for all sites (cache + rewrites)
function clear_all_wordpress_caches() {
    for_each_site clear_wordpress_caches
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
    local SITES=() site code
    es_sites

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
# Runs a query with each site's own credentials from wp-config.php (WP-CLI, as www-data, so the
# site's wp-config.php never runs as root), so it checks the account WordPress uses. Sites without wp-config.php (no WordPress) are skipped. Prints nothing
# when every site reaches its database or there are no sites. Callers compare the result with a
# list taken before a change, as with get_sites_without_php.
function get_sites_without_database() {
    local SITES=() site site_root
    es_sites

    for site in "${SITES[@]}"; do
        site_root="/var/www/sites/${site}/html"
        if [[ ! -f "${site_root}/wp-config.php" ]]; then
            continue
        fi
        if ! (cd "${site_root}" && timeout 60 runuser -u www-data -- wp db query "SELECT 1" --skip-plugins --skip-themes) > /dev/null 2>&1; then
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
# Print a random string of letters and digits, for passwords, database names and users, and
# table prefixes. Made when asked, from openssl's random bytes; base64 output also has + / =,
# which are dropped, so it reads more bytes until the string is long enough.
# Usage: es_random <length>
function es_random() {
    local length="$1" out=""
    if [[ ! "${length}" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: es_random needs a length, not '${length}'." >&2
        return 1
    fi
    while (( ${#out} < length )); do
        out+="$(openssl rand -base64 $(( length * 2 )) | tr -dc 'a-zA-Z0-9')"
    done
    printf '%s\n' "${out:0:length}"
}


# ----------------------------------------------------------------
# Hold a named lock until the script exits, so two runs cannot change the same things at once:
#   update: es.update and the Nginx, PHP, and MariaDB updates
#   sites:  Create, Import, and Remove Domain, and staging copies (site list, Redis numbers)
# The lock file is in /run, which only root can write to. Scripts this one starts inherit the
# lock, so an update that runs another update does not wait for itself. ES_LOCK_DIR overrides
# the folder (for tests). Returns 1, with a message, when another run holds the lock.
# Usage: acquire_lock <name> [seconds to wait, default 0]
function acquire_lock() {
    local name="$1" wait="${2:-0}" held_var lock_fd
    local lock_file="${ES_LOCK_DIR:-/run}/enginescript-${name}.lock"
    held_var="ES_LOCK_HELD_${name//[^A-Za-z0-9]/_}"

    if [[ "${!held_var:-}" == "1" ]]; then
        return 0
    fi
    exec {lock_fd}> "${lock_file}" || { echo "Error: Failed to open ${lock_file}" >&2; return 1; }
    if ! flock -w "${wait}" "${lock_fd}"; then
        exec {lock_fd}>&-
        echo "Error: Another EngineScript task is running (it holds ${lock_file}). Try again when it has finished." >&2
        return 1
    fi
    export "${held_var}=1"
}


# ----------------------------------------------------------------
# The server's site list, /home/EngineScript/sites-list/sites.sh (ES_SITES_LIST overrides the path
# for tests). It sets SITES, with each domain in quotes on its own line.

# Load the site list into SITES; SITES is empty when there is no list yet. Declare
# "local SITES=()" first to keep SITES out of the caller's own variables.
function es_sites() {
    local sites_file="${ES_SITES_LIST:-/home/EngineScript/sites-list/sites.sh}"
    SITES=()
    if [[ -f "${sites_file}" ]]; then
        # shellcheck source=/dev/null
        source "${sites_file}"
    fi
}

# Return 0 when the domain is on the site list
function es_site_exists() {
    local SITES=() site
    es_sites
    for site in "${SITES[@]}"; do
        if [[ "${site}" == "$1" ]]; then
            return 0
        fi
    done
    return 1
}

# Add a domain to the site list, once. The list is created from its template when missing.
# Callers that change the list hold the "sites" lock (acquire_lock).
function es_site_add() {
    local domain="$1"
    local sites_file="${ES_SITES_LIST:-/home/EngineScript/sites-list/sites.sh}"

    if [[ ! "${domain}" =~ ^[a-z0-9.-]+$ ]]; then
        echo "Error: Invalid domain '${domain}' for the site list." >&2
        return 1
    fi
    if es_site_exists "${domain}"; then
        return 0
    fi
    if [[ ! -f "${sites_file}" ]]; then
        if ! { mkdir -p "$(dirname "${sites_file}")" \
            && cp /usr/local/bin/enginescript/scripts/functions/cron/sites.sh "${sites_file}"; }; then
            echo "Error: Failed to create the site list at ${sites_file}" >&2
            return 1
        fi
    fi
    if ! grep -q '^SITES=(' "${sites_file}"; then
        echo "Error: ${sites_file} has no SITES=( line, so ${domain} was not added." >&2
        return 1
    fi
    sed -i "/^SITES=(/a \"${domain}\"" "${sites_file}" \
        || { echo "Error: Failed to add ${domain} to ${sites_file}" >&2; return 1; }
}

# Remove a domain from the site list. Only the line that holds exactly the quoted domain goes.
# Callers that change the list hold the "sites" lock (acquire_lock).
function es_site_remove() {
    local domain="$1"
    local sites_file="${ES_SITES_LIST:-/home/EngineScript/sites-list/sites.sh}"

    if [[ ! "${domain}" =~ ^[a-z0-9.-]+$ ]]; then
        echo "Error: Invalid domain '${domain}' for the site list." >&2
        return 1
    fi
    if [[ ! -f "${sites_file}" ]]; then
        return 0
    fi
    sed -i "/^[[:space:]]*\"${domain//./\\.}\"[[:space:]]*$/d" "${sites_file}" \
        || { echo "Error: Failed to remove ${domain} from ${sites_file}" >&2; return 1; }
}


# ----------------------------------------------------------------
# Ask which of the server's sites to use, from the site list (es_sites)
# Sets SELECTED_SITE. Returns 1 when there are no sites, on Cancel, or at the end of input.
function select_site() {
    local SITES=() site
    SELECTED_SITE=""
    es_sites
    if [[ "${#SITES[@]}" -eq 0 ]]; then
        echo "There are no sites on this server yet."
        return 1
    fi
    local PS3="Choose a site: "
    select site in "${SITES[@]}" "Cancel"; do
        if [[ "${site}" == "Cancel" ]]; then
            return 1
        fi
        if [[ -n "${site}" ]]; then
            # shellcheck disable=SC2034 # read by the caller
            SELECTED_SITE="${site}"
            return 0
        fi
        echo "Invalid option."
    done
    return 1
}


# ----------------------------------------------------------------
# Run a command or function in every site's WordPress folder. It runs as root: run WP-CLI
# through run_as_www_data. Prints each site's name before its output, and the sites where the
# command failed. Returns 1 when it failed for any site.
# Usage: for_each_site <command> [arguments]
function for_each_site() {
    local SITES=() site failed=()
    es_sites
    if [[ "${#SITES[@]}" -eq 0 ]]; then
        echo "There are no sites on this server yet."
        return 0
    fi
    for site in "${SITES[@]}"; do
        echo ""
        echo "${BOLD}${site}${NORMAL}"
        if ! (cd "/var/www/sites/${site}/html" && "$@"); then
            failed+=("${site}")
        fi
    done
    echo ""
    if [[ "${#failed[@]}" -gt 0 ]]; then
        echo "Failed for: ${failed[*]}"
        return 1
    fi
    echo "Done for all ${#SITES[@]} site(s)."
}


# ----------------------------------------------------------------
# Install or update EngineScript's own plugins (Site Exporter and Site Optimizer, at the versions
# in enginescript-variables.txt) in one or more sites, when INSTALL_ENGINESCRIPT_PLUGINS=1. Each
# zip is downloaded and checked once. It is extracted beside the plugin's folder, which is then
# swapped in, so a failed download or extract leaves the site's current copy untouched. Returns
# 1 when a plugin failed for any site.
# Usage: install_enginescript_plugins <domain> [domain...]
function install_enginescript_plugins() {
    local zip_dir domain plugins_dir entry slug version zip new_dir plugin_failed=0
    local plugins=("enginescript-site-exporter ${ES_SE_PLUGIN_VER}" "enginescript-site-optimizer ${ES_SO_PLUGIN_VER}")

    if [[ "${INSTALL_ENGINESCRIPT_PLUGINS:-0}" != "1" ]]; then
        echo "Skipping the EngineScript plugins (INSTALL_ENGINESCRIPT_PLUGINS is not 1)."
        return 0
    fi
    zip_dir="$(mktemp -d /tmp/enginescript-plugins.XXXXXX)" || return 1

    for entry in "${plugins[@]}"; do
        slug="${entry% *}"
        version="${entry#* }"
        zip="${zip_dir}/${slug}-${version}.zip"
        if ! curl -fsSL --proto '=https' --retry 3 -o "${zip}" \
                "https://github.com/EngineScript/${slug}/releases/download/v${version}/${slug}-${version}.zip" \
            || ! unzip -tq "${zip}" > /dev/null; then
            rm -f "${zip}"
            echo "Error: Failed to download ${slug} ${version}; the sites keep their current copy." >&2
            plugin_failed=1
            continue
        fi

        for domain in "$@"; do
            plugins_dir="/var/www/sites/${domain}/html/wp-content/plugins"
            if [[ ! -d "${plugins_dir}" ]]; then
                echo "Warning: ${plugins_dir} does not exist; skipping ${slug} for ${domain}." >&2
                continue
            fi
            # A dot folder: WordPress does not load plugins from it
            new_dir="$(mktemp -d "${plugins_dir}/.${slug}-new.XXXXXX")" || { plugin_failed=1; continue; }
            if ! unzip -q "${zip}" -d "${new_dir}" || [[ ! -d "${new_dir}/${slug}" ]] \
                || ! replace_directory "${new_dir}/${slug}" "${plugins_dir}/${slug}"; then
                echo "Error: ${slug} ${version} could not be installed for ${domain}; it keeps its current copy." >&2
                rm -rf "${new_dir}"
                plugin_failed=1
                continue
            fi
            rm -rf "${new_dir}"
            set_www_data_tree "${plugins_dir}/${slug}"
            echo "${slug} ${version} installed for ${domain}."
        done
    done

    rm -rf "${zip_dir}"
    return "${plugin_failed}"
}


# ----------------------------------------------------------------
# List the PHP files in a site's uploads folder, which should hold only media: PHP there is a
# common sign of a break-in. The folders Sucuri and WP Migrate DB keep their own PHP in are skipped.
# Usage: find_php_in_uploads <uploads folder>
function find_php_in_uploads() {
    find "$1" \( -path "$1/sucuri" -o -path "$1/wp-migrate-db" \) -prune -o -type f \
        \( -iname '*.php' -o -iname '*.php[0-9]' -o -iname '*.phtml' -o -iname '*.phar' \) -print
}


# ----------------------------------------------------------------
# Run a tool from a menu, or say how to install it: servers set up before a tool was added get
# it from Update Software > Update Server Tools
# Usage: run_tool <tool> <command> [arguments]
function run_tool() {
    local tool="$1"
    shift
    if ! command -v "${tool}" > /dev/null 2>&1; then
        echo "${tool} is not installed. Install it with: es.menu > Update Software > Update Server Tools"
        return 1
    fi
    "$@"
}


# ----------------------------------------------------------------
# Print text indented by two spaces, or "none" when it is empty (for the menus' reports)
function print_or_none() {
    if [[ -n "$1" ]]; then
        printf '  %s\n' "${1//$'\n'/$'\n'  }"
    else
        echo "  none"
    fi
}


# ----------------------------------------------------------------
# The PPAs EngineScript adds (repositories-install.sh). A new Ubuntu LTS release takes a PPA's
# owner some time: a PPA with no packages for this release yet is skipped at install time, and
# add_missing_ppas (weekly-maintenance.sh) adds it once it has them.
ENGINESCRIPT_PPAS=(
    "ppa:canonical-server/server-backports"
    "ppa:maxmind/ppa"
    "ppa:git-core/ppa"
    "ppa:lepapareil/hurl"
    "ppa:deadsnakes/ppa"
)

# True when a PPA publishes packages for this server's Ubuntu release (its codename's InRelease)
function ppa_has_release() {
    local code
    code="$(curl -s -o /dev/null -w '%{http_code}' -L --proto '=https' --proto-redir '=https' --max-time 20 \
        "https://ppa.launchpadcontent.net/${1#ppa:}/ubuntu/dists/${UBUNTU_CODENAME}/InRelease")"
    [[ "${code}" == "200" ]]
}

# True when a PPA is already one of apt's sources
function ppa_is_added() {
    grep -rqsF "/${1#ppa:}/ubuntu" /etc/apt/sources.list.d/
}

# Add each of EngineScript's PPAs that is not a source yet and now has packages for this
# release, then refresh apt's package lists once. Safe to run again.
function add_missing_ppas() {
    local ppa added=0
    for ppa in "${ENGINESCRIPT_PPAS[@]}"; do
        ppa_is_added "${ppa}" && continue
        if ! ppa_has_release "${ppa}"; then
            echo "${ppa} still has no packages for Ubuntu ${UBUNTU_VERSION} (${UBUNTU_CODENAME}); trying again next week."
            continue
        fi
        if add-apt-repository -yn "${ppa}"; then
            echo "Added ${ppa}: it now has packages for Ubuntu ${UBUNTU_VERSION}."
            added=1
        else
            echo "Warning: Could not add ${ppa}; trying again next week." >&2
        fi
    done
    if [[ "${added}" -eq 1 ]]; then
        apt-get update -qq
    fi
    return 0
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

        # 2026-11: OCSP stapling is off, so vhosts no longer load the certificate chain for it
        if grep -q '^  ssl_trusted_certificate ' "${file_path}"; then
            sed -i 's|^  ssl_trusted_certificate |  # Only used for OCSP stapling (disabled, see sslshared.conf)\n  #ssl_trusted_certificate |' "${file_path}"
        fi

        # 2026-11: the admin tools' PHP locations check that the script exists (try_files $uri
        # =404), so no PATH_INFO reaches PHP and fastcgi_split_path_info does nothing
        if [[ "${file_path}" == /etc/nginx/admin/admin.*.conf ]] && grep -q '^[[:space:]]*fastcgi_split_path_info ' "${file_path}"; then
            sed -i '/^[[:space:]]*fastcgi_split_path_info /d' "${file_path}"
        fi
    done
}


# ----------------------------------------------------------------
# Redis database numbers of the sites
#
# Each site uses its own Redis database (WP_REDIS_DATABASE in its wp-config.php), so the Redis
# Object Cache plugin's "flush cache" (FLUSHDB) empties only that site's cache. "databases" in
# redis.conf sets how many exist (128; each costs about 6 KB). A new site gets the lowest number
# no other site uses, so removing a site frees its number. ES_REDIS_CONF and ES_SITES_ROOT
# override the paths (for tests).
# shellcheck disable=SC2034  # also read by migrate_redis_databases (enginescript-upgrades.sh)
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
# Print the cron jobs EngineScript schedules, one per line, for the current install options
#
# Jobs run through run-job.sh, which logs them to /var/log/EngineScript. Two do not: the backup
# scheduler logs for itself, and the API cache sweep runs every minute with nothing to report.
function enginescript_cron_jobs() {
    local scripts="/usr/local/bin/enginescript/scripts"
    local run="bash ${scripts}/functions/cron/run-job.sh"

    # Tool updates, permissions, security scans, and the EngineScript update, in that order
    echo "52 5 * * * ${run} functions/cron/daily-maintenance.sh"

    # Weekly checks, such as PPAs that had no packages for this Ubuntu release at install time
    echo "22 4 * * 1 ${run} functions/cron/weekly-maintenance.sh"

    # WordPress Maintenance
    echo "*/15 * * * * ${run} functions/cron/wp-cron.sh"

    # Backup Tasks: one job every hour; enginescript-backup.sh reads the BACKUP_* frequencies
    echo "5 * * * * cd ${scripts}/functions/backup; bash enginescript-backup.sh scheduled >/dev/null 2>&1"

    # System Maintenance
    echo "7 * * * * ${run} functions/cron/cleanup-cron.sh"

    if [[ "${AUTOMATIC_LOSSLESS_IMAGE_OPTIMIZATION}" == "1" ]]; then
        echo "37 5 * * 0 ${run} functions/cron/optimize-images.sh"
    fi

    # Configuration Backups
    echo "47 6 * * * ${run} functions/backup/nginx-backup.sh"
    echo "48 6 * * * ${run} functions/backup/php-backup.sh"

    # Cloudflare Updates
    echo "49 5 1 * * ${run} install/nginx/nginx-cloudflare-origin-cert.sh"
    echo "50 5 1 * * ${run} install/nginx/nginx-cloudflare-ip-updater.sh"
    echo "51 5 1 * * ${run} functions/cron/ufw-cloudflare-cron.sh"
}


# ----------------------------------------------------------------
# Make root's crontab match enginescript_cron_jobs
#
# Every active line that runs something under /usr/local/bin/enginescript is EngineScript's and
# is replaced, so a job that was removed, renamed, or turned off in the install options leaves
# existing servers too. Other lines, such as acme.sh's, are kept. Safe to run again.
function install_enginescript_cron() {
    local current kept new

    current="$(crontab -l 2> /dev/null)" || current=""
    kept="$(grep -vE '^[^#]*/usr/local/bin/enginescript/' <<< "${current}" | sed '/^$/d')"
    new="$(enginescript_cron_jobs)"
    if [[ -n "${kept}" ]]; then
        new="${kept}"$'\n'"${new}"
    fi
    if [[ "${new}" == "${current}" ]]; then
        return 0
    fi
    echo "Updating EngineScript's cron jobs..."
    printf '%s\n' "${new}" | crontab -
}


# ----------------------------------------------------------------
# Install the logrotate rule for scheduled jobs' logs
function install_enginescript_logrotate() {
    cp -f /usr/local/bin/enginescript/config/etc/logrotate.d/enginescript /etc/logrotate.d/enginescript || return 1
    chmod 644 /etc/logrotate.d/enginescript || return 1
    # Older versions rotated an OPcache log that PHP no longer writes
    rm -f /etc/logrotate.d/opcache
}


# ----------------------------------------------------------------
# Cap the systemd journal (config/etc/systemd/journald.conf.d/enginescript.conf); journald shrinks
# it to the cap when it restarts. journald restarts only when the server's copy of the file
# differs, so a settings sync that changes nothing leaves it running.
function install_enginescript_journald() {
    local source="/usr/local/bin/enginescript/config/etc/systemd/journald.conf.d/enginescript.conf"
    local target="/etc/systemd/journald.conf.d/enginescript.conf"

    install -d -m 755 /etc/systemd/journald.conf.d
    if cmp -s "${source}" "${target}"; then
        return 0
    fi
    cp -f "${source}" "${target}" && chmod 644 "${target}" && systemctl restart systemd-journald
}


# ----------------------------------------------------------------
# fail2ban's settings (SSH jail, and how long it remembers past bans), when fail2ban is installed.
# fail2ban restarts only when one of its two files on the server differs.
function install_enginescript_fail2ban_config() {
    local source_dir="/usr/local/bin/enginescript/config/etc/fail2ban"
    local config changed=0

    [[ -d /etc/fail2ban ]] || return 0
    install -d -m 755 /etc/fail2ban/jail.d /etc/fail2ban/fail2ban.d
    for config in jail.d/enginescript.conf fail2ban.d/enginescript.conf; do
        if cmp -s "${source_dir}/${config}" "/etc/fail2ban/${config}"; then
            continue
        fi
        cp -f "${source_dir}/${config}" "/etc/fail2ban/${config}" && chmod 644 "/etc/fail2ban/${config}" || return 1
        changed=1
    done
    if [[ "${changed}" -eq 1 ]] && systemctl is-active --quiet fail2ban; then
        systemctl restart fail2ban
    fi
}


# ----------------------------------------------------------------
# The login message (config/etc/update-motd.d/99-enginescript)
function install_enginescript_motd() {
    cp -f /usr/local/bin/enginescript/config/etc/update-motd.d/99-enginescript /etc/update-motd.d/99-enginescript || return 1
    chown root:root /etc/update-motd.d/99-enginescript
    chmod 755 /etc/update-motd.d/99-enginescript
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
    cp -f /usr/local/bin/enginescript/config/etc/sysctl.d/60-enginescript.conf "${conf}" || return 1
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

    sysctl --system > /dev/null 2>> "${ES_STEP_ERROR_LOG}" || true
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

    # The flags are read as data (load_install_state), never sourced. Without a file, every
    # step is incomplete.
    if load_install_state; then
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
        # The steps this script starts (one-time upgrades, settings sync) skip their own check
        export ES_INSTALL_VERIFIED=1
        return 0
    else
        echo ""
        echo "$script_name cannot proceed until all components are properly installed."
        exit 1
    fi
}


# ----------------------------------------------------------------
# Stop unless EngineScript is fully installed, for the steps es.update runs after its own
# verification (verify_installation_completion sets ES_INSTALL_VERIFIED). Run on their own, they
# check quietly: only the missing steps are printed.
# Usage: require_installation_complete "<script name>"
function require_installation_complete() {
    if [[ "${ES_INSTALL_VERIFIED:-0}" == "1" ]]; then
        return 0
    fi
    if ! check_installation_completion "true"; then
        echo "${1:-This script} cannot proceed until all components are properly installed (run es.install)." >&2
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
# Run one install step once. A step whose flag is 1 in install-state.conf is skipped; otherwise
# its script runs, and its flag is set when the script exits 0. The scripts themselves neither
# check nor set their flag: they exit non-zero when they fail.
# A step that fails stops the install: later steps depend on earlier ones (PHP on MariaDB's
# repository, Nginx on GCC), and the step's flag is not set, so es.install runs it again next time.
# Usage: run_install_step "FLAG_NAME" "/path/to/script.sh" "Step Description"
function run_install_step() {
    local flag_name="$1"
    local script_path="$2"
    local step_desc="$3"
    local flag_value="${!flag_name:-0}"

    if [[ "${flag_value}" = 1 ]]; then
        echo "${flag_name} script has already run."
        return 0
    fi
    if ! run_step "${step_desc}" "${script_path}"; then
        echo "" >&2
        echo "${BOLD}Install step failed: ${step_desc}${NORMAL}" >&2
        echo "The install stopped here. The errors are in /var/log/EngineScript/install-error-log.log." >&2
        echo "Fix the problem, then run es.install again: it carries on from this step." >&2
        exit 1
    fi
    set_install_state "${flag_name}" "1" || exit 1
    printf -v "${flag_name}" '%s' "1"
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
# Install beside, then swap. The build function fills a new, empty staging folder next to the
# target (a private dot folder in the same parent, so the swap is a rename); only when it returns
# 0 does the staging folder replace the target (replace_directory). When it fails, the staging
# folder is removed and the installed copy is left as it was. The build function prints its own
# error. Returns 1 when the target was not replaced.
# Usage: install_beside <target folder> "<name for messages>" <build function> [arguments]
#        (called as: <build function> <staging folder> [arguments])
function install_beside() {
    local target="$1" label="$2" build="$3" parent new_dir
    shift 3
    parent="$(dirname "${target}")"
    mkdir -p "${parent}" || { echo "Error: Failed to create ${parent}" >&2; return 1; }
    new_dir="$(mktemp -d "${parent}/.$(basename "${target}")-new.XXXXXX")" \
        || { echo "Error: Failed to create a staging folder in ${parent}" >&2; return 1; }
    if ! "${build}" "${new_dir}" "$@"; then
        rm -rf "${new_dir:?}"
        echo "${label} was not changed." >&2
        return 1
    fi
    chmod 755 "${new_dir}"
    if ! replace_directory "${new_dir}" "${target}"; then
        rm -rf "${new_dir:?}"
        echo "Error: Failed to move the new copy into ${target}. ${label} was not changed." >&2
        return 1
    fi
}


# ----------------------------------------------------------------
# Build phpMyAdmin (PHPMYADMIN_VER) in a staging folder, for install_beside: download the release,
# unpack it, and keep the installed copy's config.inc.php when there is one (the update).
# Usage: install_beside /var/www/admin/tools/phpmyadmin "phpMyAdmin" build_phpmyadmin
function build_phpmyadmin() {
    local dir="$1" top="phpMyAdmin-${PHPMYADMIN_VER}-all-languages"
    local zip="/usr/src/phpMyAdmin-${PHPMYADMIN_VER}-all-languages.zip"
    local installed_config="/var/www/admin/tools/phpmyadmin/config.inc.php"

    download_file "https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VER}/${top}.zip" "${zip}" >&2 || return 1
    unzip -q -o "${zip}" -d "${dir}" || { echo "Error: Failed to unpack ${zip}" >&2; return 1; }
    if [[ ! -f "${dir}/${top}/index.php" ]]; then
        echo "Error: The phpMyAdmin ${PHPMYADMIN_VER} download has no ${top}/index.php" >&2
        return 1
    fi
    # The release's files go straight into the folder
    if ! { (shopt -s dotglob && mv "${dir}/${top}"/* "${dir}/") && rmdir "${dir}/${top}"; }; then
        echo "Error: Failed to unpack phpMyAdmin into ${dir}" >&2
        return 1
    fi
    mkdir -p "${dir}/tmp"
    if [[ -f "${installed_config}" ]]; then
        cp -p "${installed_config}" "${dir}/config.inc.php" \
            || { echo "Error: Failed to keep ${installed_config}" >&2; return 1; }
    fi
    rm -f "${zip}"
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

    download_file "${url}" "${output_file}" || return 1
    tar -xzf "${output_file}" -C "${extract_dir}" || {
        echo "Error: Failed to extract ${output_file}"
        return 1
    }
}


# ----------------------------------------------------------------
# Remove Apache and the PHP versions EngineScript no longer supports (7.0 to 8.0), old source
# downloads in /usr/src, and apt's cached and no longer needed packages. The package names are
# apt regular expressions, so apt lists every package it checks; that list is not shown.
function run_enginescript_cleanup() {
    apt-get remove -y -qq 'apache2.*' 'php7\.0.*' 'php7\.1.*' 'php7\.2.*' 'php7\.3.*' 'php7\.4.*' 'php8\.0.*' > /dev/null
    rm -rf /usr/src/*.tar.gz*
    apt-get clean
    apt-get autoremove --purge -y
    apt-get autoclean -y
}


# ----------------------------------------------------------------
# The options in enginescript-install-options.txt, in the file's order. Each option belongs to
# one of these two lists or to the backup lines of print_install_settings;
# scripts/ci/test-config-review.sh checks this against the template.
ENGINESCRIPT_SETTING_NAMES=(
    "DEBUG_INSTALL"
    "ADMIN_SUBDOMAIN"
    "INSTALL_PHPMYADMIN"
    "INSTALL_ADMINER"
    "HIGH_SECURITY_SSL"
    "INSTALL_HTTP3"
    "PHP_VERSION_OVERRIDE"
    "AUTOMATIC_LOSSLESS_IMAGE_OPTIMIZATION"
    "INSTALL_ENGINESCRIPT_PLUGINS"
    "INSTALL_EXTRA_WP_PLUGINS"
    "SHOW_ENGINESCRIPT_HEADER"
    "NGINX_BLOCK_UNSAFE_FILES"
    "ZLIB_IMPLEMENTATION"
    "INSTALL_DIGITALOCEAN_REMOTE_CONSOLE"
    "INSTALL_DIGITALOCEAN_METRICS_AGENT"
    "ENGINESCRIPT_AUTO_UPDATE"
    "TEST_MODE"
)
ENGINESCRIPT_CREDENTIAL_NAMES=(
    "S3_BUCKET_NAME"
    "CF_GLOBAL_API_KEY"
    "CF_ACCOUNT_EMAIL"
    "PUSHBULLET_TOKEN"
    "UBUNTU_PRO_TOKEN"
    "UPTIMEROBOT_API_KEY"
    "WPSCANAPI"
    "WP_ADMIN_EMAIL"
    "WP_ADMIN_USERNAME"
    "WP_ADMIN_PASSWORD"
    "WP_RECOVERY_EMAIL"
    "ADMIN_CONTROL_PANEL_USERNAME"
    "ADMIN_CONTROL_PANEL_PASSWORD"
    "MARIADB_ADMIN_PASSWORD"
    "PHPMYADMIN_USERNAME"
    "PHPMYADMIN_PASSWORD"
    "FILEMANAGER_USERNAME"
    "FILEMANAGER_PASSWORD"
)


# ----------------------------------------------------------------
# Print the install options that are settings, not credentials, as "NAME = value" lines
function print_install_settings() {
    local name

    for name in "${ENGINESCRIPT_SETTING_NAMES[@]}"; do
        echo "${name} = ${!name}"
    done
    resolve_backup_settings
    echo "BACKUP_DATABASE_FREQUENCY = ${BACKUP_DATABASE_FREQUENCY} (keep ${BACKUP_DATABASE_KEEP_DAYS} days)"
    echo "BACKUP_FILES_FREQUENCY = ${BACKUP_FILES_FREQUENCY} (keep ${BACKUP_FILES_KEEP_COPIES} copies)"
    echo "BACKUP_CONFIG_FREQUENCY = ${BACKUP_CONFIG_FREQUENCY} (keep ${BACKUP_CONFIG_KEEP_DAYS} days)"
    echo "BACKUP_S3 = ${BACKUP_S3} (include configuration: ${BACKUP_S3_INCLUDE_CONFIG}, keep: ${BACKUP_S3_KEEP_DAYS:-not deleted})"
}


# ----------------------------------------------------------------
# Print the credential options as "NAME = value" lines
function print_install_credentials() {
    local name

    for name in "${ENGINESCRIPT_CREDENTIAL_NAMES[@]}"; do
        echo "${name} = ${!name}"
    done
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
# Send a note to the admin through Pushbullet, when a token is set
# The token goes in on standard input: command-line arguments are visible to every user.
# Usage: notify_admin "Title" "Message"
function notify_admin() {
    local title="$1" message="$2"

    if [[ -z "${PUSHBULLET_TOKEN:-}" || "${PUSHBULLET_TOKEN}" == "PLACEHOLDER" ]]; then
        return 0
    fi
    printf 'user = "%s:"\n' "${PUSHBULLET_TOKEN}" | curl -fsS --proto '=https' --max-time 30 -K - -o /dev/null \
        https://api.pushbullet.com/v2/pushes -d type=note --data-urlencode "title=${title}" --data-urlencode "body=${message}"
}


# ----------------------------------------------------------------
# Download a file over HTTPS with curl (redirects to plain HTTP are refused)
# Usage: download_file "URL" "/destination/path"
function download_file() {
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
# Shared tuning plan (memory budget for Nginx, PHP-FPM, MariaDB, and Redis)
# shellcheck source=enginescript-tuning.sh
source "$(dirname "${BASH_SOURCE[0]}")/enginescript-tuning.sh"
