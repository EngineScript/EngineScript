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

# --- Define Fixed Import Paths ---
IMPORT_BASE_DIR="/home/EngineScript/temp/site-import"
WP_ARCHIVE_DIR="${IMPORT_BASE_DIR}/root-directory" # Directory containing the archive
DB_IMPORT_DIR="${IMPORT_BASE_DIR}/database-file"
WP_EXTRACTED_PATH="${IMPORT_BASE_DIR}/extracted-root" # Temporary path for extracted files

# --- Supported DB Charset Configuration ---
readonly ALLOWED_DB_CHARSETS=("utf8mb4" "utf8" "latin1")

# --- Instructions for Preparing Files ---
echo ""
echo "${BOLD}Preparing Files for Import:${NORMAL}"
echo "---------------------------------------------------------------------"
echo "You can use one of the following methods:"
echo ""
echo "${BOLD}Method 1: Single Export File (Recommended - using EngineScript Site Exporter plugin)${NORMAL}"
echo "   - This method uses the 'EngineScript Site Exporter' plugin to create a single .zip file"
echo "     containing both WordPress files and the database (.sql)."
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
echo ""
echo "${BOLD}Method 2: Separate Files (Manual Export)${NORMAL}"
echo "   1. ${BOLD}WordPress Root Directory Archive:${NORMAL}"
echo "      - Compress your WordPress root directory content (.tar.gz or .zip)."
echo "      - Place the archive file inside:"
echo "        \`${WP_ARCHIVE_DIR}\`"
echo "   2. ${BOLD}WordPress Database Dump:${NORMAL}"
echo "      - Export your database (.sql or .sql.gz)."
echo "      - Place the database file inside:"
echo "        \`${DB_IMPORT_DIR}\`"
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
echo "  1. The compressed WordPress site root directory (.zip or .tar.gz) is placed in:"
echo "     ${WP_ARCHIVE_DIR}"
echo "  2. The database dump file (.sql or .sql.gz) is placed in:"
echo "     ${DB_IMPORT_DIR}"
echo ""
sleep 1

# --- Function Definitions ---

# Function to extract define values (Handles single/double quotes)
extract_define() {
    local key="$1"
    # Find the line defining the key
    local line
    line=$(grep -E "^\s*define\(\s*['\"]${key}['\"]\s*," "$WP_CONFIG_PATH")
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
    # Capture the part between backticks/quotes before _options or _users
    # Regex: Match CREATE/INSERT, whitespace, quote/backtick, capture prefix (group 3), match _options/_users, quote/backtick
    local search_pattern="(CREATE TABLE|INSERT INTO)[[:space:]]+(\`|\")([a-zA-Z0-9_]+)_(options|users)(\`|\")"

    # Use zgrep for .gz, grep for .sql. Extract the captured group 3 (the prefix part).
    if [[ "$db_file" == *.gz ]]; then
        grep_cmd="zgrep"
    fi
    prefix=$("$grep_cmd" -m 1 -oE "${search_pattern}" "$db_file" | sed -E "s/${search_pattern}/\3/" | head -n 1)

    if [[ -n "$prefix" ]]; then
        # Ensure it ends with an underscore if it doesn't already
        if [[ "${prefix: -1}" != "_" ]]; then
            prefix="${prefix}_"
        fi
        # Removed intermediate echo: echo "Found and cleaned prefix: ${prefix}"
    else
         echo "Warning: Could not find common table pattern (like 'prefix_options') in the DB file." >&2 # Output warning to stderr
    fi

    # Return the extracted prefix (might be empty if not found)
    echo "$prefix" # This is the only echo that should output the final prefix
}

# --- Validate Import Paths and Files ---
echo "Validating import directories and files..."

IMPORT_FORMAT="" # "single_zip" or "two_file"
SINGLE_ZIP_FILE=""
WP_ARCHIVE_FILE="" # Path to WP files archive (for two_file method)
DB_SOURCE_PATH=""  # Path to the DB file (set differently for each method)

# Try detecting Single Zip format first
mapfile -d '' -t SINGLE_ZIP_CANDIDATES < <(find "${IMPORT_BASE_DIR}" -maxdepth 1 -type f -name "*.zip" -print0)
SINGLE_ZIP_COUNT=${#SINGLE_ZIP_CANDIDATES[@]}

if [[ "$SINGLE_ZIP_COUNT" -eq 1 && ! -d "${WP_ARCHIVE_DIR}" && ! -d "${DB_IMPORT_DIR}" ]]; then
    # Found exactly one zip file in the base dir, and the old dirs don't exist
    IMPORT_FORMAT="single_zip"
    SINGLE_ZIP_FILE="${SINGLE_ZIP_CANDIDATES[0]}"
    echo "PASSED: Detected Single Export Zip format: ${SINGLE_ZIP_FILE}"
elif [[ -d "${WP_ARCHIVE_DIR}" && -d "${DB_IMPORT_DIR}" ]]; then
    # Check the original two-file method
    # Find WP archive file
    mapfile -d '' -t WP_ARCHIVE_FILE_CANDIDATES < <(find "${WP_ARCHIVE_DIR}" -maxdepth 1 -type f \( -name "*.zip" -o -name "*.tar.gz" -o -name "*.tgz" \) -print0)
    WP_ARCHIVE_COUNT=${#WP_ARCHIVE_FILE_CANDIDATES[@]}

    # Find DB file
    mapfile -d '' -t DB_SOURCE_FILE_CANDIDATES < <(find "${DB_IMPORT_DIR}" -maxdepth 1 -type f \( -name "*.sql" -o -name "*.sql.gz" \) -print0)
    DB_SOURCE_COUNT=${#DB_SOURCE_FILE_CANDIDATES[@]}

    if [[ "$WP_ARCHIVE_COUNT" -eq 1 && "$DB_SOURCE_COUNT" -eq 1 ]]; then
        IMPORT_FORMAT="two_file"
        WP_ARCHIVE_FILE="${WP_ARCHIVE_FILE_CANDIDATES[0]}"
        DB_SOURCE_PATH="${DB_SOURCE_FILE_CANDIDATES[0]}" # Set DB path directly for this format
        echo "PASSED: Detected Two-File format."
        echo "  WordPress archive: ${WP_ARCHIVE_FILE}"
        echo "  Database file: ${DB_SOURCE_PATH}"
    fi
fi

# Validation Failure
if [[ -z "$IMPORT_FORMAT" ]]; then
    echo "FAILED: Could not detect a valid import format."
    echo "Please ensure you have either:"
    echo "  - Exactly one .zip file in ${IMPORT_BASE_DIR} (and no subdirectories like 'root-directory' or 'database-file')."
    echo "  - OR Exactly one archive (.zip, .tar.gz, .tgz) in ${WP_ARCHIVE_DIR} AND exactly one database file (.sql, .sql.gz) in ${DB_IMPORT_DIR}."
    exit 1
fi

# --- Extraction Step (Conditional) ---
echo "Extracting content..."
# Clean up any previous extraction attempt
rm -rf "${WP_EXTRACTED_PATH}"
mkdir -p "${WP_EXTRACTED_PATH}"

EXTRACT_STATUS=1 # Default to failure

if [[ "$IMPORT_FORMAT" == "single_zip" ]]; then
    echo "Extracting single zip file: ${SINGLE_ZIP_FILE}"
    unzip -q "${SINGLE_ZIP_FILE}" -d "${WP_EXTRACTED_PATH}"
    EXTRACT_STATUS=$?
    if [[ $EXTRACT_STATUS -eq 0 ]]; then
        # Find exactly one .sql file within the extracted content
        DB_SOURCE_CANDIDATE=$(find "${WP_EXTRACTED_PATH}" -maxdepth 1 -type f -name "*.sql" -print -quit)
        if [[ -z "$DB_SOURCE_CANDIDATE" ]]; then
            echo "FAILED: Could not find exactly one .sql file within the extracted single zip content in ${WP_EXTRACTED_PATH}"
            EXTRACT_STATUS=1 # Mark as failure
        else
            DB_SOURCE_SECOND_CANDIDATE=$(find "${WP_EXTRACTED_PATH}" -maxdepth 1 -type f -name "*.sql" ! -samefile "$DB_SOURCE_CANDIDATE" -print -quit)
            if [[ -n "$DB_SOURCE_SECOND_CANDIDATE" ]]; then
                echo "FAILED: Could not find exactly one .sql file within the extracted single zip content in ${WP_EXTRACTED_PATH}"
                EXTRACT_STATUS=1 # Mark as failure
            else
                DB_SOURCE_PATH="$DB_SOURCE_CANDIDATE" # Set DB path for single_zip format
                echo "PASSED: Found database file within extracted content: ${DB_SOURCE_PATH}"
            fi
        fi
    fi
elif [[ "$IMPORT_FORMAT" == "two_file" ]]; then
    echo "Extracting WordPress archive file: ${WP_ARCHIVE_FILE}"
    if [[ "${WP_ARCHIVE_FILE}" == *.zip ]]; then
        unzip -q "${WP_ARCHIVE_FILE}" -d "${WP_EXTRACTED_PATH}"
        EXTRACT_STATUS=$?
    elif [[ "${WP_ARCHIVE_FILE}" == *.tar.gz || "${WP_ARCHIVE_FILE}" == *.tgz ]]; then
        tar -zxf "${WP_ARCHIVE_FILE}" -C "${WP_EXTRACTED_PATH}"
        EXTRACT_STATUS=$?
    else
        echo "FAILED: Unrecognized archive format for ${WP_ARCHIVE_FILE}"
        EXTRACT_STATUS=1
    fi
    # DB_SOURCE_PATH is already set for two_file format
fi

# Check Extraction Status
if [[ $EXTRACT_STATUS -ne 0 ]]; then
    echo "FAILED: Extraction process failed."
    rm -rf "${WP_EXTRACTED_PATH}" # Clean up failed extraction
    exit 1
fi

# --- Locate wp-config.php and Determine Source Path (Common Logic) ---
# This logic should work for both formats as wp-config.php will be inside WP_EXTRACTED_PATH
WP_CONFIG_REL_PATH=$(find "${WP_EXTRACTED_PATH}" -name "wp-config.php" -printf "%P\n" | head -n 1)
if [[ -z "$WP_CONFIG_REL_PATH" ]]; then
    echo "FAILED: wp-config.php not found within the extracted content in ${WP_EXTRACTED_PATH}"
    rm -rf "${WP_EXTRACTED_PATH}" # Clean up
    exit 1
fi

# Determine the actual source path for WP files
if [[ "$WP_CONFIG_REL_PATH" == "wp-config.php" ]]; then
    WP_FILES_SOURCE_PATH="${WP_EXTRACTED_PATH}"
else
    SUBDIR=$(dirname "$WP_CONFIG_REL_PATH")
    WP_FILES_SOURCE_PATH="${WP_EXTRACTED_PATH}/${SUBDIR}"
fi
echo "PASSED: Archive extracted. WordPress source path set to: ${WP_FILES_SOURCE_PATH}"

# --- Extract Table Prefix from Database File ---
# DB_SOURCE_PATH is now set correctly for both formats
echo "Extracting table prefix from database file: ${DB_SOURCE_PATH}"
PREFIX=$(extract_prefix_from_db "$DB_SOURCE_PATH")
if [[ -z "$PREFIX" ]]; then
    echo "FAILED: Could not automatically determine table prefix from database file: ${DB_SOURCE_PATH}"
    echo "Please ensure the database dump contains standard WordPress tables like 'wp_options' or 'yourprefix_options'."
    rm -rf "${WP_EXTRACTED_PATH}" # Clean up
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
SITE_URL=$(echo "$SITE_URL_RAW" | sed -E 's#^https?://##; s#/$##') # Use the clean domain as SITE_URL

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
          new_site_url=$(prompt_input "Enter correct Site URL" "${SITE_URL}" 300 "^https?://([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\\.)*[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(:[0-9]{1,5})?([/?#].*)?$")
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

      # Re-assign DOMAIN based on potentially updated SITE_URL
      DOMAIN=$(echo "$SITE_URL" | sed -E 's#^https?://##; s#/$##')

      echo "Values updated. Please review again."
      sleep 1
      ;; # Loop back to show updated values
    [Ee]* )
      echo "Exiting script as requested."
      # Clean up extracted files before exiting
      rm -rf "${WP_EXTRACTED_PATH}"
      exit 0
      ;;
    * )
      echo "Invalid input. Please enter 'y', 'c', or 'e'."
      ;;
  esac
done
# --- End Confirmation and Correction Step ---

# Derive DOMAIN from the final SITE_URL (after any user corrections)
DOMAIN=$(echo "$SITE_URL" | sed -E 's#^https?://##; s#/$##')


# Cloudflare API Settings
# Set Cloudflare settings for the domain using the Cloudflare API
configure_cloudflare_settings "${DOMAIN}"

# Verify if the extracted domain is already configured
if grep -Fxq "\"${DOMAIN}\"" /home/EngineScript/sites-list/sites.sh; then
  echo -e "\n\n${BOLD}Pre-import Check: Failed${NORMAL}\n\nDomain ${DOMAIN} (extracted from wp-config.php) is already configured in EngineScript.\n\nIf you want to replace it, please remove the existing domain first using the ${BOLD}es.menu${NORMAL} command.\n\n"
  exit 1
else
  echo "${BOLD}Pre-import Check: Passed${NORMAL}"
fi

# Keep both variables intentionally: ORIGINAL_URL is the source URL and NEW_URL is the target URL
# for search-replace workflows. They are initialized identically by default and may diverge later.
ORIGINAL_URL="https://${SITE_URL}" # Assume https for consistency
NEW_URL="https://${SITE_URL}"

# Logging
LOG_FILE="/var/log/EngineScript/vhost-import.log"
exec > >(tee -a "${LOG_FILE}") 2>&1
if [ "${IMPORT_FORMAT}" = "single_zip" ]; then
  echo "Starting domain import for ${DOMAIN} from single ZIP ${SINGLE_ZIP_FILE} at $(date)"
elif [ "${IMPORT_FORMAT}" = "two_file" ]; then
  echo "Starting domain import for ${DOMAIN} from archive ${WP_ARCHIVE_FILE} and DB ${DB_SOURCE_PATH} at $(date)"
else
  echo "Starting domain import for ${DOMAIN} (format: ${IMPORT_FORMAT}) with inputs ZIP=${SINGLE_ZIP_FILE}, archive=${WP_ARCHIVE_FILE}, DB=${DB_SOURCE_PATH} at $(date)"
fi

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
domain_base="${DOMAIN}" && SANDOMAIN="${domain_base%.*}" && SDB="${SANDOMAIN}_${RAND_CHAR4}"
SUSR="${RAND_CHAR16}"
SPS="${RAND_CHAR32}"

# Domain Database Credentials (Store the *new* credentials)
echo "DB=\"${SDB}\"" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
echo "USR=\"${SUSR}\"" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
echo "PSWD=\"${SPS}\"" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"
echo "" >> "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"

source "/home/EngineScript/mysql-credentials/${DOMAIN}.txt"

echo "Generated new MySQL database credentials for ${SITE_URL}."

# Create *new* database and user (Use extracted charset if needed, though default is usually fine)
# Validate SQL inputs before interpolation to prevent SQL injection/syntax issues.
DB_CHARSET_VALIDATED="$(printf '%s' "${DB_CHARSET}" | tr '[:upper:]' '[:lower:]')"
DB_CHARSET_ALLOWED=false
for allowed_charset in "${ALLOWED_DB_CHARSETS[@]}"; do
    if [[ "${DB_CHARSET_VALIDATED}" == "${allowed_charset}" ]]; then
        DB_CHARSET_ALLOWED=true
        break
    fi
done
if [[ "${DB_CHARSET_ALLOWED}" != true ]]; then
    ALLOWED_DB_CHARSETS_CSV="$(printf '%s, ' "${ALLOWED_DB_CHARSETS[@]}" | sed 's/, $//')"
    echo "Error: Invalid DB_CHARSET value '${DB_CHARSET}'. Allowed values: ${ALLOWED_DB_CHARSETS_CSV}." >&2
    exit 1
fi
DB_COLLATION="${DB_CHARSET_VALIDATED}_unicode_ci"
if [[ ! "${DB}" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "Error: Generated database name contains invalid characters: ${DB}" >&2
    exit 1
fi
if [[ ! "${USR}" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "Error: Generated database user contains invalid characters: ${USR}" >&2
    exit 1
fi
if [[ "${PSWD}" == *"'"* || "${PSWD}" == *"\\"* ]]; then
    echo "Error: Generated database password contains unsupported SQL-unsafe characters." >&2
    exit 1
fi

sudo mariadb -e "CREATE DATABASE \`${DB}\` CHARACTER SET ${DB_CHARSET_VALIDATED} COLLATE ${DB_COLLATION};" # Use validated charset
sudo mariadb -e "CREATE USER '${USR}'@'localhost' IDENTIFIED BY '${PSWD}';"
sudo mariadb -e "GRANT ALL ON \`${DB}\`.* TO '${USR}'@'localhost'; FLUSH PRIVILEGES;"
sudo mariadb -e "GRANT ALL ON mysql.* TO '${USR}'@'localhost'; FLUSH PRIVILEGES;" # Needed for mariadb-health-checks plugin

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
echo "Generating new WordPress salts..."
SALT=$(curl --fail --silent --show-error --location --retry 3 --connect-timeout 10 --max-time 30 "https://api.wordpress.org/secret-key/1.1/salt/") || {
    echo "Error: Failed to fetch WordPress salts from api.wordpress.org" >&2
    exit 1
}

if [ -z "${SALT}" ] || ! printf '%s' "${SALT}" | grep -q "define("; then
    echo "Error: Retrieved invalid WordPress salts content" >&2
    exit 1
fi

STRING='put your unique phrase here'
printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s "${TARGET_WP_PATH}/wp-config.php"

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
HTTP_ORIGINAL_URL="http://${DOMAIN}"
HTTPS_ORIGINAL_URL="https://${DOMAIN}"

# Only run expensive full-table replacements when the source URL is present.
if wp db search "${HTTP_ORIGINAL_URL}" --all-tables --allow-root 2>/dev/null | grep -qF "${HTTP_ORIGINAL_URL}"; then
    wp search-replace "${HTTP_ORIGINAL_URL}" "${NEW_URL}" --all-tables --report-changed-only --allow-root
else
    echo "Skipping http search-replace: '${HTTP_ORIGINAL_URL}' not found in database text columns."
fi

if wp db search "${HTTPS_ORIGINAL_URL}" --all-tables --allow-root 2>/dev/null | grep -qF "${HTTPS_ORIGINAL_URL}"; then
    wp search-replace "${HTTPS_ORIGINAL_URL}" "${NEW_URL}" --all-tables --report-changed-only --allow-root
else
    echo "Skipping https search-replace: '${HTTPS_ORIGINAL_URL}' not found in database text columns."
fi

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
    if [[ -n "${WP_ARCHIVE_FILE}" ]] && [[ -f "${WP_ARCHIVE_FILE}" ]]; then
        mv "${WP_ARCHIVE_FILE}" "${BACKUP_DIR}/"
        echo "Moved ${WP_ARCHIVE_FILE} to ${BACKUP_DIR}/"
    fi
    if [[ "${IMPORT_FORMAT}" == "single_zip" ]] && [[ -n "${SINGLE_ZIP_FILE}" ]] && [[ -f "${SINGLE_ZIP_FILE}" ]]; then
        mv "${SINGLE_ZIP_FILE}" "${BACKUP_DIR}/"
        echo "Moved ${SINGLE_ZIP_FILE} to ${BACKUP_DIR}/"
    fi
    if [[ -n "${DB_SOURCE_PATH}" ]] && [[ -f "${DB_SOURCE_PATH}" ]]; then
        mv "${DB_SOURCE_PATH}" "${BACKUP_DIR}/"
        echo "Moved ${DB_SOURCE_PATH} to ${BACKUP_DIR}/"
    fi
    rm -rf "${WP_EXTRACTED_PATH}" # Remove the temporary extracted directory
    echo "Cleanup complete. Import files moved to ${BACKUP_DIR}."
    sleep 2 # Short pause after cleanup message
else
    echo "Site verification failed by user."
    echo "Removing temporary extracted files directory: ${WP_EXTRACTED_PATH}"
    rm -rf "${WP_EXTRACTED_PATH}" # Remove only the extracted directory
    if [[ "${IMPORT_FORMAT}" == "two_file" ]]; then
        echo "Original archive file (${WP_ARCHIVE_FILE}) in ${WP_ARCHIVE_DIR} and database file (${DB_SOURCE_PATH}) in ${DB_IMPORT_DIR} will NOT be removed."
    else
        echo "Original import file (${SINGLE_ZIP_FILE}) in ${IMPORT_BASE_DIR} will NOT be removed."
    fi
    echo "Please investigate the issue and use 'es.menu' to remove the domain '${SITE_URL}' when ready."
    echo "Exiting script now."
    exit 1 # Exit without full cleanup
fi
# --- End Site Verification Step ---


echo "Returning to main menu..." # Message if 'y' was chosen
sleep 5

# Exit cleanly (only reached if 'y' was chosen)
exit 0
