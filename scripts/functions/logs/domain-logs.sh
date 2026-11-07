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

printf "Please select the site you want to view logs for:\n"
select_site || exit 0

# Domain Nginx error log
echo "${BOLD}Showing last 20 lines of Nginx error log for ${SELECTED_SITE}.${NORMAL}" | boxes -a c -d shell -p a1l2
if [[ -f "/var/log/domains/${SELECTED_SITE}/${SELECTED_SITE}-nginx-error.log" ]]; then
  tail -n20 "/var/log/domains/${SELECTED_SITE}/${SELECTED_SITE}-nginx-error.log"
else
  echo "Log file not found: /var/log/domains/${SELECTED_SITE}/${SELECTED_SITE}-nginx-error.log"
fi

# WordPress error log
echo "${BOLD}Showing last 20 lines of WordPress error log for ${SELECTED_SITE}.${NORMAL}" | boxes -a c -d shell -p a1l2
if [[ -f "/var/log/domains/${SELECTED_SITE}/${SELECTED_SITE}-wp-error.log" ]]; then
  tail -n20 "/var/log/domains/${SELECTED_SITE}/${SELECTED_SITE}-wp-error.log"
else
  echo "Log file not found: /var/log/domains/${SELECTED_SITE}/${SELECTED_SITE}-wp-error.log"
fi

# Admin Control Panel access log (for security auditing)
echo "${BOLD}Showing last 20 lines of Admin Control Panel access log for ${SELECTED_SITE}.${NORMAL}" | boxes -a c -d shell -p a1l2
if [[ -f "/var/log/domains/admin.${SELECTED_SITE}-nginx-access.log" ]]; then
  tail -n20 "/var/log/domains/admin.${SELECTED_SITE}-nginx-access.log"
else
  echo "Log file not found: /var/log/domains/admin.${SELECTED_SITE}-nginx-access.log"
fi

# Admin Control Panel error log
echo "${BOLD}Showing last 20 lines of Admin Control Panel error log for ${SELECTED_SITE}.${NORMAL}" | boxes -a c -d shell -p a1l2
if [[ -f "/var/log/domains/admin.${SELECTED_SITE}-nginx-error.log" ]]; then
  tail -n20 "/var/log/domains/admin.${SELECTED_SITE}-nginx-error.log"
else
  echo "Log file not found: /var/log/domains/admin.${SELECTED_SITE}-nginx-error.log"
fi

# Ask user to acknowledge before continuing
pause
