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

# The automatic update records (a successful update clears them)
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-auto-update.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-auto-update.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script
#
# Installs the newest patch release of the installed PHP version (8.5.x) from the Sury
# repository. Switching to another version (8.5 to 8.6) is php-update.sh.
#
# Update flow:
#   1. Back up the PHP configuration (php-backup.sh)
#   2. Upgrade every installed php<version>-* package; EngineScript's php.ini and pool files are
#      kept (--force-confold)
#   3. Test the configuration (php-fpm -t), restart PHP-FPM, and check that it runs PHP
#   4. Check that every site that reached PHP before the update still does
# Sury keeps only its newest build, so the previous packages cannot be put back automatically:
# a failure in step 3 or 4 is reported, and the configuration backup is kept.
#
# --build <build>: install only that build (software-auto-update.sh passes the tested one); the
# update stops when the repository offers another.

# One update at a time (the lock is shared with es.update and the other software updates)
acquire_lock "update" || exit 1

EXPECTED_BUILD=""
if [[ "${1:-}" == "--build" ]]; then
    EXPECTED_BUILD="${2:?--build needs a build}"
fi

# Prompt for EngineScript Update. After it, run the new copy of this script: bash keeps running
# the text of the file it started with, and the shared functions sourced above are the old ones.
if [[ "${ES_ENGINESCRIPT_UPDATED:-0}" != "1" ]]; then
    if prompt_yes_no "Do you want to update EngineScript before continuing?\nThis will ensure you have the latest core scripts and variables."; then
        run_step "EngineScript Update" /usr/local/bin/enginescript/scripts/update/enginescript-update.sh
        ES_ENGINESCRIPT_UPDATED=1 exec bash /usr/local/bin/enginescript/scripts/update/php-patch-update.sh "$@"
    else
        echo "Skipping EngineScript update."
    fi
fi

# The version Nginx passes PHP requests to (resolve_php_version: the installed one)
if [[ -z "$(get_installed_php_version)" ]]; then
    echo "Error: No PHP-FPM installation detected." >&2
    exit 1
fi

apt-get update --allow-releaseinfo-change -y 2>> "${ES_STEP_ERROR_LOG}"
print_last_errors

INSTALLED_BUILD="$(php_build_of "$(dpkg-query -W -f='${Version}' "php${PHP_VER}-fpm" 2> /dev/null)")"
CANDIDATE_BUILD="$(php_build_of "$(apt-cache policy "php${PHP_VER}-fpm" 2> /dev/null | sed -n 's/^ *Candidate: //p')")"
if [[ -z "${CANDIDATE_BUILD}" || "${CANDIDATE_BUILD}" == "(none)" ]]; then
    echo "Error: apt has no php${PHP_VER}-fpm package to install. Check the Sury repository (/etc/apt/sources.list.d/php.list)." >&2
    exit 1
fi
if [[ "${CANDIDATE_BUILD}" == "${INSTALLED_BUILD}" ]]; then
    echo "PHP ${PHP_VER} is up to date (${INSTALLED_BUILD})."
    auto_update_clear "php"
    exit 0
fi
if [[ -n "${EXPECTED_BUILD}" && "${CANDIDATE_BUILD}" != "${EXPECTED_BUILD}" ]]; then
    echo "Error: The repository now offers PHP ${CANDIDATE_BUILD}, not ${EXPECTED_BUILD}. Nothing was changed." >&2
    exit 1
fi

echo ""
echo "============================================================="
echo ""
echo "PHP Update: ${INSTALLED_BUILD} -> ${CANDIDATE_BUILD}"
echo ""
echo "============================================================="
echo ""

# Every installed package of this version (extensions included)
mapfile -t PHP_PACKAGES < <(dpkg-query -W -f='${Package} ${Status}\n' "php${PHP_VER}-*" "php${PHP_VER}" 2> /dev/null \
    | awk '$NF == "installed" && $(NF-1) == "ok" { print $1 }')
if [[ ${#PHP_PACKAGES[@]} -eq 0 ]]; then
    echo "Error: No installed php${PHP_VER} packages were found." >&2
    exit 1
fi

# Sites that do not reach PHP before the update (not held against it in step 4)
SITES_FAILING_BEFORE="$(get_sites_without_php)"

# 1. Back up the PHP configuration (dated, in /home/EngineScript/config-backups/php)
/usr/local/bin/enginescript/scripts/functions/backup/php-backup.sh 2>> "${ES_STEP_ERROR_LOG}"
print_last_errors

# 2. Upgrade the packages. EngineScript replaces packaged configuration files, so dpkg would
# ask whether to keep them (and fail without a terminal); --force-confold keeps them.
if ! DEBIAN_FRONTEND=noninteractive apt-get install --only-upgrade -qy \
    -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "${PHP_PACKAGES[@]}" 2>> "${ES_STEP_ERROR_LOG}"; then
    print_last_errors
    echo "Error: The PHP ${PHP_VER} package upgrade failed." >&2
    systemctl start "php${PHP_VER}-fpm" 2> /dev/null || true
    exit 1
fi
print_last_errors
debug_pause "PHP Package Upgrade"

# 3. Test, restart, and check that PHP-FPM runs PHP
php_ok=0
if "php-fpm${PHP_VER}" -t 2>> "${ES_STEP_ERROR_LOG}"; then
    systemctl restart "php${PHP_VER}-fpm" 2>> "${ES_STEP_ERROR_LOG}"
    for _ in 1 2 3 4 5; do
        if php_fpm_answers "${PHP_VER}"; then
            php_ok=1
            break
        fi
        sleep 2
    done
fi
print_last_errors
if [[ "${php_ok}" != "1" ]]; then
    echo "CRITICAL: PHP ${PHP_VER} does not run after the upgrade to ${CANDIDATE_BUILD}. Check 'php-fpm${PHP_VER} -t' and 'systemctl status php${PHP_VER}-fpm'." >&2
    echo "The previous configuration is in /home/EngineScript/config-backups/php. The repository no longer has the previous packages." >&2
    exit 1
fi

# 4. Every site that reached PHP before the update still does
NEW_FAILURES="$(newly_failing_sites "${SITES_FAILING_BEFORE}" "$(get_sites_without_php)")"
if [[ -n "${NEW_FAILURES}" ]]; then
    echo "ERROR: These sites no longer work after the PHP update (HTTP 500, 502, 504, or no response):" >&2
    printf '  %s\n' "${NEW_FAILURES//$'\n'/$'\n'  }" >&2
    echo "PHP ${PHP_VER} itself runs; a plugin or theme on these sites may not work with ${CANDIDATE_BUILD}." >&2
    exit 1
fi

echo "PASSED: PHP ${PHP_VER} is running ${CANDIDATE_BUILD}."
auto_update_clear "php"
