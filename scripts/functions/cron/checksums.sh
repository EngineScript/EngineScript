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
source /home/EngineScript/enginescript-install-options.txt

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

#----------------------------------------------------------------------------
# Forked from https://github.com/A5hleyRich/simple-automated-tasks

# Include config
source /home/EngineScript/sites-list/sites.sh
source /home/EngineScript/enginescript-install-options.txt

# Store sites with errors
ERRORS=()

for i in "${SITES[@]}"
do
    cd "/var/www/sites/$i/html"
    # Verify checksums
    if ! wp core verify-checksums --allow-root; then
        ERRORS+=("$i")
    fi
done

if [[ ${#ERRORS[@]} -gt 0 ]]; then
    curl -u "$PUSHBULLET_TOKEN": https://api.pushbullet.com/v2/pushes \
        -d type=note \
        -d "title=Server: $IP_ADDRESS" \
        -d "body=Checksums verification failed for the following sites: ${ERRORS[*]}"
fi
