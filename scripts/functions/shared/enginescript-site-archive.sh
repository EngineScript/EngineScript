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
# without compressing them again. site-archive-zip.py writes it.
#
# Site exports (vhost-export.sh), the scheduled files backups (enginescript-backup.sh), and the
# backup before a Wordfence CLI remediation all build their archives here.
# Needs run_as_www_data from enginescript-common.sh.

# The folder that holds each site's html folder (changed by the tests)
SITE_ARCHIVE_SITES_ROOT="${SITE_ARCHIVE_SITES_ROOT:-/var/www/sites}"

# Writes the ZIP from pipes, so its parts are never on disk twice (changed by the tests)
SITE_ARCHIVE_ZIP_TOOL="${SITE_ARCHIVE_ZIP_TOOL:-/usr/local/bin/enginescript/scripts/functions/shared/site-archive-zip.py}"

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
    local folder="$1"
    df -Pk "${folder}" | awk 'NR == 2 {print $4}'
}

# Succeed when a value is a web address: http:// or https://, without spaces or control characters
# Usage: site_address_is_url <value>
function site_address_is_url() {
    local value="$1"
    [[ "${value,,}" =~ ^https?://[^[:space:][:cntrl:]]+$ ]]
}

# Print a site's address (home), WordPress address (siteurl), and table prefix, one per line. The
# options, not home_url() and site_url(): from WP-CLI, which is not on HTTPS, site_url() would
# turn https into http. As www-data, without plugins and themes, so a broken one cannot stop it.
# Each value is printed on a marked line and checked, so other output on the way (a must-use
# plugin's, which WP-CLI still loads) cannot be taken for a value: a value that is not an address,
# or not a table prefix, is printed as an empty line. Prints nothing when WP-CLI fails.
# Usage: site_archive_site_info <site root>
function site_archive_site_info() {
    local site_root="$1" output home siteurl prefix
    # shellcheck disable=SC2016  # PHP code, not shell
    output="$(cd / && run_as_www_data wp eval --path="${site_root}" --skip-plugins --skip-themes \
        'echo "\nes-home=", get_option("home"), "\nes-siteurl=", get_option("siteurl"), "\nes-prefix=", $GLOBALS["table_prefix"], "\n";' 2> /dev/null)" || return 0
    home="$(sed -n 's/^es-home=//p' <<< "${output}" | head -n 1 | tr -d '\r')"
    siteurl="$(sed -n 's/^es-siteurl=//p' <<< "${output}" | head -n 1 | tr -d '\r')"
    prefix="$(sed -n 's/^es-prefix=//p' <<< "${output}" | head -n 1 | tr -d '\r')"
    site_address_is_url "${home}" || home=""
    site_address_is_url "${siteurl}" || siteurl=""
    [[ "${prefix}" =~ ^[A-Za-z0-9_]+$ ]] || prefix=""
    printf '%s\n%s\n%s\n' "${home}" "${siteurl}" "${prefix}"
}

# Print the size of a site's database on disk, in KB, or nothing when WP-CLI cannot tell it
# Usage: site_archive_database_kb <site root>
function site_archive_database_kb() {
    local site_root="$1" bytes
    bytes="$(cd / && run_as_www_data wp db size --size_format=b --path="${site_root}" 2> /dev/null)" || return 0
    if [[ "${bytes}" =~ ^[0-9]+$ ]]; then
        echo $((bytes / 1024))
    fi
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
    local out_dir stamp staging db_name files_name zip_rc db_rc rc folder left_out_kb site_kb db_kb need_kb free_kb
    local -a info=()
    umask 077

    if [[ ! -f "${site_root}/wp-config.php" ]]; then
        echo "No WordPress site in ${site_root}" >&2
        return 1
    fi
    if ! command -v python3 > /dev/null 2>&1; then
        echo "python3 is needed to build a site archive (apt install python3)" >&2
        return 1
    fi
    out_dir="$(dirname "${output}")"
    mkdir -p "${out_dir}" || return 1

    # Staging folders that builds stopped without warning (a power cut, kill -9) left here a day
    # or more ago; a build that ends any other way, a signal included, removes its own
    find "${out_dir}" -maxdepth 1 -type d -name '.site-archive.*' -mmin +1440 -exec rm -rf {} +

    # The archive must fit. Its parts are piped straight into the ZIP, so it is the only copy on
    # disk. The files part is at most the site's size on disk without the working folders the
    # archive leaves out; the compressed dump is taken as half the database's size on disk, which
    # is generous (256 MB when WP-CLI cannot tell the size).
    site_kb="$(du -sk "${site_root}" | cut -f1)"
    for folder in cache upgrade temp; do
        if [[ -d "${site_root}/wp-content/${folder}" ]]; then
            left_out_kb="$(du -sk "${site_root}/wp-content/${folder}" | cut -f1)"
            site_kb=$((site_kb - left_out_kb))
        fi
    done
    (( site_kb < 0 )) && site_kb=0
    db_kb="$(site_archive_database_kb "${site_root}")"
    need_kb=$((site_kb + ${db_kb:-524288} / 2 + 65536))
    free_kb="$(site_archive_free_kb "${out_dir}")"
    if (( free_kb < need_kb )); then
        echo "Not enough free space in ${out_dir} for ${site}'s archive: about $((need_kb / 1024)) MB needed, $((free_kb / 1024)) MB free" >&2
        return 1
    fi

    stamp="$(date +%Y%m%d_%H%M%S)"
    staging="$(mktemp -d "${out_dir}/.site-archive.XXXXXX")" || return 1
    # The processes that make the archive, stopped when the build ends. Not local: the trap runs
    # after the function's locals are gone.
    SITE_ARCHIVE_JOBS=""
    # Bash also runs this when a signal (a reboot, kill) stops the build, and at once. A trap on
    # the signals themselves would wait for the command in progress, so there is none.
    # shellcheck disable=SC2064  # expand the folder now, for the same reason
    trap "kill \${SITE_ARCHIVE_JOBS} 2> /dev/null || true; rm -rf '${staging}'" EXIT
    db_name="${site}_db_${stamp}.sql.gz"
    files_name="${site}_files_${stamp}.tar.gz"

    # The addresses and table prefix, for the manifest's informational lines; each is checked by
    # site_archive_site_info, and empty when WP-CLI could not give it
    mapfile -t info < <(site_archive_site_info "${site_root}")
    # The first six lines keep their text and order for importers; the later ones are
    # informational and match what the plugin writes.
    {
        echo "format=enginescript-site-archive"
        echo "version=1"
        echo "site=${site}"
        echo "created_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "database_path=database/${db_name}"
        echo "files_archive_path=files/${files_name}"
        echo "home_url=${info[0]:-}"
        echo "site_url=${info[1]:-}"
        echo "table_prefix=${info[2]:-}"
        echo "wp_config_in_archive=yes"
    } > "${staging}/manifest.txt" || return 1

    # The dump and the files archive go through named pipes into site-archive-zip.py, which
    # writes the ZIP as they are made. Each command leaves its exit status in a file before its
    # end of the pipe closes, and the ZIP tool reads it once the part is in: after a failed dump
    # it stops, so the site's files are not archived for nothing.
    mkfifo "${staging}/database.pipe" "${staging}/files.pipe" || return 1
    # As www-data: WP-CLI loads the site's wp-config.php, which the site can change. One
    # transaction, so a site in use still gives a consistent dump.
    (set -o pipefail; cd / && run_as_www_data wp db export - --path="${site_root}" \
        --single-transaction --quick --add-drop-table | gzip; echo "$?" > "${staging}/database.status") \
        > "${staging}/database.pipe" &
    SITE_ARCHIVE_JOBS="$!"
    (tar -C "${site_root}" -czf - --ignore-case "${SITE_ARCHIVE_TAR_EXCLUDES[@]}" .; echo "$?" > "${staging}/files.status") \
        > "${staging}/files.pipe" &
    SITE_ARCHIVE_JOBS+=" $!"
    # The ZIP tool takes only names of files in its current folder, the staging folder. GNU tar
    # exits with 1 when a file changed while it was read; the archive is still usable.
    (cd "${staging}" && exec python3 -I "${SITE_ARCHIVE_ZIP_TOOL}" archive.zip \
        "manifest.txt=manifest.txt" \
        "database/${db_name}=database.pipe" \
        "files/${files_name}=files.pipe" \
        --status "database/${db_name}" database.status 0 \
        --status "files/${files_name}" files.status 1) &
    SITE_ARCHIVE_JOBS+=" $!"
    zip_rc=0
    wait "$!" || zip_rc=$?
    # A command whose pipe the ZIP tool never opened, because it stopped first, still waits for
    # a reader: stop it. The others have ended, so kill and wait may fail; the build goes on (also
    # in a caller that runs with set -e).
    # shellcheck disable=SC2086  # a list of process IDs
    kill ${SITE_ARCHIVE_JOBS} 2> /dev/null || true
    # shellcheck disable=SC2086
    wait ${SITE_ARCHIVE_JOBS} 2> /dev/null || true
    SITE_ARCHIVE_JOBS=""

    db_rc="$(cat "${staging}/database.status" 2> /dev/null)" || db_rc=""
    rc="$(cat "${staging}/files.status" 2> /dev/null)" || rc=""
    if (( zip_rc == 3 )) && [[ "${db_rc}" != "0" ]]; then
        echo "The database export of ${site} failed" >&2
        return 1
    fi
    if (( zip_rc == 3 )); then
        echo "Archiving ${site}'s files failed (tar exit ${rc:-unknown})" >&2
        return 1
    fi
    if (( zip_rc != 0 )); then
        echo "Writing ${site}'s archive failed" >&2
        return 1
    fi
    if [[ "${rc}" == "1" ]]; then
        echo "Note: files changed while ${site}'s files were archived." >&2
    fi
    mv -f "${staging}/archive.zip" "${output}"
)

# Succeed when a site archive reads back whole: its manifest names the format, its database dump
# ends with the line mariadb-dump writes when it finishes (so a dump cut short is caught), and its
# files archive can be listed to the end.
# Usage: site_archive_verify <archive .zip>
function site_archive_verify() {
    local archive="$1" last
    unzip -p "${archive}" manifest.txt 2> /dev/null | grep -Fxq "format=enginescript-site-archive" || return 1
    last="$(set -o pipefail; unzip -p "${archive}" 'database/*.sql.gz' 2> /dev/null | zcat 2> /dev/null | tail -n 1)" || return 1
    [[ "${last}" == "-- Dump completed"* ]] || return 1
    (set -o pipefail; unzip -p "${archive}" 'files/*.tar.gz' 2> /dev/null | tar -tzf - > /dev/null 2>&1)
}

# ----------------------------------------------------------------
# Keep a site's newest files backups
#
# The folder holds one dated folder (YYYY-MM-DD) per files backup. Only dated folders that hold a
# finished archive (a site archive, or the wp-content archive older versions made) count as
# copies; dated folders without one (left by a failed or interrupted run) are removed, so failed
# runs never push good backups out. Staging folders of interrupted builds are removed too: the
# caller holds the backup lock, so no build is writing here. Folders with other names are kept.
# Usage: site_archive_prune_backups <site's files backup folder> <domain> <copies to keep>
function site_archive_prune_backups() {
    local base="$1" site="$2" keep="$3" name excess i
    local -a complete=()
    [[ -d "${base}" ]] || return 0
    find "${base}" -mindepth 2 -maxdepth 2 -type d -name '.site-archive.*' -exec rm -rf {} +
    while IFS= read -r name; do
        if [[ -f "${base}/${name}/${site}-site-archive.zip" || -f "${base}/${name}/${site}-wp-content.tar.gz" ]]; then
            complete+=("${name}")
        else
            rm -rf "${base:?}/${name}"
        fi
    done < <(find "${base}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' | sort)
    excess=$((${#complete[@]} - keep))
    for ((i = 0; i < excess; i++)); do
        rm -rf "${base:?}/${complete[i]}"
    done
}


# ----------------------------------------------------------------
# Reading an archive (vhost-import.sh)

# Print one value from a manifest.txt (the text after "<key>=" on its first line), or nothing
# Usage: site_archive_manifest_value <manifest.txt> <key>
function site_archive_manifest_value() {
    local manifest="$1" key="$2"
    sed -n "s/^${key}=//p" "${manifest}" | head -n 1 | tr -d '\r'
}

# Print a site address (home_url, WP_HOME) without its scheme and trailing slashes. Any path
# stays: the site's URLs start with this, and the import moves them to the new address with
# search-replace.
# Usage: site_address_without_scheme <address>
function site_address_without_scheme() {
    local address="$1"
    if [[ "${address,,}" == https://* ]]; then
        address="${address:8}"
    elif [[ "${address,,}" == http://* ]]; then
        address="${address:7}"
    fi
    while [[ "${address}" == */ ]]; do
        address="${address%/}"
    done
    printf '%s\n' "${address}"
}

# Succeed when a site address has a path: a site in a subfolder (example.com/blog), or WordPress
# kept in its own folder (siteurl example.com/wp). EngineScript serves each site, and WordPress,
# at the root of its domain, so such sites are neither exported nor imported.
# Usage: site_address_has_path <address>
function site_address_has_path() {
    [[ "$(site_address_without_scheme "$1")" == */* ]]
}

# Succeed when a site address uses www (www.example.com)
# Usage: site_address_uses_www <address>
function site_address_uses_www() {
    local host
    host="$(site_address_without_scheme "$1")"
    host="${host%%/*}"
    [[ "${host,,}" == www.* ]]
}

# Print the domain an imported site is served at: the host of its address, in lowercase, without
# a port or a leading "www.". EngineScript serves each site at the root of its own domain; a site
# that used www can keep www.<domain> as its address (Import Domain asks).
# Usage: site_address_domain <address>
function site_address_domain() {
    local host
    host="$(site_address_without_scheme "$1")"
    host="${host%%/*}"
    host="${host%%:*}"
    host="${host,,}"
    printf '%s\n' "${host#www.}"
}
