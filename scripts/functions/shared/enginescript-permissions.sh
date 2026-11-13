#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------
# Permission Functions
# Owners and modes of the sites, Nginx, PHP, Redis, EngineScript's folders and logs.
# Loaded by enginescript-common.sh.
#----------------------------------------------------------------------------------


# ----------------------------------------------------------------
# Run a command as www-data
#
# Site files belong to www-data, so a hacked plugin can change them. Anything that runs those
# files (WP-CLI loads wp-config.php and every plugin) or parses them (image tools) must run as
# www-data on a schedule: as root, it would hand the plugin the whole server.
# Usage: run_as_www_data <command> [arguments]
function run_as_www_data() {
    runuser -u www-data -- "$@"
}


# ----------------------------------------------------------------
# Give a folder to www-data, with directories at 755 and files at 644
#
# www-data can swap any file in the folder for a symlink while find runs, and chmod follows
# symlinks. Run as root, chmod would then change a file outside the folder, such as a root-only
# one, so it runs as www-data, after the chown: chown -R itself does not follow symlinks.
# Usage: set_www_data_tree <folder>
function set_www_data_tree() {
    local dir="$1"

    chown -R www-data:www-data "${dir}"
    # find stops on a working directory www-data cannot read, such as /root
    (
        cd / || exit 1
        run_as_www_data find "${dir}" -type d -exec chmod 0755 {} +
        run_as_www_data find "${dir}" -type f -exec chmod 0644 {} +
    )
}


# ----------------------------------------------------------------
# Set permissions for EngineScript frontend directories and files
function set_enginescript_frontend_permissions() {
    # Set permissions for /var/www/admin/control-panel (dashboard)
    if [[ -d "/var/www/admin/control-panel" ]]; then
        set_www_data_tree /var/www/admin/control-panel
    fi

    # Set permissions for /var/www/admin/tools (phpMyAdmin, TinyFileManager, etc.)
    if [[ -d "/var/www/admin/tools" ]]; then
        set_www_data_tree /var/www/admin/tools
    fi

    # /etc/enginescript belongs to root; the control panel only reads its Uptime Robot key there
    set_enginescript_etc_permissions

    # Ensure API cache directory has correct owner and permissions
    set_api_cache_permissions
}


# ----------------------------------------------------------------
# Set permissions for /etc/enginescript
#
# Root keeps the install state and the tuning plan here and reads them on every update and every
# day, so the folder belongs to root. Owned by www-data, as it was before November 2026, a hacked
# site could put commands for root into the install state, or swap a file for a link so that root
# wrote somewhere else. The folder changes hands first: from then on www-data cannot add, swap,
# or remove anything in it. The control panel (www-data) only reads the Uptime Robot API key.
# ES_ETC_DIR overrides the folder (for tests).
function set_enginescript_etc_permissions() {
    local etc_dir="${ES_ETC_DIR:-/etc/enginescript}"

    if [[ ! -d "${etc_dir}" ]]; then
        return 0
    fi
    chown root:root "${etc_dir}" || return 1
    chmod 755 "${etc_dir}" || return 1
    # Links left there while www-data owned the folder
    find "${etc_dir}" -mindepth 1 -maxdepth 1 -type l -delete
    # chown -R changes a link itself, never the file it points to
    chown -R root:root "${etc_dir}" || return 1
    find "${etc_dir}" -mindepth 1 -maxdepth 1 -type f -exec chmod 644 {} +
    if [[ -f "${etc_dir}/uptimerobot.conf" ]]; then
        chown root:www-data "${etc_dir}/uptimerobot.conf"
        chmod 640 "${etc_dir}/uptimerobot.conf"
    fi
}


# ----------------------------------------------------------------
# The control panel's API cache (/var/cache/enginescript/api), which PHP writes as www-data:
# folders 775, files 664 (not executable). chmod runs as www-data, as in set_www_data_tree.
function set_api_cache_permissions() {
    local dir="/var/cache/enginescript/api"

    if [[ ! -d "${dir}" ]]; then
        return 0
    fi
    chown -R www-data:www-data "${dir}"
    (
        cd / || exit 1
        run_as_www_data find "${dir}" -type d -exec chmod 775 {} +
        run_as_www_data find "${dir}" -type f -exec chmod 664 {} +
    )
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
# Set permissions for /var/log/EngineScript
#
# Root writes logs here, so the folder must belong to root: www-data could otherwise replace a
# log with a symlink, and root would write to the link's target (CVE-2016-1247). The control
# panel runs as www-data and only appends to its two log files, which stay www-data's.
function set_enginescript_log_permissions() {
    local log_dir="/var/log/EngineScript" panel_log

    if [[ ! -d "${log_dir}" ]]; then
        return 0
    fi
    chown root:root "${log_dir}"
    chmod 755 "${log_dir}"
    # A link left there before the folder changed hands
    find "${log_dir}" -mindepth 1 -maxdepth 1 -type l -delete
    for panel_log in enginescript-api.log enginescript-api-security.log; do
        touch "${log_dir}/${panel_log}"
        chown www-data:www-data "${log_dir}/${panel_log}"
        chmod 644 "${log_dir}/${panel_log}"
    done
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
