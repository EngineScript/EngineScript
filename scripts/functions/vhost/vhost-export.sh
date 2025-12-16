#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh


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
EXPORT_BASE_DIR="/home/EngineScript/temp/site-export"
SITE_EXPORT_DIR="${EXPORT_BASE_DIR}/${SELECTED_SITE}"
SITE_ROOT_PATH="/var/www/sites/${SELECTED_SITE}/html"
DB_EXPORT_FILENAME="${SELECTED_SITE}_db_$(date +%Y%m%d_%H%M%S).sql"
FILES_EXPORT_FILENAME="${SELECTED_SITE}_files_$(date +%Y%m%d_%H%M%S).tar.gz"
DB_EXPORT_PATH="${SITE_EXPORT_DIR}/${DB_EXPORT_FILENAME}"
FILES_EXPORT_PATH="${SITE_EXPORT_DIR}/${FILES_EXPORT_FILENAME}"

# --- Create Export Directory ---
echo "Creating export directory: ${SITE_EXPORT_DIR}"
mkdir -p "${SITE_EXPORT_DIR}"
if [[ $? -ne 0 ]]; then
    echo "ERROR: Failed to create export directory ${SITE_EXPORT_DIR}"
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
    # Clean up potentially empty export directory
    rmdir "${SITE_EXPORT_DIR}" 2>/dev/null || true
    exit 1
fi
echo "Database exported to ${DB_EXPORT_PATH}"

# --- Compress Database ---
echo "Compressing database export..."
if ! gzip -f "${DB_EXPORT_PATH}"; then
    echo "ERROR: Failed to compress database file ${DB_EXPORT_PATH}"
    # Clean up
    rm -f "${DB_EXPORT_PATH}" 2>/dev/null || true # Remove potentially corrupted .sql file
    rmdir "${SITE_EXPORT_DIR}" 2>/dev/null || true
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
    # Clean up
    rm -f "${DB_EXPORT_PATH_GZ}" 2>/dev/null || true
    rmdir "${SITE_EXPORT_DIR}" 2>/dev/null || true
    exit 1
fi
echo "Site files archived to ${FILES_EXPORT_PATH}"

# --- Final Summary ---
echo ""
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo "|   Export Complete                                   |"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""
echo "Site: ${SELECTED_SITE}"
echo ""
echo "Exported files located in: ${SITE_EXPORT_DIR}"
echo "  - Database: ${DB_EXPORT_FILENAME}.gz"
echo "  - Site Files: ${FILES_EXPORT_FILENAME}"
echo ""
echo "These files are compatible with the vhost-import.sh script."
echo "Remember to move these files off the server if needed."
echo ""
echo "Returning to main menu..."
sleep 5

exit 0