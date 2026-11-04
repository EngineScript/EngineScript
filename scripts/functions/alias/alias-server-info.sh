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
source /home/EngineScript/enginescript-install-options.txt || { echo "Error: Failed to source /home/EngineScript/enginescript-install-options.txt" >&2; exit 1; }

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

echo -e "${BOLD}\n\n--------------------\nConfiguration Review\n--------------------${NORMAL}"

echo -e "\n=-=-=-=-=-=-=-=-=-=-=-=-=-=-\nEnginescript Install Options\n=-=-=-=-=-=-=-=-=-=-=-=-=-=-\n"
print_install_settings
echo "ADMIN_CONTROL_PANEL_USERNAME = ${ADMIN_CONTROL_PANEL_USERNAME}"
echo -e "\n\n=-=-=-=-=-=-=-=-=-\nServer Info\n=-=-=-=-=-=-=-=-=-\n"
echo "Script Run Date = $DT"
echo "CPU Count = $CPU_COUNT"
echo "32bit or 64bit = $BIT_TYPE"
echo "Server Memory = $SERVER_MEMORY_TOTAL_100"
echo "IP Address = $IP_ADDRESS"
echo "Linux Version = $UBUNTU_TYPE $UBUNTU_VERSION $UBUNTU_CODENAME"

echo -e "\n\n=-=-=-=-=-=-=-=-=-\nNginx Info\n=-=-=-=-=-=-=-=-=-\n"
nginx -V
echo ""
echo "Nginx Executable Properties:"
checksec --format=json --file=/usr/sbin/nginx --extended | jq -r

echo -e "\n\n=-=-=-=-=-=-=-=-=-\nPHP Info\n=-=-=-=-=-=-=-=-=-\n"
php -version
echo ""
php -m

echo -e "${BOLD}\n\n--------------------\nMariaDB Version\n--------------------${NORMAL}"
mariadb -V

echo -e "${BOLD}\n\n--------------------\nRedis Version\n--------------------${NORMAL}"
redis-server --version

echo ""
