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

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" -ne 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit 1
fi

#----------------------------------------------------------------------------------
# Start Main Script

# Retrieve Domains
cd /var/www/sites
printf "Please select the site you want to run an SSL capabilities check on:\n"
select d in *; do test -n "$d" && break; echo ">>> Invalid Selection"; done

# Run command
echo "testssl.sh is running. Scan may take a bit, standby for results."
echo "Scanning: $d"
/usr/local/bin/testssl.sh/testssl.sh -S -h -e -E -s -f -p -g -U "${d}"

# Ask user to acknowledge that the command has completed
echo ""
echo ""
read -n 1 -s -r -p "Press any key to continue"
echo ""
echo ""

# Return to somewhere other than the domain directory
cd /root
