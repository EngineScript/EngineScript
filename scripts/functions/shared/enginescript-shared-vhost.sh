#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------
# Shared Virtual Host Functions
# This file contains common functions used by both vhost-install.sh and vhost-import.sh
#----------------------------------------------------------------------------------
# Note: This file requires enginescript-common.sh to be sourced before it.
# The following functions are defined in enginescript-common.sh and used here:
#   - prompt_yes_no()   : Prompts the user for a yes/no answer with optional default and timeout
#   - restart_service() : Restarts a named system service via systemctl or service
#----------------------------------------------------------------------------------


# Check if required services are running (stops the script when one is not)
check_required_services() {
  echo -e "\n\n${BOLD}Running Services Check:${NORMAL}\n"

  # MariaDB, or MySQL where a server runs that instead
  if ! systemctl is-active --quiet mariadb && systemctl is-active --quiet mysql; then
    verify_service_running "mysql" "MySQL"
  else
    verify_service_running "mariadb" "MariaDB"
  fi
  verify_service_running "nginx" "Nginx"
  verify_service_running "php${PHP_VER}-fpm" "PHP ${PHP_VER}"
  verify_service_running "redis" "Redis"
}


#----------------------------------------------------------------------------------
# WP-CLI on the site being set up (WP_SITE_ROOT), as www-data. The site's own code (wp-config.php,
# plugins, and theme, which an import brings from another host) never runs as root.
# Usage: wp_site <WP-CLI arguments>
wp_site() {
  (cd "${WP_SITE_ROOT:?}" && run_as_www_data wp "$@")
}


#----------------------------------------------------------------------------------
# Print what is already on the server for a domain that is not on the site list: a site that was
# only partly set up, or taken off the list by hand. Prints nothing when there is nothing.
# Create Domain and Import Domain refuse such a domain (Remove Domain cleans it up), so that
# rolling back a failed setup can never delete anything that was there before it.
# Usage: site_leftovers <domain>
site_leftovers() {
  local domain="$1" path
  for path in "/var/www/sites/${domain}" "/etc/nginx/sites-enabled/${domain}.conf" \
      "/etc/nginx/admin/admin.${domain}.conf" "/home/EngineScript/mysql-credentials/${domain}.txt" \
      "/etc/nginx/ssl/${domain}" "/root/.acme.sh/${domain}_ecc"; do
    if [[ -e "${path}" ]]; then
      echo "${path}"
    fi
  done
}


#----------------------------------------------------------------------------------
# Roll back a failed Create Domain or Import Domain. arm_site_rollback runs just before the first
# change on this server; from then on, the script stopping with an error removes everything set
# up for the domain (remove_site), so the setup can simply run again. Backups that were there
# before are kept. disarm_site_rollback runs once the site is set up.
# The script sets: trap 'site_rollback_on_exit $?' EXIT
SITE_ROLLBACK_DOMAIN=""
SITE_ROLLBACK_KEEP_BACKUPS=0

arm_site_rollback() {
  SITE_ROLLBACK_DOMAIN="$1"
  SITE_ROLLBACK_KEEP_BACKUPS=0
  if [[ -d "/home/EngineScript/site-backups/$1" ]]; then
    SITE_ROLLBACK_KEEP_BACKUPS=1
  fi
}

disarm_site_rollback() {
  SITE_ROLLBACK_DOMAIN=""
}

site_rollback_on_exit() {
  local status="$1" domain="${SITE_ROLLBACK_DOMAIN}"
  if [[ "${status}" -eq 0 || -z "${domain}" ]]; then
    return 0
  fi
  SITE_ROLLBACK_DOMAIN=""
  echo "" >&2
  echo "${BOLD}Setting up ${domain} failed.${NORMAL} Removing what was set up for it, so it can be set up again..." >&2
  cd / || true
  REMOVE_SITE_KEEP_BACKUPS="${SITE_ROLLBACK_KEEP_BACKUPS}" remove_site "${domain}"
  echo "" >&2
  echo "${domain} was rolled back. Its Cloudflare DNS records were left as they are." >&2
  echo "Fix the error shown above, then run the setup again." >&2
}


#----------------------------------------------------------------------------------
# Remove a site and everything that belongs to it: its staging copy, its place on the site list,
# its database and user, vhosts, certificate, Redis keys, files, backups (unless
# REMOVE_SITE_KEEP_BACKUPS=1), logs, and cached pages, then reload Nginx and PHP-FPM. Each part
# that is missing is reported and skipped, so it also cleans up a site that was only partly set
# up. Used by Remove Domain, and by Create Domain and Import Domain to roll back a failed setup.
# Cloudflare's DNS records are left as they are.
# Usage: remove_site <domain>
remove_site() {
  local DOMAIN="$1" DB USR PSWD VHOST

  # Remove the site's staging copy first: it uses the site's certificate, which goes below
  if [[ -f "/etc/nginx/sites-enabled/staging.${DOMAIN}.conf" || -d "/var/www/sites/staging.${DOMAIN}" \
      || -f "/home/EngineScript/staging-credentials/staging.${DOMAIN}.txt" ]]; then
    echo "Removing the staging copy of ${DOMAIN}..."
    bash /usr/local/bin/enginescript/scripts/functions/vhost/vhost-staging.sh delete "${DOMAIN}"
  fi

  # Remove domain from site list
  if es_site_exists "${DOMAIN}"
  then
    echo -e "${BOLD}Site List Removal Check: Passed\n\n${NORMAL}Removing ${DOMAIN} from site list...\n\n"
    es_site_remove "${DOMAIN}"
  else
    echo -e "${BOLD}Site List Removal Check: Failed\n\n${NORMAL}${DOMAIN} was not found on the site list.\n\n"
  fi

  # Remove MySQL credentials
  if [[ -f "/home/EngineScript/mysql-credentials/${DOMAIN}.txt" ]]
  then
    echo -e "${BOLD}MySQL Credentials Removal Check: Passed\n\n${NORMAL}Removing MySQL credentials for ${DOMAIN}...\n\n"
    # shellcheck source=/dev/null
    source "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
    if validate_db_identifier "${DB}" "${DOMAIN}"; then
      mariadb -e "DROP DATABASE IF EXISTS \`${DB}\`;"
    fi
    if [[ "${USR}" =~ ^[A-Za-z0-9_]+$ ]]; then
      mariadb -e "DROP USER IF EXISTS '${USR}'@'localhost';"
    else
      echo "Warning: Invalid database user name '${USR}' in /home/EngineScript/mysql-credentials/${DOMAIN}.txt; the user was not dropped." >&2
    fi
    rm -f "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
  else
    echo -e "${BOLD}MySQL Credentials Check: Failed\n\n${NORMAL}${DOMAIN} did not have MySQL credentials.\n\n"
  fi

  # Remove Nginx vhosts
  for VHOST in "/etc/nginx/sites-enabled/${DOMAIN}.conf" "/etc/nginx/admin/admin.${DOMAIN}.conf"; do
    if [[ -f "${VHOST}" ]]; then
      echo -e "${BOLD}Nginx Vhost Removal Check: Passed\n\n${NORMAL}Removing ${VHOST}...\n\n"
      rm -rf "${VHOST}"
    else
      echo -e "${BOLD}Nginx Vhost Removal Check: Failed\n\n${NORMAL}${VHOST} did not exist.\n\n"
    fi
  done

  # Remove the certificate from acme.sh first: its renewal job would otherwise keep renewing it and
  # installing it into /etc/nginx/ssl/${DOMAIN}/ again
  if [[ -d "/root/.acme.sh/${DOMAIN}_ecc" ]]; then
    echo -e "${BOLD}acme.sh Certificate Removal Check: Passed\n\n${NORMAL}Removing ${DOMAIN} from acme.sh...\n\n"
    /root/.acme.sh/acme.sh --remove -d "${DOMAIN}" --ecc \
      || echo "Warning: acme.sh could not remove ${DOMAIN} from its renewal list; its folder is removed below." >&2
    rm -rf "/root/.acme.sh/${DOMAIN}_ecc"
  else
    echo -e "${BOLD}acme.sh Certificate Removal Check: Failed\n\n${NORMAL}${DOMAIN} did not have an acme.sh certificate.\n\n"
  fi

  # Remove SSL certificates
  if [[ -d "/etc/nginx/ssl/${DOMAIN}" ]];
  then
    echo -e "${BOLD}SSL Certificates Removal Check: Passed\n\n${NORMAL}Removing SSL certificates for ${DOMAIN}...\n\n"
    rm -rf "/etc/nginx/ssl/${DOMAIN}"
  else
    echo -e "${BOLD}SSL Certificates Removal Check: Failed\n\n${NORMAL}${DOMAIN} did not have SSL Certificates.\n\n"
  fi

  # Delete the site's Redis keys (read from its wp-config.php, so before the files go)
  flush_site_redis_cache "/var/www/sites/${DOMAIN}/html/wp-config.php"

  # Remove main directory
  if [[ -d "/var/www/sites/${DOMAIN}" ]];
  then
    echo -e "${BOLD}Main Directory Removal Check: Passed\n\n${NORMAL}Removing main directory for ${DOMAIN}...\n\n"
    rm -rf "/var/www/sites/${DOMAIN}"
  else
    echo -e "${BOLD}Main Directory Removal Check: Failed\n\n${NORMAL}${DOMAIN} did not have a main directory.\n\n"
  fi

  # Remove backup directory (kept when REMOVE_SITE_KEEP_BACKUPS=1)
  if [[ "${REMOVE_SITE_KEEP_BACKUPS:-0}" == "1" ]]; then
    echo "Kept the backup directory /home/EngineScript/site-backups/${DOMAIN}."
  elif [[ -d "/home/EngineScript/site-backups/${DOMAIN}" ]];
  then
    echo -e "${BOLD}Backup Directory Removal Check: Passed\n\n${NORMAL}Removing backup directory for ${DOMAIN}...\n\n"
    rm -rf "/home/EngineScript/site-backups/${DOMAIN}"
  else
    echo -e "${BOLD}Backup Directory Removal Check: Failed\n\n${NORMAL}${DOMAIN} did not have a backup directory.\n\n"
  fi

  # Remove log directory
  if [[ -d "/var/log/domains/${DOMAIN}" ]];
  then
    echo -e "${BOLD}Log Directory Removal Check: Passed\n\n${NORMAL}Removing log directory for ${DOMAIN}...\n\n"
    rm -rf "/var/log/domains/${DOMAIN}"
  else
    echo -e "${BOLD}Log Directory Removal Check: Failed\n\n${NORMAL}${DOMAIN} did not have a log directory.\n\n"
  fi
  # The admin subdomain's logs, and their rotated copies, are kept beside the log directories
  rm -f "/var/log/domains/admin.${DOMAIN}-nginx-"*.log*

  # The site's Redis database number is free again: new sites take the lowest number no other
  # site's wp-config.php uses, so nothing changes in redis.conf.

  # Delete the site's cached pages, so the domain does not serve them if it is set up again
  clear_site_nginx_cache "${DOMAIN}"

  # Reload Nginx (the site's vhost is gone) and PHP-FPM (drops the site's code from OPcache).
  # Redis keeps running; the site's keys are already deleted.
  reload_web_services
}


#----------------------------------------------------------------------------------
# Create nginx vhost configuration files
create_nginx_vhost() {
  local DOMAIN="$1"

  # Store SQL credentials
  echo "SITE_URL=\"${DOMAIN}\"" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"

  # Add Domain to Site List
  es_site_add "${DOMAIN}" || return 1
  
  # Create Nginx Vhost File
  cp -rf "/usr/local/bin/enginescript/config/etc/nginx/sites-available/your-domain.conf" "/etc/nginx/sites-enabled/${DOMAIN}.conf"
  sed -i "s|YOURDOMAIN|${DOMAIN}|g" "/etc/nginx/sites-enabled/${DOMAIN}.conf"

  # Create Admin Subdomain Vhost File
  cp -rf "/usr/local/bin/enginescript/config/etc/nginx/admin/admin.your-domain.conf" "/etc/nginx/admin/admin.${DOMAIN}.conf"
  sed -i "s|YOURDOMAIN|${DOMAIN}|g" "/etc/nginx/admin/admin.${DOMAIN}.conf"

  # Verify control panel is deployed before enabling admin subdomain
  if [[ ! -f "/var/www/admin/control-panel/index.html" ]]; then
    echo "WARNING: Admin control panel files not found. Re-deploying..."
    /usr/local/bin/enginescript/scripts/install/tools/frontend/admin-control-panel-install.sh
  fi

  # Enable Admin Subdomain Vhost File
  if [[ "${ADMIN_SUBDOMAIN}" == "1" ]];
    then
      sed -i "s|#include /etc/nginx/admin/admin.your-domain.conf;|include /etc/nginx/admin/admin.${DOMAIN}.conf;|g" "/etc/nginx/sites-enabled/${DOMAIN}.conf"
    else
      echo ""
  fi

  # Bring all vhost files up to date with template changes, then keep
  # template-derived HTTP/3 listeners aligned with the current setting.
  migrate_nginx_vhosts
  sync_nginx_http3_config
}


#----------------------------------------------------------------------------------
# Create and install SSL certificates
create_ssl_certificate() {
  local DOMAIN="$1"
  
  # Create Origin Certificate
  SSL_KEYLENGTH="ec-256"
  if [[ "${HIGH_SECURITY_SSL}" == "1" ]]; then
    SSL_KEYLENGTH="ec-384"
  fi

  mkdir -p "/etc/nginx/ssl/${DOMAIN}" || return 1

  # Issue SSL Certificate
  if ! /root/.acme.sh/acme.sh --issue --force --dns dns_cf --server zerossl -d "${DOMAIN}" -d "admin.${DOMAIN}" -d "*.${DOMAIN}" -k "${SSL_KEYLENGTH}"; then
    echo "Error: acme.sh could not issue a certificate for ${DOMAIN} (see its output above)." >&2
    return 1
  fi

  # Install SSL Certificate
  # acme.sh saves --reloadcmd and runs it after every renewal, so Nginx loads the new certificate
  if ! /root/.acme.sh/acme.sh --install-cert -d "${DOMAIN}" --ecc \
      --cert-file "/etc/nginx/ssl/${DOMAIN}/cert.pem" \
      --key-file "/etc/nginx/ssl/${DOMAIN}/key.pem" \
      --fullchain-file "/etc/nginx/ssl/${DOMAIN}/fullchain.pem" \
      --ca-file "/etc/nginx/ssl/${DOMAIN}/ca.pem" \
      --reloadcmd "systemctl reload nginx"; then
    echo "Error: acme.sh could not install the certificate for ${DOMAIN} in /etc/nginx/ssl/${DOMAIN}." >&2
    return 1
  fi

  # The private key is readable by root only (renewals keep these modes)
  secure_nginx_ssl_directory "/etc/nginx/ssl/${DOMAIN}"
}


#----------------------------------------------------------------------------------
# Create backup directories for a site
create_backup_directories() {
  local SITE_URL="$1"
  
  # Create backup directories
  # Layout written by enginescript-backup.sh
  mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/database/daily"
  mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/database/hourly"
  mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/files"
}


#----------------------------------------------------------------------------------
# Create domain log directories and files
create_domain_logs() {
  local SITE_URL="$1"
  
  # Domain Logs (stored in subdirectory)
  mkdir -p "/var/log/domains/${SITE_URL}"
  touch "/var/log/domains/${SITE_URL}/${SITE_URL}-wp-error.log"
  touch "/var/log/domains/${SITE_URL}/${SITE_URL}-nginx-helper.log"
  touch "/var/log/domains/${SITE_URL}/${SITE_URL}-nginx-error.log"

  # Admin Subdomain Logs (stored in root of /var/log/domains/)
  # These are for the admin.DOMAIN control panel access auditing
  touch "/var/log/domains/admin.${SITE_URL}-nginx-access.log"
  touch "/var/log/domains/admin.${SITE_URL}-nginx-error.log"

  # Root-owned directories, log files owned by www-data (see set_nginx_permissions)
  chown root:root "/var/log/domains" "/var/log/domains/${SITE_URL}"
  chmod 755 "/var/log/domains" "/var/log/domains/${SITE_URL}"
  chown www-data:adm "/var/log/domains/${SITE_URL}/"*.log "/var/log/domains/admin.${SITE_URL}-nginx-"*.log
  chmod 640 "/var/log/domains/${SITE_URL}/"*.log "/var/log/domains/admin.${SITE_URL}-nginx-"*.log
}


#----------------------------------------------------------------------------------
# Configure Cloudflare settings for domain
configure_cloudflare_settings() {
  local DOMAIN="$1"
  
  echo ""
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo "${BOLD}IMPORTANT: Cloudflare Configuration${NORMAL}"
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo ""
  echo "This script will make the following changes to your Cloudflare account:"
  echo ""
  echo "1. Add or update the A record for ${DOMAIN} to point to this server's IP"
  echo "2. Add or update the CNAME record for admin.${DOMAIN} and www.${DOMAIN} to point to ${DOMAIN}"
  echo "3. Configure optimal performance settings in Cloudflare"
  echo "   - SSL/TLS settings"
  echo "   - Speed optimizations"
  echo "   - Caching configurations"
  echo "   - Network settings"
  echo ""
  echo "These changes are recommended for optimal EngineScript performance."
  echo ""

  # Use enhanced validation for Cloudflare configuration
  if prompt_yes_no "Would you like to proceed with Cloudflare configuration?" "n" 300; then
      echo ""
      echo "Proceeding with Cloudflare configuration..."
      echo ""
      CF_CHOICE="y"
  else
      echo ""
      echo "Skipping Cloudflare configuration."
      echo ""
      echo "${BOLD}Before this site can answer:${NORMAL} turn on Authenticated Origin Pulls for ${DOMAIN} in"
      echo "Cloudflare (SSL/TLS > Origin Server) and keep its DNS records proxied. This server only"
      echo "accepts connections from Cloudflare, so every other request gets a 400 error."
      echo ""
      CF_CHOICE="n"
  fi

  # Only continue with Cloudflare configuration if the user chose to proceed
  if [[ "$CF_CHOICE" == "y" ]]; then
    # Cloudflare Keys
    export CF_Key="${CF_GLOBAL_API_KEY}"
    export CF_Email="${CF_ACCOUNT_EMAIL}"

    # Each change prints one line (cf_apply in enginescript-cloudflare.sh); failures are counted
    # in CF_FAILED
    CF_FAILED=0
    CF_AOP_ON=0

    ZONE_ID="$(cf_zone_id "${DOMAIN}")"

    # Check if domain exists in Cloudflare
    if [[ -z "$ZONE_ID" ]]; then
      echo ""
      echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
      echo "${BOLD}ERROR: Domain not found in Cloudflare${NORMAL}"
      echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
      echo ""
      echo "The domain '$DOMAIN' was not found in your Cloudflare account."
      echo "Please add the domain to Cloudflare first, and ensure that:"
      echo ""
      echo "1. DNS records have propagated"
      echo "2. The domain is active in your Cloudflare account"
      echo "3. The API key and email are correct"
      echo ""
      echo "Exiting installation process."
      echo ""
      exit 1
    else
      echo "Cloudflare Zone ID for $DOMAIN: $ZONE_ID"

      ## DNS Settings
      
      # Get server's current public IP address with validation
      echo "Detecting server public IP address..."
      SERVER_IP=$(curl -s --max-time 5 https://ipinfo.io/ip)
      
      # Validate IP format (ensure each octet is within 0-255)
      if ! [[ "$SERVER_IP" =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; then
        echo "WARNING: Invalid IP from ipinfo.io (${SERVER_IP}), trying backup source..."
        SERVER_IP=$(curl -s --max-time 5 https://icanhazip.com)
        
        # Validate backup IP (ensure each octet is within 0-255)
        if ! [[ "$SERVER_IP" =~ ^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$ ]]; then
          echo "ERROR: Could not obtain valid IP address from any source."
          echo "Received response: ${SERVER_IP}"
          echo ""
          echo "Troubleshooting suggestions:"
          echo "  1) Verify this server has internet connectivity:"
          echo "     - ping -c 3 8.8.8.8"
          echo "     - curl -I https://www.google.com"
          echo "  2) Ensure outbound HTTPS (TCP port 443) is allowed in any firewall/security group."
          echo "  3) Check DNS resolution for the IP services:"
          echo "     - dig +short ipinfo.io"
          echo "     - dig +short icanhazip.com"
          echo "  4) If using a proxy or restrictive network, allow access to ipinfo.io and icanhazip.com."
          echo "  5) After fixing connectivity, re-run this installation script."
          exit 1
        fi
      fi
      
      # Validate IP octets are within valid range (0-255)
      IFS='.' read -ra OCTETS <<< "$SERVER_IP"
      for octet in "${OCTETS[@]}"; do
        if [[ $octet -gt 255 ]]; then
          echo "ERROR: Invalid IP address octet: $octet in $SERVER_IP"
          exit 1
        fi
      done
      
      echo "✓ Server IP detected: ${SERVER_IP}"
      
      echo ""
      echo "Cloudflare DNS records for ${DOMAIN}:"
      A_RECORD="{\"type\": \"A\", \"name\": \"${DOMAIN}\", \"content\": \"${SERVER_IP}\", \"ttl\": 1, \"proxied\": true}"
      if ! cf_find_dns_record "${ZONE_ID}" "${DOMAIN}" "A"; then
        echo "  ✗ A record ${DOMAIN}: no answer from Cloudflare"
        CF_FAILED=$((CF_FAILED + 1))
      elif [[ -z "${CF_RECORD_ID}" ]]; then
        cf_apply "${ZONE_ID}" "A record ${DOMAIN}: ${SERVER_IP} (proxied), added" POST "/dns_records" "${A_RECORD}"
      elif [[ "${CF_RECORD_CONTENT}" != "${SERVER_IP}" ]]; then
        cf_apply "${ZONE_ID}" "A record ${DOMAIN}: ${SERVER_IP} (proxied), was ${CF_RECORD_CONTENT}" PUT "/dns_records/${CF_RECORD_ID}" "${A_RECORD}"
      else
        echo "  ✓ A record ${DOMAIN}: ${SERVER_IP}, already set"
      fi

      # The admin and www CNAME records (the first record of each name, if there are several)
      ADMIN_RECORD="{\"comment\": \"Admin Control Panel\", \"content\": \"${DOMAIN}\", \"name\": \"admin\", \"proxied\": true, \"ttl\": 1, \"type\": \"CNAME\"}"
      cf_upsert_dns_record "${ZONE_ID}" "CNAME" "admin.${DOMAIN}" "CNAME admin.${DOMAIN}: ${DOMAIN} (proxied)" "${ADMIN_RECORD}"
      WWW_RECORD="{\"comment\": \"WWW Redirect\", \"content\": \"${DOMAIN}\", \"name\": \"www\", \"proxied\": true, \"ttl\": 1, \"type\": \"CNAME\"}"
      cf_upsert_dns_record "${ZONE_ID}" "CNAME" "www.${DOMAIN}" "CNAME www.${DOMAIN}: ${DOMAIN} (proxied)" "${WWW_RECORD}"

      echo ""
      echo "Cloudflare settings for ${DOMAIN}:"


      ## SSL/TLS Settings

      # SSL/TLS Tab: SSL/TLS Encryption Mode
      cf_apply "${ZONE_ID}" "SSL/TLS encryption mode: Full (strict)" PATCH "/settings/ssl" '{"value":"strict"}'

      # Edge Certificates Section: Always Use HTTPS
      cf_apply "${ZONE_ID}" "Always Use HTTPS: off" PATCH "/settings/always_use_https" '{"value":"off"}'

      # Edge Certificates Section: Minimum TLS Version
      cf_apply "${ZONE_ID}" "Minimum TLS Version: 1.2" PATCH "/settings/min_tls_version" '{"value":"1.2"}'

      # Edge Certificates Section: Opportunistic Encryption
      cf_apply "${ZONE_ID}" "Opportunistic Encryption: on" PATCH "/settings/opportunistic_encryption" '{"value":"on"}'

      # Edge Certificates Section: TLS 1.3
      cf_apply "${ZONE_ID}" "TLS 1.3: on" PATCH "/settings/tls_1_3" '{"value":"on"}'

      # Edge Certificates Section: Automatic HTTPS Rewrites
      cf_apply "${ZONE_ID}" "Automatic HTTPS Rewrites: on" PATCH "/settings/automatic_https_rewrites" '{"value":"on"}'

      # Origin Server Section: Authenticated Origin Pulls (per zone)
      cf_apply "${ZONE_ID}" "Authenticated Origin Pulls (zone): on" PUT "/origin_tls_client_auth/settings" '{"enabled": true}' && CF_AOP_ON=1
        
      # Origin Server Section: Authenticated Origin Pulls
      cf_apply "${ZONE_ID}" "Authenticated Origin Pulls (setting): on" PATCH "/settings/tls_client_auth" '{"value":"on"}' && CF_AOP_ON=1


      ## Speed Settings

      # Speed Tab: Speed Brain
      cf_apply "${ZONE_ID}" "Speed Brain: on" PATCH "/settings/speed_brain" '{"value":"on"}'

      # Speed Tab: Early Hints
      cf_apply "${ZONE_ID}" "Early Hints: on" PATCH "/settings/early_hints" '{"value":"on"}'

      # Speed Tab: HTTP/3 (with QUIC)
      cf_apply "${ZONE_ID}" "HTTP/3 (with QUIC): on" PATCH "/settings/http3" '{"value":"on"}'

      # Speed Tab: Enhanced HTTP/2 Prioritization
      cf_apply "${ZONE_ID}" "Enhanced HTTP/2 Prioritization: on" PATCH "/settings/h2_prioritization" '{"value":"on"}'

      # Speed Tab: 0-RTT Connection Resumption
      cf_apply "${ZONE_ID}" "0-RTT Connection Resumption: on" PATCH "/settings/0rtt" '{"value":"on"}'


      ## Caching Settings

      # Caching Tab: Caching Level
      cf_apply "${ZONE_ID}" "Caching Level: aggressive" PATCH "/settings/cache_level" '{"value":"aggressive"}'

      # Caching Tab: Browser Cache TTL (Respect Existing Headers)
      cf_apply "${ZONE_ID}" "Browser Cache TTL: respect existing headers" PATCH "/settings/browser_cache_ttl" '{"value":0}'

      # Caching Tab: Always Online
      cf_apply "${ZONE_ID}" "Always Online: on" PATCH "/settings/always_online" '{"value":"on"}'

      # Tiered Cache Section: Tiered Cache Topology
      cf_apply "${ZONE_ID}" "Tiered Cache: on" PATCH "/argo/tiered_caching" '{"value":"on"}'

      # Tiered Cache Section: Tiered Cache Topology (Smart Tiered Caching)
      cf_apply "${ZONE_ID}" "Smart Tiered Cache Topology: on" PATCH "/cache/tiered_cache_smart_topology_enable" '{"value":"on"}'


      ## Network Settings

      # Network Tab: IPv6 Compatibility
      cf_apply "${ZONE_ID}" "IPv6 Compatibility: on" PATCH "/settings/ipv6" '{"value":"on"}'

      # Network Tab: WebSockets
      cf_apply "${ZONE_ID}" "WebSockets: on" PATCH "/settings/websockets" '{"value":"on"}'

      # Network Tab: Pseudo IPv4
      cf_apply "${ZONE_ID}" "Pseudo IPv4: add_header" PATCH "/settings/pseudo_ipv4" '{"value":"add_header"}'

      # Network Tab: IP Geolocation
      cf_apply "${ZONE_ID}" "IP Geolocation: on" PATCH "/settings/ip_geolocation" '{"value":"on"}'

      # Network Tab: Network Error Logging
      cf_apply "${ZONE_ID}" "Network Error Logging: on" PATCH "/settings/nel" '{"value": {"enabled": true} }'

      # Network Tab: Onion Routing
      cf_apply "${ZONE_ID}" "Onion Routing: on" PATCH "/settings/opportunistic_onion" '{"value":"on"}'

      echo ""
      if [[ "${CF_FAILED}" -eq 0 ]]; then
        echo "Cloudflare: all changes applied."
      else
        echo "${BOLD}Cloudflare: ${CF_FAILED} change(s) failed${NORMAL} (marked ✗ above). The install goes on;"
        echo "apply them in the Cloudflare dashboard."
      fi
      if [[ "${CF_AOP_ON:-0}" != "1" ]]; then
        echo ""
        echo "${BOLD}WARNING: Authenticated Origin Pulls could not be turned on for ${DOMAIN}.${NORMAL}"
        echo "This server only accepts connections from Cloudflare, so the site answers every request"
        echo "with a 400 error until it is on: Cloudflare dashboard > SSL/TLS > Origin Server."
      fi
      echo ""
    fi
  fi
}


#----------------------------------------------------------------------------------
# Create extra WordPress directories
# WordPress often doesn't include these directories by default, despite them being used or checked in the Health Check plugin
create_extra_wp_dirs() {
  local SITE_URL="$1"

  # Create Fonts Directories
  mkdir -p "/var/www/sites/${SITE_URL}/html/wp-content/fonts"
  mkdir -p "/var/www/sites/${SITE_URL}/html/wp-content/uploads/fonts"

  # Create Languages Directory
  mkdir -p "/var/www/sites/${SITE_URL}/html/wp-content/languages"

  # Create Upgrade Temp Backup Directory
  mkdir -p "/var/www/sites/${SITE_URL}/html/wp-content/upgrade-temp-backup"
}


#----------------------------------------------------------------------------------
# Install and activate required WordPress plugins
install_required_wp_plugins() {
  local SITE_URL="$1"

  # Install and Activate Required WordPress Plugins
  echo "Installing essential plugins..."

  wp_site plugin install flush-opcache --activate
  wp_site plugin install mariadb-health-checks --activate
  wp_site plugin install nginx-helper --activate
  wp_site plugin install redis-cache --activate
}


#----------------------------------------------------------------------------------
# Install extra WordPress plugins
# These plugins are optional but recommended for enhanced functionality and debugging
install_extra_wp_plugins() {
  local SITE_URL="$1"
  wp_site plugin install action-scheduler
  wp_site plugin install autodescription
  wp_site plugin install performance-lab
  wp_site plugin install php-compatibility-checker
  wp_site plugin install theme-check
  wp_site plugin install wp-crontrol
  wp_site plugin install wp-mail-smtp
}


#----------------------------------------------------------------------------------
# Configure Redis for WordPress site
configure_redis() {
  local SITE_URL="$1"
  local WP_CONFIG_PATH="$2"
  
  # Give the site its own Redis database (the lowest number no other site uses)
  if ! assign_site_redis_database "${WP_CONFIG_PATH}"; then
    echo "Warning: The site uses Redis database 0, which other sites may share." >&2
  fi

  # Set Redis Prefix
  REDISPREFIX="es_$(printf '%s' "${SITE_URL}" | sha1sum | cut -c1-12)"
  sed -i "s|SEDREDISPREFIX|${REDISPREFIX}|g" "${WP_CONFIG_PATH}"
}


#----------------------------------------------------------------------------------
# Configure wp-config.php settings (WP Scan API and Recovery Email)
configure_wpconfig_settings() {
  local SITE_URL="$1"
  local WP_CONFIG_PATH="$2"
  
  # WP Scan API Token
  sed -i "s|SEDWPSCANAPI|${WPSCANAPI}|g" "${WP_CONFIG_PATH}"

  # WP Recovery Email
  sed -i "s|SEDWPRECOVERYEMAIL|${WP_RECOVERY_EMAIL}|g" "${WP_CONFIG_PATH}"
}


#----------------------------------------------------------------------------------
# Fetch WordPress salts from api.wordpress.org and apply them to wp-config.php.
# Retries up to 5 times with a 15-second delay between attempts so that a
# transient WordPress.org API outage does not permanently break the install.
fetch_wp_salts() {
  local wp_config_path="$1"
  local max_attempts=5
  local retry_delay=15
  local salt=""
  local attempt

  echo "Generating new WordPress salts..."
  for (( attempt=1; attempt<=max_attempts; attempt++ )); do
    salt=$(curl --fail --silent --show-error --location --proto '=https' --connect-timeout 10 --max-time 30 \
      "https://api.wordpress.org/secret-key/1.1/salt/" 2>/dev/null)
    if [[ -n "${salt}" ]] && printf '%s' "${salt}" | grep -q "define("; then
      local string='put your unique phrase here'
      printf '%s\n' "g/${string}/d" a "${salt}" . w | ed -s "${wp_config_path}"
      echo "WordPress salts applied successfully."
      return 0
    fi
    if [[ ${attempt} -lt ${max_attempts} ]]; then
      echo "Warning: Failed to fetch valid WordPress salts (attempt ${attempt}/${max_attempts}). Retrying in ${retry_delay} seconds..." >&2
      sleep "${retry_delay}"
    fi
  done

  echo "Error: Failed to fetch valid WordPress salts from api.wordpress.org after ${max_attempts} attempts. Please check your internet connection and DNS/firewall/proxy settings. If the issue persists, the WordPress.org API may be temporarily unavailable—please retry the import later." >&2
  exit 1
}


#----------------------------------------------------------------------------------
# Create robots.txt file
create_robots_txt() {
  local SITE_URL="$1"
  local WP_ROOT_PATH="$2"
  
  # Create robots.txt
  cp -rf "/usr/local/bin/enginescript/config/var/www/wordpress/robots.txt" "${WP_ROOT_PATH}/robots.txt"
  sed -i "s|SEDURL|${SITE_URL}|g" "${WP_ROOT_PATH}/robots.txt"
}


#----------------------------------------------------------------------------------
# Back up every site, the new one included, and EngineScript's configuration now: the same run
# as es.backup, so the first backup has the scheduled backups' layout, retention, and S3 copy.
perform_site_backup() {
  local SITE_URL="$1"

  echo ""
  echo "Backup script will now run for all sites on this server."
  echo ""

  if bash /usr/local/bin/enginescript/scripts/functions/backup/enginescript-backup.sh now; then
    echo "Backup: Complete"
  else
    echo "Warning: The backup after setting up ${SITE_URL} reported errors; see /var/log/EngineScript/enginescript-backup.log. The site itself is set up." >&2
  fi
  clear
}


#----------------------------------------------------------------------------------
# Display final credentials summary
display_credentials_summary() {
  local SITE_URL="$1"
  local DB="$2"
  local PREFIX="$3"
  local USR="$4"
  local PSWD="$5"
  
  echo ""
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo "|${BOLD}Backups${NORMAL}:                             |"
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo "For your records:"
  echo "-------------------------------------------------------"
  echo ""
  echo "${BOLD}URL:${NORMAL}               ${SITE_URL}"
  echo "-----------------"
  echo "${BOLD}Database:${NORMAL}          ${DB}"
  echo "${BOLD}Site Prefix:${NORMAL}       ${PREFIX}"
  echo "${BOLD}DB User:${NORMAL}           ${USR}"
  echo "${BOLD}DB Password:${NORMAL}       ${PSWD}"
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo ""
  echo "The site's database credentials are saved in:"
  echo "/home/EngineScript/mysql-credentials/${SITE_URL}.txt"
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo ""
  echo "Database and wp-config.php backups, and full site archives:"
  echo "/home/EngineScript/site-backups/${SITE_URL}/"
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo ""
  echo "SSL certificate and private key (EngineScript configuration backup):"
  echo "/home/EngineScript/config-backups/enginescript/"
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo ""
  echo "Nginx configuration, including the site's vhost (daily):"
  echo "/home/EngineScript/config-backups/nginx/"
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo ""

  sleep 3
}
