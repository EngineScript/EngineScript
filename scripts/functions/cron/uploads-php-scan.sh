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



#----------------------------------------------------------------------------------
# Start Main Script

#----------------------------------------------------------------------------
# Forked from https://github.com/A5hleyRich/simple-automated-tasks

# Include config
source /home/EngineScript/sites-list/sites.sh
source /home/EngineScript/enginescript-install-options.txt

# Store sites with errors
ERRORS=""

for i in "${SITES[@]}"
do
        cd "/var/www/sites/$i/html"
        # Verify checksums
        cd "/var/www/sites/$i/html/wp-content/uploads"
        numFiles=$(find . -name '*.php' \
                ! -path './sucuri/*' \
                ! -path './wp-migrate-db/*' \
                | wc -l)

        if [[ "$numFiles" -gt 0 ]]; then
                ERRORS="$ERRORS $i"
        fi

        cd "/var/www/sites/$i/html"
done

# Trim leading space if ERRORS is not empty
ERRORS="${ERRORS##*( )}"

if [[ -n "$ERRORS" ]]; then
        # Use multiple -d options for clarity and proper quoting
        curl -u "$PUSHBULLET_TOKEN": https://api.pushbullet.com/v2/pushes \
                -d type=note \
                -d "title=Server: $IP_ADDRESS" \
                -d "body=Found PHP in the uploads directory for the following sites: $ERRORS"
fi
