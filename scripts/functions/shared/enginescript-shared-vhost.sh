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


# Check if required services are running
check_required_services() {
  echo -e "\n\n${BOLD}Running Services Check:${NORMAL}\n"

  # Database Service Check (MariaDB or MySQL)
  MARIADB_STATUS="$(systemctl is-active mariadb)"
  MYSQL_STATUS="$(systemctl is-active mysql)"

  if [[ "${MARIADB_STATUS}" != "active" && "${MYSQL_STATUS}" != "active" ]]; then
    echo "FAILED: Neither MariaDB nor MySQL is running. Please diagnose this issue before proceeding."
    exit 1
  fi

  if [[ "${MARIADB_STATUS}" == "active" ]]; then
    echo "PASSED: MariaDB is running."
  elif [[ "${MYSQL_STATUS}" == "active" ]]; then
    echo "PASSED: MySQL is running."
  fi

  # Nginx Service Check
  STATUS="$(systemctl is-active nginx)"
  if [[ "${STATUS}" == "active" ]]; then
    echo "PASSED: Nginx is running."
  else
    echo "FAILED: Nginx not running. Please diagnose this issue before proceeding."
    exit 1
  fi

  # PHP Service Check
  STATUS="$(systemctl is-active "php${PHP_VER}-fpm")"
  if [[ "${STATUS}" == "active" ]]; then
    echo "PASSED: PHP ${PHP_VER} is running."
  else
    echo "FAILED: PHP ${PHP_VER} not running. Please diagnose this issue before proceeding."
    exit 1
  fi

  # Redis Service Check
  STATUS="$(systemctl is-active redis)"
  if [[ "${STATUS}" == "active" ]]; then
    echo "PASSED: Redis is running."
  else
    echo "FAILED: Redis not running. Please diagnose this issue before proceeding."
    exit 1
  fi
}


#----------------------------------------------------------------------------------
# Create nginx vhost configuration files
create_nginx_vhost() {
  local DOMAIN="$1"

  # Store SQL credentials
  echo "SITE_URL=\"${DOMAIN}\"" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"

  # Add Domain to Site List
  sed -i "/SITES\=(/a\
  \"$DOMAIN\"" /home/EngineScript/sites-list/sites.sh
  
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

  mkdir -p "/etc/nginx/ssl/${DOMAIN}"

  # Issue SSL Certificate
  /root/.acme.sh/acme.sh --issue --force --dns dns_cf --server zerossl -d "${DOMAIN}" -d "admin.${DOMAIN}" -d "*.${DOMAIN}" -k "${SSL_KEYLENGTH}"

  # Install SSL Certificate
  # acme.sh saves --reloadcmd and runs it after every renewal, so Nginx loads the new certificate
  /root/.acme.sh/acme.sh --install-cert -d "${DOMAIN}" --ecc \
  --cert-file "/etc/nginx/ssl/${DOMAIN}/cert.pem" \
  --key-file "/etc/nginx/ssl/${DOMAIN}/key.pem" \
  --fullchain-file "/etc/nginx/ssl/${DOMAIN}/fullchain.pem" \
  --ca-file "/etc/nginx/ssl/${DOMAIN}/ca.pem" \
  --reloadcmd "systemctl reload nginx"

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

    # Make one Cloudflare API call for the zone and print one line for it (✓, or ✗ with
    # Cloudflare's error message) instead of the raw JSON. Failures are counted in CF_FAILED.
    # Usage: cf_api "<what it sets>" <METHOD> <path after /zones/ZONE_ID> [JSON body]
    CF_FAILED=0
    CF_AOP_ON=0
    cf_api() {
      local label="$1" method="$2" path="$3" body="${4:-}" response message
      local args=(-s --max-time 30 -X "${method}" "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}${path}"
        -H "Content-Type: application/json")
      if [[ -n "${body}" ]]; then
        args+=(--data "${body}")
      fi
      response="$(cloudflare_curl "${args[@]}")"
      if grep -Eq '"success"[[:space:]]*:[[:space:]]*true' <<< "${response}"; then
        echo "  ✓ ${label}"
        return 0
      fi
      message="$(grep -oE '"message"[[:space:]]*:[[:space:]]*"[^"]*"' <<< "${response}" | head -n 1 | sed -E 's/^"message"[[:space:]]*:[[:space:]]*"(.*)"$/\1/')"
      echo "  ✗ ${label}: ${message:-no answer from Cloudflare}"
      CF_FAILED=$((CF_FAILED + 1))
      return 1
    }

    get_cf_zone_id() {
      local CF_DOMAIN="$1"
      cloudflare_curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${CF_DOMAIN}&status=active" \
        -H "Content-Type: application/json" | \
        grep -o '"id":"[a-zA-Z0-9]*"' | head -n1 | cut -d'"' -f4
    }

    ZONE_ID=$(get_cf_zone_id "$DOMAIN")

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
      
      # Check if A record exists and matches server IP
      A_RECORD_INFO=$(cloudflare_curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=A&name=${DOMAIN}" \
        -H "Content-Type: application/json")
      
      A_RECORD_ID=$(echo "$A_RECORD_INFO" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
      A_RECORD_CONTENT=$(echo "$A_RECORD_INFO" | grep -o '"content":"[^"]*' | head -1 | cut -d'"' -f4)
      
      echo ""
      echo "Cloudflare DNS records for ${DOMAIN}:"
      A_RECORD="{\"type\": \"A\", \"name\": \"${DOMAIN}\", \"content\": \"${SERVER_IP}\", \"ttl\": 1, \"proxied\": true}"
      if [[ -z "$A_RECORD_ID" ]]; then
        # A record doesn't exist, create it
        cf_api "A record ${DOMAIN}: ${SERVER_IP} (proxied), added" POST "/dns_records" "${A_RECORD}"
      elif [[ "$A_RECORD_CONTENT" != "$SERVER_IP" ]]; then
        # A record exists but IP doesn't match, update it
        cf_api "A record ${DOMAIN}: ${SERVER_IP} (proxied), was ${A_RECORD_CONTENT}" PUT "/dns_records/${A_RECORD_ID}" "${A_RECORD}"
      else
        echo "  ✓ A record ${DOMAIN}: ${SERVER_IP}, already set"
      fi

      # Check if admin subdomain already exists (the first record, if there are several)
      ADMIN_RECORD_ID=$(cloudflare_curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=CNAME&name=admin.${DOMAIN}" \
        -H "Content-Type: application/json" | grep -o '"id":"[^"]*' | head -n 1 | cut -d'"' -f4)

      ADMIN_RECORD="{\"comment\": \"Admin Control Panel\", \"content\": \"${DOMAIN}\", \"name\": \"admin\", \"proxied\": true, \"ttl\": 1, \"type\": \"CNAME\"}"
      if [[ -z "$ADMIN_RECORD_ID" ]]; then
        # Admin subdomain does not exist, create it
        cf_api "CNAME admin.${DOMAIN}: ${DOMAIN} (proxied), added" POST "/dns_records" "${ADMIN_RECORD}"
      else
        # Admin subdomain exists, update it
        cf_api "CNAME admin.${DOMAIN}: ${DOMAIN} (proxied), updated" PUT "/dns_records/${ADMIN_RECORD_ID}" "${ADMIN_RECORD}"
      fi

      # Check if www subdomain already exists (the first record, if there are several)
      WWW_RECORD_ID=$(cloudflare_curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=CNAME&name=www.${DOMAIN}" \
        -H "Content-Type: application/json" | grep -o '"id":"[^"]*' | head -n 1 | cut -d'"' -f4)

      WWW_RECORD="{\"comment\": \"WWW Redirect\", \"content\": \"${DOMAIN}\", \"name\": \"www\", \"proxied\": true, \"ttl\": 1, \"type\": \"CNAME\"}"
      if [[ -z "$WWW_RECORD_ID" ]]; then
        # www subdomain does not exist, create it
        cf_api "CNAME www.${DOMAIN}: ${DOMAIN} (proxied), added" POST "/dns_records" "${WWW_RECORD}"
      else
        # www subdomain exists, update it
        cf_api "CNAME www.${DOMAIN}: ${DOMAIN} (proxied), updated" PUT "/dns_records/${WWW_RECORD_ID}" "${WWW_RECORD}"
      fi

      echo ""
      echo "Cloudflare settings for ${DOMAIN}:"


      ## SSL/TLS Settings

      # SSL/TLS Tab: SSL/TLS Encryption Mode
      cf_api "SSL/TLS encryption mode: Full (strict)" PATCH "/settings/ssl" '{"value":"strict"}'

      # Edge Certificates Section: Always Use HTTPS
      cf_api "Always Use HTTPS: off" PATCH "/settings/always_use_https" '{"value":"off"}'

      # Edge Certificates Section: Minimum TLS Version
      cf_api "Minimum TLS Version: 1.2" PATCH "/settings/min_tls_version" '{"value":"1.2"}'

      # Edge Certificates Section: Opportunistic Encryption
      cf_api "Opportunistic Encryption: on" PATCH "/settings/opportunistic_encryption" '{"value":"on"}'

      # Edge Certificates Section: TLS 1.3
      cf_api "TLS 1.3: on" PATCH "/settings/tls_1_3" '{"value":"on"}'

      # Edge Certificates Section: Automatic HTTPS Rewrites
      cf_api "Automatic HTTPS Rewrites: on" PATCH "/settings/automatic_https_rewrites" '{"value":"on"}'

      # Origin Server Section: Authenticated Origin Pulls (per zone)
      cf_api "Authenticated Origin Pulls (zone): on" PUT "/origin_tls_client_auth/settings" '{"enabled": true}' && CF_AOP_ON=1
        
      # Origin Server Section: Authenticated Origin Pulls
      cf_api "Authenticated Origin Pulls (setting): on" PATCH "/settings/tls_client_auth" '{"value":"on"}' && CF_AOP_ON=1


      ## Speed Settings

      # Speed Tab: Speed Brain
      cf_api "Speed Brain: on" PATCH "/settings/speed_brain" '{"value":"on"}'

      # Speed Tab: Early Hints
      cf_api "Early Hints: on" PATCH "/settings/early_hints" '{"value":"on"}'

      # Speed Tab: HTTP/3 (with QUIC)
      cf_api "HTTP/3 (with QUIC): on" PATCH "/settings/http3" '{"value":"on"}'

      # Speed Tab: Enhanced HTTP/2 Prioritization
      cf_api "Enhanced HTTP/2 Prioritization: on" PATCH "/settings/h2_prioritization" '{"value":"on"}'

      # Speed Tab: 0-RTT Connection Resumption
      cf_api "0-RTT Connection Resumption: on" PATCH "/settings/0rtt" '{"value":"on"}'


      ## Caching Settings

      # Caching Tab: Caching Level
      cf_api "Caching Level: aggressive" PATCH "/settings/cache_level" '{"value":"aggressive"}'

      # Caching Tab: Browser Cache TTL (Respect Existing Headers)
      cf_api "Browser Cache TTL: respect existing headers" PATCH "/settings/browser_cache_ttl" '{"value":0}'

      # Caching Tab: Always Online
      cf_api "Always Online: on" PATCH "/settings/always_online" '{"value":"on"}'

      # Tiered Cache Section: Tiered Cache Topology
      cf_api "Tiered Cache: on" PATCH "/argo/tiered_caching" '{"value":"on"}'

      # Tiered Cache Section: Tiered Cache Topology (Smart Tiered Caching)
      cf_api "Smart Tiered Cache Topology: on" PATCH "/cache/tiered_cache_smart_topology_enable" '{"value":"on"}'


      ## Network Settings

      # Network Tab: IPv6 Compatibility
      cf_api "IPv6 Compatibility: on" PATCH "/settings/ipv6" '{"value":"on"}'

      # Network Tab: WebSockets
      cf_api "WebSockets: on" PATCH "/settings/websockets" '{"value":"on"}'

      # Network Tab: Pseudo IPv4
      cf_api "Pseudo IPv4: add_header" PATCH "/settings/pseudo_ipv4" '{"value":"add_header"}'

      # Network Tab: IP Geolocation
      cf_api "IP Geolocation: on" PATCH "/settings/ip_geolocation" '{"value":"on"}'

      # Network Tab: Network Error Logging
      cf_api "Network Error Logging: on" PATCH "/settings/nel" '{"value": {"enabled": true} }'

      # Network Tab: Onion Routing
      cf_api "Onion Routing: on" PATCH "/settings/opportunistic_onion" '{"value":"on"}'

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

  wp plugin install flush-opcache --allow-root --activate
  wp plugin install mariadb-health-checks --allow-root --activate
  wp plugin install nginx-helper --allow-root --activate
  wp plugin install redis-cache --allow-root --activate
}


#----------------------------------------------------------------------------------
# Install extra WordPress plugins
# These plugins are optional but recommended for enhanced functionality and debugging
install_extra_wp_plugins() {
  local SITE_URL="$1"
  wp plugin install action-scheduler --allow-root
  wp plugin install autodescription --allow-root
  wp plugin install performance-lab --allow-root
  wp plugin install php-compatibility-checker --allow-root
  wp plugin install theme-check --allow-root
  wp plugin install wp-crontrol --allow-root
  wp plugin install wp-mail-smtp --allow-root
}


#----------------------------------------------------------------------------------
# Install EngineScript custom plugins
install_enginescript_custom_plugins() {
  local SITE_URL="$1"
  
  if [[ "${INSTALL_ENGINESCRIPT_PLUGINS}" == "1" ]]; then
    echo "Installing EngineScript custom plugins..."
    
    # 1. EngineScript Site Optimizer plugin
    mkdir -p "/tmp/enginescript-es-so-plugin"
    curl -fsSL --proto '=https' "https://github.com/EngineScript/enginescript-site-optimizer/releases/download/v${ES_SO_PLUGIN_VER}/enginescript-site-optimizer-${ES_SO_PLUGIN_VER}.zip" -o "/tmp/enginescript-es-so-plugin/enginescript-site-optimizer-${ES_SO_PLUGIN_VER}.zip" || {
      echo "ERROR: Failed to download EngineScript Site Optimizer plugin (version ${ES_SO_PLUGIN_VER})."
      rm -rf "/tmp/enginescript-es-so-plugin"
      return 1
    }
    unzip -q -o "/tmp/enginescript-es-so-plugin/enginescript-site-optimizer-${ES_SO_PLUGIN_VER}.zip" -d "/var/www/sites/${SITE_URL}/html/wp-content/plugins/" || {
      echo "ERROR: Failed to extract EngineScript Site Optimizer plugin archive."
      rm -rf "/tmp/enginescript-es-so-plugin"
      return 1
    }
    rm -rf "/tmp/enginescript-es-so-plugin"

    # 2. EngineScript Site Exporter plugin
    mkdir -p "/tmp/enginescript-es-se-plugin"
    curl -fsSL --proto '=https' "https://github.com/EngineScript/enginescript-site-exporter/releases/download/v${ES_SE_PLUGIN_VER}/enginescript-site-exporter-${ES_SE_PLUGIN_VER}.zip" -o "/tmp/enginescript-es-se-plugin/enginescript-site-exporter-${ES_SE_PLUGIN_VER}.zip" || {
      echo "ERROR: Failed to download EngineScript Site Exporter plugin (version ${ES_SE_PLUGIN_VER})."
      rm -rf "/tmp/enginescript-es-se-plugin"
      return 1
    }
    unzip -q -o "/tmp/enginescript-es-se-plugin/enginescript-site-exporter-${ES_SE_PLUGIN_VER}.zip" -d "/var/www/sites/${SITE_URL}/html/wp-content/plugins/" || {
      echo "ERROR: Failed to extract EngineScript Site Exporter plugin archive."
      rm -rf "/tmp/enginescript-es-se-plugin"
      return 1
    }
    rm -rf "/tmp/enginescript-es-se-plugin"
  else
    echo "Skipping EngineScript custom plugins installation (disabled in config)..."
  fi
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
