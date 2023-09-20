#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 22.04 (jammy)
#----------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit
fi

#----------------------------------------------------------------------------
# Start Main Script

cat <<EOT >> /root/.bashrc
alias enginescript="/usr/local/bin/enginescript/scripts/menu/enginescript-menu.sh"
alias es.backup="/usr/local/bin/enginescript/scripts/functions/alias/alias-cache.sh"
alias es.cache="/usr/local/bin/enginescript/scripts/functions/alias/alias-virus-scan.sh"
alias es.config="nano /home/EngineScript/enginescript-install-options.txt"
alias es.images="/usr/local/bin/enginescript/scripts/functions/cron/optimize-images.sh"
alias es.install="/usr/local/bin/enginescript/enginescript-install.sh"
alias es.menu="/usr/local/bin/enginescript/scripts/menu/enginescript-menu.sh"
alias es.mysql="/usr/local/bin/enginescript/scripts/functions/alias/alias-mysql-pass.sh"
alias es.permissions="/usr/local/bin/enginescript/scripts/functions/cron/permissions.sh"
alias es.restart="/usr/local/bin/enginescript/scripts/functions/alias/alias-restart.sh"
alias es.update="/usr/local/bin/enginescript/scripts/update/enginescript-update.sh"
alias es.variables="nano /usr/local/bin/enginescript/enginescript-variables.txt"
alias ng.reload="ng.test && systemctl reload nginx"
alias ng.stop="ng.test && systemctl stop nginx"
alias ng.test="nginx -t -c /etc/nginx/nginx.conf"
EOT
