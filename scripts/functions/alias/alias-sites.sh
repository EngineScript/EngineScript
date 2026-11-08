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

# Terminal colors for better readability
if command -v tput > /dev/null; then
    BOLD=$(tput bold)
    NORMAL=$(tput sgr0)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    RED=$(tput setaf 1)
    BLUE=$(tput setaf 4)
else
    # Fallback if tput is not available
    BOLD=""
    NORMAL=""
    GREEN=""
    YELLOW=""
    RED=""
    BLUE=""
fi

# Header
echo -e "\n${BOLD}WordPress Sites on this Server${NORMAL}"
echo -e "================================\n"

# The server's sites
sites_config_file="${ES_SITES_LIST:-/home/EngineScript/sites-list/sites.sh}"
es_sites

if [[ ${#SITES[@]} -eq 0 ]]; then
    echo "${YELLOW}No WordPress sites configured on this server.${NORMAL}"
    echo "Sites are managed through: $sites_config_file"
    echo ""
    echo "To install a new WordPress site, run: ${BOLD}es.menu${NORMAL}"
    exit 0
fi

site_count=${#SITES[@]}

# Display sites in a formatted table
echo "${BOLD}| # | Domain | Document Root | Status |${NORMAL}"
echo "|---|--------|---------------|--------|"

counter=1
for domain in "${SITES[@]}"; do
    # Construct expected site path
    site_path="/var/www/sites/$domain/html"
    
    # Validate that the site directory exists
    if [[ ! -d "$site_path" ]]; then
        status="${RED}✗ Missing${NORMAL}"
    else
        # Check if site is accessible
        if curl -sL --proto '=https' -w "%{http_code}" "https://$domain" -o /dev/null 2>/dev/null | grep -q "200"; then
            status="${GREEN}✓ Online${NORMAL}"
        elif curl -sL -w "%{http_code}" "http://$domain" -o /dev/null 2>/dev/null | grep -q "200"; then
            status="${YELLOW}⚠ HTTP Only${NORMAL}"
        else
            status="${RED}✗ Offline${NORMAL}"
        fi
    fi
    
    # Display site information
    printf "| %2d | %-20s | %-25s | %s |\n" "$counter" "$domain" "$site_path" "$status"
    ((counter++))
done

echo ""

# Summary
if [[ $site_count -eq 1 ]]; then
    echo "${BOLD}Found 1 WordPress site configured on this server.${NORMAL}"
else
    echo "${BOLD}Found $site_count WordPress sites configured on this server.${NORMAL}"
fi

# Additional information
echo ""
echo "${BLUE}Additional Commands:${NORMAL}"
echo "  ${BOLD}es.menu${NORMAL}        - Access EngineScript management menu"
echo "  ${BOLD}es.debug${NORMAL}       - View detailed site status and server information"
echo "  ${BOLD}es.info${NORMAL}        - Display server information"
echo "  ${BOLD}es.help${NORMAL}        - Show all available commands"
echo ""

# Show sites configuration information
echo "${GREEN}✓${NORMAL} Sites are configured for automated tasks (backups, maintenance, etc.)"
echo "  Configuration file: ${BOLD}$sites_config_file${NORMAL}"

echo ""
