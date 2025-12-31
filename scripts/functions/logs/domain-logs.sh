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
printf "Please select the site you want to view logs for:\n"
select d in *; do test -n "$d" && break; echo ">>> Invalid Selection"; done

# Domain Nginx error log
echo "${BOLD}Showing last 20 lines of Nginx error log for ${d}.${NORMAL}" | boxes -a c -d shell -p a1l2
if [[ -f "/var/log/domains/${d}/${d}-nginx-error.log" ]]; then
  tail -n20 "/var/log/domains/${d}/${d}-nginx-error.log"
else
  echo "Log file not found: /var/log/domains/${d}/${d}-nginx-error.log"
fi

# WordPress error log
echo "${BOLD}Showing last 20 lines of WordPress error log for ${d}.${NORMAL}" | boxes -a c -d shell -p a1l2
if [[ -f "/var/log/domains/${d}/${d}-wp-error.log" ]]; then
  tail -n20 "/var/log/domains/${d}/${d}-wp-error.log"
else
  echo "Log file not found: /var/log/domains/${d}/${d}-wp-error.log"
fi

# Admin Control Panel access log (for security auditing)
echo "${BOLD}Showing last 20 lines of Admin Control Panel access log for ${d}.${NORMAL}" | boxes -a c -d shell -p a1l2
if [[ -f "/var/log/domains/admin.${d}-nginx-access.log" ]]; then
  tail -n20 "/var/log/domains/admin.${d}-nginx-access.log"
else
  echo "Log file not found: /var/log/domains/admin.${d}-nginx-access.log"
fi

# Admin Control Panel error log
echo "${BOLD}Showing last 20 lines of Admin Control Panel error log for ${d}.${NORMAL}" | boxes -a c -d shell -p a1l2
if [[ -f "/var/log/domains/admin.${d}-nginx-error.log" ]]; then
  tail -n20 "/var/log/domains/admin.${d}-nginx-error.log"
else
  echo "Log file not found: /var/log/domains/admin.${d}-nginx-error.log"
fi

# Ask user to acknowledge before continuing
echo ""
echo ""
read -n 1 -s -r -p "Press any key to continue"
echo ""
echo ""
