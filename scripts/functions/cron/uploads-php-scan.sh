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

#----------------------------------------------------------------------------
# Forked from https://github.com/A5hleyRich/simple-automated-tasks

# The server's sites
es_sites

# Store sites with errors
ERRORS=()

for i in "${SITES[@]}"
do
        [[ -d "/var/www/sites/$i/html/wp-content/uploads" ]] || continue
        numFiles=$(find_php_in_uploads "/var/www/sites/$i/html/wp-content/uploads" | wc -l)
        if [[ "$numFiles" -gt 0 ]]; then
                ERRORS+=(
                        "$i"
                )
        fi
done

if [[ ${#ERRORS[@]} -gt 0 ]]; then
        echo "Found PHP in the uploads directory for the following sites: ${ERRORS[*]}"
        notify_admin "Server: $IP_ADDRESS" "Found PHP in the uploads directory for the following sites: ${ERRORS[*]}"
        exit 1
fi
