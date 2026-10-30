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

# Create tools directory if it doesn't exist
mkdir -p /var/www/admin/tools

# Download and install official Tiny File Manager from GitHub
echo "Installing official Tiny File Manager from GitHub..."
TFM_DIR="/var/www/admin/tools/tinyfilemanager"
TFM_ZIP_URL="https://github.com/prasathmani/tinyfilemanager/archive/refs/tags/${TINYFILEMANAGER_VER}.tar.gz"

# The new copy is downloaded and unpacked in a staging directory, and replaces the installed
# copy only once it is complete, so a failed download leaves the installed copy in place.
STAGING_DIR="$(mktemp -d /var/www/admin/.tinyfilemanager-new.XXXXXX)" || { echo "Error: Failed to create a staging directory in /var/www/admin" >&2; exit 1; }
TFM_NEW="${STAGING_DIR}/tinyfilemanager-${TINYFILEMANAGER_VER}"

# Remove the staging directory and stop; the installed copy is not changed
function fail_tfm_install() {
    rm -rf "${STAGING_DIR:?}"
    echo "Error: $1" >&2
    echo "Tiny File Manager was not changed." >&2
    exit 1
}

# Download and extract TFM
curl -fsSL --proto '=https' --connect-timeout 30 --max-time 60 "${TFM_ZIP_URL}" -o "${STAGING_DIR}/tinyfilemanager.tar.gz" || fail_tfm_install "Failed to download Tiny File Manager from GitHub"
tar -xzf "${STAGING_DIR}/tinyfilemanager.tar.gz" -C "${STAGING_DIR}" || fail_tfm_install "Failed to extract the Tiny File Manager archive"
if [[ ! -f "${TFM_NEW}/tinyfilemanager.php" ]]; then
    fail_tfm_install "The Tiny File Manager archive has no tinyfilemanager-${TINYFILEMANAGER_VER}/tinyfilemanager.php"
fi

# The archive's hidden files (.github and the like) were never installed
find "${TFM_NEW}" -mindepth 1 -maxdepth 1 -name '.*' -exec rm -rf {} +

# Copy our custom configuration file
# Config templates are stored in /config/var/www/admin/tools/ to mirror the install location
if [[ -f "/usr/local/bin/enginescript/config/var/www/admin/tools/tinyfilemanager/config.php" ]]; then
    cp /usr/local/bin/enginescript/config/var/www/admin/tools/tinyfilemanager/config.php "${TFM_NEW}/" || fail_tfm_install "Failed to copy the Tiny File Manager configuration"
fi

# Set proper permissions
find "${TFM_NEW}" -type f -name "*.php" -exec chmod 644 {} \;
find "${TFM_NEW}" -type f -name "*.md" -exec chmod 644 {} \;
find "${TFM_NEW}" -type f -name "*.txt" -exec chmod 644 {} \;
find "${TFM_NEW}" -type d -exec chmod 755 {} \;

# Swap the new copy in, then clean up
replace_directory "${TFM_NEW}" "${TFM_DIR}" || fail_tfm_install "Failed to move the new copy into ${TFM_DIR}"
rm -rf "${STAGING_DIR:?}"

echo "✓ Official Tiny File Manager v${TINYFILEMANAGER_VER} installed successfully"
echo "  - Location: $TFM_DIR"
echo "  - Access URL: /tinyfilemanager/tinyfilemanager.php"
echo "  - Login: Uses credentials from main EngineScript configuration"

# Set permissions for the EngineScript frontend
set_enginescript_frontend_permissions

# Return to /usr/src
return_to_src
