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

printf "Please select the site you want to scan for vulnerabilities:\n"
select_site || exit 0
echo "WPScan"

# Run WPScan
if [[ "${WPSCANAPI}" == "PLACEHOLDER" ]]
  then
    wpscan --url "${SELECTED_SITE}"
  else
    wpscan --url "${SELECTED_SITE}" --api-token "${WPSCANAPI}"
fi

# Ask user to acknowledge that the scan has completed before moving on
pause
