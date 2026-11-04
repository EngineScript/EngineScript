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


#----------------------------------------------------------------------------------
# Start Main Script

resolve_backup_settings
AWS="/usr/local/bin/aws"

# Wait for a key before the menu redraws
pause() {
  echo ""
  read -n 1 -s -r -p "Press any key to continue"
  echo ""
  echo ""
}

# The newest dated folder in a backup folder, its size, and how many are kept
latest_backup() {
  local newest count
  newest="$(find "$1" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2> /dev/null | sort | tail -n 1)"
  if [[ -z "${newest}" ]]; then
    echo "none"
    return
  fi
  count="$(find "$1" -mindepth 1 -maxdepth 1 -type d | wc -l)"
  echo "${newest} ($(du -sh "$1/${newest}" | cut -f1); ${count} kept)"
}

# The newest local backup of each kind, per site, and where copies go
show_backups() {
  local SITES=() site base size
  if [[ -f /home/EngineScript/sites-list/sites.sh ]]; then
    # shellcheck source=/dev/null
    source /home/EngineScript/sites-list/sites.sh
  fi
  echo ""
  echo "Local backups in /home/EngineScript/site-backups (the newest of each kind):"
  [[ "${#SITES[@]}" -eq 0 ]] && echo "  No sites yet."
  for site in "${SITES[@]}"; do
    base="/home/EngineScript/site-backups/${site}"
    size="$(du -sh "${base}" 2> /dev/null | cut -f1)"
    echo ""
    echo "  ${site} (${size:-0} in all)"
    printf '    %-20s %s\n' "Database (daily)" "$(latest_backup "${base}/database/daily")"
    printf '    %-20s %s\n' "Database (hourly)" "$(latest_backup "${base}/database/hourly")"
    printf '    %-20s %s\n' "Files (wp-content)" "$(latest_backup "${base}/files")"
  done
  echo ""
  printf '  %-22s %s\n' "EngineScript config" "$(latest_backup /home/EngineScript/config-backups/enginescript)"
  echo ""
  if [[ "${BACKUP_S3}" == "1" ]]; then
    echo "Copies go to Amazon S3: s3://${S3_BUCKET_NAME}/"
  else
    echo "Copies to Amazon S3 are off (BACKUP_S3 in es.config)."
  fi
  echo "Each backup run is logged in /var/log/EngineScript/enginescript-backup.log."
}

# Check the AWS credentials, then list, write, and delete a small test file in the bucket
test_s3() {
  local key test_file
  echo ""
  if [[ "${BACKUP_S3}" != "1" || -z "${S3_BUCKET_NAME:-}" || "${S3_BUCKET_NAME}" == "PLACEHOLDER" ]]; then
    echo "Copies to Amazon S3 are off. Set BACKUP_S3=1 and S3_BUCKET_NAME in es.config to turn them on."
    return 1
  fi
  if [[ ! -x "${AWS}" ]]; then
    echo "The AWS CLI is not installed (${AWS}). Set INSTALL_S3_BACKUP=1 in es.config and run:"
    echo "  /usr/local/bin/enginescript/scripts/install/tools/system/amazon-s3-install.sh"
    return 1
  fi
  echo "Credentials:"
  if ! "${AWS}" sts get-caller-identity --query Arn --output text; then
    echo "The AWS credentials do not work. Set them again with: aws configure"
    return 1
  fi
  echo ""
  echo "Listing s3://${S3_BUCKET_NAME}/:"
  if ! "${AWS}" s3 ls "s3://${S3_BUCKET_NAME}/" > /dev/null; then
    echo "The bucket could not be listed: check its name and the s3:ListBucket permission."
    return 1
  fi
  echo "  OK"
  echo ""
  key="enginescript-connection-test/$(hostname)-$(date +%Y%m%d%H%M%S).txt"
  test_file="$(mktemp)"
  echo "EngineScript S3 connection test from $(hostname), $(date)" > "${test_file}"
  echo "Writing s3://${S3_BUCKET_NAME}/${key}:"
  if ! "${AWS}" s3 cp "${test_file}" "s3://${S3_BUCKET_NAME}/${key}" --only-show-errors; then
    rm -f "${test_file}"
    echo "The test file could not be written: backups need the s3:PutObject permission."
    return 1
  fi
  rm -f "${test_file}"
  echo "  OK"
  echo ""
  echo "Deleting the test file:"
  if "${AWS}" s3 rm "s3://${S3_BUCKET_NAME}/${key}" --only-show-errors; then
    echo "  OK"
  else
    echo "  The test file stays in the bucket: deleting needs s3:DeleteObject, which backups only use"
    echo "  when BACKUP_S3_KEEP_DAYS is set."
  fi
  echo ""
  echo "S3 backups can reach the bucket."
}

# Main Menu
while true
  do
    clear
    echo -e "Backup Tools" | boxes -a c -d shell -p a1l2
    echo ""
    echo ""
    PS3='Please enter your choice: '
    secoptions=(
      "Backup (All Domains)"
      "Backup One Domain"
      "List Backups"
      "Test S3 Connection"
      "Exit Backup Tools"
    )
    select secopt in "${secoptions[@]}"
    do
      case $secopt in
        "Backup (All Domains)")
          echo "Backing up all domains..."
          /usr/local/bin/enginescript/scripts/functions/alias/alias-backup.sh
          echo ""
          echo "Done!"
          echo ""
          read -n 1 -s -r -p "Press any key to continue"
          echo ""
          echo ""
          break
          ;;
        "Backup One Domain")
          if select_site; then
            echo "Backing up ${SELECTED_SITE}'s database, wp-config.php, and wp-content..."
            if bash /usr/local/bin/enginescript/scripts/functions/backup/enginescript-backup.sh site "${SELECTED_SITE}"; then
              echo ""
              echo "Done!"
            else
              echo ""
              echo "The backup had errors: see /var/log/EngineScript/enginescript-backup.log"
            fi
          fi
          pause
          break
          ;;
        "List Backups")
          show_backups
          pause
          break
          ;;
        "Test S3 Connection")
          test_s3
          pause
          break
          ;;
        "Exit Backup Tools")
          exit
          ;;
        *) echo "Invalid option.";;
      esac
    done
  done
