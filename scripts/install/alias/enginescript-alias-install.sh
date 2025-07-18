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

cat <<EOT >> /root/.bashrc
alias enginescript="/usr/local/bin/enginescript/scripts/menu/enginescript-menu.sh"
alias es.backup="/usr/local/bin/enginescript/scripts/functions/alias/alias-backup.sh"
alias es.cache="/usr/local/bin/enginescript/scripts/functions/alias/alias-cache.sh"
alias es.config="nano /home/EngineScript/enginescript-install-options.txt"
alias es.debug="/usr/local/bin/enginescript/scripts/functions/alias/alias-debug.sh"
alias es.help="/usr/local/bin/enginescript/scripts/functions/alias/alias-help.sh"
alias es.images="/usr/local/bin/enginescript/scripts/functions/cron/optimize-images.sh"
alias es.info="/usr/local/bin/enginescript/scripts/functions/alias/alias-server-info.sh"
alias es.install="/usr/local/bin/enginescript/scripts/install/enginescript-install.sh"
alias es.menu="/usr/local/bin/enginescript/scripts/menu/enginescript-menu.sh"
alias es.permissions="/usr/local/bin/enginescript/scripts/functions/cron/permissions.sh"
alias es.restart="/usr/local/bin/enginescript/scripts/functions/alias/alias-restart.sh"
alias es.sites="/usr/local/bin/enginescript/scripts/functions/alias/alias-sites.sh"
alias es.update="/usr/local/bin/enginescript/scripts/update/enginescript-update.sh"
alias es.variables="nano /usr/local/bin/enginescript/enginescript-variables.txt"
alias ng.reload="ng.test && systemctl reload nginx"
alias ng.stop="ng.test && systemctl stop nginx"
alias ng.test="nginx -t -c /etc/nginx/nginx.conf"
EOT
