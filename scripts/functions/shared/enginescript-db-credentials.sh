#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------
# Shared Database Credential Functions
# This file contains functions for generating, validating, and applying
# MariaDB/MySQL credentials used by vhost-install.sh and vhost-import.sh.
#----------------------------------------------------------------------------------


#----------------------------------------------------------------------------------
# Constants
#----------------------------------------------------------------------------------

# Database username validation bounds
DB_USER_MIN_LENGTH=8
DB_USER_MAX_LENGTH=80

# Allowed charsets for import credential validation
ALLOWED_DB_CHARSETS=(
  "utf8mb4"
  "utf8"
  "latin1"
)

# Domain endings, in one place. Create Domain offers COMMON_TLDS and MULTIPART_PUBLIC_SUFFIXES as
# its list of endings, and generate_db_name strips a multi-part suffix whole (example.co.uk gives
# "example", not "example_co").
# shellcheck disable=SC2034  # read by vhost-install.sh
COMMON_TLDS=(
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
)

MULTIPART_PUBLIC_SUFFIXES=(
  "co.uk" "org.uk" "gov.uk" "ac.uk"
  "com.au" "net.au" "org.au"
  "co.nz" "org.nz"
  "co.jp"
  "com.br" "com.sg" "com.my" "com.mx"
  "co.za" "com.tr" "com.hk"
)


#----------------------------------------------------------------------------------
# Escape arbitrary text for safe inclusion in MariaDB single-quoted string literals.
#----------------------------------------------------------------------------------
escape_sql_string_literal() {
  local input="$1"
  input="${input//\\/\\\\}"
  input="${input//\'/\'\'}"
  printf '%s' "$input"
  return
}


#----------------------------------------------------------------------------------
# Validate a database identifier for safe use in backtick-quoted SQL.
# Arguments:
#   $1 - The database identifier to validate
#   $2 - The domain context (for error messages)
#----------------------------------------------------------------------------------
validate_db_identifier() {
  local db_identifier="$1"
  local domain_context="$2"
  # Explicitly reject backticks as defense-in-depth for backtick-quoted SQL identifiers.
  if [[ -z "${db_identifier}" || ! "${db_identifier}" =~ ^[A-Za-z][A-Za-z0-9_]*$ || "${db_identifier}" == *'`'* ]]; then
    echo "Error: Invalid database name '${db_identifier}' for domain '${domain_context}'." >&2
    return 1
  fi
}


#----------------------------------------------------------------------------------
# Generate the database name for a new or imported site.
# The domain without its public suffix, with every character other than a letter or digit
# turned into "_" (and "db_" in front when it starts with a digit), then a hash of the full
# domain and a random suffix. Enforces the 64-char MariaDB identifier limit.
#   example.com      -> example_<hash>_<rand>
#   my-site.co.uk    -> my_site_<hash>_<rand>
#   1password.com    -> db_1password_<hash>_<rand>
#   blog.example.com -> blog_example_<hash>_<rand>
#
# Arguments:
#   $1 - DOMAIN (e.g. "wordpresstesting.com" or "example.co.uk")
#
# Requires: es_random (enginescript-common.sh)
# Sets:     ES_DB_NAME (the constructed database name)
#----------------------------------------------------------------------------------
generate_db_name() {
  local DOMAIN="$1"
  local domain_without_tld="${DOMAIN%.*}"
  local public_suffix
  local domain_hash
  local db_name_suffix
  local max_db_name_len=64
  local expected_db_name_suffix_len=14
  local max_domain_without_tld_len

  for public_suffix in "${MULTIPART_PUBLIC_SUFFIXES[@]}"; do
    if [[ "${DOMAIN}" == *".${public_suffix}" ]]; then
      domain_without_tld="${DOMAIN%".${public_suffix}"}"
      break
    fi
  done

  # Hyphens and the dots of a subdomain are not allowed in the identifier; neither is a leading digit
  domain_without_tld="${domain_without_tld//[^A-Za-z0-9]/_}"
  if [[ ! "${domain_without_tld}" =~ ^[A-Za-z] ]]; then
    domain_without_tld="db_${domain_without_tld}"
  fi

  # The suffix ends with 4 random letters and digits (es_random).
  # Enforce MySQL/MariaDB identifier max length (64 chars) before concatenation.
  # Include a stable hash of the full domain to avoid collisions when truncation occurs.
  domain_hash="$(printf '%s' "${DOMAIN}" | sha256sum | awk '{print $1}' | cut -c1-8)"
  if [[ ! "${domain_hash}" =~ ^[0-9a-f]{8}$ ]]; then
    echo "Error: Failed to generate domain hash for database name suffix (got '${domain_hash}')." >&2
    return 1
  fi
  db_name_suffix="_${domain_hash}_$(es_random 4)"
  # Expected: '_' (1) + domain_hash (8) + '_' (1) + random (4) = 14 chars.
  if (( ${#db_name_suffix} != expected_db_name_suffix_len )); then
    echo "Error: Invalid random suffix length for database name generation (expected ${expected_db_name_suffix_len}, got ${#db_name_suffix})." >&2
    return 1
  fi
  max_domain_without_tld_len=$((max_db_name_len - ${#db_name_suffix}))
  if (( ${#domain_without_tld} > max_domain_without_tld_len )); then
    echo "Warning: Truncating database name base '${domain_without_tld}' to ${max_domain_without_tld_len} characters for domain '${DOMAIN}'." >&2
    domain_without_tld="${domain_without_tld:0:max_domain_without_tld_len}"
  fi
  ES_DB_NAME="${domain_without_tld}${db_name_suffix}"

  # Validate DB identifier before writing credentials file or interpolating into SQL
  validate_db_identifier "${ES_DB_NAME}" "${DOMAIN}"
}


#----------------------------------------------------------------------------------
# Validate credentials using the vhost-install method.
# Checks database_user length (8-80) and charset (a-zA-Z0-9 only).
# Checks database_password charset (a-zA-Z0-9_ only).
#
# Arguments:
#   $1 - database_user
#   $2 - database_password
#   $3 - DOMAIN (for error messages)
#----------------------------------------------------------------------------------
validate_install_credentials() {
  local database_user="$1"
  local database_password="$2"
  local DOMAIN="$3"

  # es_random uses a-zA-Z0-9 only; the regex matches that exact charset.
  if [[ -z "${database_user}" || ${#database_user} -lt "${DB_USER_MIN_LENGTH}" || ${#database_user} -gt "${DB_USER_MAX_LENGTH}" || ! "${database_user}" =~ ^[A-Za-z0-9]+$ ]]; then
    echo "Error: Invalid generated MariaDB user '${database_user}' for domain '${DOMAIN}' (must be ${DB_USER_MIN_LENGTH}-${DB_USER_MAX_LENGTH} characters and contain only letters or numbers)." >&2
    return 1
  fi

  if [[ -z "${database_password}" || ! "${database_password}" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "Error: Invalid generated database password for domain '${DOMAIN}'." >&2
    return 1
  fi
}


#----------------------------------------------------------------------------------
# Validate credentials using the vhost-import method.
# Validates charset allowlist, DB/USR regex, PSWD SQL-safety.
#
# Arguments:
#   $1 - DB (database name)
#   $2 - USR (database user)
#   $3 - PSWD (database password)
#   $4 - DB_CHARSET (e.g. "utf8mb4")
#
# Sets:     ES_DB_CHARSET_VALIDATED, ES_DB_COLLATION
#----------------------------------------------------------------------------------
validate_import_credentials() {
  local DB="$1"
  local USR="$2"
  local PSWD="$3"
  local DB_CHARSET="$4"

  # Validate SQL inputs before interpolation to prevent SQL injection/syntax issues.
  ES_DB_CHARSET_VALIDATED="$(printf '%s' "${DB_CHARSET}" | tr '[:upper:]' '[:lower:]')"
  case "${ES_DB_CHARSET_VALIDATED}" in
      utf8mb4|utf8|latin1)
          ;;
      *)
          local ALLOWED_DB_CHARSETS_CSV
          ALLOWED_DB_CHARSETS_CSV="$(printf '%s, ' "${ALLOWED_DB_CHARSETS[@]}" | sed 's/, $//')"
          echo "Error: Invalid DB_CHARSET value '${DB_CHARSET}'. Allowed values: ${ALLOWED_DB_CHARSETS_CSV}." >&2
          return 1
          ;;
  esac
  # shellcheck disable=SC2034  # read by the caller, as ES_DB_CHARSET_VALIDATED is
  ES_DB_COLLATION="${ES_DB_CHARSET_VALIDATED}_unicode_ci"

  if [[ ! "${DB}" =~ ^[A-Za-z0-9_]+$ ]]; then
      echo "Error: Generated database name contains invalid characters: ${DB}" >&2
      return 1
  fi
  if [[ ! "${USR}" =~ ^[A-Za-z0-9_]+$ ]]; then
      echo "Error: Generated database user contains invalid characters: ${USR}" >&2
      return 1
  fi
  if [[ "${PSWD}" == *"'"* || "${PSWD}" == *"\\"* ]]; then
      echo "Error: Generated database password contains unsupported SQL-unsafe characters." >&2
      return 1
  fi
}


#----------------------------------------------------------------------------------
# Write database credentials to a file with secure permissions.
#
# Arguments:
#   $1 - credentials_dir (directory to write the file in)
#   $2 - domain (used as the filename: <domain>.txt)
#   $3 - database_name (DB value)
#   $4 - database_user (USR value)
#   $5 - database_password (PSWD value)
#
# Sets:     DB, USR, PSWD (via sourcing the written file)
#----------------------------------------------------------------------------------
write_credentials_file() {
  local credentials_dir="$1"
  local domain="$2"
  local database_name="$3"
  local database_user="$4"
  local database_password="$5"
  local credentials_file="${credentials_dir}/${domain}.txt"

  # Ensure parent directory exists and is restricted before writing sensitive data
  install -d -m 700 "${credentials_dir}"
  chmod 700 "${credentials_dir}"
  # Create the file with restrictive permissions before writing any sensitive data
  install -m 600 /dev/null "${credentials_file}"
  echo "DB=\"${database_name}\"" >> "${credentials_file}"
  echo "USR=\"${database_user}\"" >> "${credentials_file}"
  echo "PSWD=\"${database_password}\"" >> "${credentials_file}"
  echo "" >> "${credentials_file}"

  # shellcheck source=/dev/null
  source "${credentials_file}"
}


#----------------------------------------------------------------------------------
# Execute the SQL statements for vhost-install credential creation.
# Uses printf -v for database creation and escape_sql_string_literal for password.
#
# Arguments:
#   $1 - DB (database name, from sourced credentials file)
#   $2 - USR (database user)
#   $3 - PSWD (database password)
#   $4 - DOMAIN (for error messages)
#----------------------------------------------------------------------------------
execute_install_sql() {
  local DB="$1"
  local USR="$2"
  local PSWD="$3"
  local DOMAIN="$4"
  local create_db_sql
  local SQL_ESCAPED_PSWD

  printf -v create_db_sql "CREATE DATABASE \`%s\` CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci;" "${DB}"
  if ! mariadb -e "${create_db_sql}"; then
    echo "Error: Failed to create database '${DB}' for domain '${DOMAIN}'." >&2
    return 1
  fi

  SQL_ESCAPED_PSWD="$(escape_sql_string_literal "${PSWD}")"

  if ! mariadb -e "CREATE USER '${USR}'@'localhost' IDENTIFIED BY '${SQL_ESCAPED_PSWD}';"; then
    echo "Error: Failed to create MariaDB user '${USR}' for domain '${DOMAIN}'." >&2
    return 1
  fi

  if ! mariadb -e "GRANT ALL ON \`${DB}\`.* TO '${USR}'@'localhost'; FLUSH PRIVILEGES;"; then
    echo "Error: Failed to grant privileges on database '${DB}' to user '${USR}'." >&2
    return 1
  fi
}


#----------------------------------------------------------------------------------
# Convert a database's MyISAM tables to InnoDB.
# A site imported from an older server can bring MyISAM tables: the dump keeps each table's
# engine. InnoDB is crash-safe and locks rows instead of whole tables, which is what WordPress
# and EngineScript's MariaDB settings expect. A table that cannot be converted stays MyISAM
# and is reported; the site keeps working.
#
# Arguments:
#   $1 - database name
#
# Returns 0 when every MyISAM table was converted (or there were none), 1 otherwise.
#----------------------------------------------------------------------------------
convert_myisam_tables_to_innodb() {
  local db="$1"
  local table
  local converted=0
  local tables=()

  validate_db_identifier "${db}" "${db}" || return 1

  mapfile -t tables < <(mariadb -N -e "SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = '${db}' AND ENGINE = 'MyISAM' AND TABLE_TYPE = 'BASE TABLE' ORDER BY TABLE_NAME;")
  if [[ ${#tables[@]} -eq 0 ]]; then
    return 0
  fi

  echo "Converting ${#tables[@]} MyISAM table(s) in '${db}' to InnoDB..."
  for table in "${tables[@]}"; do
    # Table names come from the server; double any backtick for the quoted identifier
    if mariadb -e "ALTER TABLE \`${db}\`.\`${table//\`/\`\`}\` ENGINE=InnoDB;"; then
      converted=$((converted + 1))
    else
      echo "Warning: Could not convert table '${table}' to InnoDB; it stays MyISAM." >&2
    fi
  done
  echo "Converted ${converted} of ${#tables[@]} MyISAM table(s) to InnoDB."
  [[ "${converted}" -eq ${#tables[@]} ]]
}


#----------------------------------------------------------------------------------
# Execute the SQL statements for vhost-import credential creation.
# Uses charset/collation interpolation. The site user gets privileges on its own database
# only, as with vhost-install: privileges on the mysql system database would let a site
# change any account's privileges and reach every other site's database.
#
# Arguments:
#   $1 - DB (database name)
#   $2 - USR (database user)
#   $3 - PSWD (database password)
#   $4 - DB_CHARSET_VALIDATED (validated charset, e.g. "utf8mb4")
#   $5 - DB_COLLATION (e.g. "utf8mb4_unicode_ci")
#----------------------------------------------------------------------------------
execute_import_sql() {
  local DB="$1"
  local USR="$2"
  local PSWD="$3"
  local DB_CHARSET_VALIDATED="$4"
  local DB_COLLATION="$5"

  # Use validated charset
  if ! mariadb -e "CREATE DATABASE \`${DB}\` CHARACTER SET ${DB_CHARSET_VALIDATED} COLLATE ${DB_COLLATION};"; then
    echo "Error: Failed to create database '${DB}'." >&2
    return 1
  fi

  if ! mariadb -e "CREATE USER '${USR}'@'localhost' IDENTIFIED BY '${PSWD}';"; then
    echo "Error: Failed to create MariaDB user '${USR}'." >&2
    return 1
  fi

  if ! mariadb -e "GRANT ALL ON \`${DB}\`.* TO '${USR}'@'localhost'; FLUSH PRIVILEGES;"; then
    echo "Error: Failed to grant privileges on database '${DB}' to user '${USR}'." >&2
    return 1
  fi
}
