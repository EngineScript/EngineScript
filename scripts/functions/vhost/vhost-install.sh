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

# Check if services are running
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

# Intro Warning
echo ""
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo "|   Domain Creation                                   |"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""
echo "WARNING: Do not run this script on a site that already exists."
echo "If you do, things will break."
echo ""
sleep 1

# Domain Input
echo "For the domain name, enter only the domain portion (e.g., 'wordpresstesting')."
echo "Note: lowercase text only, no spaces or special characters. Do not include https:// or www."
echo ""
echo "Then, select a valid TLD from the provided list."
echo ""

# Prompt for domain name
while true; do
  read -p "Enter the domain name (e.g., 'wordpresstesting'): " DOMAIN_NAME
  if [[ "$DOMAIN_NAME" =~ ^[a-z0-9-]+$ ]]; then
    echo "You entered: ${DOMAIN_NAME}"
    break
  else
    echo "Invalid domain name. Only lowercase letters, numbers, and hyphens are allowed."
  fi
done

# Prompt for TLD
echo ""
echo "Select a valid TLD from the list below:"
VALID_TLDS=(
    # Common gTLDs
    "com" "net" "org" "info" "biz" "name" "pro" "int"

    # Popular gTLDs
    "io" "dev" "app" "tech" "ai" "cloud" "store" "online" "site" "xyz" "club"
    "design" "media" "agency" "solutions" "services" "digital" "studio" "live"
    "blog" "news" "shop" "art" "finance" "health" "law" "marketing" "software"

    # Country-code TLDs (ccTLDs)
    "us" "uk" "ca" "au" "de" "fr" "es" "it" "nl" "se" "no" "fi" "dk" "jp" "cn"
    "in" "br" "ru" "za" "mx" "ar" "ch" "at" "be" "pl" "gr" "pt" "tr" "kr" "hk"
    "sg" "id" "my" "th" "ph" "vn" "nz" "ie" "il" "sa" "ae" "eg" "ng" "ke" "gh"
    "co.uk"
)
select TLD in "${VALID_TLDS[@]}"; do
  if [[ -n "$TLD" ]]; then
    echo "You selected: ${TLD}"
    break
  else
    echo "Invalid selection. Please choose a valid TLD from the list."
  fi
done

# Combine domain name and TLD
DOMAIN="${DOMAIN_NAME}.${TLD}"
echo ""
echo "Full domain: ${DOMAIN}"
sleep 2

# Verify if the domain is already configured
if grep -Fxq "${DOMAIN}" /home/EngineScript/sites-list/sites.sh; then
  echo -e "\n\n${BOLD}Preinstallation Check: Failed${NORMAL}\n\n${DOMAIN} is already installed.${NORMAL}\n\nIf you believe this is an error, please remove the domain by using the ${BOLD}es.menu${NORMAL} command and selecting the Server & Site Tools option\n\n"
  exit 1
else
  echo "${BOLD}Preinstallation Check: Passed${NORMAL}"
fi

# Logging
LOG_FILE="/var/log/EngineScript/vhost-install.log"
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "Starting domain installation for ${DOMAIN} at $(date)"

# Continue the installation

# ================= Cloudflare API Settings =================
# Set Cloudflare settings for the domain using the Cloudflare API

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
if prompt_yes_no "Would you like to proceed with Cloudflare configuration?" "y" 300; then
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
    
    # Get server's current public IP address
    SERVER_IP=$(curl -s https://ipinfo.io/ip)
    
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

# ================= Cloudflare API Settings =================


# Store SQL credentials
echo "SITE_URL=\"${DOMAIN}\"" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"

# Add Domain to Site List
sed -i "\/SITES\=(/a\
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

# Secure Admin Subdomain (always enabled now)
sed -i "s|#satisfy any|satisfy any|g" "/etc/nginx/admin/admin.${DOMAIN}.conf"
sed -i "s|#auth_basic|auth_basic|g" "/etc/nginx/admin/admin.${DOMAIN}.conf"
sed -i "s|#allow |allow |g" "/etc/nginx/admin/admin.${DOMAIN}.conf"

# Enable HTTP/3 if configured
if [[ "${INSTALL_HTTP3}" == "1" ]]; then
  sed -i "s|#listen 443 quic|listen 443 quic|g" "/etc/nginx/sites-enabled/${DOMAIN}.conf"
  sed -i "s|#listen [::]:443 quic|listen [::]:443 quic|g" "/etc/nginx/sites-enabled/${DOMAIN}.conf"
fi

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

# Print date for logs
echo "System Date: $(date)"

# Domain Creation Variables
PREFIX="${RAND_CHAR2}"
sand="${DOMAIN}" && SANDOMAIN="${sand%.*}" && SDB="${SANDOMAIN}_${RAND_CHAR4}"
SUSR="${RAND_CHAR16}"
SPS="${RAND_CHAR32}"

# Domain Database Credentials
echo "DB=\"${SDB}\"" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
echo "USR=\"${SUSR}\"" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
echo "PSWD=\"${SPS}\"" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
echo "" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"

source "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"

echo "Randomly generated MySQL database credentials for ${SITE_URL}."

sudo mariadb -e "CREATE DATABASE ${DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mariadb -e "CREATE USER '${USR}'@'localhost' IDENTIFIED BY '${PSWD}';"
sudo mariadb -e "GRANT ALL ON ${DB}.* TO '${USR}'@'localhost'; FLUSH PRIVILEGES;"
sudo mariadb -e "GRANT ALL ON mysql.* TO '${USR}'@'localhost'; FLUSH PRIVILEGES;"

# Backup Dir Creation
mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/database"
mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/database/daily"
mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/database/hourly"
mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/nginx"
mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/ssl-keys"
mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/wp-config"
mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/wp-content"
mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/wp-uploads"

# Site Root
mkdir -p "/var/www/sites/${SITE_URL}/html"
cd "/var/www/sites/${SITE_URL}/html"

# Domain Logs
mkdir -p "/var/log/domains/${SITE_URL}"
touch "/var/log/domains/${SITE_URL}/${SITE_URL}-wp-error.log"
touch "/var/log/domains/${SITE_URL}/${SITE_URL}-nginx-helper.log"
chown -R www-data:www-data "/var/log/domains/${SITE_URL}"

# Download WordPress using WP-CLI
wp core download --allow-root
rm -f "/var/www/sites/${SITE_URL}/html/wp-content/plugins/hello.php"

# Create Fonts Directories
mkdir -p "/var/www/sites/${SITE_URL}/html/wp-content/fonts"
mkdir -p "/var/www/sites/${SITE_URL}/html/wp-content/uploads/fonts"

# Create Languages Directory
mkdir -p "/var/www/sites/${SITE_URL}/html/wp-content/languages"

# Create Upgrade Temp Backup Directory
mkdir -p "/var/www/sites/${SITE_URL}/html/wp-content/upgrade-temp-backup"

# Create wp-config.php
cp -rf /usr/local/bin/enginescript/config/var/www/wordpress/wp-config.php "/var/www/sites/${SITE_URL}/html/wp-config.php"
sed -i "s|SEDWPDB|${DB}|g" "/var/www/sites/${SITE_URL}/html/wp-config.php"
sed -i "s|SEDWPUSER|${USR}|g" "/var/www/sites/${SITE_URL}/html/wp-config.php"
sed -i "s|SEDWPPASS|${PSWD}|g" "/var/www/sites/${SITE_URL}/html/wp-config.php"
sed -i "s|SEDPREFIX|${PREFIX}|g" "/var/www/sites/${SITE_URL}/html/wp-config.php"
sed -i "s|SEDURL|${SITE_URL}|g" "/var/www/sites/${SITE_URL}/html/wp-config.php"

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
    sed -i "s|WP_REDIS_DATABASE', 0|WP_REDIS_DATABASE', ${OLDREDISDB}|g" "/var/www/sites/${SITE_URL}/html/wp-config.php"
fi

# Set Redis Prefix
REDISPREFIX="$(echo "${DOMAIN::5}")" && sed -i "s|SEDREDISPREFIX|${REDISPREFIX}|g" "/var/www/sites/${SITE_URL}/html/wp-config.php"

# WP Salt Creation
SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
STRING='put your unique phrase here'
printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s "/var/www/sites/${SITE_URL}/html/wp-config.php"

# WP Scan API Token
sed -i "s|SEDWPSCANAPI|${WPSCANAPI}|g" "/var/www/sites/${SITE_URL}/html/wp-config.php"

# WP Recovery Email
sed -i "s|SEDWPRECOVERYEMAIL|${WP_RECOVERY_EMAIL}|g" "/var/www/sites/${SITE_URL}/html/wp-config.php"

# Create robots.txt
cp -rf "/usr/local/bin/enginescript/config/var/www/wordpress/robots.txt" "/var/www/sites/${SITE_URL}/html/robots.txt"
sed -i "s|SEDURL|${SITE_URL}|g" "/var/www/sites/${SITE_URL}/html/robots.txt"

# WP File Permissions
find "/var/www/sites/${SITE_URL}" -type d -print0 | sudo xargs -0 chmod 0755
find "/var/www/sites/${SITE_URL}" -type f -print0 | sudo xargs -0 chmod 0644
chown -R www-data:www-data "/var/www/sites/${SITE_URL}"
chmod +x "/var/www/sites/${SITE_URL}/html/wp-cron.php"
chmod 600 "/var/www/sites/${SITE_URL}/html/wp-config.php"

# WP-CLI Finalizing Install
clear
echo "============================================="
echo "Finalizing ${SITE_URL} Install:"
echo "============================================="

# Ask user to continue install
#while true;
  #do
    #read -p "When ready, enter y to begin finalizing ${SITE_URL}: " y
      #case $y in
        #[Yy]* )
          #echo "Let's continue";
          #sleep 1;
          #break
          #;;
        #* ) echo "Please answer y";;
      #esac
  #done

# WP-CLI Install WordPress
cd "/var/www/sites/${SITE_URL}/html"
wp core install --admin_user="${WP_ADMIN_USERNAME}" --admin_password="${WP_ADMIN_PASSWORD}" --admin_email="${WP_ADMIN_EMAIL}" --url="https://${SITE_URL}" --title='New Site' --skip-email --allow-root

# WP-CLI Install Plugins
wp plugin install app-for-cf --allow-root
wp plugin install autodescription --allow-root
wp plugin install flush-opcache --allow-root
wp plugin install mariadb-health-checks --allow-root
wp plugin install nginx-helper --allow-root
wp plugin install performance-lab --allow-root
wp plugin install php-compatibility-checker --allow-root
wp plugin install redis-cache --allow-root
wp plugin install theme-check --allow-root
wp plugin install wp-crontrol --allow-root
wp plugin install wp-mail-smtp --allow-root

# Install EngineScript custom plugins if enabled
if [[ "${INSTALL_ENGINESCRIPT_PLUGINS}" == "1" ]]; then
    echo "Installing EngineScript custom plugins..."
    # 1. Simple WP Optimizer plugin
    mkdir -p "/tmp/swpo-plugin-download"
    wget -q "https://github.com/EngineScript/Simple-WP-Optimizer/releases/latest/download/simple-wp-optimizer.zip" -O "/tmp/swpo-plugin-download/simple-wp-optimizer.zip"
    unzip -q -o "/tmp/swpo-plugin-download/simple-wp-optimizer.zip" -d "/var/www/sites/${SITE_URL}/html/wp-content/plugins/"
    rm -rf "/tmp/swpo-plugin-download"

    # 2. Simple Site Exporter plugin
    mkdir -p "/tmp/sse-plugin-download"
    wget -q "https://github.com/EngineScript/Simple-WP-Site-Exporter/releases/latest/download/simple-site-exporter.zip" -O "/tmp/sse-plugin-download/simple-site-exporter.zip"
    unzip -q -o "/tmp/sse-plugin-download/simple-site-exporter.zip" -d "/var/www/sites/${SITE_URL}/html/wp-content/plugins/"
    rm -rf "/tmp/sse-plugin-download"
else
    echo "Skipping EngineScript custom plugins installation (disabled in config)..."
fi

# Always install and activate essential plugins regardless of INSTALL_ENGINESCRIPT_PLUGINS setting
# WP-CLI Activate Plugins
wp plugin activate flush-opcache --allow-root
wp plugin activate mariadb-health-checks --allow-root
wp plugin activate nginx-helper --allow-root
wp plugin activate redis-cache --allow-root
wp plugin activate wp-mail-smtp --allow-root

# WP-CLI Flush Transients
wp transient delete --all --allow-root

# WP-CLI Enable Plugins
wp redis enable --allow-root

# WP-CLI set permalink structure for FastCGI Cache
wp option get permalink_structure --allow-root
wp option update permalink_structure '/%category%/%postname%/' --allow-root
wp rewrite flush --hard --allow-root

# Setting Permissions Again
# For whatever reason, using WP-CLI to install plugins with --allow-root reassigns
# the ownership of the /uploads, /upgrade, and plugin directories to root:root.
cd "/var/www/sites/${SITE_URL}"
chown -R www-data:www-data "/var/www/sites/${SITE_URL}"
chmod +x "/var/www/sites/${SITE_URL}/html/wp-cron.php"
find "/var/www/sites/${SITE_URL}" -type d -print0 | sudo xargs -0 chmod 0755
find "/var/www/sites/${SITE_URL}" -type f -print0 | sudo xargs -0 chmod 0644
chmod 600 "/var/www/sites/${SITE_URL}/html/wp-config.php"

clear

# Backup
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

cd "/var/www/sites/${SITE_URL}/html"

# Backup database
wp db export "/home/EngineScript/site-backups/${SITE_URL}/database/daily/$DATABASE_FILE" --add-drop-table --allow-root

# Compress database file
gzip -f "/home/EngineScript/site-backups/${SITE_URL}/database/daily/$DATABASE_FILE"

# Backup uploads directory
#tar -zcf "/home/EngineScript/site-backups/${SITE_URL}/wp-uploads/$UPLOADS_FILE" wp-content/uploads

# Backup uploads, themes, and plugins
tar -zcf "/home/EngineScript/site-backups/${SITE_URL}/wp-content/$WPCONTENT_FILE" wp-content

# Nginx vhost backup
gzip -cf "/etc/nginx/sites-enabled/${SITE_URL}.conf" > "/home/EngineScript/site-backups/${SITE_URL}/nginx/$VHOST_FILE"

# SSL keys backup
tar -zcf "/home/EngineScript/site-backups/${SITE_URL}/ssl-keys/$SSL_FILE" "/etc/nginx/ssl/${SITE_URL}"

# wp-config.php backup
gzip -cf "/var/www/sites/${SITE_URL}/html/wp-config.php" > "/home/EngineScript/site-backups/${SITE_URL}/wp-config/$WPCONFIG_FILE"

# Remove old backups
find "/home/EngineScript/site-backups/${SITE_URL}/database/daily" -type f -mtime +7 | xargs rm -fR
find "/home/EngineScript/site-backups/${SITE_URL}/nginx" -type f -mtime +7 | xargs rm -fR
find "/home/EngineScript/site-backups/${SITE_URL}/ssl-keys" -type f -mtime +7 | xargs rm -fR
find "/home/EngineScript/site-backups/${SITE_URL}/wp-config" -type f -mtime +7 | xargs rm -fR
find "/home/EngineScript/site-backups/${SITE_URL}/wp-content" -type f -mtime +15 | xargs rm -fR
find "/home/EngineScript/site-backups/${SITE_URL}/wp-uploads" -type f -mtime +15  | xargs rm -fR

echo "Backup: Complete"
clear

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

# Restart Services
/usr/local/bin/enginescript/scripts/functions/alias/alias-restart.sh

echo ""
echo "============================================================="
echo ""
echo "        Domain setup completed."
echo ""
echo "        Your domain should be available now at:"
echo "        https://${SITE_URL}"
echo ""
echo "        Returning to main menu in 5 seconds."
echo ""
echo "============================================================="
echo ""
sleep 3
