#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

set -euo pipefail

#----------------------------------------------------------------------------------
# Start Main Script

install_exec_command() {
  local command_name="$1"
  local command_path="/usr/local/bin/${command_name}"
  shift

  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf 'exec'
    printf ' %q' "$@"
    printf ' "$@"\n'
  } > "${command_path}"

  chmod 755 "${command_path}"
  chown root:root "${command_path}"
}

install_shell_command() {
  local command_name="$1"
  local command_body="$2"
  local command_path="/usr/local/bin/${command_name}"

  {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' "${command_body}"
  } > "${command_path}"

  chmod 755 "${command_path}"
  chown root:root "${command_path}"
}

install_exec_command "es.backup" "/usr/local/bin/enginescript/scripts/functions/alias/alias-backup.sh"
install_exec_command "es.cache" "/usr/local/bin/enginescript/scripts/functions/alias/alias-cache.sh"
install_exec_command "es.config" "nano" "/home/EngineScript/enginescript-install-options.txt"
install_exec_command "es.debug" "/usr/local/bin/enginescript/scripts/functions/alias/alias-debug.sh"
install_exec_command "es.help" "/usr/local/bin/enginescript/scripts/functions/alias/alias-help.sh"
install_exec_command "es.images" "/usr/local/bin/enginescript/scripts/functions/cron/optimize-images.sh"
install_exec_command "es.info" "/usr/local/bin/enginescript/scripts/functions/alias/alias-server-info.sh"
install_exec_command "es.install" "/usr/local/bin/enginescript/scripts/install/enginescript-install.sh"
install_exec_command "es.menu" "/usr/local/bin/enginescript/scripts/menu/enginescript-menu.sh"
install_exec_command "es.permissions" "/usr/local/bin/enginescript/scripts/functions/cron/permissions.sh"
install_exec_command "es.restart" "/usr/local/bin/enginescript/scripts/functions/alias/alias-restart.sh"
install_exec_command "es.sites" "/usr/local/bin/enginescript/scripts/functions/alias/alias-sites.sh"
install_exec_command "es.update" "/usr/local/bin/enginescript/scripts/update/enginescript-update.sh"
install_exec_command "es.variables" "nano" "/usr/local/bin/enginescript/enginescript-variables.txt"

install_shell_command "ng.test" 'exec nginx -t -c /etc/nginx/nginx.conf "$@"'
install_shell_command "ng.reload" 'set -e
nginx -t -c /etc/nginx/nginx.conf
exec systemctl reload nginx "$@"'
install_shell_command "ng.stop" 'set -e
nginx -t -c /etc/nginx/nginx.conf
exec systemctl stop nginx "$@"'

touch /root/.bashrc
tmp_bashrc="$(mktemp)"
trap 'rm -f "${tmp_bashrc}"' EXIT
sed \
  -e '/^# EngineScript command aliases$/,/^# End EngineScript command aliases$/d' \
  -e '/^alias enginescript=/d' \
  -e '/^alias es\.backup=/d' \
  -e '/^alias es\.cache=/d' \
  -e '/^alias es\.config=/d' \
  -e '/^alias es\.debug=/d' \
  -e '/^alias es\.help=/d' \
  -e '/^alias es\.images=/d' \
  -e '/^alias es\.info=/d' \
  -e '/^alias es\.install=/d' \
  -e '/^alias es\.menu=/d' \
  -e '/^alias es\.permissions=/d' \
  -e '/^alias es\.restart=/d' \
  -e '/^alias es\.sites=/d' \
  -e '/^alias es\.update=/d' \
  -e '/^alias es\.variables=/d' \
  -e '/^alias ng\.reload=/d' \
  -e '/^alias ng\.stop=/d' \
  -e '/^alias ng\.test=/d' \
  /root/.bashrc > "${tmp_bashrc}"
cat "${tmp_bashrc}" > /root/.bashrc
rm -f "${tmp_bashrc}"
trap - EXIT

cat <<EOT >> /root/.bashrc
# EngineScript command aliases
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
# End EngineScript command aliases
EOT
