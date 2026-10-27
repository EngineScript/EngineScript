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
#
# Switch flow (the sites keep running on the current PHP version until step 4):
#   1. Back up the PHP configuration and the Nginx files that name the PHP-FPM socket
#   2. Install the new PHP version alongside the current one (each version has its own
#      service and socket)
#   3. Configure the new version, test it (php-fpm -t), start it, and check that it runs PHP
#   4. Point Nginx at the new socket, test (nginx -t), and reload
#   5. Check that every site that reached PHP before the switch still does
#   6. Remove the previous version(s)
# On a failure in steps 2 to 5, Nginx is pointed back at the previous socket and the new
# version is removed. The previous PHP-FPM is never stopped before step 6, so the sites keep
# PHP throughout.

ROLLBACK_DIR="/home/EngineScript/config-backups/php/pre-switch"

# Prompt for EngineScript Update
if prompt_yes_no "Do you want to update EngineScript before continuing?\nThis will ensure you have the latest core scripts and variables."; then
    /usr/local/bin/enginescript/scripts/update/enginescript-update.sh 2>> /tmp/enginescript_install_errors.log
else
    echo "Skipping EngineScript update."
fi
print_last_errors
debug_pause "EngineScript Update"

# Target version: from the argument (used by the menu), or the version the install options
# select (PHP_VERSION_OVERRIDE or the default)
NEW_PHP_VER="${1:-${PHP_CONFIGURED_VER}}"
if ! printf '%s\n' "${SUPPORTED_PHP_VERSIONS[@]}" | grep -qxF "${NEW_PHP_VER}"; then
    echo "Unsupported PHP version: ${NEW_PHP_VER}. Supported versions: ${SUPPORTED_PHP_VERSIONS[*]}"
    exit 1
fi

# Installed PHP-FPM versions (any version, including ones EngineScript no longer supports)
mapfile -t INSTALLED_PHP_VERS < <(get_installed_php_versions)
if [[ ${#INSTALLED_PHP_VERS[@]} -eq 0 ]]; then
    echo "No existing PHP-FPM installation detected. Use php-install.sh for fresh installs."
    exit 1
fi

# The version Nginx passes PHP requests to now: the switch rolls back to it on a failure
CURRENT_PHP_VER="$(get_nginx_php_socket | sed -n 's|^/run/php/php\([0-9][0-9]*\.[0-9][0-9]*\)-fpm\.sock$|\1|p')"
CURRENT_PHP_VER="${CURRENT_PHP_VER:-${PHP_VER}}"

OLD_PHP_VERS=()
NEW_WAS_INSTALLED=0
for ver in "${INSTALLED_PHP_VERS[@]}"; do
    if [[ "${ver}" == "${NEW_PHP_VER}" ]]; then
        NEW_WAS_INSTALLED=1
    else
        OLD_PHP_VERS+=("${ver}")
    fi
done

SWITCH_NEEDED=1
if [[ "${CURRENT_PHP_VER}" == "${NEW_PHP_VER}" ]]; then
    if [[ ${#OLD_PHP_VERS[@]} -eq 0 ]]; then
        echo "PHP ${NEW_PHP_VER} is already installed and in use. Nothing to switch."
        exit 0
    fi
    # Left over from an interrupted switch: only remove the other versions
    SWITCH_NEEDED=0
fi

echo ""
echo "============================================================="
echo ""
echo "PHP Switch: PHP ${CURRENT_PHP_VER} -> PHP ${NEW_PHP_VER}"
echo "Installed PHP-FPM version(s): ${INSTALLED_PHP_VERS[*]}"
echo ""
echo "============================================================="
echo ""

# Sites that do not reach PHP before the switch (not held against it in step 5)
SITES_FAILING_BEFORE="$(get_sites_without_php)"
NGINX_SWITCHED=0

# Undo the switch: point Nginx back at the previous PHP-FPM (still running), remove the new
# version, and restore the apt pins
rollback_switch() {
    echo "" >&2
    echo "ERROR: $1" >&2
    echo "Rolling back to PHP ${CURRENT_PHP_VER}..." >&2

    if [[ "${NGINX_SWITCHED}" == "1" ]]; then
        tar -xzf "${ROLLBACK_DIR}/etc-nginx.tar.gz" -C / || echo "Error: Could not restore ${ROLLBACK_DIR}/etc-nginx.tar.gz" >&2
        if /usr/sbin/nginx -t > /dev/null 2>&1; then
            systemctl reload nginx
        else
            echo "CRITICAL: The restored Nginx configuration fails nginx -t. Run 'nginx -t' and fix it." >&2
        fi
    fi
    if [[ -f "${ROLLBACK_DIR}/phpsysinfo.ini" ]]; then
        cp -p "${ROLLBACK_DIR}/phpsysinfo.ini" /var/www/admin/tools/phpsysinfo/phpsysinfo.ini
    fi

    if [[ "${NEW_WAS_INSTALLED}" == "0" ]]; then
        systemctl stop "php${NEW_PHP_VER}-fpm" 2> /dev/null || true
        systemctl disable "php${NEW_PHP_VER}-fpm" 2> /dev/null || true
        apt purge -y "php${NEW_PHP_VER}*" 2>> /tmp/enginescript_install_errors.log || true
        rm -rf "/etc/php/${NEW_PHP_VER}"
    fi
    rm -f /etc/apt/preferences.d/php*-block
    cp -p "${ROLLBACK_DIR}"/apt-preferences/php*-block /etc/apt/preferences.d/ 2> /dev/null || true

    systemctl start "php${CURRENT_PHP_VER}-fpm" 2> /dev/null || true
    if php_fpm_answers "${CURRENT_PHP_VER}"; then
        echo "The switch was rolled back. The sites are running on PHP ${CURRENT_PHP_VER}." >&2
    else
        echo "CRITICAL: PHP ${CURRENT_PHP_VER} does not answer after the rollback. Check 'systemctl status php${CURRENT_PHP_VER}-fpm'." >&2
    fi
    exit 1
}

if [[ "${SWITCH_NEEDED}" == "1" ]]; then
    # 1. Back up
    echo "Backing up the PHP configuration and Nginx files to ${ROLLBACK_DIR}..."
    rm -rf "${ROLLBACK_DIR}"
    mkdir -p "${ROLLBACK_DIR}/apt-preferences"
    if ! tar -czf "${ROLLBACK_DIR}/etc-nginx.tar.gz" -C / etc/nginx; then
        echo "Error: Could not back up /etc/nginx. The switch stopped; nothing was changed." >&2
        exit 1
    fi
    cp -p /etc/apt/preferences.d/php*-block "${ROLLBACK_DIR}/apt-preferences/" 2> /dev/null || true
    if [[ -f /var/www/admin/tools/phpsysinfo/phpsysinfo.ini ]]; then
        cp -p /var/www/admin/tools/phpsysinfo/phpsysinfo.ini "${ROLLBACK_DIR}/phpsysinfo.ini"
    fi
    # Dated backup of the PHP configuration as well
    /usr/local/bin/enginescript/scripts/functions/backup/php-backup.sh 2>> /tmp/enginescript_install_errors.log

    # 2. Install the new version alongside the current one
    echo "Installing PHP ${NEW_PHP_VER} alongside PHP ${CURRENT_PHP_VER}..."

    # Package blocking pins every non-selected PHP version. Remove the target pin so apt can
    # install the requested version.
    rm -f "/etc/apt/preferences.d/php${NEW_PHP_VER//./}-block"

    mapfile -t php_packages < <(get_php_packages_array "${NEW_PHP_VER}")
    if [[ "${INSTALL_EXPANDED_PHP}" == "1" ]]; then
        mapfile -t -O "${#php_packages[@]}" php_packages < <(get_expanded_php_packages_array "${NEW_PHP_VER}")
    fi
    if ! apt install -qy "${php_packages[@]}" 2>> /tmp/enginescript_install_errors.log; then
        print_last_errors
        rollback_switch "Unable to install the PHP ${NEW_PHP_VER} packages."
    fi
    print_last_errors
    debug_pause "PHP Package Installation"

    if [[ -f "/etc/logrotate.d/php${NEW_PHP_VER}-fpm" ]]; then
        sed -i "s|rotate 12|rotate 5|g" "/etc/logrotate.d/php${NEW_PHP_VER}-fpm"
    fi

    # 3. Configure, test, start, and check the new version
    if ! /usr/local/bin/enginescript/scripts/update/php-config-update.sh "${NEW_PHP_VER}" 2>> /tmp/enginescript_install_errors.log; then
        print_last_errors
        rollback_switch "Applying the EngineScript configuration to PHP ${NEW_PHP_VER} failed."
    fi
    print_last_errors
    debug_pause "PHP Configuration"

    mkdir -p /var/cache/opcache
    mkdir -p /var/cache/php-sessions
    mkdir -p /var/cache/wsdlcache
    set_php_permissions

    if ! "php-fpm${NEW_PHP_VER}" -t 2>> /tmp/enginescript_install_errors.log; then
        print_last_errors
        rollback_switch "The PHP ${NEW_PHP_VER} configuration failed its test (php-fpm${NEW_PHP_VER} -t)."
    fi
    systemctl enable "php${NEW_PHP_VER}-fpm" 2>> /tmp/enginescript_install_errors.log
    systemctl restart "php${NEW_PHP_VER}-fpm" 2>> /tmp/enginescript_install_errors.log
    new_php_ok=0
    for _ in 1 2 3 4 5; do
        if php_fpm_answers "${NEW_PHP_VER}"; then
            new_php_ok=1
            break
        fi
        sleep 2
    done
    if [[ "${new_php_ok}" != "1" ]]; then
        rollback_switch "PHP ${NEW_PHP_VER} did not start or does not run PHP (check 'systemctl status php${NEW_PHP_VER}-fpm')."
    fi
    echo "PHP ${NEW_PHP_VER} is running and answering on /run/php/php${NEW_PHP_VER}-fpm.sock."

    # 4. Point Nginx at the new socket
    echo "Pointing Nginx at PHP ${NEW_PHP_VER}..."
    NGINX_SWITCHED=1
    if [[ -f /etc/nginx/globals/php-fpm.conf ]]; then
        sed -E -i "s|(unix:/run/php/php)[0-9]+\.[0-9]+(-fpm\.sock)|\1${NEW_PHP_VER}\2|g" /etc/nginx/globals/php-fpm.conf
    fi
    for config_file in /etc/nginx/sites-available/*; do
        if [[ -f "${config_file}" ]]; then
            sed -E -i "s|(fastcgi_pass[[:space:]]+[^;]*php)[0-9]+\.[0-9]+(-fpm)|\1${NEW_PHP_VER}\2|g" "${config_file}"
        fi
    done
    if ! /usr/sbin/nginx -t 2>> /tmp/enginescript_install_errors.log; then
        print_last_errors
        rollback_switch "The Nginx configuration for PHP ${NEW_PHP_VER} failed its test (nginx -t)."
    fi
    if ! systemctl reload nginx 2>> /tmp/enginescript_install_errors.log; then
        print_last_errors
        rollback_switch "Nginx did not reload with the PHP ${NEW_PHP_VER} configuration."
    fi

    # 5. Check the sites
    sleep 2
    sites_ok=0
    for _ in 1 2 3; do
        new_failures="$(newly_failing_sites "${SITES_FAILING_BEFORE}" "$(get_sites_without_php)")"
        if [[ -z "${new_failures}" ]]; then
            sites_ok=1
            break
        fi
        sleep 3
    done
    if [[ "${sites_ok}" != "1" ]]; then
        echo "These sites do not work on PHP ${NEW_PHP_VER} (HTTP 500, 502, 504, or no response):" >&2
        printf '  %s\n' "${new_failures//$'\n'/$'\n'  }" >&2
        rollback_switch "Sites did not answer on PHP ${NEW_PHP_VER}."
    fi
    echo "PASSED: The sites are running on PHP ${NEW_PHP_VER}."

    # The switch is complete: update the other references to the PHP version
    if [[ -f /var/www/admin/tools/phpsysinfo/phpsysinfo.ini ]]; then
        echo "Updating phpSysInfo configuration..."
        for OLD_VER in "${OLD_PHP_VERS[@]}"; do
            sed -E -i "s|^([[:space:]]*[[:alnum:]_.-]+[[:space:]]*=[[:space:]]*.*)php${OLD_VER//./\.}(-fpm)?|\1php${NEW_PHP_VER}\2|g" /var/www/admin/tools/phpsysinfo/phpsysinfo.ini
        done
    fi
    if [[ -f /var/www/admin/control-panel/api.php ]]; then
        echo "Updating admin control panel API configuration..."
        for OLD_VER in "${OLD_PHP_VERS[@]}"; do
            sed -E -i "/(php-fpm|fastcgi_pass|sock(et)?|service)/ s|(php)${OLD_VER//./\.}(-fpm)?|\1${NEW_PHP_VER}\2|g" /var/www/admin/control-panel/api.php
        done
    fi
fi

set_install_state "PHP" "1"

# 6. Remove the previous version(s)
for OLD_VER in "${OLD_PHP_VERS[@]}"; do
    echo "Removing PHP ${OLD_VER}..."
    systemctl stop "php${OLD_VER}-fpm" 2> /dev/null || true
    systemctl disable "php${OLD_VER}-fpm" 2> /dev/null || true
    apt purge -y "php${OLD_VER}*" 2>> /tmp/enginescript_install_errors.log || true
    rm -rf "/etc/php/${OLD_VER}"
    rm -f "/etc/logrotate.d/php${OLD_VER}-fpm"

    # Archive the old log (the package default location, and the one older EngineScript
    # installs used)
    for old_log in "/var/log/php${OLD_VER}-fpm.log" "/var/log/php/php${OLD_VER}-fpm.log"; do
        if [[ -f "${old_log}" ]]; then
            mv "${old_log}" "${old_log}.old" 2> /dev/null || true
        fi
    done
    echo "PHP ${OLD_VER} has been removed."
done

# Keep the apt pins aligned with the selected version: block every other supported version,
# and the versions just removed
for ver in "${SUPPORTED_PHP_VERSIONS[@]}" "${OLD_PHP_VERS[@]}"; do
    pin_file="/etc/apt/preferences.d/php${ver//./}-block"
    if [[ "${ver}" == "${NEW_PHP_VER}" ]]; then
        rm -f "${pin_file}"
    else
        echo -e "Package: php${ver}*\nPin: release *\nPin-Priority: -1" > "${pin_file}"
    fi
done

# Cleanup
/usr/local/bin/enginescript/scripts/functions/php-clean.sh 2>> /tmp/enginescript_install_errors.log
/usr/local/bin/enginescript/scripts/functions/enginescript-cleanup.sh 2>> /tmp/enginescript_install_errors.log
print_last_errors
debug_pause "Cleanup"

# Display PHP version and modules
echo -e "\n\n=-=-=-=-=-=-=-=-=-\nPHP Info\n=-=-=-=-=-=-=-=-=-\n"
php --version
echo ""
php -m

# Final message
echo ""
echo ""
echo "============================================================="
echo ""
echo "PHP switch to ${NEW_PHP_VER} completed successfully."
echo ""
echo "Changes made:"
echo "  - Installed PHP ${NEW_PHP_VER} and extensions alongside the previous version"
echo "  - Applied EngineScript configuration for PHP ${NEW_PHP_VER}"
echo "  - Pointed Nginx at PHP ${NEW_PHP_VER} and checked every site"
if [[ ${#OLD_PHP_VERS[@]} -gt 0 ]]; then
    echo "  - Removed PHP version(s): ${OLD_PHP_VERS[*]}"
fi
echo ""
echo "============================================================="
echo ""
