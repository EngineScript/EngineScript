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

# --- Define Fixed Import Paths (Needed for instructions) ---
IMPORT_BASE_DIR="/home/EngineScript/temp/site-import"
# Directories for the original two-file method (keep variable names consistent)
WP_ARCHIVE_DIR_ORIGINAL="${IMPORT_BASE_DIR}/root-directory"
DB_IMPORT_DIR_ORIGINAL="${IMPORT_BASE_DIR}/database-file"
# Temporary path for extracted files (used by both methods)
WP_EXTRACTED_PATH="${IMPORT_BASE_DIR}/extracted-root"

# --- Instructions for Preparing Files ---
echo ""
echo "${BOLD}Preparing Files for Import:${NORMAL}"
echo "---------------------------------------------------------------------"
echo "You can use one of the following methods:"
echo ""
echo "${BOLD}Method 1: Single Export File (Recommended - using Simple Site Exporter plugin)${NORMAL}"
echo "   - This method uses the 'Simple Site Exporter' plugin to create a single .zip file"
echo "     containing both WordPress files and the database (.sql)."
echo "   - ${YELLOW}If you don't have the plugin on your source site:${NORMAL}"
echo "     1. Download the plugin zip: ${UNDERLINE}https://github.com/EngineScript/Simple-WP-Site-Exporter/releases/latest/download/simple-site-exporter.zip${NORMAL}"
echo "     2. In your source WordPress admin area, go to 'Plugins' -> 'Add New' -> 'Upload Plugin'."
echo "     3. Upload the downloaded .zip file and activate the 'EngineScript: Simple Site Exporter' plugin."
echo "   - Once the plugin is active on your source site:"
echo "     1. Go to 'Tools' -> 'Site Exporter' in your WordPress admin."
echo "     2. Click the 'Export Site' button."
echo "     3. Download the generated .zip file (e.g., site_export_sse_... .zip)."
echo "   - Place this single downloaded .zip file directly inside the following directory on the EngineScript server:"
echo "     \`${IMPORT_BASE_DIR}\`"
echo "     (Ensure only this one .zip file is present in ${IMPORT_BASE_DIR})"
echo ""
echo "${BOLD}Method 2: Separate Files (Manual Export)${NORMAL}"
echo "   1. ${BOLD}WordPress Root Directory Archive:${NORMAL}"
echo "      - Compress your WordPress root directory content (.tar.gz or .zip)."
echo "      - Place the archive file inside:"
echo "        \`${WP_ARCHIVE_DIR_ORIGINAL}\`"
echo "   2. ${BOLD}WordPress Database Dump:${NORMAL}"
echo "      - Export your database (.sql or .sql.gz)."
echo "      - Place the database file inside:"
echo "        \`${DB_IMPORT_DIR_ORIGINAL}\`"
echo "---------------------------------------------------------------------"
prompt_continue "Press [Enter] when your files are prepared and ready" 600
# --- End Instructions ---

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

# --- Define Fixed Import Paths ---
IMPORT_BASE_DIR="/home/EngineScript/temp/site-import"
WP_ARCHIVE_DIR="${IMPORT_BASE_DIR}/root-directory" # Directory containing the archive
DB_IMPORT_DIR="${IMPORT_BASE_DIR}/database-file"
WP_EXTRACTED_PATH="${IMPORT_BASE_DIR}/extracted-root" # Temporary path for extracted files

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
    local line=$(grep -E "^\s*define\(\s*['\"]${key}['\"]\s*," "$WP_CONFIG_PATH")
    # Extract the value between single or double quotes after the comma
    local value=$(echo "$line" | sed -E "s/.*,\s*['\"]([^'\"]*)['\"].*/\1/")
    echo "$value"
}

# Function to extract table prefix from the database dump file
extract_prefix_from_db() {
    local db_file="$1"
    local prefix=""
    # Look for CREATE TABLE or INSERT INTO lines with common tables (_options or _users)
    # Capture the part between backticks/quotes before _options or _users
    # Regex: Match CREATE/INSERT, whitespace, quote/backtick, capture prefix (group 3), match _options/_users, quote/backtick
    local search_pattern="(CREATE TABLE|INSERT INTO)[[:space:]]+(\`|\")([a-zA-Z0-9_]+)_(options|users)(\`|\")"

    # Use zgrep for .gz, grep for .sql. Extract the captured group 3 (the prefix part).
    if [[ "$db_file" == *.gz ]]; then
        prefix=$(zgrep -m 1 -oE "${search_pattern}" "$db_file" | sed -E "s/${search_pattern}/\3/" | head -n 1)
    else
        prefix=$(grep -m 1 -oE "${search_pattern}" "$db_file" | sed -E "s/${search_pattern}/\3/" | head -n 1)
    fi

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
SINGLE_ZIP_CANDIDATE=$(find "${IMPORT_BASE_DIR}" -maxdepth 1 -type f -name "*.zip")
SINGLE_ZIP_COUNT=$(echo "$SINGLE_ZIP_CANDIDATE" | wc -l)

if [[ "$SINGLE_ZIP_COUNT" -eq 1 && ! -d "${WP_ARCHIVE_DIR_ORIGINAL}" && ! -d "${DB_IMPORT_DIR_ORIGINAL}" ]]; then
    # Found exactly one zip file in the base dir, and the old dirs don't exist
    IMPORT_FORMAT="single_zip"
    SINGLE_ZIP_FILE="$SINGLE_ZIP_CANDIDATE"
    echo "PASSED: Detected Single Export Zip format: ${SINGLE_ZIP_FILE}"
elif [[ -d "${WP_ARCHIVE_DIR_ORIGINAL}" && -d "${DB_IMPORT_DIR_ORIGINAL}" ]]; then
    # Check the original two-file method
    # Find WP archive file
    WP_ARCHIVE_FILE_CANDIDATE=$(find "${WP_ARCHIVE_DIR_ORIGINAL}" -maxdepth 1 -type f \( -name "*.zip" -o -name "*.tar.gz" -o -name "*.tgz" \))
    WP_ARCHIVE_COUNT=$(echo "$WP_ARCHIVE_FILE_CANDIDATE" | wc -l)

    # Find DB file
    DB_SOURCE_FILE_CANDIDATE=$(find "${DB_IMPORT_DIR_ORIGINAL}" -maxdepth 1 -type f \( -name "*.sql" -o -name "*.sql.gz" \))
    DB_SOURCE_COUNT=$(echo "$DB_SOURCE_FILE_CANDIDATE" | wc -l)

    if [[ "$WP_ARCHIVE_COUNT" -eq 1 && "$DB_SOURCE_COUNT" -eq 1 ]]; then
        IMPORT_FORMAT="two_file"
        WP_ARCHIVE_FILE="$WP_ARCHIVE_FILE_CANDIDATE"
        DB_SOURCE_PATH="$DB_SOURCE_FILE_CANDIDATE" # Set DB path directly for this format
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
    echo "  - OR Exactly one archive (.zip, .tar.gz, .tgz) in ${WP_ARCHIVE_DIR_ORIGINAL} AND exactly one database file (.sql, .sql.gz) in ${DB_IMPORT_DIR_ORIGINAL}."
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
        # Find the .sql file within the extracted content
        DB_SOURCE_CANDIDATE=$(find "${WP_EXTRACTED_PATH}" -maxdepth 1 -type f -name "*.sql")
        DB_SOURCE_FOUND_COUNT=$(echo "$DB_SOURCE_CANDIDATE" | wc -l)
        if [[ "$DB_SOURCE_FOUND_COUNT" -eq 1 ]]; then
            DB_SOURCE_PATH="$DB_SOURCE_CANDIDATE" # Set DB path for single_zip format
            echo "PASSED: Found database file within extracted content: ${DB_SOURCE_PATH}"
        else
            echo "FAILED: Could not find exactly one .sql file within the extracted single zip content in ${WP_EXTRACTED_PATH}"
            EXTRACT_STATUS=1 # Mark as failure
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


# --- Extract WordPress Archive ---
echo "Extracting WordPress archive..."
# Clean up any previous extraction attempt
rm -rf "${WP_EXTRACTED_PATH}"
mkdir -p "${WP_EXTRACTED_PATH}"

if [[ "${WP_ARCHIVE_FILE}" == *.zip ]]; then
    unzip -q "${WP_ARCHIVE_FILE}" -d "${WP_EXTRACTED_PATH}"
    EXTRACT_STATUS=$?
elif [[ "${WP_ARCHIVE_FILE}" == *.tar.gz || "${WP_ARCHIVE_FILE}" == *.tgz ]]; then
    tar -zxf "${WP_ARCHIVE_FILE}" -C "${WP_EXTRACTED_PATH}"
    EXTRACT_STATUS=$?
else
    echo "FAILED: Unrecognized archive format for ${WP_ARCHIVE_FILE}"
    exit 1
fi

if [[ $EXTRACT_STATUS -ne 0 ]]; then
    echo "FAILED: Could not extract archive file ${WP_ARCHIVE_FILE}"
    rm -rf "${WP_EXTRACTED_PATH}" # Clean up failed extraction
    exit 1
fi

# Check for wp-config.php within the extracted directory
# Handle cases where tar/zip might create a subdirectory
# Find wp-config.php within the extracted path, potentially in a subdirectory
WP_CONFIG_REL_PATH=$(find "${WP_EXTRACTED_PATH}" -name "wp-config.php" -printf "%P\n" | head -n 1)
if [[ -z "$WP_CONFIG_REL_PATH" ]]; then
    echo "FAILED: wp-config.php not found within the extracted archive content in ${WP_EXTRACTED_PATH}"
    rm -rf "${WP_EXTRACTED_PATH}" # Clean up
    exit 1
fi

# Determine the actual source path (could be WP_EXTRACTED_PATH or a subdirectory within it)
if [[ "$WP_CONFIG_REL_PATH" == "wp-config.php" ]]; then
    # wp-config.php is directly in WP_EXTRACTED_PATH
    WP_FILES_SOURCE_PATH="${WP_EXTRACTED_PATH}"
else
    # wp-config.php is in a subdirectory, adjust the source path
    SUBDIR=$(dirname "$WP_CONFIG_REL_PATH")
    WP_FILES_SOURCE_PATH="${WP_EXTRACTED_PATH}/${SUBDIR}"
fi
echo "PASSED: Archive extracted. WordPress source path set to: ${WP_FILES_SOURCE_PATH}"


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
DOMAIN=$(echo "$SITE_URL_RAW" | sed -E 's#^https?://##; s#/$##')
SITE_URL="$DOMAIN" # Use the clean domain as SITE_URL

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
          new_site_url=$(prompt_input "Enter correct Site URL" "${SITE_URL}" 300 "^https?://[a-zA-Z0-9.-]+[a-zA-Z0-9](/.*)?$")
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
if prompt_yes_no "Would you like to proceed with Cloudflare configuration?" "n" 300; then
    echo ""
    echo "Proceeding with Cloudflare configuration..."
    echo ""
    # Set CF_CHOICE for compatibility with existing logic
    CF_CHOICE="y"
else
    echo ""
    echo "Skipping Cloudflare configuration."
    echo ""
    # Set CF_CHOICE for compatibility with existing logic
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


# Verify if the extracted domain is already configured
if grep -Fxq "\"${DOMAIN}\"" /home/EngineScript/sites-list/sites.sh; then
  echo -e "\n\n${BOLD}Pre-import Check: Failed${NORMAL}\n\nDomain ${DOMAIN} (extracted from wp-config.php) is already configured in EngineScript.${NORMAL}\n\nIf you want to replace it, please remove the existing domain first using the ${BOLD}es.menu${NORMAL} command.\n\n"
  exit 1
else
  echo "${BOLD}Pre-import Check: Passed${NORMAL}"
fi

# Set Original URL from extracted data for search-replace consistency check
ORIGINAL_URL="https://${SITE_URL}" # Assume https for consistency
NEW_URL="https://${SITE_URL}"

# Logging
LOG_FILE="/var/log/EngineScript/vhost-import.log"
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "Starting domain import for ${DOMAIN} from archive ${WP_ARCHIVE_FILE} and DB ${DB_SOURCE_PATH} at $(date)" # Updated log message

# Continue the installation

# Store SQL credentials (Generate new ones for EngineScript)
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

# Secure Admin Subdomain
if [[ "${NGINX_SECURE_ADMIN}" == "1" ]];
  then
    sed -i "s|#satisfy any|satisfy any|g" "/etc/nginx/admin/admin.${DOMAIN}.conf"
    sed -i "s|#auth_basic|auth_basic|g" "/etc/nginx/admin/admin.${DOMAIN}.conf"
    sed -i "s|#allow |allow |g" "/etc/nginx/admin/admin.${DOMAIN}.conf"
  else
    echo ""
fi

# Enable HTTP/3 if configured
if [[ "${INSTALL_HTTP3}" == "1" ]]; then
  sed -i "s|#listen 443 quic|listen 443 quic|g" "/etc/nginx/sites-enabled/${DOMAIN}.conf"
  sed -i "s|#listen [::]:443 quic|listen [::]:443 quic|g" "/etc/nginx/sites-enabled/${DOMAIN}.conf"
fi

# Create Origin Certificate
mkdir -p "/etc/nginx/ssl/${DOMAIN}"

# Issue Certificate (Same as vhost-install)
echo "Issuing SSL Certificate via ACME.sh (ZeroSSL)..."
/root/.acme.sh/acme.sh --issue --dns dns_cf --server zerossl --ocsp -d "${DOMAIN}" -d "admin.${DOMAIN}" -d "*.${DOMAIN}" -k ec-384

# Install Certificate (Same as vhost-install)
/root/.acme.sh/acme.sh --install-cert -d "${DOMAIN}" --ecc \
--cert-file "/etc/nginx/ssl/${DOMAIN}/cert.pem" \
--key-file "/etc/nginx/ssl/${DOMAIN}/key.pem" \
--fullchain-file "/etc/nginx/ssl/${DOMAIN}/fullchain.pem" \
--ca-file "/etc/nginx/ssl/${DOMAIN}/ca.pem"

# Print date for logs
echo "System Date: $(date)"

# --- Database and File Handling ---

# Table Prefix is already extracted and stored in $PREFIX

# Domain Creation Variables (Generate *new* secure credentials for this server)
sand="${DOMAIN}" && SANDOMAIN="${sand%.*}" && SDB="${SANDOMAIN}_${RAND_CHAR4}"
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
sudo mariadb -e "CREATE DATABASE ${DB} CHARACTER SET ${DB_CHARSET} COLLATE ${DB_CHARSET}_unicode_ci;" # Use extracted charset
sudo mariadb -e "CREATE USER '${USR}'@'localhost' IDENTIFIED BY '${PSWD}';"
sudo mariadb -e "GRANT ALL ON ${DB}.* TO '${USR}'@'localhost'; FLUSH PRIVILEGES;"
sudo mariadb -e "GRANT ALL ON mysql.* TO '${USR}'@'localhost'; FLUSH PRIVILEGES;" # Needed for mariadb-health-checks plugin

# Backup Dir Creation (Same as vhost-install)
mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/database/daily"
mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/database/hourly"
mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/nginx"
mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/ssl-keys"
mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/wp-config"
mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/wp-content"
mkdir -p "/home/EngineScript/site-backups/${SITE_URL}/wp-uploads"

# Site Root
mkdir -p "/var/www/sites/${SITE_URL}/html"
TARGET_WP_PATH="/var/www/sites/${SITE_URL}/html"

# Domain Logs
mkdir -p "/var/log/domains/${SITE_URL}"
touch "/var/log/domains/${SITE_URL}/${SITE_URL}-wp-error.log"
touch "/var/log/domains/${SITE_URL}/${SITE_URL}-nginx-helper.log"
chown -R www-data:www-data "/var/log/domains/${SITE_URL}"

# --- Import WordPress Files ---
echo "Copying WordPress files from ${WP_FILES_SOURCE_PATH} to ${TARGET_WP_PATH}..." # Use the determined source path
# Use rsync for efficiency and better handling of permissions/ownership later
rsync -av --exclude 'wp-config.php' "${WP_FILES_SOURCE_PATH}/" "${TARGET_WP_PATH}/"
# Ensure correct ownership before proceeding with WP-CLI
chown -R www-data:www-data "${TARGET_WP_PATH}"
echo "WordPress files copied."

# Create Fonts Directories
mkdir -p "/var/www/sites/${SITE_URL}/html/wp-content/fonts"
mkdir -p "/var/www/sites/${SITE_URL}/html/wp-content/uploads/fonts"

# Create Languages Directory
mkdir -p "/var/www/sites/${SITE_URL}/html/wp-content/languages"

# --- Create wp-config.php ---
echo "Creating new wp-config.php with EngineScript settings..."
cp -rf "/usr/local/bin/enginescript/config/var/www/wordpress/wp-config.php" "${TARGET_WP_PATH}/wp-config.php"
# Use *new* DB credentials and *original* prefix
sed -i "s|SEDWPDB|${DB}|g" "${TARGET_WP_PATH}/wp-config.php"
sed -i "s|SEDWPUSER|${USR}|g" "${TARGET_WP_PATH}/wp-config.php"
sed -i "s|SEDWPPASS|${PSWD}|g" "${TARGET_WP_PATH}/wp-config.php"

# --- Debugging line added ---
echo "DEBUG: Attempting to set prefix. Value of PREFIX is: '${PREFIX}'"
# --- End Debugging line ---

sed -i "s|SEDPREFIX_|${PREFIX}|g" "${TARGET_WP_PATH}/wp-config.php" # Use original prefix
echo "DEBUG: sed command exit status for prefix: $?" # Check if sed reported an error

sed -i "s|SEDURL|${SITE_URL}|g" "${TARGET_WP_PATH}/wp-config.php"
sed -i "s|define( 'DB_CHARSET', 'utf8mb4' );|define( 'DB_CHARSET', '${DB_CHARSET}' );|g" "${TARGET_WP_PATH}/wp-config.php" # Use extracted DB Charset

# Redis Config (Same as vhost-install)
source /home/EngineScript/sites-list/sites.sh
if [[ "${#SITES[@]}" = 1 ]];
  then
    echo "There is only 1 domain in the site list. Not adding additional Redis databases."
    # Ensure WP_REDIS_DATABASE is 0 for the first site
    sed -i "s|WP_REDIS_DATABASE', 0|WP_REDIS_DATABASE', 0|g" "${TARGET_WP_PATH}/wp-config.php"
  else
    OLDREDISDB=$((${#SITES[@]} - 1))
    # Check if redis.conf needs update (avoid duplicate changes)
    if ! grep -q "databases ${#SITES[@]}" /etc/redis/redis.conf; then
        sed -i "s|databases ${OLDREDISDB}|databases ${#SITES[@]}|g" /etc/redis/redis.conf
        restart_service "redis-server"
    fi
    # Set WordPress to use the latest Redis database number.
    sed -i "s|WP_REDIS_DATABASE', 0|WP_REDIS_DATABASE', ${OLDREDISDB}|g" "${TARGET_WP_PATH}/wp-config.php"
fi

# Set Redis Prefix (Same as vhost-install)
REDISPREFIX="$(echo "${DOMAIN::5}")" && sed -i "s|SEDREDISPREFIX|${REDISPREFIX}|g" "${TARGET_WP_PATH}/wp-config.php"

# WP Salt Creation (Generate new salts)
echo "Generating new WordPress salts..."
SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
STRING='put your unique phrase here'
printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s "${TARGET_WP_PATH}/wp-config.php"

# WP Scan API Token (Same as vhost-install)
sed -i "s|SEDWPSCANAPI|${WPSCANAPI}|g" "${TARGET_WP_PATH}/wp-config.php"

# WP Recovery Email (Same as vhost-install)
sed -i "s|SEDWPRECOVERYEMAIL|${WP_RECOVERY_EMAIL}|g" "${TARGET_WP_PATH}/wp-config.php"

# Create robots.txt (Same as vhost-install)
cp -rf /usr/local/bin/enginescript/config/var/www/wordpress/robots.txt "${TARGET_WP_PATH}/robots.txt"
sed -i "s|SEDURL|${SITE_URL}|g" "${TARGET_WP_PATH}/robots.txt"

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
# Run search-replace for both http and https versions of the extracted domain to be safe
HTTP_ORIGINAL_URL="http://${DOMAIN}"
HTTPS_ORIGINAL_URL="https://${DOMAIN}"
wp search-replace "${HTTP_ORIGINAL_URL}" "${NEW_URL}" --all-tables --report-changed-only --allow-root
wp search-replace "${HTTPS_ORIGINAL_URL}" "${NEW_URL}" --all-tables --report-changed-only --allow-root

# Flush Cache and Rewrite Rules
echo "Flushing cache and rewrite rules..."
wp cache flush --allow-root
wp rewrite flush --hard --allow-root

# Install and Activate Essential EngineScript Plugins
echo "Installing essential plugins..."
# WP-CLI Install Plugins (Overwrite/update if already present from import)
wp plugin install app-for-cf --allow-root
wp plugin install autodescription --allow-root
wp plugin install flush-opcache --allow-root --activate # Activate this one
wp plugin install mariadb-health-checks --allow-root --activate # Activate this one
wp plugin install nginx-helper --allow-root --activate # Activate this one
wp plugin install php-compatibility-checker --allow-root
wp plugin install redis-cache --allow-root --activate # Activate this one
wp plugin install theme-check --allow-root
wp plugin install wp-crontrol --allow-root
wp plugin install wp-mail-smtp --allow-root --activate # Activate this one

# Install EngineScript custom plugins if enabled
if [[ "${INSTALL_ENGINESCRIPT_PLUGINS}" == "1" ]]; then
    echo "Installing EngineScript custom plugins..."
    # 1. Simple WP Optimizer plugin
    mkdir -p "/tmp/swpo-plugin"
    wget -q "https://github.com/EngineScript/Simple-WP-Optimizer/releases/latest/download/simple-wp-optimizer.zip" -O "/tmp/swpo-plugin/simple-wp-optimizer.zip"
    unzip -q -o "/tmp/swpo-plugin/simple-wp-optimizer.zip" -d "/var/www/sites/${SITE_URL}/html/wp-content/plugins/"
    rm -rf "/tmp/swpo-plugin"

    # 2. Simple Site Exporter plugin
    mkdir -p /tmp/sse-plugin
    wget -q "https://github.com/EngineScript/Simple-WP-Site-Exporter/releases/latest/download/simple-site-exporter.zip" -O "/tmp/sse-plugin/simple-site-exporter.zip"
    unzip -q -o "/tmp/sse-plugin/simple-site-exporter.zip" -d "/var/www/sites/${SITE_URL}/html/wp-content/plugins/"
    rm -rf /tmp/sse-plugin
else
    echo "Skipping EngineScript custom plugins installation (disabled in config)..."
fi

# Always perform these operations regardless of INSTALL_ENGINESCRIPT_PLUGINS setting
# WP-CLI Flush Transients


# WP-CLI Flush Transients
wp transient delete --all --allow-root

# Enable Redis Cache via WP-CLI
if wp plugin is-active redis-cache --allow-root; then
  echo "Enabling Redis object cache..."
  wp redis enable --allow-root
else
  echo "Warning: Redis Cache plugin not active. Skipping 'wp redis enable'."
fi

# Set permalink structure for FastCGI Cache (Good practice)
echo "Setting permalink structure to /%category%/%postname%/..."
wp option update permalink_structure '/%category%/%postname%/' --allow-root
wp rewrite flush --hard --allow-root

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

# Backup (Run backup for the newly imported site)
echo ""
echo "Backup script will now run for the imported site: ${SITE_URL}"
echo ""

# Date
NOW=$(date +%m-%d-%Y-%H)

# Filenames
DATABASE_FILE="${NOW}-database.sql";
# FULLWPFILES="${NOW}-wordpress-files.gz"; # Less common to back up full files daily
NGINX_FILE="${NOW}-nginx-vhost.conf.gz";
# PHP_FILE="${NOW}-php.tar.gz"; # PHP config backup not usually per-site
SSL_FILE="${NOW}-ssl-keys.gz";
# UPLOADS_FILE="${NOW}-uploads.tar.gz"; # Covered by wp-content backup
VHOST_FILE="${NOW}-nginx-vhost.conf.gz";
WPCONFIG_FILE="${NOW}-wp-config.php.gz";
WPCONTENT_FILE="${NOW}-wp-content.gz";

cd "${TARGET_WP_PATH}"

# Backup database
wp db export "/home/EngineScript/site-backups/${SITE_URL}/database/daily/$DATABASE_FILE" --add-drop-table --allow-root

# Compress database file
gzip -f "/home/EngineScript/site-backups/${SITE_URL}/database/daily/$DATABASE_FILE"

# Backup uploads, themes, and plugins (wp-content)
tar -zcf "/home/EngineScript/site-backups/${SITE_URL}/wp-content/$WPCONTENT_FILE" wp-content

# Nginx vhost backup
gzip -cf "/etc/nginx/sites-enabled/${SITE_URL}.conf" > "/home/EngineScript/site-backups/${SITE_URL}/nginx/${VHOST_FILE}"

# SSL keys backup
tar -zcf "/home/EngineScript/site-backups/${SITE_URL}/ssl-keys/${SSL_FILE}" "/etc/nginx/ssl/${SITE_URL}"

# wp-config.php backup
gzip -cf "${TARGET_WP_PATH}/wp-config.php" > "/home/EngineScript/site-backups/${SITE_URL}/wp-config/${WPCONFIG_FILE}"

# Remove old backups (Keep this logic)
find "/home/EngineScript/site-backups/${SITE_URL}/database/daily" -type f -mtime +7 | xargs rm -fR
find "/home/EngineScript/site-backups/${SITE_URL}/nginx" -type f -mtime +7 | xargs rm -fR
find "/home/EngineScript/site-backups/${SITE_URL}/ssl-keys" -type f -mtime +7 | xargs rm -fR
find "/home/EngineScript/site-backups/${SITE_URL}/wp-config" -type f -mtime +7 | xargs rm -fR
find "/home/EngineScript/site-backups/${SITE_URL}/wp-content" -type f -mtime +15 | xargs rm -fR

echo "Backup: Complete"
clear

# --- Final Summary ---
echo ""
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo "|${BOLD}Import Summary & Credentials${NORMAL}:             |"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo "For your records (New Database Credentials):"
echo "-------------------------------------------------------"
echo ""
echo "${BOLD}URL:${NORMAL}               ${SITE_URL}"
echo "-----------------"
echo "${BOLD}Database:${NORMAL}          ${DB}"
echo "${BOLD}DB Table Prefix:${NORMAL}   ${PREFIX}" # Show the original prefix used
echo "${BOLD}DB User:${NORMAL}           ${USR}"
echo "${BOLD}DB Password:${NORMAL}       ${PSWD}"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""
echo "MySQL Domain login credentials backed up to:"
echo "/home/EngineScript/mysql-credentials/${SITE_URL}.txt" # Corrected path
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
echo "WordPress wp-content directory backed up to:"
echo "/home/EngineScript/site-backups/${SITE_URL}/wp-content"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""

sleep 3

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
    echo "Original archive (${WP_ARCHIVE_FILE}) and database (${DB_SOURCE_PATH}) files in ${IMPORT_BASE_DIR} will NOT be removed."
    echo "Please investigate the issue and use 'es.menu' to remove the domain '${SITE_URL}' when ready."
    echo "Exiting script now."
    exit 1 # Exit without full cleanup
fi
# --- End Site Verification Step ---


echo "Returning to main menu..." # Message if 'y' was chosen
sleep 5

# Exit cleanly (only reached if 'y' was chosen)
exit 0
