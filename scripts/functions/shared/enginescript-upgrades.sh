#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------
# One-Time Upgrades
# The changes servers installed by earlier versions get once (run_once), listed in
# ONE_TIME_UPGRADES in normal-auto-upgrade.sh, which loads this file after enginescript-common.sh.
#----------------------------------------------------------------------------------


# ----------------------------------------------------------------
# One-time upgrades (normal-auto-upgrade.sh)
#
# Each one-time upgrade is a function that brings an existing server up to the current setup.
# Its name is recorded in upgrades-done.conf when it succeeds, and it never runs again on that
# server; one that fails is tried again on the next update. New installs record every one-time
# upgrade as done, since they start with the current setup. The record is in /var/lib/enginescript,
# which only root can write to.
#
# The record holds the function's name. To change what an upgrade that servers have already run
# does, add a new function with a new name: editing the old one reaches only the servers that
# have not run it yet.

# True when the one-time upgrade has already run on this server
function upgrade_is_done() {
    grep -qxF "$1" "${ENGINESCRIPT_UPGRADES_DONE_FILE:-/var/lib/enginescript/upgrades-done.conf}" 2> /dev/null
}

# Record a one-time upgrade as done
function record_upgrade_done() {
    local done_file="${ENGINESCRIPT_UPGRADES_DONE_FILE:-/var/lib/enginescript/upgrades-done.conf}"
    upgrade_is_done "$1" && return 0
    mkdir -p "$(dirname "${done_file}")" || return 1
    echo "$1" >> "${done_file}" || return 1
    chmod 644 "${done_file}"
}

# Remove a one-time upgrade's record, so the next update runs it again. The install uses it when
# a step that an upgrade repeats did not finish (install_fail2ban after fail2ban failed).
function forget_upgrade_done() {
    local done_file="${ENGINESCRIPT_UPGRADES_DONE_FILE:-/var/lib/enginescript/upgrades-done.conf}"
    upgrade_is_done "$1" || return 0
    sed -i "/^${1}\$/d" "${done_file}"
}

# Usage: run_once <function>
# Run a one-time upgrade unless it has already run, and record it when it succeeds
function run_once() {
    upgrade_is_done "$1" && return 0
    if "$1"; then
        record_upgrade_done "$1"
    else
        echo "Error: $1 did not finish; it runs again on the next EngineScript update." >&2
        return 1
    fi
}

# Usage: package_is_installed <package>
# Succeeds when dpkg has the package installed (also when it is held)
function package_is_installed() {
    local package="$1"
    dpkg-query -W -f='${Status}' "${package}" 2> /dev/null | grep -q 'ok installed'
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
    local SITES=() domain domain_conf failures=0

    if [[ ! -x "${acme}" ]]; then
        return 0
    fi
    es_sites

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
            || { echo "Warning: Could not add a certificate reload command for ${domain}." >&2; failures=1; }
        secure_nginx_ssl_directory "/etc/nginx/ssl/${domain}"
    done
    return "${failures}"
}


# ----------------------------------------------------------------
# Move the PHP-FPM log back to the package default
#
# EngineScript used to set error_log = /var/log/php/phpX.Y-fpm.log, which no logrotate file
# covers, so the log grew without limit. The PHP package logs to /var/log/phpX.Y-fpm.log and
# rotates it with its own logrotate file. This changes only the error_log line of existing
# installs, tests the configuration, and reloads PHP-FPM.
function migrate_php_fpm_log_path() {
    local conf ver old_log failures=0
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
            failures=1
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
    return "${failures}"
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
# Remove the import folders older versions created
#
# Import Domain reads one site archive placed directly in /home/EngineScript/temp/site-import.
# The database-file and root-directory folders inside it belonged to an import format that is
# gone. They are removed only when empty, so nothing left in them is lost.
function remove_old_import_folders() {
    local folder
    for folder in database-file root-directory; do
        rmdir "/home/EngineScript/temp/site-import/${folder}" 2> /dev/null
    done
    return 0
}


# ----------------------------------------------------------------
# Remove the variables and install options lines from the site list
#
# The site list template of older versions loaded enginescript-variables.txt and the install
# options itself, so every script that read the list loaded them again partway through and drew
# new random values. The list now holds only SITES; its domains stay as they are.
function remove_site_list_variable_sources() {
    local sites_file="${ES_SITES_LIST:-/home/EngineScript/sites-list/sites.sh}"

    if [[ ! -f "${sites_file}" ]]; then
        return 0
    fi
    sed -i \
        -e '/^# EngineScript Variables$/d' \
        -e '\|^source /usr/local/bin/enginescript/enginescript-variables.txt|d' \
        -e '\|^source /home/EngineScript/enginescript-install-options.txt|d' \
        "${sites_file}"
}


# ----------------------------------------------------------------
# Install igbinary explicitly for every installed PHP version
#
# Redis Object Cache serializes with it (WP_REDIS_IGBINARY). Existing servers only have it as a
# dependency of php-redis, marked automatically installed, so apt autoremove would remove it if
# php-redis ever stopped requiring it. Installing it by name marks it manually installed, and
# adds it where it is missing (then PHP-FPM reloads to load the extension).
function ensure_php_igbinary() {
    local ver failures=0
    while IFS= read -r ver; do
        [[ -n "${ver}" ]] || continue
        if package_is_installed "php${ver}-igbinary"; then
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
            failures=1
        fi
    done < <(get_installed_php_versions)
    return "${failures}"
}


# ----------------------------------------------------------------
# Install PHP's SOAP extension on existing installs
#
# SOAP is in the standard PHP package list since 2026-11-27 (get_php_packages_array): shipping
# and payment connectors call SOAP APIs (WooCommerce's FedEx rates, for example), and Site Health
# asks for it. php.ini already holds its settings, and its WSDL cache folder already exists
# (php-install.sh, set_php_permissions). This installs it for each installed PHP version and
# reloads that version's PHP-FPM, so the sites can use it.
function ensure_php_soap() {
    local ver failures=0
    while IFS= read -r ver; do
        [[ -n "${ver}" ]] || continue
        package_is_installed "php${ver}-soap" && continue
        echo "Installing php${ver}-soap..."
        if apt-get install -y -qq "php${ver}-soap" > /dev/null; then
            if systemctl is-active --quiet "php${ver}-fpm"; then
                systemctl reload "php${ver}-fpm"
            fi
        else
            echo "Error: Installing php${ver}-soap failed." >&2
            failures=1
        fi
    done < <(get_installed_php_versions)
    return "${failures}"
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
    local ini ver failures=0
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
            failures=1
            continue
        fi
        rm -f "${ini}.pre-upload-progress"

        # A reload (graceful restart) starts new workers with the changed php.ini
        if systemctl is-active --quiet "php${ver}-fpm"; then
            systemctl reload "php${ver}-fpm"
        fi
    done
    return "${failures}"
}



# Existing servers: at least REDIS_MIN_DATABASES databases, and every site on its own number.
# Earlier versions numbered sites by the site count, so a site added after a removal could share
# a number with another site. The first site (in directory order) keeps a shared number; the
# others move to free numbers, which only empties their object cache.
function migrate_redis_databases() {
    local count number wp_config failures=0
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
        assign_site_redis_database "${wp_config}" || failures=1
    done
    return "${failures}"
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
# Keep WordPress's Cache-Control on PHP responses
#
# The site-wide "expires" replaced the Cache-Control that WordPress sends for logged-in pages,
# wp-admin, wp-login.php, and REST responses ("no-cache, must-revalidate, max-age=0, no-store,
# private") with just "no-cache", so a shared cache could store a logged-in page. The next Nginx
# update brings the fix with the rest of the configuration; this adds it now: the
# $es_php_expires map in map-expires.conf and "expires $es_php_expires" in php-fpm.conf. Nginx
# reloads only when its configuration test passes; otherwise both files are put back.
function migrate_nginx_php_cache_control() {
    local globals="${ES_NGINX_GLOBALS:-/etc/nginx/globals}"
    local maps="${globals}/map-expires.conf" php="${globals}/php-fpm.conf" line

    [[ -f "${maps}" && -f "${php}" ]] || return 0
    # shellcheck disable=SC2016  # Nginx variables, matched as text
    grep -q 'expires \$es_php_expires;' "${php}" && return 0

    echo "Nginx: logged-in pages keep WordPress's Cache-Control (private, no-store)..."
    cp -p "${maps}" "${maps}.pre-cache-control"
    cp -p "${php}" "${php}.pre-cache-control"

    # shellcheck disable=SC2016  # Nginx variables, matched as text
    if ! grep -q 'map \$upstream_http_cache_control \$es_php_expires' "${maps}"; then
        cat >> "${maps}" << 'MAP'

# For PHP responses (php-fpm.conf): the content-type lifetime above only when PHP sent no
# Cache-Control of its own. WordPress sends "no-cache, must-revalidate, max-age=0, no-store,
# private" for logged-in pages, wp-admin, wp-login.php, and REST responses, and "expires" would
# otherwise replace it with just "no-cache".
map $upstream_http_cache_control $es_php_expires {
  ""                                      $expires;
  default                                 off;
}
MAP
    fi

    # Before the FastCGI cache key, as in the current php-fpm.conf
    line="$(grep -n -m 1 -e '^# FastCGI cache key$' -e '^fastcgi_cache_key ' "${php}" | cut -d: -f1)"
    if [[ -z "${line}" ]]; then
        echo "Error: ${php} has no fastcgi_cache_key line; left unchanged." >&2
        mv -f "${maps}.pre-cache-control" "${maps}"
        mv -f "${php}.pre-cache-control" "${php}"
        return 1
    fi
    {
        head -n "$((line - 1))" "${php}.pre-cache-control"
        echo "# Keep the Cache-Control that WordPress sends (private, no-store for logged-in pages); the"
        echo "# content-type lifetimes apply only to responses without one (map-expires.conf)"
        echo "expires \$es_php_expires;"
        echo ""
        tail -n "+${line}" "${php}.pre-cache-control"
    } > "${php}"

    if ! nginx -t > /dev/null 2>&1; then
        echo "Error: nginx -t failed; kept the previous map-expires.conf and php-fpm.conf." >&2
        mv -f "${maps}.pre-cache-control" "${maps}"
        mv -f "${php}.pre-cache-control" "${php}"
        return 1
    fi
    rm -f "${maps}.pre-cache-control" "${php}.pre-cache-control"
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
    fi
}

# ----------------------------------------------------------------
# Install fail2ban on servers set up before it was part of the install
#
# fail2ban bans an address for an hour after 5 failed SSH logins within 10 minutes. New installs
# get it in the tools step; existing servers only got it from Update Server Tools. Servers that
# already have it are left alone.
function install_fail2ban() {
    package_is_installed fail2ban && return 0
    echo "Installing fail2ban (bans addresses after repeated failed SSH logins)..."
    "${ES_FAIL2BAN_SCRIPT:-/usr/local/bin/enginescript/scripts/install/tools/security/fail2ban.sh}"
}


# ----------------------------------------------------------------
# Add the automatic software update options to the install options file
#
# Options files written before AUTO_UPDATE_NGINX, AUTO_UPDATE_PHP, and AUTO_UPDATE_MARIADB
# existed have none of them, and a missing option is on (resolve_auto_update_settings). Writing
# them into the file, below ENGINESCRIPT_AUTO_UPDATE, shows the admin that they exist and where
# to switch them off. A new release waits a day before it is installed, so the note sent here
# reaches the admin before the first automatic update. Options already in the file are kept.
function add_auto_update_options() {
    local options_file="${ENGINESCRIPT_INSTALL_OPTIONS_FILE:-/home/EngineScript/enginescript-install-options.txt}"
    local name block

    if [[ ! -f "${options_file}" ]]; then
        return 0
    fi
    block="$(mktemp)" || return 1
    for name in AUTO_UPDATE_NGINX AUTO_UPDATE_PHP AUTO_UPDATE_MARIADB; do
        if grep -q "^${name}=" "${options_file}"; then
            continue
        fi
        case "${name}" in
            AUTO_UPDATE_NGINX) echo "# Nginx: rebuilt when Nginx, OpenSSL, PCRE2, or zlib has a new release (sites keep serving throughout)" ;;
            AUTO_UPDATE_PHP) echo "# PHP: patch releases of the installed version only. Switching to a new version is never automatic." ;;
            AUTO_UPDATE_MARIADB) echo "# MariaDB: patch releases of the installed series only. Every database is backed up first. MariaDB restarts." ;;
            *) ;;
        esac
        echo "${name}=1"
    done > "${block}"
    if [[ ! -s "${block}" ]]; then
        rm -f "${block}"
        return 0
    fi

    echo "Adding the automatic software update options to ${options_file}..."
    {
        echo ""
        echo "## Automatic Software Updates (Recommended) ##"
        echo "# Installs new releases of Nginx, PHP, and MariaDB about a day after EngineScript has tested"
        echo "# and released them. Each update backs up first and checks that your sites still work."
        echo "# These need ENGINESCRIPT_AUTO_UPDATE=1. 0 = disabled, 1 = enabled"
        cat "${block}"
    } > "${block}.new"
    # shellcheck disable=SC2181  # the status of the block above, which is too long for an if
    if [[ $? -ne 0 ]] || ! mv -f "${block}.new" "${block}"; then
        rm -f "${block}" "${block}.new"
        return 1
    fi

    if grep -q '^ENGINESCRIPT_AUTO_UPDATE=' "${options_file}"; then
        sed -i "/^ENGINESCRIPT_AUTO_UPDATE=/r ${block}" "${options_file}" || { rm -f "${block}"; return 1; }
    else
        cat "${block}" >> "${options_file}" || { rm -f "${block}"; return 1; }
    fi
    rm -f "${block}"

    notify_admin "Server: ${IP_ADDRESS:-}" "EngineScript now installs new Nginx, PHP patch, and MariaDB patch releases automatically, about a day after each is released, with a backup and checks first. To switch any of them off, run es.config and set AUTO_UPDATE_NGINX, AUTO_UPDATE_PHP, or AUTO_UPDATE_MARIADB to 0." || true
}


# ----------------------------------------------------------------
# Compile with GCC 15 on Ubuntu 26.04
#
# Ubuntu 26.04's gcc-16 is a development snapshot of GCC 16 (16-20260322, "experimental"), not a
# release, and servers installed before November 2026 compiled Nginx and OpenSSL with it.
# gcc-install.sh now sets up GCC 15 alone on 26.04: running it again points the gcc alternative
# at GCC 15, and the snapshot is removed. Nginx is rebuilt with GCC 15 on its next update.
function migrate_gcc_15_on_ubuntu_26_04() {
    [[ "${UBUNTU_VERSION:-}" == "26.04" ]] || return 0
    package_is_installed gcc-16 || return 0
    echo "Switching the compiler from the GCC 16 development snapshot to GCC 15..."
    "${ES_GCC_INSTALL_SCRIPT:-/usr/local/bin/enginescript/scripts/install/gcc/gcc-install.sh}" || return 1
    apt-get remove --purge -y g++-16 gcc-16 \
        || echo "Warning: The GCC 16 snapshot could not be removed. GCC 15 compiles from now on." >&2
}


# ----------------------------------------------------------------
# Remove the liburing EngineScript compiled from source
#
# Older versions compiled liburing and installed it in /usr: the library in /usr/lib, headers in
# /usr/include, and man pages in /usr/man. Nothing used it. MariaDB loads Ubuntu's liburing2 from
# /usr/lib/x86_64-linux-gnu, which the loader searches first, and Nginx, PHP-FPM, and Redis do not
# use liburing. A file a package owns is left alone. While a running program has the library
# loaded, nothing is removed, and the upgrade runs again on the next update.
# ES_LIBURING_ROOT puts the paths under another folder (for tests).
function remove_source_built_liburing() {
    local root="${ES_LIBURING_ROOT:-}" file dir
    local -a files=()

    if grep -lsF "${root}/usr/lib/liburing" /proc/[0-9]*/maps > /dev/null 2>&1; then
        echo "Warning: A running program has the old liburing loaded; it is removed on the next update." >&2
        return 1
    fi

    shopt -s nullglob
    files=(
        "${root}"/usr/lib/liburing*.so* "${root}"/usr/lib/liburing*.a
        "${root}"/usr/lib/pkgconfig/liburing*.pc
        "${root}"/usr/include/liburing.h "${root}"/usr/include/liburing/*.h "${root}"/usr/include/liburing/io_uring/*.h
        "${root}"/usr/man/man[237]/*[iI][oO]_[uU][rR][iI][nN][gG]*
    )
    shopt -u nullglob
    if [[ ${#files[@]} -eq 0 ]]; then
        return 0
    fi

    echo "Removing the liburing EngineScript compiled from source (nothing on the server uses it)..."
    for file in "${files[@]}"; do
        if dpkg-query -S "${file#"${root}"}" > /dev/null 2>&1; then
            continue
        fi
        rm -f "${file}"
    done
    # The folders only liburing used, once empty (rmdir leaves a folder that still has files)
    for dir in "${root}/usr/include/liburing/io_uring" "${root}/usr/include/liburing" \
        "${root}"/usr/man/man[237] "${root}/usr/man"; do
        rmdir "${dir}" 2> /dev/null || true
    done
    rm -rf "${root}"/usr/src/liburing-liburing-*
    if [[ -z "${root}" ]]; then
        ldconfig
    fi
    return 0
}


# ----------------------------------------------------------------
# Remove the documentation tools pipx brought in
#
# The Gixy-Next step installed pipx with its recommended packages: mkdocs, a documentation site
# generator, and about 40 packages it needs (numpy, nltk, pytest, tk, and others). Gixy-Next does
# not use them; pipx gives it its own Python environment. mkdocs is removed only when apt
# installed it as a recommendation (marked automatic), not when the admin installed it, and
# autoremove then removes what only it needed.
function remove_pipx_recommended_packages() {
    package_is_installed mkdocs || return 0
    apt-mark showauto mkdocs 2> /dev/null | grep -qx 'mkdocs' || return 0
    echo "Removing mkdocs and the packages only it needs (pipx installed them; Gixy-Next does not use them)..."
    apt-get purge -y mkdocs || return 1
    apt-get autoremove --purge -y || return 1
}


# ----------------------------------------------------------------
# Remove ktls-utils
#
# Its only program, tlshd, is a background service that does TLS handshakes for TLS users inside
# the kernel (NFS over TLS, NVMe over TCP). Nginx's kTLS does not use it: OpenSSL does the
# handshake inside Nginx and passes the keys to the kernel's tls module, which EngineScript loads
# itself (/etc/modules-load.d/tls.conf). Tested: with ktls-utils purged, Nginx still sends
# through kernel TLS.
function remove_ktls_utils() {
    package_is_installed ktls-utils || return 0
    echo "Removing ktls-utils (its tlshd service is not used; Nginx's kTLS does not need it)..."
    apt-get purge -y ktls-utils
}


# ----------------------------------------------------------------
# Remove the unused development libraries
#
# The dependencies step installed development libraries (-dev) that nothing compiles against:
# Nginx compiles with its own copies of OpenSSL, PCRE2, zlib, and Brotli, and PHP comes from
# packages. libjemalloc2 is here too: nothing has used it since Nginx stopped linking it in 2024.
#
# Each one that is installed is marked as automatically installed, so apt keeps it while an
# installed package still needs it (libjemalloc2 for redis-tools on Ubuntu 26.04, for example).
# Then only the packages that this marking left unneeded are purged: the libraries and what only
# they needed. Packages that were already unneeded before are left alone.
#
# zlib1g-dev is not on the list: the system's zlib is kept whole for other software (Nginx links
# its own). Servers that ran this before it was taken off get it back (restore_zlib_dev).
UNUSED_DEV_LIBRARIES=(
    libbsd-dev libbz2-dev libcunit1-dev libcurl4-openssl-dev libelf-dev libev-dev libevent-dev
    libexpat1-dev libgd-dev libgeoip-dev libgoogle-perftools-dev libjansson-dev libjemalloc-dev
    libjemalloc2 libmaxminddb-dev libmcrypt-dev libmhash-dev libmnl-dev libopts25-dev libpam0g-dev
    libpcre2-dev libpcre3-dev libperl-dev libreadline-dev libsodium-dev libssh2-1-dev libssl-dev
    libtidy-dev libxml2-dev libxslt1-dev uuid-dev
)
function remove_unused_dev_libraries() {
    local -a installed=() before=() after=() unneeded=()
    mapfile -t installed < <(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' "${UNUSED_DEV_LIBRARIES[@]}" 2> /dev/null \
        | awk '$1 == "ii" { print $2 }')
    if [[ ${#installed[@]} -eq 0 ]]; then return 0; fi

    mapfile -t before < <(apt-get -s autoremove 2> /dev/null | awk '$1 == "Remv" { print $2 }')
    apt-mark auto "${installed[@]}" > /dev/null || return 1
    mapfile -t after < <(apt-get -s autoremove 2> /dev/null | awk '$1 == "Remv" { print $2 }')
    mapfile -t unneeded < <(comm -13 <(printf '%s\n' "${before[@]}" | sort -u) <(printf '%s\n' "${after[@]}" | sort -u) | grep -v '^$')
    if [[ ${#unneeded[@]} -eq 0 ]]; then return 0; fi

    echo "Removing ${#unneeded[@]} unused development libraries and the packages only they needed..."
    apt-get purge -y "${unneeded[@]}"
}


# ----------------------------------------------------------------
# Put the system zlib's headers back
#
# remove_unused_dev_libraries removed zlib1g-dev (zlib.h, libz.so for compiling) until
# 2026-11-27. The system's zlib stays whole for software compiled on the server; Nginx links the
# zlib ZLIB_IMPLEMENTATION selects, built in its own folder, and does not use it.
function restore_zlib_dev() {
    package_is_installed zlib1g-dev && return 0
    echo "Installing zlib1g-dev (the system zlib's headers, for software compiled on the server)..."
    apt-get install -y zlib1g-dev
}


# ----------------------------------------------------------------
# Let existing site users read mysql.table_stats
#
# Site users created from 2026-11-27 can read mysql.table_stats (grant_site_table_stats in
# enginescript-db-credentials.sh), which the MariaDB Health Checks plugin needs for its
# histograms. This gives the same one privilege to the users of existing sites: the user named in
# each site's credentials file, when it exists. Granting it again changes nothing.
function grant_site_users_table_stats() {
    local credentials_dir="${ES_MYSQL_CREDENTIALS_DIR:-/home/EngineScript/mysql-credentials}"
    local file usr failures=0
    for file in "${credentials_dir}"/*.txt; do
        [[ -f "${file}" ]] || continue
        usr="$(sed -n 's/^USR="\(.*\)"$/\1/p' "${file}" | head -n 1)"
        [[ "${usr}" =~ ^[A-Za-z0-9_]+$ ]] || continue
        [[ "$(mariadb -N -e "SELECT COUNT(*) FROM mysql.user WHERE User = '${usr}' AND Host = 'localhost';")" == "1" ]] || continue
        if ! mariadb -e "GRANT SELECT ON mysql.table_stats TO '${usr}'@'localhost';"; then
            echo "Error: Could not let '${usr}' ($(basename "${file}" .txt)) read mysql.table_stats." >&2
            failures=$((failures + 1))
        fi
    done
    [[ "${failures}" -eq 0 ]]
}


# ----------------------------------------------------------------
# PHP-FPM: keep running when a worker is killed at the memory ceiling
#
# install_php_fpm_service_override now adds OOMPolicy=continue to the override that holds the
# tuning plan's memory ceiling: with systemd's default (stop), the kernel killing one worker at
# MemoryMax stopped all of PHP-FPM. The override is rewritten only on a re-tune, so servers get
# it here, for each PHP version that has EngineScript's override. daemon-reload applies it to
# the running service; no restart.
function migrate_php_fpm_oom_policy() {
    local systemd_dir="${ES_SYSTEMD_DIR:-/etc/systemd/system}" conf ver failures=0
    for conf in "${systemd_dir}"/php*-fpm.service.d/enginescript.conf; do
        [[ -f "${conf}" ]] || continue
        grep -qx 'OOMPolicy=continue' "${conf}" && continue
        ver="${conf#"${systemd_dir}"/php}"
        ver="${ver%%-fpm.service.d/*}"
        echo "PHP ${ver}: PHP-FPM now keeps running when a worker is killed at its memory limit..."
        install_php_fpm_service_override "${ver}"
        if ! grep -qx 'OOMPolicy=continue' "${conf}"; then
            echo "Error: could not update ${conf}." >&2
            failures=1
        fi
    done
    return "${failures}"
}
