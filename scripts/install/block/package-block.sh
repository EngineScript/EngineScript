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

cd /etc/apt/preferences.d/

# Block Apache2 from APT
echo -e "Package: apache2*\nPin: release *\nPin-Priority: -1" > apache2-block

# Block Nginx from APT
echo -e "Package: nginx*\nPin: release *\nPin-Priority: -1" > nginx-block

# Block Litespeed from APT
echo -e "Package: openlitespeed*\nPin: release *\nPin-Priority: -1" > litespeed-block
echo -e "Package: lighttpd*\nPin: release *\nPin-Priority: -1" > litespeed-block2

# Block all PHP versions except the selected one
# Always block legacy versions
block_versions=("5" "7.0" "7.1" "7.2" "7.3" "7.4" "8.0" "8.1" "8.2" "8.3" "8.4" "8.5")

for ver in "${block_versions[@]}"; do
    # Skip the selected PHP version
    if [[ "${ver}" == "${PHP_VER}" ]]; then
        continue
    fi
    sanitized="${ver//.}"
    echo -e "Package: php${ver}*\nPin: release *\nPin-Priority: -1" > "php${sanitized}-block"
done
