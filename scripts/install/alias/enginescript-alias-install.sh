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

cat <<'EOT' >> /root/.bashrc
alias enginescript="/usr/local/bin/enginescript/scripts/menu/enginescript-menu.sh"
alias es.backup="/usr/local/bin/enginescript/scripts/functions/alias/alias-backup.sh"
alias es.cache="/usr/local/bin/enginescript/scripts/functions/alias/alias-cache.sh"
alias es.config="nano /home/EngineScript/enginescript-install-options.txt"
alias es.images="/usr/local/bin/enginescript/scripts/functions/cron/optimize-images.sh"
alias es.info="/usr/local/bin/enginescript/scripts/functions/alias/alias-server-info.sh"
alias es.install="/usr/local/bin/enginescript/scripts/install/enginescript-install.sh"
alias es.menu="/usr/local/bin/enginescript/scripts/menu/enginescript-menu.sh"
alias es.mysql="/usr/local/bin/enginescript/scripts/functions/alias/alias-mysql-pass.sh"
alias es.permissions="/usr/local/bin/enginescript/scripts/functions/cron/permissions.sh"
alias es.restart="/usr/local/bin/enginescript/scripts/functions/alias/alias-restart.sh"
alias es.update="/usr/local/bin/enginescript/scripts/update/enginescript-update.sh"
alias es.variables="nano /usr/local/bin/enginescript/enginescript-variables.txt"
alias ng.reload="ng.test && systemctl reload nginx"
alias ng.stop="ng.test && systemctl stop nginx"
alias ng.test="nginx -t -c /etc/nginx/nginx.conf"
alias es.help='printf "${BOLD}Available EngineScript Commands:${NORMAL}\n\
--------------------------------\n\
es.backup       - Runs the backup script to backup all domains locally and optionally in the cloud\n\
es.cache        - Clear FastCGI Cache, OpCache, and Redis (server-wide)\n\
es.config       - Opens the configuration file in Nano\n\
es.help         - Displays EngineScript commands and locations\n\
es.images       - Losslessly compress all images in the WordPress /uploads directory (server-wide)\n\
es.info         - Displays server information\n\
es.install      - Runs the main EngineScript installation script\n\
es.menu         - EngineScript menu\n\
es.permissions  - Resets the permissions of all files in the WordPress directory (server-wide)\n\
es.restart      - Restart Nginx and PHP\n\
es.server       - Displays server information\n\
es.update       - Update EngineScript\n\
es.variables    - Opens the variable file in Nano. This file resets when EngineScript is updated\n\n\
${BOLD}EngineScript Locations:${NORMAL}\n\
-----------------------\n\
/etc/mysql                  - MySQL (MariaDB) config\n\
/etc/nginx                  - Nginx config\n\
/etc/php                    - PHP config\n\
/etc/redis                  - Redis config\n\
/home/EngineScript          - EngineScript user directories\n\
/usr/local/bin/enginescript - EngineScript source\n\
/var/lib/mysql              - MySQL database\n\
/var/log                    - Server logs\n\
/var/www/admin/enginescript - Tools accessible via server IP address or admin.YOURDOMAIN subdomain\n\
/var/www/sites/*YOURDOMAIN*/html - Root directory for your WordPress installation\n'
EOT
