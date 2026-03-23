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

# Return to /usr/src
cd /usr/src

# Create control-panel directory if it doesn't exist
mkdir -p /var/www/admin/control-panel

# Copy Admin Control Panel
cp -a /usr/local/bin/enginescript/config/var/www/admin/control-panel/. /var/www/admin/control-panel/

# Substitute frontend dependency versions
# Note: The Font Awesome version placeholder {FONTAWESOME_VER} may also appear in
# inline JS comments/strings in index.html, so we scope the substitution to only
# the specific Font Awesome CDN URL that contains the version segment. If the
# Font Awesome CDN path changes, update the pattern below accordingly.
sed -i 's|\(cdnjs\.cloudflare\.com/ajax/libs/font-awesome/\){FONTAWESOME_VER}\(/css/all\.min\.css\)|\1'"${FONTAWESOME_VER}"'\2|g' /var/www/admin/control-panel/index.html
for file in index.html dashboard.js external-services/external-services.js; do
    sed -i "s|{ES_DASHBOARD_VER}|${ES_DASHBOARD_VER}|g" "/var/www/admin/control-panel/${file}"
done

# Remove Adminer tool card if INSTALL_ADMINER=0
if [[ "${INSTALL_ADMINER}" -eq 0 ]]; then
    # NOTE: This sed range depends on the HTML structure of index.html:
    #   - the Adminer card must be wrapped in a single <div ... id="adminer-tool" ...> ... </div> block
    #   - the opening <div> with id="adminer-tool" and its matching closing </div> must each be on a single line
    #   - the block must not contain nested <div> elements whose closing tags appear before the end of the card
    # If this structure changes, update this command (or switch to an HTML-aware tool) to avoid partial removal.
    # To avoid corrupting the page if the structure has changed, first ensure that the expected
    # single-line opening <div> for the Adminer card is present before applying the sed range.
    if grep -qE '<div[^>]*id="adminer-tool"[^>]*>' "/var/www/admin/control-panel/index.html"; then
        sed -i '/<div[^>]*id="adminer-tool"[^>]*>/,/<\/div>/d' "/var/www/admin/control-panel/index.html"
    else
        echo "Warning: Expected Adminer tool div not found in index.html; skipping Adminer card removal." >&2
    fi
fi

# Set permissions for the EngineScript frontend
set_enginescript_frontend_permissions

# Return to /usr/src
cd /usr/src
