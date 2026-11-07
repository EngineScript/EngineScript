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

# One certificate's expiry date and the days left
show_certificate() {
  local label="$1" cert="$2" end
  if ! end="$(openssl x509 -enddate -noout -in "${cert}" 2> /dev/null)"; then
    printf '  %-44s no certificate at %s\n' "${label}" "${cert}"
    return
  fi
  end="${end#notAfter=}"
  printf '  %-44s expires %s (%s days)\n' "${label}" "$(date -d "${end}" '+%Y-%m-%d')" \
    "$(( ($(date -d "${end}" +%s) - $(date +%s)) / 86400 ))"
}

# The certificate of every site, and the Cloudflare certificate that origin pulls are checked with
show_certificates() {
  local SITES=() site
  if [[ -f /home/EngineScript/sites-list/sites.sh ]]; then
    # shellcheck source=/dev/null
    source /home/EngineScript/sites-list/sites.sh
  fi
  echo ""
  echo "Site certificates (acme.sh renews them on its own before they expire):"
  [[ "${#SITES[@]}" -eq 0 ]] && echo "  No sites yet."
  for site in "${SITES[@]}"; do
    show_certificate "${site}" "/etc/nginx/ssl/${site}/fullchain.pem"
  done
  echo ""
  show_certificate "Cloudflare origin pull CA" /etc/nginx/ssl/cloudflare/origin-pull-ca.pem
}

# Get a new certificate for one site now, even if the current one is far from expiring.
# --renew reuses what acme.sh saved when the site was created: the domains (site, admin., and *.),
# the CA, the Cloudflare DNS check, the key type, the install paths, and the Nginx reload.
reissue_certificate() {
  local site="$1" end
  if [[ ! -f "/root/.acme.sh/${site}_ecc/${site}.conf" ]]; then
    echo "acme.sh has no certificate for ${site} (/root/.acme.sh/${site}_ecc/), so there is nothing to re-issue."
    return 1
  fi
  echo "Requesting a new certificate for ${site} (this takes a minute or two)..."
  if ! /root/.acme.sh/acme.sh --renew -d "${site}" --ecc --force; then
    echo ""
    echo "The certificate was not re-issued; the current one stays in place. See /root/.acme.sh/acme.sh.log"
    return 1
  fi
  secure_nginx_ssl_directory "/etc/nginx/ssl/${site}"
  end="$(openssl x509 -enddate -noout -in "/etc/nginx/ssl/${site}/fullchain.pem" 2> /dev/null)"
  echo ""
  echo "Done! The certificate for ${site} now expires $(date -d "${end#notAfter=}" '+%Y-%m-%d' 2> /dev/null)."
}

# Create a staging copy of one site at staging.<domain>, or refresh or delete the one it has
manage_staging_copy() {
  local site="$1" choice script=/usr/local/bin/enginescript/scripts/functions/vhost/vhost-staging.sh
  echo ""
  if [[ ! -f "/home/EngineScript/staging-credentials/staging.${site}.txt" && ! -d "/var/www/sites/staging.${site}" ]]; then
    echo "This copies ${site}'s files and database to https://staging.${site}. The copy asks for the"
    echo "admin control panel's username and password, sends no email, is hidden from search engines,"
    echo "and is skipped by backups and cron jobs."
    if prompt_yes_no "Create the staging copy?" "n"; then
      bash "${script}" create "${site}"
    fi
    return
  fi
  echo "${site} has a staging copy at https://staging.${site}."
  local PS3="What would you like to do? "
  select choice in "Refresh it from the live site" "Delete it" "Cancel"; do
    case "${choice}" in
      "Refresh it from the live site")
        echo "Refreshing replaces the staging copy's files and database: changes made there are lost."
        if prompt_yes_no "Refresh staging.${site}?" "n"; then
          bash "${script}" refresh "${site}"
        fi
        return
        ;;
      "Delete it")
        if prompt_yes_no "Delete staging.${site}, with its files and database?" "n"; then
          bash "${script}" delete "${site}"
        fi
        return
        ;;
      "Cancel")
        return
        ;;
      *) echo "Invalid option.";;
    esac
  done
}

# Main Menu
while true
  do
    clear
    echo -e "Domain Configuration Tools" | boxes -a c -d shell -p a1l2
    echo ""
    echo ""
    PS3='Please enter your choice: '
    secoptions=(
      "Create New Domain"
      "Import Domain"
      "Export Domain"
      "List Domains"
      "Re-issue a Domain's Certificate"
      "SSL Capabilities Test (Single Domain)"
      "SSL Certificate Expiry"
      "Staging Copy of a Domain (Create, Refresh, Delete)"
      "Remove Domain (DANGER)"
      "Exit Domain Configuration Tools"
    )
    select secopt in "${secoptions[@]}"
    do
      case $secopt in
        "Create New Domain")
          /usr/local/bin/enginescript/scripts/functions/vhost/vhost-install.sh
          break
          ;;
        "Import Domain")
          /usr/local/bin/enginescript/scripts/functions/vhost/vhost-import.sh
          break
          ;;
        "Export Domain")
          /usr/local/bin/enginescript/scripts/functions/vhost/vhost-export.sh
          break
          ;;
        "List Domains")
          /usr/local/bin/enginescript/scripts/functions/alias/alias-sites.sh
          pause
          break
          ;;
        "SSL Capabilities Test (Single Domain)")
          /usr/local/bin/enginescript/scripts/functions/server-tools/testssl.sh
          pause
          break
          ;;
        "SSL Certificate Expiry")
          show_certificates
          pause
          break
          ;;
        "Re-issue a Domain's Certificate")
          if select_site; then
            reissue_certificate "${SELECTED_SITE}"
          fi
          pause
          break
          ;;
        "Staging Copy of a Domain (Create, Refresh, Delete)")
          if select_site; then
            manage_staging_copy "${SELECTED_SITE}"
          fi
          pause
          break
          ;;
        "Remove Domain (DANGER)")
          /usr/local/bin/enginescript/scripts/functions/vhost/vhost-remove.sh
          break
          ;;
        "Exit Domain Configuration Tools")
          exit 0
          ;;
        *) echo "Invalid option.";;
      esac
    done
  done
