#!/bin/bash

# Source EngineScript variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Create temp file with date stamp
DEBUG_FILE="/tmp/enginescript-debug-$(date +%Y%m%d-%H%M%S).md"

# ANSI color codes
BOLD="\e[1m"
NORMAL="\e[0m"
GREEN="\e[32m"
YELLOW="\e[33m"

# Persistent error log path
ERROR_LOG="/var/log/EngineScript/install-error-log.txt"

# Function to log errors to persistent error log
log_error() {
    echo -e "$1" >> "$ERROR_LOG"
}

# Function to write to both console, file, and error log if applicable
debug_print() {
    echo -e "$1"
    echo -e "$2" >> "$DEBUG_FILE"
    if [[ "$1" == *"ERROR"* || "$1" == *"FAILED"* ]]; then
        log_error "$1"
    fi
}

# Get server info from alias-server-info.sh functions
get_server_info() {
    # System Info
    BIT_TYPE=$(getconf LONG_BIT)
    CPU_COUNT=$(nproc)
    SERVER_MEMORY_TOTAL_100=$(free -m | awk '/^Mem:/{print $2}')
    IP_ADDRESS=$(hostname -I | awk '{print $1}')
    UBUNTU_TYPE=$(lsb_release -i | cut -f2)
    UBUNTU_VERSION=$(lsb_release -r | cut -f2)
    UBUNTU_CODENAME=$(lsb_release -c | cut -f2)
    
    # CPU Info
    if ! CPU_INFO=$(lscpu | grep -E "^Model name:" | cut -d":" -f2 | xargs); then
        debug_print "ERROR: Failed to retrieve CPU model information." "ERROR: Failed to retrieve CPU model information."
    fi
    CPU_CORES=$(nproc)
    CPU_FREQ=$(lscpu | grep -E "^CPU MHz:" | cut -d":" -f2 | xargs)
    
    # Memory Info
    TOTAL_RAM=$(free -h | awk '/^Mem:/ {print $2}')
    USED_RAM=$(free -h | awk '/^Mem:/ {print $3}')
    FREE_RAM=$(free -h | awk '/^Mem:/ {print $4}')
    SWAP_TOTAL=$(free -h | awk '/^Swap:/ {print $2}')
    SWAP_USED=$(free -h | awk '/^Swap:/ {print $3}')
    
    # Disk Info
    ROOT_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    ROOT_USED=$(df -h / | awk 'NR==2 {print $3}')
    ROOT_FREE=$(df -h / | awk 'NR==2 {print $4}')
    ROOT_PCENT=$(df -h / | awk 'NR==2 {print $5}')
    
    # Load Average
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    
    # Network Info
    NETWORK_INFO=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1')
}

# Start debug report
debug_print "\n# EngineScript Debug Report\n" "# EngineScript Debug Report\n"
debug_print "Generated: $(date '+%Y-%m-%d %H:%M:%S')\n" "Generated: $(date '+%Y-%m-%d %H:%M:%S')\n"

# Get server info
get_server_info

# Basic Information
debug_print "## Basic Information\n" "## Basic Information\n"
debug_print "| Component | Value |" "| Component | Value |"
debug_print "|-----------|--------|" "|-----------|--------|"
debug_print "Variables File Date | ${VARIABLES_DATE}" "| Variables File Date | \`${VARIABLES_DATE}\` |"
debug_print "Architecture | ${BIT_TYPE}-bit" "| Architecture | \`${BIT_TYPE}-bit\` |"
debug_print "Ubuntu Version | ${UBUNTU_TYPE} ${UBUNTU_VERSION} (${UBUNTU_CODENAME})" "| Ubuntu Version | \`${UBUNTU_TYPE} ${UBUNTU_VERSION} (${UBUNTU_CODENAME})\` |"

# System Information
debug_print "\n## System Information\n" "\n## System Information\n"
debug_print "| Component | Details |" "| Component | Details |"
debug_print "|-----------|----------|" "|-----------|----------|"
debug_print "Hostname | $(hostname)" "| Hostname | \`$(hostname)\` |"
debug_print "IP Address | ${IP_ADDRESS}" "| IP Address | \`${IP_ADDRESS}\` |"
debug_print "CPU Model | ${CPU_INFO}" "| CPU Model | \`${CPU_INFO}\` |"
debug_print "CPU Cores | ${CPU_CORES}" "| CPU Cores | \`${CPU_CORES}\` |"

# Network Information
debug_print "\n## Network Information\n" "\n## Network Information\n"
debug_print "### IP Addresses\n" "### IP Addresses\n"
debug_print "| Interface | IP Address |" "| Interface | IP Address |"
debug_print "|-----------|------------|" "|-----------|------------|"
ip -4 addr show | grep inet | while read -r line; do
    IFACE=$(echo "$line" | awk '{print $NF}')
    IP=$(echo "$line" | awk '{print $2}' | cut -d/ -f1)
    debug_print "${IFACE} | ${IP}" "| ${IFACE} | \`${IP}\` |"
done

debug_print "\n\n"

debug_print "\n### Active Ports\n" "### Active Ports\n"
debug_print "\`\`\`" "\`\`\`"
debug_print "$(netstat -tuln | grep LISTEN)" "$(netstat -tuln | grep LISTEN)"
debug_print "\`\`\`\n" "\`\`\`\n"

# Memory Information
debug_print "\n## Memory Information\n" "\n## Memory Information\n"
debug_print "| Type | Total | Used | Free |" "| Type | Total | Used | Free |"
debug_print "|------|-------|------|------|" "|------|-------|------|------|"
debug_print "RAM | ${TOTAL_RAM} | ${USED_RAM} | ${FREE_RAM}" "| RAM | \`${TOTAL_RAM}\` | \`${USED_RAM}\` | \`${FREE_RAM}\` |"
debug_print "Swap | ${SWAP_TOTAL} | ${SWAP_USED} | N/A" "| Swap | \`${SWAP_TOTAL}\` | \`${SWAP_USED}\` | \`N/A\` |"

# Disk Information
debug_print "\n## Disk Information\n" "\n## Disk Information\n"
debug_print "| Mount | Total | Used | Free | Usage |" "| Mount | Total | Used | Free | Usage |"
debug_print "|-------|-------|------|------|-------|" "|-------|-------|------|------|-------|"
debug_print "Root (/) | ${ROOT_TOTAL} | ${ROOT_USED} | ${ROOT_FREE} | ${ROOT_PCENT}" "| Root (/) | \`${ROOT_TOTAL}\` | \`${ROOT_USED}\` | \`${ROOT_FREE}\` | \`${ROOT_PCENT}\` |"

# Configuration Review
debug_print "\n## Configuration Review\n" "\n## Configuration Review\n"

# EngineScript Install Options
debug_print "### EngineScript Install Options\n" "### EngineScript Install Options\n"
debug_print "| Option | Value |" "| Option | Value |"
debug_print "|--------|--------|" "|--------|--------|"
debug_print "Admin Subdomain | ${ADMIN_SUBDOMAIN}" "| Admin Subdomain | \`${ADMIN_SUBDOMAIN}\` |"
debug_print "Auto Image Optimization | ${AUTOMATIC_LOSSLESS_IMAGE_OPTIMIZATION}" "| Auto Image Optimization | \`${AUTOMATIC_LOSSLESS_IMAGE_OPTIMIZATION}\` |"
debug_print "Auto Emergency Updates | ${ENGINESCRIPT_AUTO_EMERGENCY_UPDATES}" "| Auto Emergency Updates | \`${ENGINESCRIPT_AUTO_EMERGENCY_UPDATES}\` |"
debug_print "Auto Update | ${ENGINESCRIPT_AUTO_UPDATE}" "| Auto Update | \`${ENGINESCRIPT_AUTO_UPDATE}\` |"
debug_print "Install Adminer | ${INSTALL_ADMINER}" "| Install Adminer | \`${INSTALL_ADMINER}\` |"
debug_print "Expanded PHP | ${INSTALL_EXPANDED_PHP}" "| Expanded PHP | \`${INSTALL_EXPANDED_PHP}\` |"
debug_print "HTTP/3 | ${INSTALL_HTTP3}" "| HTTP/3 | \`${INSTALL_HTTP3}\` |"
debug_print "phpMyAdmin | ${INSTALL_PHPMYADMIN}" "| phpMyAdmin | \`${INSTALL_PHPMYADMIN}\` |"
debug_print "Secure Admin | ${NGINX_SECURE_ADMIN}" "| Secure Admin | \`${NGINX_SECURE_ADMIN}\` |"
debug_print "Show Header | ${SHOW_ENGINESCRIPT_HEADER}" "| Show Header | \`${SHOW_ENGINESCRIPT_HEADER}\` |"

# Backup Settings
debug_print "\n### Backup Configuration\n" "\n### Backup Configuration\n"
debug_print "| Backup Type | Enabled |" "| Backup Type | Enabled |"
debug_print "|-------------|----------|" "|-------------|----------|"
debug_print "Daily Local DB | ${DAILY_LOCAL_DATABASE_BACKUP}" "| Daily Local DB | \`${DAILY_LOCAL_DATABASE_BACKUP}\` |"
debug_print "Hourly Local DB | ${HOURLY_LOCAL_DATABASE_BACKUP}" "| Hourly Local DB | \`${HOURLY_LOCAL_DATABASE_BACKUP}\` |"
debug_print "Weekly Local wp-content | ${WEEKLY_LOCAL_WPCONTENT_BACKUP}" "| Weekly Local wp-content | \`${WEEKLY_LOCAL_WPCONTENT_BACKUP}\` |"
debug_print "S3 Backup Enabled | ${INSTALL_S3_BACKUP}" "| S3 Backup Enabled | \`${INSTALL_S3_BACKUP}\` |"
debug_print "Daily S3 DB | ${DAILY_S3_DATABASE_BACKUP}" "| Daily S3 DB | \`${DAILY_S3_DATABASE_BACKUP}\` |"
debug_print "Hourly S3 DB | ${HOURLY_S3_DATABASE_BACKUP}" "| Hourly S3 DB | \`${HOURLY_S3_DATABASE_BACKUP}\` |"
debug_print "Weekly S3 wp-content | ${WEEKLY_S3_WPCONTENT_BACKUP}" "| Weekly S3 wp-content | \`${WEEKLY_S3_WPCONTENT_BACKUP}\` |"

# Software Versions
debug_print "\n## Software Versions\n" "\n## Software Versions\n"
debug_print "| Software | Version |" "| Software | Version |"
debug_print "|----------|----------|" "|----------|----------|"
debug_print "MariaDB | ${MARIADB_VER}" "| MariaDB | \`${MARIADB_VER}\` |"
debug_print "NGINX | ${NGINX_VER}" "| NGINX | \`${NGINX_VER}\` |"
debug_print "OpenSSL | ${OPENSSL_VER}" "| OpenSSL | \`${OPENSSL_VER}\` |"
debug_print "PCRE2 | ${PCRE2_VER}" "| PCRE2 | \`${PCRE2_VER}\` |"
debug_print "PHP | ${PHP_VER}" "| PHP | \`${PHP_VER}\` |"
debug_print "phpMyAdmin | ${PHPMYADMIN_VER}" "| phpMyAdmin | \`${PHPMYADMIN_VER}\` |"
debug_print "Zlib | ${ZLIB_VER}" "| Zlib | \`${ZLIB_VER}\` |"

# NGINX Details
debug_print "\n### NGINX Configuration\n" "\n### NGINX Configuration\n"
debug_print "\`\`\`" "\`\`\`"
NGINX_INFO=$(nginx -V 2>&1)
debug_print "${NGINX_INFO}" "${NGINX_INFO}"
debug_print "\`\`\`\n" "\`\`\`\n"

debug_print "#### NGINX Modules\n" "#### NGINX Modules\n"
debug_print "\`\`\`" "\`\`\`"
NGINX_MODULES=$(nginx -V 2>&1 | grep -oP "(?<=--with-)[^\s]+")
debug_print "${NGINX_MODULES}" "${NGINX_MODULES}"
debug_print "\`\`\`\n" "\`\`\`\n"

debug_print "#### NGINX Configuration Test\n" "#### NGINX Configuration Test\n"
if ! nginx -t 2>&1; then
    debug_print "ERROR: NGINX configuration test failed." "ERROR: NGINX configuration test failed."
fi
debug_print "\`\`\`" "\`\`\`"
NGINX_TEST=$(nginx -t 2>&1)
debug_print "${NGINX_TEST}" "${NGINX_TEST}"
debug_print "\`\`\`\n" "\`\`\`\n"

debug_print "#### NGINX Security Properties\n" "#### NGINX Security Properties\n"
debug_print "\`\`\`json" "\`\`\`json"
debug_print "$(checksec --format=json --file=/usr/sbin/nginx --extended | jq -r)" "$(checksec --format=json --file=/usr/sbin/nginx --extended | jq -r)"
debug_print "\`\`\`\n" "\`\`\`\n"

# PHP Details
debug_print "\n### PHP Configuration\n" "\n### PHP Configuration\n"
debug_print "Version:\n\`\`\`" "Version:\n\`\`\`"
debug_print "$(php -version)" "$(php -version)"
debug_print "\`\`\`\n" "\`\`\`\n"

debug_print "Loaded Modules:\n\`\`\`" "Loaded Modules:\n\`\`\`"
debug_print "$(php -m)" "$(php -m)"
debug_print "\`\`\`\n" "\`\`\`\n"

# Database Versions
debug_print "\n### Database Versions\n" "\n### Database Versions\n"
debug_print "MariaDB: $(mariadb -V)" "MariaDB: \`$(mariadb -V)\`"
debug_print "Redis: $(redis-server --version)" "Redis: \`$(redis-server --version)\`"

# Service Status
debug_print "\n## Service Status\n" "\n## Service Status\n"
debug_print "| Service | Status |" "| Service | Status |"
debug_print "|---------|---------|" "|---------|---------|"
services=("nginx" "php8.3-fpm" "mariadb" "redis-server")
for service in "${services[@]}"; do
    status=$(systemctl is-active "$service")
    if [ "$status" = "active" ]; then
        debug_print "${service} | ${GREEN}${status}${NORMAL}" "| ${service} | 🟢 \`${status}\` |"
    else
        debug_print "${service} | ${YELLOW}${status}${NORMAL}" "| ${service} | 🟡 \`${status}\` |"
    fi
done

# Website Status
debug_print "\n## Website Status\n" "\n## Website Status\n"
debug_print "| Domain | Status |" "| Domain | Status |"
debug_print "|--------|---------|" "|--------|---------|"

# Store first domain for header sample
first_domain=""

while IFS= read -r site; do
    # Get full domain name
    domain=$(basename "$(dirname "$site")")
    
    # Store first domain encountered
    if [ -z "$first_domain" ]; then
        first_domain="$domain"
    fi
    
    # Get HTTP status
    curl_result=$(curl -sL -w "%{http_code}" "https://$domain" -o /dev/null 2>/dev/null)
    
    # Set status emoji
    case $curl_result in
        200) status_emoji="🟢" ;;
        301|302) status_emoji="🔄" ;;
        404) status_emoji="🟡" ;;
        *) status_emoji="🔴" ;;
    esac
    
    # Print domain and status
    debug_print "$domain | $status_emoji HTTP $curl_result" "| $domain | $status_emoji \`HTTP $curl_result\` |"
done < <(find /var/www/sites/*/html -maxdepth 0 -type d 2>/dev/null)

debug_print "\n\n"

# Show sample headers from first domain
if [ -n "$first_domain" ]; then
    debug_print "\n### Sample HTTP Headers\n" "\n### Sample HTTP Headers\n"
    debug_print "Below is a sample of HTTP headers from \`$first_domain\`. Other domains may have different configurations.\n" "Below is a sample of HTTP headers from \`$first_domain\`. Other domains may have different configurations.\n"
    debug_print "To check headers for other domains, use: \`curl -I https://domain.com\`\n" "To check headers for other domains, use: \`curl -I https://domain.com\`\n"
    debug_print "\`\`\`" "\`\`\`"
    debug_print "$(curl -sI "https://$first_domain" 2>/dev/null)" "$(curl -sI "https://$first_domain" 2>/dev/null)"
    debug_print "\`\`\`\n" "\`\`\`\n"
fi

# Final instructions
debug_print "\nDebug report has been saved to: ${DEBUG_FILE}" ""
debug_print "\nTo view the formatted report:" ""
debug_print "cat ${DEBUG_FILE}" ""
debug_print "\nTo copy to clipboard (if xclip is installed):" ""
debug_print "cat ${DEBUG_FILE} | xclip -selection clipboard" ""

# Add GitHub issue template
cat << 'EOF' >> "$DEBUG_FILE"

## Additional Information
<!-- Please provide any additional context about the issue you're experiencing -->

## Steps to Reproduce
1. 
2. 
3. 

## Expected Behavior
<!-- What did you expect to happen? -->

## Actual Behavior
<!-- What actually happened? -->
EOF

# Append install error log if it exists
if [ -f /var/log/EngineScript/install-error-log.txt ]; then
    echo -e "\n## EngineScript Install Error Log (Full Contents)\n" >> "$DEBUG_FILE"
    cat /var/log/EngineScript/install-error-log.txt >> "$DEBUG_FILE"
fi
