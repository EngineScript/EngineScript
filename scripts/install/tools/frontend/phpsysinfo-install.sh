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

# phpSysinfo
PSI_DIR="/var/www/admin/tools/phpsysinfo"

# The new copy is cloned into a staging directory and replaces the installed copy only once it
# is complete, so a failed clone leaves the installed copy in place.
STAGING_DIR="$(mktemp -d /var/www/admin/.phpsysinfo-new.XXXXXX)" || { echo "Error: Failed to create a staging directory in /var/www/admin" >&2; exit 1; }
PSI_NEW="${STAGING_DIR}/phpsysinfo"

# Remove the staging directory and stop; the installed copy is not changed
function fail_psi_install() {
    rm -rf "${STAGING_DIR:?}"
    echo "Error: $1" >&2
    echo "phpSysInfo was not changed." >&2
    exit 1
}

# Clone the phpSysinfo repository
git clone --depth 1 "https://github.com/phpsysinfo/phpsysinfo.git" "${PSI_NEW}" || fail_psi_install "Failed to clone phpSysInfo from GitHub"
if [[ ! -f "${PSI_NEW}/index.php" ]]; then
    fail_psi_install "The phpSysInfo clone has no index.php"
fi

# The repository's own files (.git, .github and the like) are not served
find "${PSI_NEW}" -mindepth 1 -maxdepth 1 -name '.*' -exec rm -rf {} +

# Copy EngineScript phpSysinfo configuration template
# Config templates are stored in /config/var/www/admin/tools/ to mirror the install location
cp -f /usr/local/bin/enginescript/config/var/www/admin/tools/phpsysinfo/phpsysinfo.ini "${PSI_NEW}/phpsysinfo.ini" || fail_psi_install "Failed to copy the phpSysInfo configuration"
sed -i "s|SEDPHPVER|${PHP_VER}|g" "${PSI_NEW}/phpsysinfo.ini" || fail_psi_install "Failed to set the PHP version in the phpSysInfo configuration"

# Swap the new copy in, then clean up
chmod 755 "${PSI_NEW}"
replace_directory "${PSI_NEW}" "${PSI_DIR}" || fail_psi_install "Failed to move the new copy into ${PSI_DIR}"
rm -rf "${STAGING_DIR:?}"

# Set permissions for the EngineScript frontend
set_enginescript_frontend_permissions

# Return to /usr/src
return_to_src
