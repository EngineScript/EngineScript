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
    # Verify checksums
    if ! cd "/var/www/sites/$i/html" || ! run_as_www_data wp core verify-checksums; then
        ERRORS+=(
            "$i"
        )
    fi
done

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo "Checksums verification failed for the following sites: ${ERRORS[*]}"
    notify_admin "Server: $IP_ADDRESS" "Checksums verification failed for the following sites: ${ERRORS[*]}"
    exit 1
fi
