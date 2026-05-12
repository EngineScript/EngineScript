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

# Source shared database credential functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-db-credentials.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-db-credentials.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# --- Define Fixed Import Paths ---
IMPORT_BASE_DIR="/home/EngineScript/temp/site-import"
WP_EXTRACTED_PATH="${IMPORT_BASE_DIR}/extracted-root" # Temporary path for extracted files
WP_FILES_EXTRACTED_PATH="${IMPORT_BASE_DIR}/extracted-files" # Temporary path for nested files archives

# EngineScript combined site archive format (v1)
# Keep this contract aligned with the EngineScript Site Exporter WordPress plugin:
#   - The user places exactly one outer .zip file in IMPORT_BASE_DIR.
#   - The ZIP must contain manifest.txt, database/<dump>.sql.gz, and files/<wordpress-files>.tar.gz.
#   - This is the only supported import format. Keep the WordPress plugin exporter identical.

# Note: ALLOWED_DB_CHARSETS is now defined in enginescript-db-credentials.sh

# Build the default URL validation regex from documented components.
# Pattern intent:
# - scheme: http:// or https://
# - host: one or more DNS labels separated by dots
# - port: optional :<1-5 digits>
# - suffix: optional path/query/fragment beginning with /, ?, or #
build_default_url_validation_regex() {
  local scheme='https?://'
  local host_label='[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
  local host="(${host_label}\\.)*${host_label}"
  local port='(:[0-9]{1,5})?'
  local suffix='([/?#].*)?'

  echo "^${scheme}${host}${port}${suffix}$"
  return 0
}

readonly DEFAULT_URL_VALIDATION_REGEX="$(build_default_url_validation_regex)"
URL_VALIDATION_REGEX="${URL_VALIDATION_REGEX:-$DEFAULT_URL_VALIDATION_REGEX}"

# Validate ZIP archive entries to prevent path traversal (Zip Slip)
validate_zip_archive_paths() {
    local archive_file="$1"
    local entry=""
    local archive_entries=""

    if ! archive_entries="$(unzip -Z -1 "$archive_file")"; then
        echo "FAILED: Could not read ZIP archive ${archive_file}"
        return 1
    fi

    while IFS= read -r entry; do
        # Reject absolute paths and parent-directory traversal segments
        if [[ "$entry" == /* ]] || [[ "$entry" =~ (^|/)\.\.(\/|$) ]]; then
            echo "FAILED: Unsafe path detected in archive ${archive_file}: ${entry}"
            return 1
        fi
    done <<< "$archive_entries"

    return 0
}

# Validate tar archive entries before extraction. The exporter stores WordPress files in
# files/<site>_files_<timestamp>.tar.gz inside the outer combined ZIP.
validate_tar_archive_paths() {
    local archive_file="$1"
    local entry=""
    local archive_entries=""

    if ! archive_entries="$(tar -tzf "$archive_file")"; then
        echo "FAILED: Could not read tar archive ${archive_file}"
        return 1
    fi

    while IFS= read -r entry; do
        # Reject absolute paths and parent-directory traversal segments
        if [[ "$entry" == /* ]] || [[ "$entry" =~ (^|/)\.\.(\/|$) ]]; then
            echo "FAILED: Unsafe path detected in archive ${archive_file}: ${entry}"
            return 1
        fi
    done <<< "$archive_entries"

    return 0
}

# Print the directory containing wp-config.php for a WordPress file tree.
find_wordpress_files_source_path() {
    local search_root="$1"
    local wp_config_rel_path=""
    local wp_config_dir=""

    wp_config_rel_path=$(find "${search_root}" -name "wp-config.php" -printf "%P\n" | sort | head -n 1)
    if [[ -z "${wp_config_rel_path}" ]]; then
        return 1
    fi

    wp_config_dir="$(dirname "${wp_config_rel_path}")"
    if [[ "${wp_config_dir}" == "." ]]; then
        echo "${search_root}"
    else
        echo "${search_root}/${wp_config_dir}"
    fi

    return 0
}

# --- Instructions for Preparing Files ---
echo ""
echo "${BOLD}Preparing Files for Import:${NORMAL}"
echo "---------------------------------------------------------------------"
echo "This import process accepts one combined EngineScript site archive:"
echo ""
echo "${BOLD}Single Combined Export File (EngineScript Site Exporter format)${NORMAL}"
echo "   - Use a single .zip file containing both WordPress files and one database dump."
echo "   - The current EngineScript shell exporter writes:"
echo "       manifest.txt"
echo "       database/<site>_db_<timestamp>.sql.gz"
echo "       files/<site>_files_<timestamp>.tar.gz"
echo "   - ${YELLOW}If you don't have the plugin on your source site:${NORMAL}"
echo "     1. Download the plugin zip from: ${UNDERLINE}https://github.com/EngineScript/enginescript-site-exporter/releases/latest${NORMAL}"
echo "     2. In your source WordPress admin area, go to 'Plugins' -> 'Add New' -> 'Upload Plugin'."
echo "     3. Upload the downloaded .zip file and activate the 'EngineScript Site Exporter' plugin."
echo "   - Once the plugin is active on your source site:"
echo "     1. Go to 'Tools' -> 'Site Exporter' in your WordPress admin."
echo "     2. Click the 'Export Site' button."
echo "     3. Download the generated .zip file (e.g., site_export_es_se_... .zip)."
echo "   - Place this single downloaded .zip file directly inside the following directory on the EngineScript server:"
echo "     \`${IMPORT_BASE_DIR}\`"
echo "     (Ensure only this one .zip file is present in ${IMPORT_BASE_DIR})"
echo "   - Only this canonical single-archive format is supported."
echo "---------------------------------------------------------------------"
prompt_continue "Press [Enter] when your files are prepared and ready" 600
# --- End Instructions ---

# Check if services are running
check_required_services

# Intro Warning
echo ""
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo "|   Domain Import                                     |"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""
echo "This script will import an existing WordPress site."
echo "Please ensure the following:"
echo "  1. Exactly one combined EngineScript site export .zip is placed in:"
echo "     ${IMPORT_BASE_DIR}"
echo "  2. The combined .zip contains manifest.txt, database/*.sql.gz, and files/*.tar.gz."
echo ""
sleep 1

# --- Function Definitions ---

# Escape a string so it can be safely embedded as a literal inside a sed/grep -E pattern.
# Escaped characters:
#   [](){}.^$*+?|\\/-
# These are ERE metacharacters or delimiter-sensitive characters in this sed usage.
escape_ere_literal_for_sed() {
    local raw="$1"
    printf '%s' "$raw" | sed -E 's#[][(){}.^$*+?|\\/-]#\\&#g'
    return 0
}

# Function to extract define values (Handles single/double quotes)
extract_define() {
    local key="$1"
    local escaped_key
    escaped_key=$(escape_ere_literal_for_sed "$key")
    # Find the line defining the key
    local line
    line=$(grep -E "^\s*define\(\s*['\"]${escaped_key}['\"]\s*," "$WP_CONFIG_PATH")
    # Extract the value between single or double quotes after the comma
    local value
    value=$(echo "$line" | sed -E "s/.*,\s*['\"]([^'\"]*)['\"].*/\1/")
    echo "$value"
}

# Function to extract table prefix from the database dump file
extract_prefix_from_db() {
    local db_file="$1"
    local prefix=""
    local grep_cmd="grep"
    # Look for CREATE TABLE or INSERT INTO lines with common tables (_options or _users)
    # Capture the table name between backticks/quotes, then strip _options/_users to derive prefix
    local search_pattern="(CREATE TABLE|INSERT INTO)[[:space:]]+(\`|\")[^\`\"]+_(options|users)(\`|\")"
    # NOTE: [^\`\"]+ intentionally allows hyphens and other characters valid in MySQL table names,
    # broadening the previous [a-zA-Z0-9_]+ which would miss prefixes like "my-site_".
    local table_name=""

    # Use zgrep for .gz, grep for .sql.
    if [[ "$db_file" == *.gz ]]; then
        grep_cmd="zgrep"
    fi
    table_name=$("$grep_cmd" -m 1 -oE "${search_pattern}" "$db_file" | head -n 1)

    if [[ -n "$table_name" ]]; then
        # Keep only the quoted/backticked table identifier token (last whitespace-delimited field)
        table_name="${table_name##* }"
        # Remove surrounding quote/backtick and known suffix
        table_name="${table_name%\`}"
        table_name="${table_name%\"}"
        table_name="${table_name#\`}"
        table_name="${table_name#\"}"
        prefix="${table_name%_options}"
        prefix="${prefix%_users}"
    fi

    if [[ -n "$prefix" ]]; then
        # Ensure it ends with an underscore if it doesn't already
        if [[ "${prefix: -1}" != "_" ]]; then
            prefix="${prefix}_"
        fi
    else
         echo "Warning: Could not find common table pattern (like 'prefix_options') in the DB file." >&2 # Output warning to stderr
    fi

    # Return the extracted prefix (might be empty if not found)
    echo "$prefix" # This is the only echo that should output the final prefix
}

# --- Validate Import Paths and Files ---
echo "Validating import directories and files..."

COMBINED_ARCHIVE_FILE=""
DB_SOURCE_PATH=""
WP_FILES_SOURCE_PATH=""
WP_FILES_ARCHIVE_PATH=""
MANIFEST_PATH=""

mapfile -d '' -t COMBINED_ARCHIVE_CANDIDATES < <(find "${IMPORT_BASE_DIR}" -maxdepth 1 -type f -name "*.zip" -print0 | sort -z)
COMBINED_ARCHIVE_COUNT=${#COMBINED_ARCHIVE_CANDIDATES[@]}

if [[ "${COMBINED_ARCHIVE_COUNT}" -ne 1 ]]; then
    echo "FAILED: Could not detect a valid combined import archive."
    echo "Please place exactly one EngineScript site export .zip directly in:"
    echo "  ${IMPORT_BASE_DIR}"
    echo ""
    echo "The archive must contain manifest.txt, database/*.sql.gz, and files/*.tar.gz."
    exit 1
fi

COMBINED_ARCHIVE_FILE="${COMBINED_ARCHIVE_CANDIDATES[0]}"
echo "PASSED: Detected combined EngineScript site archive: ${COMBINED_ARCHIVE_FILE}"

# --- Extraction Step ---
echo "Extracting combined archive content..."
# Clean up any previous extraction attempt
rm -rf "${WP_EXTRACTED_PATH}" "${WP_FILES_EXTRACTED_PATH}"
mkdir -p "${WP_EXTRACTED_PATH}"

EXTRACT_STATUS=1 # Default to failure

echo "Extracting combined zip file: ${COMBINED_ARCHIVE_FILE}"
if validate_zip_archive_paths "${COMBINED_ARCHIVE_FILE}"; then
    unzip -q "${COMBINED_ARCHIVE_FILE}" -d "${WP_EXTRACTED_PATH}"
    EXTRACT_STATUS=$?
else
    EXTRACT_STATUS=1
fi

# Check Extraction Status
if [[ $EXTRACT_STATUS -ne 0 ]]; then
    echo "FAILED: Extraction process failed."
    rm -rf "${WP_EXTRACTED_PATH}" "${WP_FILES_EXTRACTED_PATH}" # Clean up failed extraction
    exit 1
fi

# Validate the canonical bundle layout. The WordPress plugin should write the same
# structure as vhost-export.sh so the import path stays intentionally narrow.
MANIFEST_PATH="${WP_EXTRACTED_PATH}/manifest.txt"
if [[ ! -f "${MANIFEST_PATH}" ]]; then
    echo "FAILED: manifest.txt not found at the root of the combined archive."
    rm -rf "${WP_EXTRACTED_PATH}" "${WP_FILES_EXTRACTED_PATH}"
    exit 1
fi

if ! grep -Fxq "format=enginescript-site-archive" "${MANIFEST_PATH}"; then
    echo "FAILED: manifest.txt does not identify an EngineScript site archive."
    rm -rf "${WP_EXTRACTED_PATH}" "${WP_FILES_EXTRACTED_PATH}"
    exit 1
fi

if ! grep -Fxq "version=1" "${MANIFEST_PATH}"; then
    echo "FAILED: Unsupported EngineScript site archive manifest version."
    rm -rf "${WP_EXTRACTED_PATH}" "${WP_FILES_EXTRACTED_PATH}"
    exit 1
fi

if [[ ! -d "${WP_EXTRACTED_PATH}/database" ]]; then
    echo "FAILED: database/ directory not found in the combined archive."
    rm -rf "${WP_EXTRACTED_PATH}" "${WP_FILES_EXTRACTED_PATH}"
    exit 1
fi

if [[ ! -d "${WP_EXTRACTED_PATH}/files" ]]; then
    echo "FAILED: files/ directory not found in the combined archive."
    rm -rf "${WP_EXTRACTED_PATH}" "${WP_FILES_EXTRACTED_PATH}"
    exit 1
fi

mapfile -d '' -t DB_SOURCE_CANDIDATES < <(find "${WP_EXTRACTED_PATH}/database" -maxdepth 1 -type f -name "*.sql.gz" -print0 | sort -z)
if [[ ${#DB_SOURCE_CANDIDATES[@]} -ne 1 ]]; then
    echo "FAILED: Could not find exactly one compressed database file inside the combined archive."
    echo "Expected canonical path: database/<dump>.sql.gz"
    rm -rf "${WP_EXTRACTED_PATH}" "${WP_FILES_EXTRACTED_PATH}"
    exit 1
fi
DB_SOURCE_PATH="${DB_SOURCE_CANDIDATES[0]}"
echo "PASSED: Found database file within combined archive: ${DB_SOURCE_PATH}"

mapfile -d '' -t WP_FILES_ARCHIVE_CANDIDATES < <(find "${WP_EXTRACTED_PATH}/files" -maxdepth 1 -type f -name "*.tar.gz" -print0 | sort -z)
if [[ ${#WP_FILES_ARCHIVE_CANDIDATES[@]} -ne 1 ]]; then
    echo "FAILED: Could not find exactly one WordPress files archive inside the combined archive."
    echo "Expected canonical path: files/<wordpress-files>.tar.gz"
    rm -rf "${WP_EXTRACTED_PATH}" "${WP_FILES_EXTRACTED_PATH}"
    exit 1
fi

WP_FILES_ARCHIVE_PATH="${WP_FILES_ARCHIVE_CANDIDATES[0]}"
echo "Extracting WordPress files archive: ${WP_FILES_ARCHIVE_PATH}"
mkdir -p "${WP_FILES_EXTRACTED_PATH}"
if ! validate_tar_archive_paths "${WP_FILES_ARCHIVE_PATH}" || ! tar -zxf "${WP_FILES_ARCHIVE_PATH}" -C "${WP_FILES_EXTRACTED_PATH}"; then
    echo "FAILED: Could not extract WordPress files archive."
    rm -rf "${WP_EXTRACTED_PATH}" "${WP_FILES_EXTRACTED_PATH}"
    exit 1
fi

if ! WP_FILES_SOURCE_PATH="$(find_wordpress_files_source_path "${WP_FILES_EXTRACTED_PATH}")"; then
    echo "FAILED: wp-config.php not found within the extracted WordPress files archive."
    rm -rf "${WP_EXTRACTED_PATH}" "${WP_FILES_EXTRACTED_PATH}"
    exit 1
fi
echo "PASSED: Archive extracted. WordPress source path set to: ${WP_FILES_SOURCE_PATH}"

# --- Extract Table Prefix from Database File ---
echo "Extracting table prefix from database file: ${DB_SOURCE_PATH}"
PREFIX=$(extract_prefix_from_db "$DB_SOURCE_PATH")
if [[ -z "$PREFIX" ]]; then
    echo "FAILED: Could not automatically determine table prefix from database file: ${DB_SOURCE_PATH}"
    echo "Please ensure the database dump contains standard WordPress tables like 'wp_options'/'yourprefix_options' or 'wp_users'/'yourprefix_users'."
    rm -rf "${WP_EXTRACTED_PATH}" "${WP_FILES_EXTRACTED_PATH}" # Clean up
    exit 1 # Exit if DB extraction fails
fi
echo "PASSED: Determined table prefix from database: ${PREFIX}"
# --- End Prefix Extraction ---


# --- Extract Information from wp-config.php ---
echo "Extracting site information from wp-config.php..."
WP_CONFIG_PATH="${WP_FILES_SOURCE_PATH}/wp-config.php" # Use the determined source path

# Extract WP_HOME or WP_SITEURL
SITE_URL_RAW=$(extract_define 'WP_HOME')
if [[ -z "$SITE_URL_RAW" ]]; then
    SITE_URL_RAW=$(extract_define 'WP_SITEURL')
fi

if [[ -z "$SITE_URL_RAW" ]]; then
    echo "FAILED: Could not extract WP_HOME or WP_SITEURL from wp-config.php."
    exit 1
fi

# Extract domain from URL (remove http(s):// and potential trailing slash)
SITE_URL=$(echo "$SITE_URL_RAW" | sed -E 's#^https?://##; s#/$##') # Use the clean domain extracted from URL

# Extract DB Charset (optional, for reference)
DB_CHARSET=$(extract_define 'DB_CHARSET')
if [[ -z "$DB_CHARSET" ]]; then
    echo "Warning: Could not extract DB_CHARSET from wp-config.php. Using default utf8mb4."
    DB_CHARSET="utf8mb4" # Default if not found
fi

echo "Extracted Information:"
echo "  Domain (SITE_URL): ${SITE_URL}"
echo "  Table Prefix (PREFIX): ${PREFIX}" # Already extracted from DB
echo "  DB Charset: ${DB_CHARSET}"
sleep 1 # Short pause

# --- Confirmation and Correction Step ---
while true; do
  echo ""
  echo "-------------------------------------------------------"
  echo "${BOLD}Extracted Site Information:${NORMAL}"
  echo "-------------------------------------------------------"
  echo "  Site URL:   ${SITE_URL}"
  echo "  DB Prefix:  ${PREFIX}"
  echo "  DB Charset: ${DB_CHARSET}"
  echo "-------------------------------------------------------"
  echo ""
  read -p "Are these details correct? ([Y]es/[C]hange/[E]xit): " confirm_details
  case $confirm_details in
    [Yy]* )
      echo "Details confirmed."
      sleep 1
      break # Exit the confirmation loop and proceed
      ;;
    [Cc]* )
      echo "Please enter the correct values:"
      
      # Site URL input with validation
      while true; do
          new_site_url=$(prompt_input "Enter correct Site URL" "${SITE_URL}" 300)
          if [[ -n "$new_site_url" ]]; then
              if validate_url "$new_site_url"; then
                  SITE_URL="$new_site_url"
                  break
              else
                  echo "Invalid URL format. Please use format: https://example.com or http://example.com"
              fi
          else
              break  # Keep existing value
          fi
      done

      # DB Prefix input with validation
      new_prefix=$(prompt_input "Enter correct DB Prefix" "${PREFIX}" 300 "^[a-zA-Z0-9_]+$" true)
      if [[ -n "$new_prefix" ]]; then
          # Ensure prefix ends with _ if not empty
          if [[ "${new_prefix: -1}" != "_" ]]; then
              new_prefix="${new_prefix}_"
              echo "  (Appended '_' to prefix)"
          fi
          PREFIX="$new_prefix"
      fi

      # DB Charset input with validation
      new_db_charset=$(prompt_input "Enter correct DB Charset" "${DB_CHARSET}" 300 "^[a-zA-Z0-9_]+$" true)
      if [[ -n "$new_db_charset" ]]; then
          DB_CHARSET="$new_db_charset"
      fi

      echo "Values updated. Please review again."
      sleep 1
      ;; # Loop back to show updated values
    [Ee]* )
      echo "Exiting script as requested."
      # Clean up extracted files before exiting
      rm -rf "${WP_EXTRACTED_PATH}" "${WP_FILES_EXTRACTED_PATH}"
      exit 0
      ;;
    * )
      echo "Invalid input. Please enter 'y', 'c', or 'e'."
      ;;
  esac
done
# --- End Confirmation and Correction Step ---

# Derive DOMAIN from the final SITE_URL (after any user corrections)
DOMAIN="${SITE_URL}"


# Cloudflare API Settings
# Set Cloudflare settings for the domain using the Cloudflare API
configure_cloudflare_settings "${DOMAIN}"

# Verify if the extracted domain is already configured
if grep -Fxq "\"${DOMAIN}\"" /home/EngineScript/sites-list/sites.sh; then
  echo -e "\n\n${BOLD}Pre-import Check: Failed${NORMAL}\n\nDomain ${DOMAIN} (extracted from wp-config.php) is already configured in EngineScript.\n\nIf you want to replace it, please remove the existing domain first using the ${BOLD}es.menu${NORMAL} command.\n\n"
  rm -rf "${WP_EXTRACTED_PATH}" "${WP_FILES_EXTRACTED_PATH}"
  exit 1
else
  echo "${BOLD}Pre-import Check: Passed${NORMAL}"
fi

# Canonical URL used for import/search-replace workflows.
# Currently source and target are the same during import.
NEW_URL="https://${SITE_URL}" # Assume https for consistency

# Logging
LOG_FILE="/var/log/EngineScript/vhost-import.log"
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "Starting domain import for ${DOMAIN} from combined ZIP ${COMBINED_ARCHIVE_FILE} at $(date)"

# Continue the installation
# Create nginx vhost configuration files
create_nginx_vhost "${DOMAIN}"

# Create and install SSL certificates
create_ssl_certificate "${DOMAIN}"

# Print date for logs
echo "System Date: $(date)"

# --- Database and File Handling ---

# Table Prefix is already extracted and stored in $PREFIX

# Domain Creation Variables (Generate *new* secure credentials for this server)
source /usr/local/bin/enginescript/enginescript-variables.txt
generate_import_db_name "${DOMAIN}" || exit 1
DB="${ES_DB_NAME}"
USR="${RAND_CHAR16}"
PSWD="${RAND_CHAR32}"

# Domain Database Credentials (Store the *new* credentials)
write_credentials_file "/home/EngineScript/mysql-credentials" "${DOMAIN}" "${DB}" "${USR}" "${PSWD}"

echo "Generated new MySQL database credentials for ${SITE_URL}."

# Create *new* database and user (Use extracted charset if needed, though default is usually fine)
# Validate SQL inputs before interpolation to prevent SQL injection/syntax issues.
DB_CHARSET="${DB_CHARSET:-utf8mb4}"
validate_import_credentials "${DB}" "${USR}" "${PSWD}" "${DB_CHARSET}" || exit 1
DB_CHARSET="${ES_DB_CHARSET_VALIDATED}"
DB_COLLATION="${ES_DB_COLLATION}"

execute_import_sql "${DB}" "${USR}" "${PSWD}" "${DB_CHARSET}" "${DB_COLLATION}"

# Create backup directories
create_backup_directories "${SITE_URL}"

# Site Root
mkdir -p "/var/www/sites/${SITE_URL}/html"
TARGET_WP_PATH="/var/www/sites/${SITE_URL}/html"

# Create domain log directories and files
create_domain_logs "${SITE_URL}"

# --- Import WordPress Files ---
echo "Copying WordPress files from ${WP_FILES_SOURCE_PATH} to ${TARGET_WP_PATH}..." # Use the determined source path
# Use rsync for efficiency and better handling of permissions/ownership later
rsync -av --exclude 'wp-config.php' "${WP_FILES_SOURCE_PATH}/" "${TARGET_WP_PATH}/"
# Ensure correct ownership before proceeding with WP-CLI
chown -R www-data:www-data "${TARGET_WP_PATH}"
echo "WordPress files copied."

# Create Extra WordPress Directories
# WordPress often doesn't include these directories by default, despite them being used or checked in the Health Check plugin.
create_extra_wp_dirs "${SITE_URL}"

# --- Create wp-config.php ---
echo "Creating new wp-config.php with EngineScript settings..."
cp -rf "/usr/local/bin/enginescript/config/var/www/wordpress/wp-config.php" "${TARGET_WP_PATH}/wp-config.php"
# Use *new* DB credentials and *original* prefix
sed -i \
    -e "s|SEDWPDB|${DB}|g" \
    -e "s|SEDWPUSER|${USR}|g" \
    -e "s|SEDWPPASS|${PSWD}|g" \
    -e "s|SEDPREFIX_|${PREFIX}|g" \
    -e "s|SEDURL|${SITE_URL}|g" \
    -e "s|define( 'DB_CHARSET', 'utf8mb4' );|define( 'DB_CHARSET', '${DB_CHARSET}' );|g" \
    "${TARGET_WP_PATH}/wp-config.php" # Use original prefix and extracted DB Charset

# Configure Redis for WordPress
configure_redis "${SITE_URL}" "${TARGET_WP_PATH}/wp-config.php"

# WP Salt Creation (Generate new salts)
fetch_wp_salts "${TARGET_WP_PATH}/wp-config.php"

# Configure wp-config.php settings
configure_wpconfig_settings "${SITE_URL}" "${TARGET_WP_PATH}/wp-config.php"

# Create robots.txt file
create_robots_txt "${SITE_URL}" "${TARGET_WP_PATH}"

# --- Import Database ---
echo "Importing database from ${DB_SOURCE_PATH}..." # DB_SOURCE_PATH is already set
cd "${TARGET_WP_PATH}" # WP-CLI needs to be in the WP root

# Handle compressed DB (using DB_SOURCE_PATH)
IMPORT_FILE_PATH="${DB_SOURCE_PATH}"
if [[ "${DB_SOURCE_PATH}" == *.gz ]]; then
    echo "Decompressing database..."
    IMPORT_FILE_PATH="/tmp/${DOMAIN}_db_import.sql"
    gunzip -c "${DB_SOURCE_PATH}" > "${IMPORT_FILE_PATH}"
    if [[ $? -ne 0 ]]; then
        echo "Failed to decompress database file. Exiting."
        exit 1
    fi
fi

# Import the database using WP-CLI
wp db import "${IMPORT_FILE_PATH}" --allow-root
if [[ $? -ne 0 ]]; then
    echo "Failed to import database. Please check the database file and credentials. Exiting."
    # Clean up temp file if created
    if [[ "${DB_SOURCE_PATH}" == *.gz ]]; then
        rm -f "${IMPORT_FILE_PATH}"
    fi
    exit 1
fi
echo "Database imported successfully."

# Clean up temp file if created
if [[ "${DB_SOURCE_PATH}" == *.gz ]]; then
    rm -f "${IMPORT_FILE_PATH}"
fi

# --- Post Import Tasks ---

# Search and Replace URLs
echo "Running search-replace for URL consistency in the database..."
echo "Ensuring URL is '${NEW_URL}'"
HTTPS_ORIGINAL_URL="${NEW_URL}"
HTTP_ORIGINAL_URL="${HTTPS_ORIGINAL_URL/#https:\/\//http://}"

run_url_search_replace_if_present() {
    local original_url="$1"

    # Run search-replace directly; --report-changed-only will emit output only for changed rows.
    wp search-replace "${original_url}" "${NEW_URL}" --all-tables --report-changed-only --allow-root
    return
}

run_url_search_replace_if_present "${HTTP_ORIGINAL_URL}"
run_url_search_replace_if_present "${HTTPS_ORIGINAL_URL}"

# Flush Cache and Rewrite Rules
clear_wordpress_caches

# Install and activate required WordPress plugins
install_required_wp_plugins

# Install extra WordPress plugins if enabled
if [[ "${INSTALL_EXTRA_WP_PLUGINS}" == "1" ]]; then
    install_extra_wp_plugins
else
    echo "Skipping extra WordPress plugins installation (disabled in config)..."
fi

# Install EngineScript custom plugins if enabled
install_enginescript_custom_plugins "${SITE_URL}"

# Clear WordPress caches, transients, and rewrite rules
clear_wordpress_caches

# Enable Redis Cache via WP-CLI
if wp plugin is-active redis-cache --allow-root; then
  echo "Enabling Redis object cache..."
  wp redis enable --allow-root
else
  echo "Warning: Redis Cache plugin not active. Skipping 'wp redis enable'."
fi

# Set permalink structure for FastCGI Cache (Good practice)
# Changing the permalink structure would probably catastrophically break existing sites and their SEO if they use a different structure, so this is commented out by default.
#echo "Setting permalink structure to /%category%/%postname%/..."
#wp option update permalink_structure '/%category%/%postname%/' --allow-root
#flush_wordpress_rewrites

# Final File Permissions
echo "Setting final file permissions..."
# Set ownership first
chown -R www-data:www-data "${TARGET_WP_PATH}"
# Set directory and file permissions
find "${TARGET_WP_PATH}" -type d -print0 | sudo xargs -0 chmod 0755
find "${TARGET_WP_PATH}" -type f -print0 | sudo xargs -0 chmod 0644
# Secure specific files
chmod 600 "${TARGET_WP_PATH}/wp-config.php"
# Ensure wp-cron is executable if it exists
if [[ -f "${TARGET_WP_PATH}/wp-cron.php" ]]; then
    chmod +x "${TARGET_WP_PATH}/wp-cron.php"
fi

clear

# Perform site backup
perform_site_backup "${SITE_URL}" "${TARGET_WP_PATH}"

# Display final credentials summary
display_credentials_summary "${SITE_URL}" "${DB}" "${PREFIX}" "${USR}" "${PSWD}"

# Restart Services
/usr/local/bin/enginescript/scripts/functions/alias/alias-restart.sh

echo ""
echo "============================================================="
echo ""
echo "        Domain import completed for ${SITE_URL}."
echo ""
echo "        Your domain should be available now at:"
echo "        https://${SITE_URL}"
echo ""
echo "        ${BOLD}ACTION REQUIRED:${NORMAL}"
echo "        Please open your web browser and thoroughly verify the site functionality."
echo "        Check pages, posts, images, forms, and plugin features."
echo ""
echo "        If the site is NOT working correctly:"
echo "          - Answer 'n' to the prompt below."
echo "          - The script will exit WITHOUT removing temporary import files."
echo "          - You can then investigate the issue."
echo "          - Afterwards, use the main EngineScript menu (es.menu) -> Domain Configuration -> Remove Domain"
echo "            to clean up the partially imported site."
echo ""
echo "============================================================="
echo ""

# --- Site Verification Step ---
echo ""
if prompt_yes_no "Is the imported site at https://${SITE_URL} working correctly?" "n" 600; then
    echo "Great! Proceeding with cleanup..."
    # Move import files to completed-backups directory
    BACKUP_DIR="/home/EngineScript/temp/site-import-completed-backups"
    mkdir -p "${BACKUP_DIR}"
    if [[ -n "${COMBINED_ARCHIVE_FILE}" ]] && [[ -f "${COMBINED_ARCHIVE_FILE}" ]]; then
        mv "${COMBINED_ARCHIVE_FILE}" "${BACKUP_DIR}/"
        echo "Moved ${COMBINED_ARCHIVE_FILE} to ${BACKUP_DIR}/"
    fi
    rm -rf "${WP_EXTRACTED_PATH}" "${WP_FILES_EXTRACTED_PATH}" # Remove temporary extracted directories
    echo "Cleanup complete. Import files moved to ${BACKUP_DIR}."
    sleep 2 # Short pause after cleanup message
else
    echo "Site verification failed by user."
    echo "Removing temporary extracted file directories: ${WP_EXTRACTED_PATH}, ${WP_FILES_EXTRACTED_PATH}"
    rm -rf "${WP_EXTRACTED_PATH}" "${WP_FILES_EXTRACTED_PATH}" # Remove only extracted directories
    echo "Original combined import file (${COMBINED_ARCHIVE_FILE}) in ${IMPORT_BASE_DIR} will NOT be removed."
    echo "Please investigate the issue and use 'es.menu' to remove the domain '${SITE_URL}' when ready."
    echo "Exiting script now."
    exit 1 # Exit without full cleanup
fi
# --- End Site Verification Step ---


echo "Returning to main menu..." # Message if 'y' was chosen
sleep 5

# Exit cleanly (only reached if 'y' was chosen)
exit 0
