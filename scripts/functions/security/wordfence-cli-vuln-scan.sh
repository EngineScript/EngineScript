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
echo "Wordfence CLI vulnerability scan is running. This scan may take a bit; stand by for results."
echo "When completed, the scan results will be located at:"
echo "/home/EngineScript/wordfence-scan-results/wordfence-cli-vulnerability-scan-results.csv"

# Scan
wordfence vuln-scan --images --output-path /home/EngineScript/wordfence-scan-results/wordfence-cli-vulnerability-scan-results.csv "/var/www/sites/${SELECTED_SITE}/html"

# Ask user to acknowledge that the scan has completed before moving on
echo ""
echo ""
echo "The scan results will be located at:"
echo "/home/EngineScript/wordfence-scan-results/wordfence-cli-vulnerability-scan-results.csv"
pause
