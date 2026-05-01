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

# Return to /usr/src
return_to_src

# Create control-panel directory if it doesn't exist
mkdir -p /var/www/admin/control-panel

# Copy Admin Control Panel
cp -a /usr/local/bin/enginescript/config/var/www/admin/control-panel/. /var/www/admin/control-panel/ || { echo "Error: Failed to copy admin control panel files to /var/www/admin/control-panel/" >&2; exit 1; }

# Substitute frontend dependency versions
# Note: The Font Awesome version placeholder {FONTAWESOME_VER} may also appear in
# inline JS comments/strings in index.html, so we scope the substitution to only
# the specific Font Awesome CDN URL that contains the version segment. If the
# Font Awesome CDN path changes, update the pattern below accordingly.
sed -i "s|https://cdnjs.cloudflare.com/ajax/libs/font-awesome/{FONTAWESOME_VER}/css/all.min.css|https://cdnjs.cloudflare.com/ajax/libs/font-awesome/${FONTAWESOME_VER}/css/all.min.css|g" /var/www/admin/control-panel/index.html
# Verify that the Font Awesome placeholder was successfully replaced to avoid silent failures
if grep -q '{FONTAWESOME_VER}' /var/www/admin/control-panel/index.html; then
    echo "Error: Failed to substitute Font Awesome version in index.html; placeholder {FONTAWESOME_VER} still present." >&2
    exit 1
fi

# Substitute and verify dashboard version placeholders in one pass
for file in index.html dashboard.js; do
    sed -i "s|{ES_DASHBOARD_VER}|${ES_DASHBOARD_VER}|g" "/var/www/admin/control-panel/${file}"
    if grep -q '{ES_DASHBOARD_VER}' "/var/www/admin/control-panel/${file}"; then
        echo "Error: Failed to substitute dashboard version in /var/www/admin/control-panel/${file}; placeholder {ES_DASHBOARD_VER} still present." >&2
        exit 1
    fi
done

# Set permissions for the EngineScript frontend
set_enginescript_frontend_permissions

# Return to /usr/src
return_to_src
