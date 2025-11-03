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


# Check if required services are running
check_required_services() {
  echo -e "\n\n${BOLD}Running Services Check:${NORMAL}\n"

  # MariaDB Service Check
  STATUS="$(systemctl is-active mariadb)"
  if [[ "${STATUS}" == "active" ]]; then
    echo "PASSED: MariaDB is running."
  else
    echo "FAILED: MariaDB not running. Please diagnose this issue before proceeding."
    exit 1
  fi

  # MySQL Service Check
  STATUS="$(systemctl is-active mysql)"
  if [[ "${STATUS}" == "active" ]]; then
    echo "PASSED: MySQL is running."
  else
    echo "FAILED: MySQL not running. Please diagnose this issue before proceeding."
    exit 1
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

  # Enable Admin Subdomain Vhost File
  if [[ "${ADMIN_SUBDOMAIN}" == "1" ]];
    then
      sed -i "s|#include /etc/nginx/admin/admin.your-domain.conf;|include /etc/nginx/admin/admin.${DOMAIN}.conf;|g" "/etc/nginx/sites-enabled/${DOMAIN}.conf"
    else
      echo ""
  fi

  # Enable HTTP/3 if configured
  if [[ "${INSTALL_HTTP3}" == "1" ]]; then
    sed -i "s|#listen 443 quic|listen 443 quic|g" "/etc/nginx/sites-enabled/${DOMAIN}.conf"
    sed -i "s|#listen [::]:443 quic|listen [::]:443 quic|g" "/etc/nginx/sites-enabled/${DOMAIN}.conf"
  fi
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
  /root/.acme.sh/acme.sh --issue --force --dns dns_cf --server zerossl -d "${DOMAIN}" -d "admin.${DOMAIN}" -d "*.${DOMAIN}" -k ${SSL_KEYLENGTH}

  # Install SSL Certificate
  /root/.acme.sh/acme.sh --install-cert -d "${DOMAIN}" --ecc \
  --cert-file "/etc/nginx/ssl/${DOMAIN}/cert.pem" \
  --key-file "/etc/nginx/ssl/${DOMAIN}/key.pem" \
  --fullchain-file "/etc/nginx/ssl/${DOMAIN}/fullchain.pem" \
  --ca-file "/etc/nginx/ssl/${DOMAIN}/ca.pem"
}


#----------------------------------------------------------------------------------
# Create backup directories for a site
create_backup_directories() {
  local SITE_URL="$1"
  
  # Backup Dir Creation
  mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/database"
  mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/database/daily"
  mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/database/hourly"
  mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/nginx"
  mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/ssl-keys"
  mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/wp-config"
  mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/wp-content"
  mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/wp-uploads"
}


#----------------------------------------------------------------------------------
# Create domain log directories and files
create_domain_logs() {
  local SITE_URL="$1"
  
  # Domain Logs
  mkdir -p "/var/log/domains/${SITE_URL}"
  touch "/var/log/domains/${SITE_URL}/${SITE_URL}-wp-error.log"
  touch "/var/log/domains/${SITE_URL}/${SITE_URL}-nginx-helper.log"
  chown -R www-data:www-data "/var/log/domains/${SITE_URL}"
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
      CF_CHOICE="n"
  fi

  # Only continue with Cloudflare configuration if the user chose to proceed
  if [[ "$CF_CHOICE" =~ ^[Yy] ]]; then
    # Cloudflare Keys
    export CF_Key="${CF_GLOBAL_API_KEY}"
    export CF_Email="${CF_ACCOUNT_EMAIL}"

    get_cf_zone_id() {
      local CF_DOMAIN="$1"
      curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${CF_DOMAIN}&status=active" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
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
      
      # Validate IP format
      if ! [[ "$SERVER_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "WARNING: Invalid IP from ipinfo.io (${SERVER_IP}), trying backup source..."
        SERVER_IP=$(curl -s --max-time 5 https://icanhazip.com)
        
        # Validate backup IP
        if ! [[ "$SERVER_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
          echo "ERROR: Could not obtain valid IP address from any source"
          echo "Received: ${SERVER_IP}"
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
      A_RECORD_INFO=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=A&name=${DOMAIN}" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json")
      
      A_RECORD_ID=$(echo "$A_RECORD_INFO" | grep -o '"id":"[^"]*' | head -1 | cut -d'"' -f4)
      A_RECORD_CONTENT=$(echo "$A_RECORD_INFO" | grep -o '"content":"[^"]*' | head -1 | cut -d'"' -f4)
      
      if [[ -z "$A_RECORD_ID" ]]; then
        # A record doesn't exist, create it
        echo "Adding A record for ${DOMAIN} pointing to ${SERVER_IP}..."
        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records" \
          -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
          -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
          -H "Content-Type: application/json" \
          -d "{
            \"type\": \"A\",
            \"name\": \"${DOMAIN}\",
            \"content\": \"${SERVER_IP}\",
            \"ttl\": 1,
            \"proxied\": true
          }"
      elif [[ "$A_RECORD_CONTENT" != "$SERVER_IP" ]]; then
        # A record exists but IP doesn't match, update it
        echo "Updating A record for ${DOMAIN} from ${A_RECORD_CONTENT} to ${SERVER_IP}..."
        curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${A_RECORD_ID}" \
          -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
          -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
          -H "Content-Type: application/json" \
          -d "{
            \"type\": \"A\",
            \"name\": \"${DOMAIN}\",
            \"content\": \"${SERVER_IP}\",
            \"ttl\": 1,
            \"proxied\": true
          }"
      else
        echo "A record for ${DOMAIN} already points to ${SERVER_IP}. No update needed."
      fi
      
      # Check if admin subdomain already exists
      ADMIN_RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=CNAME&name=admin.${DOMAIN}" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" | grep -o '"id":"[^"]*' | cut -d'"' -f4)

      if [[ -z "$ADMIN_RECORD_ID" ]]; then
        # Admin subdomain does not exist, create it
        echo "Adding admin subdomain to Cloudflare..."
        curl -s https://api.cloudflare.com/client/v4/zones/"${ZONE_ID}"/dns_records \
          -H 'Content-Type: application/json' \
          -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
          -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
          -d "{
            \"comment\": \"Admin Control Panel\",
            \"content\": \"${DOMAIN}\",
            \"name\": \"admin\",
            \"proxied\": true,
            \"ttl\": 1,
            \"type\": \"CNAME\"
          }"
      else
        # Admin subdomain exists, update it
        echo "Updating existing admin subdomain in Cloudflare..."
        curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${ADMIN_RECORD_ID}" \
          -H 'Content-Type: application/json' \
          -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
          -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
          -d "{
            \"comment\": \"Admin Control Panel\",
            \"content\": \"${DOMAIN}\",
            \"name\": \"admin\",
            \"proxied\": true,
            \"ttl\": 1,
            \"type\": \"CNAME\"
          }"
      fi
      
      # Check if www subdomain already exists
      WWW_RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=CNAME&name=www.${DOMAIN}" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" | grep -o '"id":"[^"]*' | cut -d'"' -f4)

      if [[ -z "$WWW_RECORD_ID" ]]; then
        # www subdomain does not exist, create it
        echo "Adding www subdomain to Cloudflare..."
        curl -s https://api.cloudflare.com/client/v4/zones/"${ZONE_ID}"/dns_records \
          -H 'Content-Type: application/json' \
          -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
          -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
          -d "{
            \"comment\": \"WWW Redirect\",
            \"content\": \"${DOMAIN}\",
            \"name\": \"www\",
            \"proxied\": true,
            \"ttl\": 1,
            \"type\": \"CNAME\"
          }"
      else
        # www subdomain exists, update it
        echo "Updating existing www subdomain in Cloudflare..."
        curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${WWW_RECORD_ID}" \
          -H 'Content-Type: application/json' \
          -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
          -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
          -d "{
            \"comment\": \"WWW Redirect\",
            \"content\": \"${DOMAIN}\",
            \"name\": \"www\",
            \"proxied\": true,
            \"ttl\": 1,
            \"type\": \"CNAME\"
          }"
      fi


      ## SSL/TLS Settings

      # SSL/TLS Tab: SSL/TLS Encryption Mode
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/ssl" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"strict"}'

      # Edge Certificates Section: Always Use HTTPS
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/always_use_https" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"off"}'

      # Edge Certificates Section: Minimum TLS Version
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/min_tls_version" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"1.2"}'

      # Edge Certificates Section: Opportunistic Encryption
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/opportunistic_encryption" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}'

      # Edge Certificates Section: TLS 1.3
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/tls_1_3" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}'

      # Edge Certificates Section: Automatic HTTPS Rewrites
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/automatic_https_rewrites" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}'

      # Origin Server Section: Authenticated Origin Pulls (per zone)
      curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/origin_tls_client_auth/settings" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"enabled": true}'
        
      # Origin Server Section: Authenticated Origin Pulls
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/tls_client_auth" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}'


      ## Speed Settings

      # Speed Tab: Speed Brain
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/speed_brain" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}'

      # Speed Tab: Early Hints
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/early_hints" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}'

      # Speed Tab: HTTP/3 (with QUIC)
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/http3" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}'

      # Speed Tab: Enhanced HTTP/2 Prioritization
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/h2_prioritization" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}'

      # Speed Tab: 0-RTT Connection Resumption
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/0rtt" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}'


      ## Caching Settings

      # Caching Tab: Caching Level
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/cache_level" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"aggressive"}'

      # Caching Tab: Browser Cache TTL (Respect Existing Headers)
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/browser_cache_ttl" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":0}'

      # Caching Tab: Always Online
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/always_online" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}'

      # Tiered Cache Section: Tiered Cache Topology
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/argo/tiered_caching" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}'

      # Tiered Cache Section: Tiered Cache Topology (Smart Tiered Caching)
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/cache/tiered_cache_smart_topology_enable" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}'


      ## Network Settings

      # Network Tab: IPv6 Compatibility
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/ipv6" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}'

      # Network Tab: WebSockets
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/websockets" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}'

      # Network Tab: Pseudo IPv4
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/pseudo_ipv4" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"add_header"}'

      # Network Tab: IP Geolocation
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/ip_geolocation" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}'

      # Network Tab: Network Error Logging
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/nel" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value": {"enabled": true} }'

      # Network Tab: Onion Routing
      curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/settings/opportunistic_onion" \
        -H "X-Auth-Email: ${CF_ACCOUNT_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_API_KEY}" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}'
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
  wp plugin install app-for-cf --allow-root
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
    
    # 1. Simple WP Optimizer plugin
    mkdir -p "/tmp/enginescript-swpo-plugin"
    wget -q "https://github.com/EngineScript/Simple-WP-Optimizer/releases/latest/download/simple-wp-optimizer.zip" -O "/tmp/enginescript-swpo-plugin/simple-wp-optimizer.zip"
    unzip -q -o "/tmp/enginescript-swpo-plugin/simple-wp-optimizer.zip" -d "/var/www/sites/${SITE_URL}/html/wp-content/plugins/"
    rm -rf "/tmp/enginescript-swpo-plugin"

    # 2. Simple Site Exporter plugin
    mkdir -p "/tmp/enginescript-sse-plugin"
    wget -q "https://github.com/EngineScript/Simple-WP-Site-Exporter/releases/latest/download/simple-site-exporter.zip" -O "/tmp/enginescript-sse-plugin/simple-site-exporter.zip"
    unzip -q -o "/tmp/enginescript-sse-plugin/simple-site-exporter.zip" -d "/var/www/sites/${SITE_URL}/html/wp-content/plugins/"
    rm -rf "/tmp/enginescript-sse-plugin"
  else
    echo "Skipping EngineScript custom plugins installation (disabled in config)..."
  fi
}


#----------------------------------------------------------------------------------
# Configure Redis for WordPress site
configure_redis() {
  local SITE_URL="$1"
  local WP_CONFIG_PATH="$2"
  
  # Redis Config
  # Scale Redis Databases to Number of Installed Domains
  source /home/EngineScript/sites-list/sites.sh
  if [[ "${#SITES[@]}" == "1" ]];
    then
      # If number of installed domains = 1, leave Redis at 1 database and WordPress set to use database 0
      echo "There is only 1 domain in the site list. Not adding additional Redis databases."
    else
      # Raise number of Redis databases to equal number of domains in sites.sh
      OLDREDISDB=$((${#SITES[@]} - 1))
      sed -i "s|databases ${OLDREDISDB}|databases ${#SITES[@]}|g" /etc/redis/redis.conf
      restart_service "redis-server"

      # Set WordPress to use the latest Redis database number.
      # Redis starts databases at number 0, so we take the total number of domains in sites.sh and reduce by 1. Three installed domains = database 2
      sed -i "s|WP_REDIS_DATABASE', 0|WP_REDIS_DATABASE', ${OLDREDISDB}|g" "${WP_CONFIG_PATH}"
  fi

  # Set Redis Prefix
  REDISPREFIX="$(echo "${DOMAIN::5}")" && sed -i "s|SEDREDISPREFIX|${REDISPREFIX}|g" "${WP_CONFIG_PATH}"
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
# Create robots.txt file
create_robots_txt() {
  local SITE_URL="$1"
  local WP_ROOT_PATH="$2"
  
  # Create robots.txt
  cp -rf "/usr/local/bin/enginescript/config/var/www/wordpress/robots.txt" "${WP_ROOT_PATH}/robots.txt"
  sed -i "s|SEDURL|${SITE_URL}|g" "${WP_ROOT_PATH}/robots.txt"
}


#----------------------------------------------------------------------------------
# Perform site backup
perform_site_backup() {
  local SITE_URL="$1"
  local WP_ROOT_PATH="$2"
  
  echo ""
  echo "Backup script will now run for all sites on this server."
  echo ""

  # Date
  NOW=$(date +%m-%d-%Y-%H)

  # Filenames
  DATABASE_FILE="${NOW}-database.sql";
  FULLWPFILES="${NOW}-wordpress-files.gz";
  NGINX_FILE="${NOW}-nginx-vhost.conf.gz";
  PHP_FILE="${NOW}-php.tar.gz";
  SSL_FILE="${NOW}-ssl-keys.gz";
  UPLOADS_FILE="${NOW}-uploads.tar.gz";
  VHOST_FILE="${NOW}-nginx-vhost.conf.gz";
  WPCONFIG_FILE="${NOW}-wp-config.php.gz";
  WPCONTENT_FILE="${NOW}-wp-content.gz";

  cd "${WP_ROOT_PATH}"

  # Backup database
  wp db export "/home/EngineScript/site-backups/${SITE_URL}/database/daily/$DATABASE_FILE" --add-drop-table --allow-root

  # Compress database file
  gzip -f "/home/EngineScript/site-backups/${SITE_URL}/database/daily/$DATABASE_FILE"

  # Backup uploads, themes, and plugins
  tar -zcf "/home/EngineScript/site-backups/${SITE_URL}/wp-content/$WPCONTENT_FILE" wp-content

  # Nginx vhost backup
  gzip -cf "/etc/nginx/sites-enabled/${SITE_URL}.conf" > "/home/EngineScript/site-backups/${SITE_URL}/nginx/$VHOST_FILE"

  # SSL keys backup
  tar -zcf "/home/EngineScript/site-backups/${SITE_URL}/ssl-keys/$SSL_FILE" "/etc/nginx/ssl/${SITE_URL}"

  # wp-config.php backup
  gzip -cf "${WP_ROOT_PATH}/wp-config.php" > "/home/EngineScript/site-backups/${SITE_URL}/wp-config/$WPCONFIG_FILE"

  # Remove old backups
  find "/home/EngineScript/site-backups/${SITE_URL}/database/daily" -type f -mtime +7 | xargs rm -fR
  find "/home/EngineScript/site-backups/${SITE_URL}/nginx" -type f -mtime +7 | xargs rm -fR
  find "/home/EngineScript/site-backups/${SITE_URL}/ssl-keys" -type f -mtime +7 | xargs rm -fR
  find "/home/EngineScript/site-backups/${SITE_URL}/wp-config" -type f -mtime +7 | xargs rm -fR
  find "/home/EngineScript/site-backups/${SITE_URL}/wp-content" -type f -mtime +15 | xargs rm -fR
  find "/home/EngineScript/site-backups/${SITE_URL}/wp-uploads" -type f -mtime +15  | xargs rm -fR

  echo "Backup: Complete"
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
  echo "${BOLD}Site Prefix${NORMAL}        ${PREFIX}"
  echo "${BOLD}DB User:${NORMAL}           ${USR}"
  echo "${BOLD}DB Password:${NORMAL}       ${PSWD}"
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo ""
  echo "MySQL Root and Domain login credentials backed up to:"
  echo "/home/EngineScript/mysql-credentials/${SITE_URL}"
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo ""
  echo "Origin Certificate and Private Key have been backed up to:"
  echo "/home/EngineScript/site-backups/${SITE_URL}/ssl-keys"
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo ""
  echo "Domain Vhost .conf file backed up to:"
  echo "/home/EngineScript/site-backups/${SITE_URL}/nginx"
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo ""
  echo "WordPress wp-config.php file backed up to:"
  echo "/home/EngineScript/site-backups/${SITE_URL}/wp-config"
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo ""

  sleep 3
}
