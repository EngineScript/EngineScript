#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt || { echo "Error: Failed to source /usr/local/bin/enginescript/enginescript-variables.txt" >&2; exit 1; }
source /home/EngineScript/enginescript-install-options.txt || { echo "Error: Failed to source /home/EngineScript/enginescript-install-options.txt" >&2; exit 1; }

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }

# Source shared vhost functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-shared-vhost.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-shared-vhost.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# Prompt timeout settings (seconds)
WORDPRESS_PROMPT_TIMEOUT=300

# Escape arbitrary text for safe inclusion in MariaDB single-quoted string literals.
escape_sql_string_literal() {
  local input="$1"
  input="${input//\\/\\\\}"
  input="${input//\'/\'\'}"
  printf '%s' "$input"
  return
}

# Shared multi-part public suffixes for domain parsing logic.
# Keep this aligned with supported multi-part entries in VALID_TLDS.
MULTIPART_PUBLIC_SUFFIXES=(
  "co.uk" "org.uk" "gov.uk" "ac.uk"
  "com.au" "net.au" "org.au"
  "co.nz" "org.nz"
  "com.br" "com.sg" "com.my" "com.mx"
  "co.za" "com.tr" "com.hk"
)
	
validate_db_identifier() {
  local db_identifier="$1"
  local domain_context="$2"
  if [[ -z "${db_identifier}" || ! "${db_identifier}" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]]; then
    echo "Error: Invalid database name '${db_identifier}' for domain '${domain_context}'." >&2
    exit 1
  fi
}
MULTIPART_SUFFIX_CASE_PATTERN="$(IFS='|'; echo "${MULTIPART_PUBLIC_SUFFIXES[*]}")"

# Check if services are running
check_required_services

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
# IMPORTANT: Single-character domain names (e.g., 'x.com', 'a.io') MUST be accepted by this regex.
# They are fully valid under DNS and ICANN rules, and EngineScript must support them.
#
# INTENTIONAL DESIGN — DO NOT CHANGE THIS REGEX:
#   ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$
#
# The optional group `([a-z0-9-]*[a-z0-9])?` makes the entire suffix optional, which means a
# single alphanumeric character (e.g., "x") satisfies the pattern on its own.  The group is still
# required for multi-character names to prevent leading or trailing hyphens (e.g., "-bad" or
# "bad-" would not match).  Changing this back to `^[a-z0-9][a-z0-9-]*[a-z0-9]$` would silently
# reject every single-character label and break installs for legitimate one-letter domains.
#
# Rules enforced by this regex:
#   - Minimum length: 1 character (single-char labels are valid DNS labels per RFC 1035)
#   - Only lowercase letters (a-z), digits (0-9), and hyphens (-) are permitted
#   - The label must not start or end with a hyphen (per RFC 952 / RFC 1123)
#
# This is intentional behaviour. Do not "fix" it to require at least two characters.
while true; do
  read -p "Enter the domain name (e.g., 'wordpresstesting'): " DOMAIN_NAME
  if [[ "$DOMAIN_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
    echo "You entered: ${DOMAIN_NAME}"
    break
  else
    echo "Invalid domain name. Only lowercase letters, numbers, and hyphens are allowed. Hyphens cannot be at the start or end."
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

    # Common multi-part public suffixes
    "co.uk" "co.jp" "com.au" "co.nz" "com.sg" "com.my" "com.br" "com.mx" "co.za" "com.tr" "com.hk"
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

# WordPress Installation Choice
echo ""
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo "|   Installation Type                                  |"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""
echo "You can install this domain with or without WordPress."
echo ""
echo "  With WordPress:    Full LEMP stack with WordPress, database,"
echo "                     plugins, Redis caching, and backups."
echo ""
echo "  Without WordPress: Nginx vhost, SSL certificates, and a"
echo "                     placeholder page. No database or CMS."
echo ""

if prompt_yes_no "Would you like to install WordPress on this domain?" "y" "${WORDPRESS_PROMPT_TIMEOUT}"; then
  INSTALL_WORDPRESS="1"
  echo "WordPress will be installed on ${DOMAIN}."
else
  INSTALL_WORDPRESS="0"
  echo "Skipping WordPress. A placeholder page will be installed on ${DOMAIN}."
fi
echo ""
sleep 1

# Continue the installation

# Cloudflare API Settings
# Set Cloudflare settings for the domain using the Cloudflare API
configure_cloudflare_settings "${DOMAIN}"

# Create nginx vhost configuration files
create_nginx_vhost "${DOMAIN}"

# Create and install SSL certificates
create_ssl_certificate "${DOMAIN}"

# Print date for logs
echo "System Date: $(date)"

# Create backup directories
create_backup_directories "${DOMAIN}"

# Site Root
mkdir -p "/var/www/sites/${DOMAIN}/html"
cd "/var/www/sites/${DOMAIN}/html"

# Create domain log directories and files
create_domain_logs "${DOMAIN}"

if [[ "${INSTALL_WORDPRESS}" == "1" ]]; then
  #----------------------------------------------------------------------------------
  # WordPress Installation Path
  #----------------------------------------------------------------------------------

  # Domain Creation Variables
  # RAND_CHAR2 is sourced from /usr/local/bin/enginescript/enginescript-variables.txt
  PREFIX="${RAND_CHAR2}"
  domain_input="${DOMAIN}"
  IFS='.' read -r -a domain_parts <<< "${domain_input}"
  domain_without_tld="${domain_input%.*}"
  if (( ${#domain_parts[@]} >= 3 )); then
    public_suffix="${domain_parts[${#domain_parts[@]}-2]}.${domain_parts[${#domain_parts[@]}-1]}"
    case "${public_suffix}" in
      ${MULTIPART_SUFFIX_CASE_PATTERN})
      domain_without_tld="${domain_parts[${#domain_parts[@]}-3]}"
        ;;
    esac
  fi
  # RAND_CHAR4, RAND_CHAR16, and RAND_CHAR32 are random strings (length 4/16/32)
  # sourced from /usr/local/bin/enginescript/enginescript-variables.txt.
  # Enforce MySQL/MariaDB identifier max length (64 chars) before concatenation.
  db_name_suffix="_${RAND_CHAR4}"
  max_db_name_len=64
  if (( ${#db_name_suffix} >= max_db_name_len )); then
    echo "Error: Invalid random suffix length for database name generation." >&2
    exit 1
  fi
  max_domain_without_tld_len=$((max_db_name_len - ${#db_name_suffix}))
  if (( ${#domain_without_tld} > max_domain_without_tld_len )); then
    echo "Warning: Truncating database name base '${domain_without_tld}' to ${max_domain_without_tld_len} characters for domain '${DOMAIN}'." >&2
    domain_without_tld="${domain_without_tld:0:max_domain_without_tld_len}"
  fi
  database_name="${domain_without_tld}${db_name_suffix}"
  # Validate DB identifier before writing credentials file or interpolating into SQL
  validate_db_identifier "${database_name}" "${DOMAIN}"
  database_user="${RAND_CHAR16}"
  database_password="${RAND_CHAR32}"

  # Domain Database Credentials
  credentials_dir="/home/EngineScript/mysql-credentials"
  credentials_file="${credentials_dir}/${DOMAIN}.txt"
  # Ensure parent directory exists and is restricted before writing sensitive data
  # Validate generated credentials before writing any sensitive data to disk
  if [[ -z "${database_user}" || ${#database_user} -lt 8 || ${#database_user} -gt 80 || ! "${database_user}" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "Error: Invalid generated MariaDB user '${database_user}' for domain '${DOMAIN}' (must be 8-80 characters and contain only letters, numbers, or underscores)." >&2
    exit 1
  fi
  
  if [[ -z "${database_password}" || ! "${database_password}" =~ ^[A-Za-z0-9_]+$ || "${database_password}" == *"'"* || "${database_password}" == *"\\"* ]]; then
    echo "Error: Invalid generated database password for domain '${DOMAIN}'." >&2
    exit 1
  fi
  
  install -d -m 700 "${credentials_dir}"
  chmod 700 "${credentials_dir}"
  # Create the file with restrictive permissions before writing any sensitive data
  install -m 600 /dev/null "${credentials_file}"
  echo "DB=\"${database_name}\"" >> "${credentials_file}"
  echo "USR=\"${database_user}\"" >> "${credentials_file}"
  echo "PSWD=\"${database_password}\"" >> "${credentials_file}"
  echo "" >> "${credentials_file}"

  source "${credentials_file}"

  # Validate DB identifier before interpolating into SQL
  if [[ -z "${DB}" || ! "${DB}" =~ ^[A-Za-z][A-Za-z0-9_]*$ ]]; then
    echo "Error: Invalid database name '${DB}' for domain '${DOMAIN}'." >&2
    exit 1
  fi

  # Validate DB password before interpolating into SQL single-quoted string.
  # Allow printable ASCII generally, but reject characters that would break
  # single-quoted SQL interpolation without escaping (' and \).
  if [[ -z "${PSWD}" || ! "${PSWD}" =~ ^[[:print:]]+$ || "${PSWD}" == *"'"* || "${PSWD}" == *"\\"* ]]; then
    echo "Error: Invalid database password for domain '${DOMAIN}'." >&2
    exit 1
  fi

  echo "Randomly generated MySQL database credentials for ${DOMAIN}."

  local create_db_sql
  printf -v create_db_sql 'CREATE DATABASE `%s` CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci;' "${DB}"
  if ! sudo mariadb -e "${create_db_sql}"; then
    echo "Error: Failed to create database '${DB}' for domain '${DOMAIN}'." >&2
    exit 1
  fi

  local SQL_ESCAPED_PSWD
  SQL_ESCAPED_PSWD="$(escape_sql_string_literal "${PSWD}")"

  if ! sudo mariadb -e "CREATE USER '${USR}'@'localhost' IDENTIFIED BY '${SQL_ESCAPED_PSWD}';"; then
    echo "Error: Failed to create MariaDB user '${USR}' for domain '${DOMAIN}'." >&2
    exit 1
  fi

  if ! sudo mariadb -e "GRANT ALL ON \`${DB}\`.* TO '${USR}'@'localhost'; FLUSH PRIVILEGES;"; then
    echo "Error: Failed to grant privileges on database '${DB}' to user '${USR}'." >&2
    exit 1
  fi

  # Download WordPress using WP-CLI
  wp core download --allow-root
  if ! wp plugin delete hello-dolly --allow-root; then
    echo "Notice: Could not delete 'hello-dolly' via WP-CLI. This is expected on newer WordPress versions where the plugin is not installed by default. Continuing installation."
  fi

  # Create Extra WordPress Directories
  # WordPress often doesn't include these directories by default, despite them being used or checked in the Health Check plugin.
  create_extra_wp_dirs "${DOMAIN}"

  # Create wp-config.php
  cp -rf /usr/local/bin/enginescript/config/var/www/wordpress/wp-config.php "/var/www/sites/${DOMAIN}/html/wp-config.php"
  sed -i "s|SEDWPDB|${DB}|g" "/var/www/sites/${DOMAIN}/html/wp-config.php"
  sed -i "s|SEDWPUSER|${USR}|g" "/var/www/sites/${DOMAIN}/html/wp-config.php"
  sed -i "s|SEDWPPASS|${PSWD}|g" "/var/www/sites/${DOMAIN}/html/wp-config.php"
  sed -i "s|SEDPREFIX|${PREFIX}|g" "/var/www/sites/${DOMAIN}/html/wp-config.php"
  sed -i "s|SEDURL|${DOMAIN}|g" "/var/www/sites/${DOMAIN}/html/wp-config.php"

  # Configure Redis for WordPress
  configure_redis "${DOMAIN}" "/var/www/sites/${DOMAIN}/html/wp-config.php"

  # WP Salt Creation
  fetch_wp_salts "/var/www/sites/${DOMAIN}/html/wp-config.php"

  # Configure wp-config.php settings
  configure_wpconfig_settings "${DOMAIN}" "/var/www/sites/${DOMAIN}/html/wp-config.php"

  # Create robots.txt file
  create_robots_txt "${DOMAIN}" "/var/www/sites/${DOMAIN}/html"

  # WP File Permissions
  find "/var/www/sites/${DOMAIN}" -type d -print0 | sudo xargs -0 chmod 0755
  find "/var/www/sites/${DOMAIN}" -type f -print0 | sudo xargs -0 chmod 0644
  chown -R www-data:www-data "/var/www/sites/${DOMAIN}"
  chmod +x "/var/www/sites/${DOMAIN}/html/wp-cron.php"
  chmod 600 "/var/www/sites/${DOMAIN}/html/wp-config.php"

  # WP-CLI Finalizing Install
  clear
  echo "============================================="
  echo "Finalizing ${DOMAIN} Install:"
  echo "============================================="

  # WP-CLI Install WordPress
  cd "/var/www/sites/${DOMAIN}/html"

  # Validate WordPress admin credentials before install
  if [[ -z "${WP_ADMIN_USERNAME}" || -z "${WP_ADMIN_PASSWORD}" || -z "${WP_ADMIN_EMAIL}" ]]; then
      echo "Error: WP admin credentials must not be empty (WP_ADMIN_USERNAME, WP_ADMIN_PASSWORD, WP_ADMIN_EMAIL)." >&2
      exit 1
  fi

  # Username: 3-60 chars, must start with alphanumeric, letters/numbers/underscore/dot/hyphen
  # Use explicit length checks for clarity and maintainability, then validate allowed characters.
  if [[ ${#WP_ADMIN_USERNAME} -lt 3 || ${#WP_ADMIN_USERNAME} -gt 60 ]]; then
      echo "Error: WP_ADMIN_USERNAME must be between 3 and 60 characters long." >&2
      exit 1
  fi

  if [[ ! "${WP_ADMIN_USERNAME}" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
      echo "Error: WP_ADMIN_USERNAME is invalid. Use letters, numbers, underscore, dot, or hyphen, and start with a letter or number." >&2
      exit 1
  fi

  # Email: basic format validation (practical, non-RFC-complete).
  # Accepts common addresses like a@example.com and user.name+tag@example.co.uk.
  EMAIL_REGEX='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
  if [[ ! "${WP_ADMIN_EMAIL}" =~ ${EMAIL_REGEX} ]]; then
      echo "Error: WP_ADMIN_EMAIL is not a valid email address format." >&2
      exit 1
  fi

  # Password: minimum complexity requirements
  if [[ ${#WP_ADMIN_PASSWORD} -lt 12 ]] || \
     [[ ! "${WP_ADMIN_PASSWORD}" =~ [A-Z] ]] || \
     [[ ! "${WP_ADMIN_PASSWORD}" =~ [a-z] ]] || \
     [[ ! "${WP_ADMIN_PASSWORD}" =~ [0-9] ]] || \
     [[ ! "${WP_ADMIN_PASSWORD}" =~ [^A-Za-z0-9] ]]; then
      echo "Error: WP_ADMIN_PASSWORD must be at least 12 characters and include uppercase, lowercase, number, and special character." >&2
      exit 1
  fi

  wp core install --admin_user="${WP_ADMIN_USERNAME}" --admin_password="${WP_ADMIN_PASSWORD}" --admin_email="${WP_ADMIN_EMAIL}" --url="https://${DOMAIN}" --title='New Site' --skip-email --allow-root

  # Install and activate required WordPress plugins
  install_required_wp_plugins

  # Install extra WordPress plugins if enabled
  if [[ "${INSTALL_EXTRA_WP_PLUGINS}" == "1" ]]; then
      install_extra_wp_plugins
  else
      echo "Skipping extra WordPress plugins installation (disabled in config)..."
  fi

  # Install EngineScript custom plugins if enabled
  install_enginescript_custom_plugins "${DOMAIN}"

  # Clear WordPress caches, transients, and rewrite rules
  clear_wordpress_caches

  # Enable Redis Cache via WP-CLI
  if wp plugin is-active redis-cache --allow-root; then
    echo "Enabling Redis object cache..."
    wp redis enable --allow-root
  else
    echo "Warning: Redis Cache plugin not active. Skipping 'wp redis enable'."
  fi

  # WP-CLI set permalink structure for FastCGI Cache
  wp option get permalink_structure --allow-root
  wp option update permalink_structure '/%category%/%postname%/' --allow-root
  flush_wordpress_rewrites

  # Setting Permissions Again
  # For whatever reason, using WP-CLI to install plugins with --allow-root reassigns
  # the ownership of the /uploads, /upgrade, and plugin directories to root:root.
  cd "/var/www/sites/${DOMAIN}"
  chown -R www-data:www-data "/var/www/sites/${DOMAIN}"
  chmod +x "/var/www/sites/${DOMAIN}/html/wp-cron.php"
  find "/var/www/sites/${DOMAIN}" -type d -print0 | sudo xargs -0 chmod 0755
  find "/var/www/sites/${DOMAIN}" -type f -print0 | sudo xargs -0 chmod 0644
  chmod 600 "/var/www/sites/${DOMAIN}/html/wp-config.php"

  clear

  # Perform site backup
  perform_site_backup "${DOMAIN}" "/var/www/sites/${DOMAIN}/html"

  # Display final credentials summary
  display_credentials_summary "${DOMAIN}" "${DB}" "${PREFIX}" "${USR}" "${PSWD}"

else
  #----------------------------------------------------------------------------------
  # Non-WordPress Installation Path (Placeholder Page)
  #----------------------------------------------------------------------------------

  echo "Installing placeholder page for ${DOMAIN}..."

  # Install placeholder page
  cp -f /usr/local/bin/enginescript/config/var/www/placeholder/index.html "/var/www/sites/${DOMAIN}/html/index.html"
  sed -i "s|YOURDOMAIN|${DOMAIN}|g" "/var/www/sites/${DOMAIN}/html/index.html"

  # Set file permissions
  find "/var/www/sites/${DOMAIN}" -type d -print0 | sudo xargs -0 chmod 0755
  find "/var/www/sites/${DOMAIN}" -type f -print0 | sudo xargs -0 chmod 0644
  chown -R www-data:www-data "/var/www/sites/${DOMAIN}"

  # Backup nginx vhost and SSL keys
  BACKUP_DATE_HOUR=$(date +%m-%d-%Y-%H)
  gzip -cf "/etc/nginx/sites-enabled/${DOMAIN}.conf" > "/home/EngineScript/site-backups/${DOMAIN}/nginx/${BACKUP_DATE_HOUR}-nginx-vhost.conf.gz"
  tar -zcf "/home/EngineScript/site-backups/${DOMAIN}/ssl-keys/${BACKUP_DATE_HOUR}-ssl-keys.gz" "/etc/nginx/ssl/${DOMAIN}"

  clear

  echo ""
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo "|${BOLD} Domain Summary (No WordPress)${NORMAL}                       |"
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo ""
  echo "${BOLD}URL:${NORMAL}               ${DOMAIN}"
  echo ""
  echo "Site root:         /var/www/sites/${DOMAIN}/html"
  echo "Nginx vhost:       /etc/nginx/sites-enabled/${DOMAIN}.conf"
  echo "SSL certificates:  /etc/nginx/ssl/${DOMAIN}/"
  echo "Backups:           /home/EngineScript/site-backups/${DOMAIN}/"
  echo ""
  echo "A placeholder page has been installed. Replace"
  echo "/var/www/sites/${DOMAIN}/html/index.html with your own content."
  echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
  echo ""
  sleep 3
fi

# Restart Services
/usr/local/bin/enginescript/scripts/functions/alias/alias-restart.sh

echo ""
echo "============================================================="
echo ""
echo "        Domain setup completed."
echo ""
echo "        Your domain should be available now at:"
echo "        https://${DOMAIN}"
echo ""
echo "        Returning to main menu in 5 seconds."
echo ""
echo "============================================================="
echo ""
sleep 5
