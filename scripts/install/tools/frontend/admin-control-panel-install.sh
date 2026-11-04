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

# The new panel is built in a staging directory beside the running one and swapped in only
# when every step below has succeeded, so a failed copy or substitution leaves the running
# panel as it was. The swap also drops files that the new version no longer has.
CONTROL_PANEL_SOURCE="/usr/local/bin/enginescript/config/var/www/admin/control-panel"
CONTROL_PANEL_DIR="/var/www/admin/control-panel"
mkdir -p /var/www/admin
STAGING_DIR="$(mktemp -d /var/www/admin/.control-panel-new.XXXXXX)" || { echo "Error: Failed to create a staging directory in /var/www/admin" >&2; exit 1; }

# Remove the staging directory and stop; the running panel is not changed
function fail_panel_install() {
    rm -rf "${STAGING_DIR:?}"
    echo "Error: $1" >&2
    echo "The Admin Control Panel was not changed." >&2
    exit 1
}

# Copy Admin Control Panel
cp -a "${CONTROL_PANEL_SOURCE}/." "${STAGING_DIR}/" || fail_panel_install "Failed to copy the admin control panel files"

# The panel's README.md and LICENSE document the repository copy; they are not served.
rm -f "${STAGING_DIR}/README.md" "${STAGING_DIR}/LICENSE"

# Substitute frontend dependency versions
# Note: The Font Awesome version placeholder {FONTAWESOME_VER} may also appear in
# inline JS comments/strings in index.html, so we scope the substitution to only
# the specific Font Awesome CDN URL that contains the version segment. If the
# Font Awesome CDN path changes, update the pattern below accordingly.
CONTROL_PANEL_INDEX="${STAGING_DIR}/index.html"
FONTAWESOME_CDN_PLACEHOLDER='https://cdnjs.cloudflare.com/ajax/libs/font-awesome/{FONTAWESOME_VER}/css/all.min.css'
FONTAWESOME_CDN_URL="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/${FONTAWESOME_VER}/css/all.min.css"

sed -i "s|${FONTAWESOME_CDN_PLACEHOLDER}|${FONTAWESOME_CDN_URL}|g" "$CONTROL_PANEL_INDEX" || fail_panel_install "Failed to substitute the Font Awesome version in index.html"

# Verify the CDN URL was replaced without treating explanatory comments/strings as failures.
if grep -Fq "$FONTAWESOME_CDN_PLACEHOLDER" "$CONTROL_PANEL_INDEX"; then
    fail_panel_install "Failed to substitute Font Awesome version in index.html CDN URL; placeholder path still present."
fi

if ! grep -Fq "$FONTAWESOME_CDN_URL" "$CONTROL_PANEL_INDEX"; then
    fail_panel_install "Failed to configure Font Awesome CDN URL in index.html."
fi

# Dashboard version: the date it was installed (shown in the footer) and a hash of the panel's
# files. The assets' URLs carry it, so they change whenever the files do, even on the same day.
PANEL_HASH="$(cd "${CONTROL_PANEL_SOURCE}" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -c1-8)"
if [[ ! "${PANEL_HASH}" =~ ^[0-9a-f]{8}$ ]]; then
    fail_panel_install "Failed to compute the dashboard version hash."
fi
DASHBOARD_VER="${ES_DASHBOARD_VER}-${PANEL_HASH}"

# Substitute and verify dashboard version placeholders in one pass
for file in index.html dashboard.js; do
    sed -i "s|{ES_DASHBOARD_VER}|${DASHBOARD_VER}|g" "${STAGING_DIR}/${file}" || fail_panel_install "Failed to substitute the dashboard version in ${file}"
    if grep -q '{ES_DASHBOARD_VER}' "${STAGING_DIR}/${file}"; then
        fail_panel_install "Failed to substitute dashboard version in ${file}; placeholder {ES_DASHBOARD_VER} still present."
    fi
done

# Swap the new panel in (mktemp made the staging directory private)
chmod 755 "${STAGING_DIR}"
replace_directory "${STAGING_DIR}" "${CONTROL_PANEL_DIR}" || fail_panel_install "Failed to move the new panel into ${CONTROL_PANEL_DIR}"

# Set permissions for the EngineScript frontend
set_enginescript_frontend_permissions

# Return to /usr/src
return_to_src
