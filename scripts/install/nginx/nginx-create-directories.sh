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

# Create Nginx Directories with error handling
DIRS=(
    "/etc/nginx/custom-global-directives"
    "/etc/nginx/custom-single-domain-directives"
    "/etc/nginx/globals"
    "/etc/nginx/restricted-access"
    "/etc/nginx/sites-available"
    "/etc/nginx/sites-enabled"
    "/etc/nginx/ssl/cloudflare"
    "/etc/nginx/ssl/dhe"
    "/etc/nginx/ssl/localhost"
    "/usr/lib/nginx/modules"
    "/tmp/nginx_proxy"
    "/var/cache/nginx"
    "/var/lib/nginx/body"
    "/var/lib/nginx/fastcgi"
    "/var/lib/nginx/proxy"
    "/var/log/domains"
    "/var/log/nginx"
    "/var/www/admin/control-panel"
    "/var/www/admin/tools"
    "/var/www/sites"
)

for DIR in "${DIRS[@]}"; do
    mkdir -p "${DIR}" || { echo "Error: Failed to create directory ${DIR}"; exit 1; }
done

for DIR in "${DIRS[@]}"; do
    if [[ -d "${DIR}" ]]; then
        echo "Directory ${DIR} already exists. Skipping."
    else
        mkdir -p "${DIR}" || { echo "Error: Failed to create directory ${DIR}"; exit 1; }
        echo "Created directory: ${DIR}"
    fi
done

# Summary
echo "----------------------------------------------------------"
echo "Nginx directory creation completed successfully."
echo "Directories created or verified:"
for DIR in "${DIRS[@]}"; do
    echo "  - ${DIR}"
done
echo "----------------------------------------------------------"
