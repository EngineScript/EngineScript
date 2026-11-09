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
# which only root can write to (unlike /etc/enginescript, which the web server user owns).

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
    dpkg-query -W -f='${Status}' fail2ban 2> /dev/null | grep -q 'ok installed' && return 0
    echo "Installing fail2ban (bans addresses after repeated failed SSH logins)..."
    "${ES_FAIL2BAN_SCRIPT:-/usr/local/bin/enginescript/scripts/install/tools/security/fail2ban.sh}"
}
