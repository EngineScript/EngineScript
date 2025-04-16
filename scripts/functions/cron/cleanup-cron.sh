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

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" -ne 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit 1
fi

#----------------------------------------------------------------------------------
# Start Main Script

# Get Latest Version

# Removes stuck lock files.
# Credit SlickStack for the idea.
/usr/bin/find /tmp/*.lock -mmin +360 -delete > /dev/null 2>&1


# Move EngineScript Simple Site Exporter files from public directory to private directory
# Source the list of sites
SITES_LIST_FILE="/home/EngineScript/sites-list/sites.sh"
if [[ -f "$SITES_LIST_FILE" ]]; then
    source "$SITES_LIST_FILE"
else
    echo "ERROR: Site list file not found at $SITES_LIST_FILE"
fi

for DOMAIN in "${SITES[@]}"; do
    # Set paths
    PUBLIC_EXPORT_DIR="/var/www/sites/${DOMAIN}/html/wp-content/uploads/enginescript-sse-site-exports"
    PRIVATE_EXPORT_DIR="/var/www/sites/${DOMAIN}/enginescript-sse-site-exports"

    # Only proceed if the public export directory exists
    if [ -d "$PUBLIC_EXPORT_DIR" ]; then
        # Find zip files
        shopt -s nullglob
        zip_files=("$PUBLIC_EXPORT_DIR"/*.zip)
        shopt -u nullglob

        if [ ${#zip_files[@]} -gt 0 ]; then
            # Create the private directory if it doesn't exist
            mkdir -p "$PRIVATE_EXPORT_DIR"
            # Move all zip files
            mv "$PUBLIC_EXPORT_DIR"/*.zip "$PRIVATE_EXPORT_DIR"/
            echo "Moved ${#zip_files[@]} zip(s) from $PUBLIC_EXPORT_DIR to $PRIVATE_EXPORT_DIR"
        fi
    fi
done
