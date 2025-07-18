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


# Define BOLD and NORMAL terminal codes using tput if available
if command -v tput > /dev/null; then
    BOLD=$(tput bold)
    NORMAL=$(tput sgr0)
else
    # Fallback if tput is not available
    BOLD=""
    NORMAL=""
fi

# Use printf to display the information.
# Double quotes allow variable expansion (${BOLD}, ${NORMAL}).
# Newlines within the double-quoted string are preserved by printf.
printf "${BOLD}EngineScript Commands:${NORMAL}
--------------------------------
es.backup       - Runs the backup script to backup all domains locally and optionally in the cloud
es.cache        - Clear FastCGI Cache, OpCache, and Redis (server-wide)
es.config       - Opens the configuration file in Nano
es.debug        - Displays debug information for EngineScript
es.help         - Displays EngineScript commands and locations
es.images       - Losslessly compress all images in the WordPress /uploads directory (server-wide)
es.info         - Displays server information
es.install      - Runs the main EngineScript installation script
es.menu         - EngineScript menu
es.permissions  - Resets the permissions of all files in the WordPress directory (server-wide)
es.restart      - Restart Nginx and PHP
es.sites        - Lists all WordPress sites installed on the server
es.update       - Update EngineScript
es.variables    - Opens the variable file in Nano. This file resets when EngineScript is updated

${BOLD}EngineScript Locations:${NORMAL}
-----------------------
/etc/mysql                  - MySQL (MariaDB) config
/etc/nginx                  - Nginx config
/etc/php                    - PHP config
/etc/redis                  - Redis config
/home/EngineScript          - EngineScript user directories
/usr/local/bin/enginescript - EngineScript source
/var/lib/mysql              - MySQL database
/var/log                    - Server logs
/var/www/admin/enginescript - Tools accessible via server IP address or admin.YOURDOMAIN subdomain
/var/www/sites/YOURDOMAIN/html - Root directory for your WordPress installation
"
