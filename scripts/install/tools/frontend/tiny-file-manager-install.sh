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

# Download and install official Tiny File Manager from GitHub
echo "Installing official Tiny File Manager from GitHub..."
TFM_DIR="/var/www/admin/tools/tinyfilemanager"
TFM_ZIP_URL="https://github.com/prasathmani/tinyfilemanager/archive/refs/tags/${TINYFILEMANAGER_VER}.tar.gz"

# Download and unpack Tiny File Manager into <staging folder>, with EngineScript's configuration
# (install_beside swaps it in when this succeeds, so a failed download leaves the installed copy)
build_tiny_file_manager() {
    local dir="$1" archive="$1/.tinyfilemanager.tar.gz"
    curl -fsSL --proto '=https' --connect-timeout 30 --max-time 60 "${TFM_ZIP_URL}" -o "${archive}" \
        || { echo "Error: Failed to download Tiny File Manager from GitHub" >&2; return 1; }
    # The archive holds tinyfilemanager-<version>/; its contents go straight into the folder
    tar -xzf "${archive}" -C "${dir}" --strip-components=1 \
        || { echo "Error: Failed to extract the Tiny File Manager archive" >&2; return 1; }
    rm -f "${archive}"
    if [[ ! -f "${dir}/tinyfilemanager.php" ]]; then
        echo "Error: The Tiny File Manager archive has no tinyfilemanager.php" >&2
        return 1
    fi

    # The archive's hidden files (.github and the like) were never installed
    find "${dir}" -mindepth 1 -maxdepth 1 -name '.*' -exec rm -rf {} +

    # EngineScript's configuration, stored in config/var/www/admin/tools/ to mirror the install
    # location
    if [[ -f "/usr/local/bin/enginescript/config/var/www/admin/tools/tinyfilemanager/config.php" ]]; then
        cp /usr/local/bin/enginescript/config/var/www/admin/tools/tinyfilemanager/config.php "${dir}/" \
            || { echo "Error: Failed to copy the Tiny File Manager configuration" >&2; return 1; }
    fi
}

# Its permissions are set below, as www-data (set_enginescript_frontend_permissions): a root chmod
# in a folder www-data owns could be led outside it by a link.
install_beside "${TFM_DIR}" "Tiny File Manager" build_tiny_file_manager || exit 1

echo "✓ Official Tiny File Manager v${TINYFILEMANAGER_VER} installed successfully"
echo "  - Location: $TFM_DIR"
echo "  - Access URL: /tinyfilemanager/tinyfilemanager.php"
echo "  - Login: Uses credentials from main EngineScript configuration"

# Set permissions for the EngineScript frontend
set_enginescript_frontend_permissions

# Return to /usr/src
return_to_src
