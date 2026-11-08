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

# Retrieve Domains
printf "Please select the site you want to run an SSL capabilities check on:\n"
select_site || exit 0

# Run the command
echo "testssl.sh is running. The scan may take a bit; stand by for results."
echo "Scanning: ${SELECTED_SITE}"
/usr/local/bin/testssl.sh/testssl.sh -S -h -e -E -s -f -p -g -U "${SELECTED_SITE}"

# Ask user to acknowledge that the command has completed
pause

