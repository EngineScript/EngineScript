#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript site archive (format version 1)
#
# One ZIP that holds:
#   manifest.txt
#   database/<site>_db_<timestamp>.sql.gz
#   files/<site>_files_<timestamp>.tar.gz    (the contents of the site's html folder)
# vhost-import.sh reads it, and the EngineScript Site Exporter WordPress plugin writes the same
# layout: keep the three in step. The payloads are already compressed, so the ZIP stores them
# without compressing them again (zip -0).
#
# Site exports (vhost-export.sh), the scheduled files backups (enginescript-backup.sh), and the
# backup before a Wordfence CLI remediation all build their archives here.
# Needs run_as_www_data from enginescript-common.sh.

# The folder that holds each site's html folder (changed by the tests)
SITE_ARCHIVE_SITES_ROOT="${SITE_ARCHIVE_SITES_ROOT:-/var/www/sites}"

# Left out of the files archive, as the EngineScript Site Exporter plugin leaves them out, so both
# carry the same files: version-control data, macOS metadata, Apache and per-directory PHP
# settings (a .user.ini holds settings for the old server, such as paths, that PHP-FPM would
# apply), and the contents of WordPress's working folders wp-content/cache, upgrade, and temp (the
# folders themselves are kept). Matched without regard to case.
SITE_ARCHIVE_TAR_EXCLUDES=(
    --exclude='.git' --exclude='.svn' --exclude='.hg' --exclude='.DS_Store'
    --exclude='.htaccess' --exclude='.user.ini'
    --exclude='./wp-content/cache/*' --exclude='./wp-content/upgrade/*' --exclude='./wp-content/temp/*'
)

# Free space, in KB, on the filesystem that holds a folder
# Usage: site_archive_free_kb <folder>
function site_archive_free_kb() {
    df -Pk "$1" | awk 'NR == 2 {print $4}'
}

# ----------------------------------------------------------------
# Build a site archive
#
# The archive holds wp-config.php and the whole database, so it is written for its owner only
# (root). That only applies on this server: a copy made elsewhere belongs to whoever makes it, and
# the import reads it as root. The output file appears only once the archive is complete.
# Errors go to stderr.
# Usage: build_site_archive <domain> <output .zip>
function build_site_archive() (
    local site="$1" output="$2"
    local site_root="${SITE_ARCHIVE_SITES_ROOT}/${site}/html"
    local out_dir stamp staging bundle db_name files_name rc site_kb parts_kb free_kb
    local -a info=()
    umask 077

    if [[ ! -f "${site_root}/wp-config.php" ]]; then
        echo "No WordPress site in ${site_root}" >&2
        return 1
    fi
    if ! command -v zip > /dev/null 2>&1; then
        echo "The zip command is needed to build a site archive (apt install zip)" >&2
        return 1
    fi
    out_dir="$(dirname "${output}")"
    mkdir -p "${out_dir}" || return 1

    # The parts, and while the ZIP is written a second copy of them, must fit. The site's size on
    # disk bounds the files part; 256 MB more covers the database. Checked again before the ZIP.
    site_kb="$(du -sk "${site_root}" | cut -f1)"
    free_kb="$(site_archive_free_kb "${out_dir}")"
    if (( free_kb < site_kb * 2 + 262144 )); then
        echo "Not enough free space in ${out_dir} for ${site}'s archive: about $(( (site_kb * 2 + 262144) / 1024 )) MB needed, $((free_kb / 1024)) MB free" >&2
        return 1
    fi

    stamp="$(date +%Y%m%d_%H%M%S)"
    staging="$(mktemp -d "${out_dir}/.site-archive.XXXXXX")" || return 1
    # shellcheck disable=SC2064  # expand now: the trap runs after the function's locals are gone
    trap "rm -rf '${staging}'" EXIT
    bundle="${staging}/bundle"
    db_name="${site}_db_${stamp}.sql.gz"
    files_name="${site}_files_${stamp}.tar.gz"
    mkdir -p "${bundle}/database" "${bundle}/files" || return 1

    # As www-data: WP-CLI loads the site's wp-config.php, which the site can change. One
    # transaction, so a site in use still gives a consistent dump.
    if ! (set -o pipefail; cd / && run_as_www_data wp db export - --path="${site_root}" \
            --single-transaction --quick --add-drop-table | gzip > "${bundle}/database/${db_name}"); then
        echo "The database export of ${site} failed" >&2
        return 1
    fi

    tar -C "${site_root}" -czf "${bundle}/files/${files_name}" --ignore-case "${SITE_ARCHIVE_TAR_EXCLUDES[@]}" .
    rc=$?
    # GNU tar exits with 1 when a file changed while it was read; the archive is still usable
    if (( rc > 1 )); then
        echo "Archiving ${site}'s files failed (tar exit ${rc})" >&2
        return 1
    fi
    if (( rc == 1 )); then
        echo "Note: files changed while ${site}'s files were archived." >&2
    fi

    # The addresses and table prefix, for the manifest's informational lines. The options, not
    # home_url() and site_url(): from WP-CLI, which is not on HTTPS, site_url() would turn https
    # into http. Plugins and themes are not loaded, so a broken one cannot stop the archive; the
    # values stay empty on failure.
    # shellcheck disable=SC2016  # PHP code, not shell
    mapfile -t info < <(cd / && run_as_www_data wp eval --path="${site_root}" --skip-plugins --skip-themes \
        'echo get_option("home"), "\n", get_option("siteurl"), "\n", $GLOBALS["table_prefix"], "\n";' 2> /dev/null)
    # The first six lines keep their text and order for importers; the later ones are
    # informational and match what the plugin writes. One value per line: control characters go.
    {
        echo "format=enginescript-site-archive"
        echo "version=1"
        echo "site=${site}"
        echo "created_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "database_path=database/${db_name}"
        echo "files_archive_path=files/${files_name}"
        echo "home_url=${info[0]:-}" | tr -d '\000-\011\013-\037\177'
        echo "site_url=${info[1]:-}" | tr -d '\000-\011\013-\037\177'
        echo "table_prefix=${info[2]:-}" | tr -d '\000-\011\013-\037\177'
        echo "wp_config_in_archive=yes"
    } > "${bundle}/manifest.txt" || return 1

    parts_kb="$(du -sk "${bundle}" | cut -f1)"
    free_kb="$(site_archive_free_kb "${out_dir}")"
    if (( free_kb < parts_kb + 65536 )); then
        echo "Not enough free space in ${out_dir} to write ${site}'s archive: about $(( (parts_kb + 65536) / 1024 )) MB needed, $((free_kb / 1024)) MB free" >&2
        return 1
    fi
    if ! (cd "${bundle}" && zip -0 -r -q "${staging}/archive.zip" .); then
        echo "Writing ${site}'s archive failed" >&2
        return 1
    fi
    mv -f "${staging}/archive.zip" "${output}"
)
