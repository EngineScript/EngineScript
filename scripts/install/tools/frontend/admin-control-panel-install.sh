#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript settings and shared functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# Return to /usr/src
return_to_src

CONTROL_PANEL_SOURCE="/usr/local/bin/enginescript/config/var/www/admin/control-panel"
CONTROL_PANEL_DIR="/var/www/admin/control-panel"

# Build the new panel in <staging folder> (install_beside swaps it in when this succeeds, so a
# failed copy or substitution leaves the running panel as it was; the swap also drops files the
# new version no longer has)
build_control_panel() {
    local dir="$1" index file panel_hash dashboard_ver
    local fontawesome_placeholder='https://cdnjs.cloudflare.com/ajax/libs/font-awesome/{FONTAWESOME_VER}/css/all.min.css'
    local fontawesome_url="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/${FONTAWESOME_VER}/css/all.min.css"

    cp -a "${CONTROL_PANEL_SOURCE}/." "${dir}/" || { echo "Error: Failed to copy the admin control panel files" >&2; return 1; }

    # The panel's README.md and LICENSE document the repository copy; they are not served.
    rm -f "${dir}/README.md" "${dir}/LICENSE"

    # Substitute frontend dependency versions
    # Note: The Font Awesome version placeholder {FONTAWESOME_VER} may also appear in
    # inline JS comments/strings in index.html, so we scope the substitution to only
    # the specific Font Awesome CDN URL that contains the version segment. If the
    # Font Awesome CDN path changes, update the pattern below accordingly.
    index="${dir}/index.html"
    sed -i "s|${fontawesome_placeholder}|${fontawesome_url}|g" "${index}" \
        || { echo "Error: Failed to substitute the Font Awesome version in index.html" >&2; return 1; }
    # Verify the CDN URL was replaced without treating explanatory comments/strings as failures.
    if grep -Fq "${fontawesome_placeholder}" "${index}"; then
        echo "Error: Failed to substitute Font Awesome version in index.html CDN URL; placeholder path still present." >&2
        return 1
    fi
    if ! grep -Fq "${fontawesome_url}" "${index}"; then
        echo "Error: Failed to configure Font Awesome CDN URL in index.html." >&2
        return 1
    fi

    # Dashboard version: the date it was installed (shown in the footer) and a hash of the panel's
    # files. The assets' URLs carry it, so they change whenever the files do, even on the same day.
    panel_hash="$(cd "${CONTROL_PANEL_SOURCE}" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -c1-8)"
    if [[ ! "${panel_hash}" =~ ^[0-9a-f]{8}$ ]]; then
        echo "Error: Failed to compute the dashboard version hash." >&2
        return 1
    fi
    dashboard_ver="${ES_DASHBOARD_VER}-${panel_hash}"

    # Substitute and verify dashboard version placeholders in one pass
    for file in index.html dashboard.js; do
        sed -i "s|{ES_DASHBOARD_VER}|${dashboard_ver}|g" "${dir}/${file}" \
            || { echo "Error: Failed to substitute the dashboard version in ${file}" >&2; return 1; }
        if grep -q '{ES_DASHBOARD_VER}' "${dir}/${file}"; then
            echo "Error: Failed to substitute dashboard version in ${file}; placeholder {ES_DASHBOARD_VER} still present." >&2
            return 1
        fi
    done
}

install_beside "${CONTROL_PANEL_DIR}" "The Admin Control Panel" build_control_panel || exit 1

# Set permissions for the EngineScript frontend
set_enginescript_frontend_permissions

# Return to /usr/src
return_to_src
