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

cd /var/www/sites
printf "Please select the site you want to scan for vulnerabilities:\n"
select d in *; do test -n "$d" && break; echo ">>> Invalid Selection"; done
echo "${BOLD}Showing last 20 lines of Nginx error log for ${d}.${NORMAL}" | boxes -a c -d shell -p a1l2
tail -n20 "/var/log/domains/${d}/${d}-nginx-error.log"
echo "${BOLD}Showing last 20 lines of WordPress error log for ${d}.${NORMAL}" | boxes -a c -d shell -p a1l2
tail -n20 "/var/log/domains/${d}/${d}-wp-error.log"

# Ask user to acknowledge that the scan has completed before moving on
echo ""
echo ""
read -n 1 -s -r -p "Press any key to continue"
echo ""
echo ""
