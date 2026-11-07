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

# Source the site archive builder
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-site-archive.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-site-archive.sh" >&2; exit 1; }


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
options=(
  "${SITES[@]}"
  "Exit Script"
)
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

# --- Build the Archive ---
# The EngineScript site archive (manifest.txt, database/*.sql.gz, files/*.tar.gz in one ZIP) that
# vhost-import.sh reads; enginescript-site-archive.sh describes the format.
EXPORT_BASE_DIR="/home/EngineScript/temp/site-export"
SITE_EXPORT_DIR="${EXPORT_BASE_DIR}/${SELECTED_SITE}"
EXPORT_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
COMBINED_EXPORT_FILENAME="${SELECTED_SITE}_enginescript_site_export_${EXPORT_TIMESTAMP}.zip"
COMBINED_EXPORT_PATH="${SITE_EXPORT_DIR}/${COMBINED_EXPORT_FILENAME}"

# EngineScript serves each site, and WordPress, at the root of its domain. A site whose address,
# or WordPress address, was changed to a subfolder cannot be imported, so it is not exported.
mapfile -t SITE_INFO < <(site_archive_site_info "${SITE_ARCHIVE_SITES_ROOT}/${SELECTED_SITE}/html")
for address in "${SITE_INFO[@]:0:2}"; do
    if [[ -n "${address}" ]] && site_address_has_path "${address}"; then
        echo "ERROR: ${SELECTED_SITE} is not at the root of its domain:" >&2
        echo "  Site address:      ${SITE_INFO[0]}" >&2
        echo "  WordPress address: ${SITE_INFO[1]:-}" >&2
        echo "EngineScript only exports and imports sites at the root of their domain, such as https://${SELECTED_SITE}." >&2
        echo "Remove the path from WP_HOME and WP_SITEURL in ${SITE_ARCHIVE_SITES_ROOT}/${SELECTED_SITE}/html/wp-config.php, then export again. Nothing was exported." >&2
        exit 1
    fi
done

echo "Exporting ${SELECTED_SITE}'s database and files..."
if ! build_site_archive "${SELECTED_SITE}" "${COMBINED_EXPORT_PATH}"; then
    echo "ERROR: The export of ${SELECTED_SITE} failed (see the message above)." >&2
    exit 1
fi
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
echo "The archive holds wp-config.php and the database, so on this server only root can read it:"
echo "download it as root, or copy it first with sudo."
echo ""
echo "Returning to main menu..."
sleep 5

exit 0
