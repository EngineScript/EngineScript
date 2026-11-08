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

PSI_DIR="/var/www/admin/tools/phpsysinfo"

# Clone phpSysInfo into <staging folder>, with EngineScript's configuration (install_beside swaps
# it in when this succeeds, so a failed clone leaves the installed copy in place)
build_phpsysinfo() {
    local dir="$1"
    git clone --depth 1 "https://github.com/phpsysinfo/phpsysinfo.git" "${dir}" \
        || { echo "Error: Failed to clone phpSysInfo from GitHub" >&2; return 1; }
    if [[ ! -f "${dir}/index.php" ]]; then
        echo "Error: The phpSysInfo clone has no index.php" >&2
        return 1
    fi

    # The repository's own files (.git, .github and the like) are not served
    find "${dir}" -mindepth 1 -maxdepth 1 -name '.*' -exec rm -rf {} +

    # EngineScript's configuration template, stored in config/var/www/admin/tools/ to mirror the
    # install location
    cp -f /usr/local/bin/enginescript/config/var/www/admin/tools/phpsysinfo/phpsysinfo.ini "${dir}/phpsysinfo.ini" \
        || { echo "Error: Failed to copy the phpSysInfo configuration" >&2; return 1; }
    sed -i "s|SEDPHPVER|${PHP_VER}|g" "${dir}/phpsysinfo.ini" \
        || { echo "Error: Failed to set the PHP version in the phpSysInfo configuration" >&2; return 1; }
}

install_beside "${PSI_DIR}" "phpSysInfo" build_phpsysinfo || exit 1

# Set permissions for the EngineScript frontend
set_enginescript_frontend_permissions

# Return to /usr/src
return_to_src
