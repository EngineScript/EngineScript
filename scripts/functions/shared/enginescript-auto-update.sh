#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------
# Automatic Software Updates
# The decisions software-auto-update.sh makes for Nginx, PHP, and MariaDB: whether a part is
# switched on, whether the server is behind, and whether a new release has waited long enough.
# Loaded after enginescript-common.sh. scripts/ci/test-auto-update.sh tests these functions.
#----------------------------------------------------------------------------------

# ----------------------------------------------------------------
# State, in /var/lib/enginescript/auto-update (only root can write to it; ES_AUTO_UPDATE_DIR
# overrides the folder for tests). For each part (nginx, php, mariadb):
#   <part>.pending   the release waiting to be installed, and the day the server first saw it
#   <part>.failed    the release whose automatic update failed (not tried again)
#   <part>.last      the last automatic update: day, result, and release
#   nginx.installed  what the installed Nginx was built from (nginx_build_fingerprint)
function auto_update_dir() {
    echo "${ES_AUTO_UPDATE_DIR:-/var/lib/enginescript/auto-update}"
}


# ----------------------------------------------------------------
# Resolve the automatic update settings
#
# The install options set AUTO_UPDATE_NGINX, AUTO_UPDATE_PHP, and AUTO_UPDATE_MARIADB (0 | 1).
# Options files written before these settings existed have none of them: a missing setting is
# on, and so is any value other than 0. AUTO_UPDATE_DELAY_DAYS (enginescript-variables.txt) is
# the number of days a new release waits on a server before it is installed.
function resolve_auto_update_settings() {
    local setting

    for setting in AUTO_UPDATE_NGINX AUTO_UPDATE_PHP AUTO_UPDATE_MARIADB; do
        if [[ "${!setting:-1}" == "0" ]]; then
            printf -v "${setting}" '%s' 0
        else
            printf -v "${setting}" '%s' 1
        fi
    done
    if [[ ! "${AUTO_UPDATE_DELAY_DAYS:-}" =~ ^[0-9]+$ ]]; then
        AUTO_UPDATE_DELAY_DAYS=1
    fi
}


# ----------------------------------------------------------------
# True when the maintainer paused a part's automatic updates (AUTO_UPDATE_PAUSED in
# enginescript-variables.txt names the parts, or "all")
# Usage: auto_update_paused <nginx|php|mariadb>
function auto_update_paused() {
    local name

    for name in ${AUTO_UPDATE_PAUSED//,/ }; do
        if [[ "${name}" == "$1" || "${name}" == "all" ]]; then
            return 0
        fi
    done
    return 1
}


# ----------------------------------------------------------------
# True when a part's automatic updates are switched on in the install options
# (after resolve_auto_update_settings)
# Usage: auto_update_enabled <nginx|php|mariadb>
function auto_update_enabled() {
    local setting="AUTO_UPDATE_${1^^}"

    [[ "${!setting:-1}" == "1" ]]
}


# ----------------------------------------------------------------
# Decide whether a release is installed now
#
# A release the server sees for the first time is recorded and waits AUTO_UPDATE_DELAY_DAYS
# days, so a release that turns out to be bad can be paused or withdrawn before most servers
# install it. A release whose automatic update failed is not tried again: the server would
# otherwise compile and restart every day. It is tried again when the release changes, or after
# a successful update by hand. Returns 0 when the release is due; otherwise prints the reason
# and returns 1. ES_AUTO_UPDATE_TODAY overrides the day (YYYY-MM-DD, for tests).
# Usage: auto_update_due <part> "<release>"
function auto_update_due() {
    local part="$1" release="$2" dir today seen_release="" seen_day="" waited
    dir="$(auto_update_dir)"
    today="${ES_AUTO_UPDATE_TODAY:-$(date -u +%F)}"

    if [[ -f "${dir}/${part}.failed" && "$(< "${dir}/${part}.failed")" == "${release}" ]]; then
        echo "its automatic update failed before, so it is not tried again. Run the update by hand (es.menu > Update Software)."
        return 1
    fi

    if [[ -f "${dir}/${part}.pending" ]]; then
        { IFS= read -r seen_release; IFS= read -r seen_day; } < "${dir}/${part}.pending"
    fi
    if [[ "${seen_release}" != "${release}" || ! "${seen_day}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        mkdir -p "${dir}" || return 1
        printf '%s\n%s\n' "${release}" "${today}" > "${dir}/${part}.pending" || return 1
        seen_day="${today}"
    fi

    waited=$(( ($(date -u -d "${today}" +%s) - $(date -u -d "${seen_day}" +%s)) / 86400 ))
    if (( waited < AUTO_UPDATE_DELAY_DAYS )); then
        echo "first seen on ${seen_day}; it is installed ${AUTO_UPDATE_DELAY_DAYS} day(s) after that."
        return 1
    fi
    return 0
}


# ----------------------------------------------------------------
# Record a release whose automatic update failed (see auto_update_due)
# Usage: auto_update_record_failed <part> "<release>"
function auto_update_record_failed() {
    local dir
    dir="$(auto_update_dir)"

    mkdir -p "${dir}" || return 1
    printf '%s\n' "$2" > "${dir}/$1.failed"
}


# ----------------------------------------------------------------
# Forget a part's waiting and failed releases, after a successful update (automatic or by hand)
# Usage: auto_update_clear <part>
function auto_update_clear() {
    local dir
    dir="$(auto_update_dir)"

    rm -f "${dir}/$1.pending" "${dir}/$1.failed"
}


# ----------------------------------------------------------------
# Record a part's last automatic update, for es.debug
# Usage: auto_update_record_last <part> <updated|failed> "<description>"
function auto_update_record_last() {
    local dir
    dir="$(auto_update_dir)"

    mkdir -p "${dir}" || return 1
    printf '%s %s: %s\n' "$(date -u +%F)" "$2" "$3" > "${dir}/$1.last"
}


# ----------------------------------------------------------------
# Print what an Nginx built now would be built from: the versions in enginescript-variables.txt
# that nginx-build.sh compiles in, the install options that change the build, and
# NGINX_BUILD_REV, which the maintainer raises when a change to the build itself should reach
# every server. A server whose installed Nginx has another fingerprint is behind.
function nginx_build_fingerprint() {
    local zlib

    case "${ZLIB_IMPLEMENTATION:-}" in
        zlib-ng) zlib="zlib-ng-${ZLIB_NG_VER}" ;;
        zlib-rs) zlib="zlib-rs-${ZLIB_RS_VER}" ;;
        *) zlib="zlib-${ZLIB_VER}" ;;
    esac
    echo "nginx=${NGINX_VER} openssl=${OPENSSL_VER} pcre2=${PCRE2_VER} zlib=${zlib} headers-more=${NGINX_HEADER_VER} cache-purge=${NGINX_PURGE_VER} http3=${INSTALL_HTTP3:-0} rev=${NGINX_BUILD_REV:-1}"
}


# ----------------------------------------------------------------
# Record the fingerprint of the Nginx that was just built and is running (the install and
# nginx-update.sh, after their checks pass)
function record_nginx_build_fingerprint() {
    local dir
    dir="$(auto_update_dir)"

    mkdir -p "${dir}" || return 1
    nginx_build_fingerprint > "${dir}/nginx.installed"
}


# ----------------------------------------------------------------
# Print the fingerprint Nginx should be rebuilt to, or nothing when the installed Nginx is
# current
#
# Servers installed before the fingerprint existed have none. Theirs is recorded without a
# rebuild when the running Nginx already has the current Nginx and OpenSSL versions (the two
# the binary reports), so the first automatic run does not rebuild every server.
# ES_NGINX_BIN overrides the binary (for tests).
function nginx_auto_update_target() {
    local dir current installed="" nginx_bin="${ES_NGINX_BIN:-/usr/sbin/nginx}" build_info
    dir="$(auto_update_dir)"
    current="$(nginx_build_fingerprint)"

    if [[ -f "${dir}/nginx.installed" ]]; then
        installed="$(< "${dir}/nginx.installed")"
    else
        build_info="$("${nginx_bin}" -V 2>&1)"
        if [[ "${build_info}" =~ nginx/([0-9.]+) && "${BASH_REMATCH[1]}" == "${NGINX_VER}" ]] \
            && [[ "${build_info}" =~ built\ with\ OpenSSL\ ([^[:space:]]+) && "${BASH_REMATCH[1]}" == "${OPENSSL_VER}" ]]; then
            record_nginx_build_fingerprint || return 1
            installed="${current}"
        fi
    fi

    if [[ "${installed}" != "${current}" ]]; then
        echo "${current}"
    fi
}


# ----------------------------------------------------------------
# Send the admin a note once: a note already sent with the same value is not sent again
# (the newest supported PHP version, the MariaDB series EngineScript installs)
# Usage: auto_update_notice_once <name> "<value>" "<message>"
function auto_update_notice_once() {
    local dir
    dir="$(auto_update_dir)"

    if [[ -f "${dir}/$1.notified" && "$(< "${dir}/$1.notified")" == "$2" ]]; then
        return 0
    fi
    echo "Notice: $3"
    notify_admin "Server: ${IP_ADDRESS:-}" "$3" || return 1
    mkdir -p "${dir}" || return 1
    printf '%s\n' "$2" > "${dir}/$1.notified"
}


# ----------------------------------------------------------------
# Print the installed MariaDB server version (11.8.9 from 1:11.8.9+maria~ubu2604), or nothing
function mariadb_installed_version() {
    local version
    version="$(dpkg-query -W -f='${Version}' mariadb-server 2> /dev/null)"
    if [[ "${version}" =~ ^([0-9]+:)?([0-9]+\.[0-9]+\.[0-9]+) ]]; then
        echo "${BASH_REMATCH[2]}"
    fi
}


# ----------------------------------------------------------------
# Print the MariaDB release to update to, or nothing
#
# Only a newer patch release of the installed series (11.8.x): a new series changes how
# MariaDB behaves and stays a step the admin takes (es.menu > Update Software > Update MariaDB).
# Nothing is printed when MariaDB is not installed, or newer than MARIADB_VER.
function mariadb_auto_update_target() {
    local installed
    installed="$(mariadb_installed_version)"

    if [[ -z "${installed}" || -z "${MARIADB_VER:-}" || "${installed}" == "${MARIADB_VER}" ]]; then
        return 0
    fi
    if [[ "${installed%.*}" != "${MARIADB_VER%.*}" ]]; then
        return 0
    fi
    if [[ "$(printf '%s\n' "${installed}" "${MARIADB_VER}" | sort -V | tail -n 1)" == "${MARIADB_VER}" ]]; then
        echo "${MARIADB_VER}"
    fi
}


# ----------------------------------------------------------------
# Print MARIADB_VER when it is a newer series than the installed one (for a one-time note)
function mariadb_newer_series() {
    local installed
    installed="$(mariadb_installed_version)"

    if [[ -z "${installed}" || -z "${MARIADB_VER:-}" || "${installed%.*}" == "${MARIADB_VER%.*}" ]]; then
        return 0
    fi
    if [[ "$(printf '%s\n' "${installed%.*}" "${MARIADB_VER%.*}" | sort -V | tail -n 1)" == "${MARIADB_VER%.*}" ]]; then
        echo "${MARIADB_VER}"
    fi
}


# ----------------------------------------------------------------
# Print the build EngineScript tested for a PHP version (PHP_TESTED_BUILDS in
# enginescript-variables.txt, entries "8.5=8.5.12-1+0~20261021.27"), or nothing
# Usage: php_tested_build <version>
function php_tested_build() {
    local entry

    for entry in "${PHP_TESTED_BUILDS[@]}"; do
        if [[ "${entry%%=*}" == "$1" ]]; then
            echo "${entry#*=}"
            return 0
        fi
    done
}


# ----------------------------------------------------------------
# Print a Sury package version without its Ubuntu part:
# 8.5.12-1+0~20261021.27+ubuntu26.04~1.gbp1a3e8a becomes 8.5.12-1+0~20261021.27, the same build
# on every Ubuntu release
# Usage: php_build_of "<package version>"
function php_build_of() {
    echo "${1%%+ubuntu*}"
}


# ----------------------------------------------------------------
# Print the PHP build to update to, or nothing
#
# Only a patch release of the installed version (8.5.x), and only the build EngineScript
# tested: the packages come from the Sury repository, which keeps only its newest build, so a
# server cannot install the tested build once Sury has published a newer one. It waits until
# that one is tested too. Reads the candidate from apt-cache, so run apt-get update first.
# Usage: php_auto_update_target <version>
function php_auto_update_target() {
    local ver="$1" installed candidate tested

    installed="$(php_build_of "$(dpkg-query -W -f='${Version}' "php${ver}-fpm" 2> /dev/null)")"
    candidate="$(php_build_of "$(apt-cache policy "php${ver}-fpm" 2> /dev/null | sed -n 's/^ *Candidate: //p')")"
    tested="$(php_tested_build "${ver}")"

    if [[ -z "${installed}" || -z "${candidate}" || "${candidate}" == "(none)" || "${candidate}" == "${installed}" ]]; then
        return 0
    fi
    if [[ -z "${tested}" || "${candidate}" != "${tested}" ]]; then
        echo "PHP ${ver}: Sury offers ${candidate}, which EngineScript has not tested yet (tested: ${tested:-none}); waiting." >&2
        return 0
    fi
    echo "${candidate}"
}


# ----------------------------------------------------------------
# Print the newest PHP version EngineScript supports when it is newer than the installed one
# (for a one-time note), or nothing
# Usage: php_newer_version <installed version>
function php_newer_version() {
    local newest
    newest="$(printf '%s\n' "${SUPPORTED_PHP_VERSIONS[@]}" | sort -V | tail -n 1)"

    if [[ -n "$1" && -n "${newest}" && "${newest}" != "$1" \
        && "$(printf '%s\n' "$1" "${newest}" | sort -V | tail -n 1)" == "${newest}" ]]; then
        echo "${newest}"
    fi
}
