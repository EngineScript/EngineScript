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

# Source the list of sites
SITES_LIST_FILE="/home/EngineScript/sites-list/sites.sh"
if [[ -f "$SITES_LIST_FILE" ]]; then
    source "$SITES_LIST_FILE"
else
    echo "ERROR: Site list file not found at ${SITES_LIST_FILE}"
    exit 1
fi

# Check if SITES array is empty or unset
if [[ ${#SITES[@]} -eq 0 ]]; then
    echo "No sites found in ${SITES_LIST_FILE}. Cannot export."
    exit 1
fi

# --- Select Site to Export ---
clear
echo ""
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo "|   Domain Export                                     |"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""
echo "Select the site you wish to export:"
echo ""
PS3='Please enter the number corresponding to the site (or type the number for Exit): '
options=("${SITES[@]}" "Exit Script") # Add "Exit Script" to the options
select SELECTED_ITEM in "${options[@]}"; do
    if [[ "$SELECTED_ITEM" == "Exit Script" ]]; then
        echo "Exiting script as requested."
        exit 0
    elif [[ -n "$SELECTED_ITEM" ]]; then
        SELECTED_SITE="$SELECTED_ITEM" # Assign the selected site
        echo "You selected: ${SELECTED_SITE}"
        break
    else
        echo "Invalid selection. Please try again."
    fi
done

# --- Define Export Paths ---
# EngineScript combined site archive format (v1)
# Keep this layout aligned with vhost-import.sh and the EngineScript Site Exporter
# WordPress plugin. The importer expects one outer ZIP that contains:
#   manifest.txt
#   database/<site>_db_<timestamp>.sql.gz
#   files/<site>_files_<timestamp>.tar.gz
# The WordPress files are intentionally kept as a nested tar.gz payload so a manual
# shell export and a plugin export can both hand users one portable ZIP file.
# The outer ZIP is created with store/no-compression mode because the database and
# files payloads are already compressed. Match this in the WordPress plugin exporter.
EXPORT_BASE_DIR="/home/EngineScript/temp/site-export"
SITE_EXPORT_DIR="${EXPORT_BASE_DIR}/${SELECTED_SITE}"
EXPORT_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
EXPORT_STAGING_DIR="${SITE_EXPORT_DIR}/staging-${EXPORT_TIMESTAMP}"
BUNDLE_ROOT_DIR="${EXPORT_STAGING_DIR}/bundle"
DATABASE_EXPORT_DIR="${BUNDLE_ROOT_DIR}/database"
FILES_EXPORT_DIR="${BUNDLE_ROOT_DIR}/files"
MANIFEST_PATH="${BUNDLE_ROOT_DIR}/manifest.txt"
SITE_ROOT_PATH="/var/www/sites/${SELECTED_SITE}/html"
DB_EXPORT_FILENAME="${SELECTED_SITE}_db_${EXPORT_TIMESTAMP}.sql"
FILES_EXPORT_FILENAME="${SELECTED_SITE}_files_${EXPORT_TIMESTAMP}.tar.gz"
COMBINED_EXPORT_FILENAME="${SELECTED_SITE}_enginescript_site_export_${EXPORT_TIMESTAMP}.zip"
DB_EXPORT_PATH="${DATABASE_EXPORT_DIR}/${DB_EXPORT_FILENAME}"
FILES_EXPORT_PATH="${FILES_EXPORT_DIR}/${FILES_EXPORT_FILENAME}"
COMBINED_EXPORT_PATH="${SITE_EXPORT_DIR}/${COMBINED_EXPORT_FILENAME}"

# --- Create Export Directory ---
echo "Creating export directory: ${SITE_EXPORT_DIR}"
mkdir -p "${DATABASE_EXPORT_DIR}" "${FILES_EXPORT_DIR}"
if [[ $? -ne 0 ]]; then
    echo "ERROR: Failed to create export staging directories in ${SITE_EXPORT_DIR}"
    exit 1
fi

if ! command -v zip >/dev/null 2>&1; then
    echo "ERROR: The zip command is required to create a combined EngineScript site archive."
    rm -rf "${EXPORT_STAGING_DIR}"
    exit 1
fi

# --- Export Database ---
echo "Exporting database for ${SELECTED_SITE}..."
# Check if site root exists before changing directory
if [[ ! -d "$SITE_ROOT_PATH" ]]; then
    echo "ERROR: Site root directory not found at ${SITE_ROOT_PATH}"
    exit 1
fi

# Change to site root for wp-cli context with error checking
if ! cd "$SITE_ROOT_PATH"; then
    echo "ERROR: Failed to change directory to ${SITE_ROOT_PATH}"
    exit 1
fi

# Export database with immediate error checking
if ! wp db export "${DB_EXPORT_PATH}" --allow-root; then
    echo "ERROR: Failed to export database for ${SELECTED_SITE} using wp-cli."
    rm -rf "${EXPORT_STAGING_DIR}"
    exit 1
fi
echo "Database exported to ${DB_EXPORT_PATH}"

# --- Compress Database ---
echo "Compressing database export..."
if ! gzip -f "${DB_EXPORT_PATH}"; then
    echo "ERROR: Failed to compress database file ${DB_EXPORT_PATH}"
    rm -rf "${EXPORT_STAGING_DIR}"
    exit 1
fi
DB_EXPORT_PATH_GZ="${DB_EXPORT_PATH}.gz" # Update path to compressed file
echo "Database compressed to ${DB_EXPORT_PATH_GZ}"

# --- Export Site Files ---
echo "Exporting site files for ${SELECTED_SITE}..."
# Go back one level to archive the 'html' directory itself or its contents
if ! cd "/var/www/sites/${SELECTED_SITE}/"; then
    echo "ERROR: Failed to change directory to /var/www/sites/${SELECTED_SITE}/"
    exit 1
fi

# Archive the contents of the html directory with immediate error checking
if ! tar -zcf "${FILES_EXPORT_PATH}" -C html .; then
    echo "ERROR: Failed to create site files archive for ${SELECTED_SITE}"
    rm -rf "${EXPORT_STAGING_DIR}"
    exit 1
fi
echo "Site files archived to ${FILES_EXPORT_PATH}"

# --- Write Manifest ---
# This small manifest is deliberately simple key=value text so the WordPress plugin
# can reproduce it without needing a custom parser.
echo "Writing combined archive manifest..."
{
    echo "format=enginescript-site-archive"
    echo "version=1"
    echo "site=${SELECTED_SITE}"
    echo "created_at_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "database_path=database/${DB_EXPORT_FILENAME}.gz"
    echo "files_archive_path=files/${FILES_EXPORT_FILENAME}"
} > "${MANIFEST_PATH}"

# --- Create Combined Archive ---
echo "Creating combined EngineScript site archive..."
if ! ( cd "${BUNDLE_ROOT_DIR}" && zip -0 -r -q "${COMBINED_EXPORT_PATH}" . ); then
    echo "ERROR: Failed to create combined export archive ${COMBINED_EXPORT_PATH}"
    rm -rf "${EXPORT_STAGING_DIR}"
    exit 1
fi

rm -rf "${EXPORT_STAGING_DIR}"
echo "Combined archive created at ${COMBINED_EXPORT_PATH}"

# --- Final Summary ---
echo ""
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo "|   Export Complete                                   |"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""
echo "Site: ${SELECTED_SITE}"
echo ""
echo "Exported file located in: ${SITE_EXPORT_DIR}"
echo "  - Combined Archive: ${COMBINED_EXPORT_FILENAME}"
echo ""
echo "This single archive is compatible with the vhost-import.sh script."
echo "Remember to move these files off the server if needed."
echo ""
echo "Returning to main menu..."
sleep 5

exit 0
