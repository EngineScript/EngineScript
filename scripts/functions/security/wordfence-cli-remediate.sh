#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript settings and shared functions
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-env.sh" >&2; exit 1; }

# Source the site archive builder
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-site-archive.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-site-archive.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# Date
NOW=$(date +%m-%d-%Y-%H)

# Select site
printf "Please select the site you want to remove infected files on:\n"
select_site || exit 0
BACKUP_DIR="/home/EngineScript/site-backups/${SELECTED_SITE}/wordfence-cli-remediate-backup/${NOW}"
echo "Wordfence CLI will attempt to remediate infections of known files by reverting them back to their original version."
echo -e "\nEngineScript will now back up your site's files and database as a site archive.\n"

# A site archive, so Import Domain can restore the site from it
if ! build_site_archive "${SELECTED_SITE}" "${BACKUP_DIR}/${SELECTED_SITE}-site-archive.zip"; then
  echo ""
  echo "The backup failed (see the message above), so the remediation was not started."
  pause
  exit 1
fi

echo -e "\nBackup completed.
\n\nIf something goes wrong, the backup can be found in:
\n${BACKUP_DIR}/${SELECTED_SITE}-site-archive.zip\n\n"

# Remediate
echo -e "\nStarting the remediate process...
\n\nThis will take a while.\n\n"
sleep 3

wordfence remediate "/var/www/sites/${SELECTED_SITE}/html"

# Ask user to acknowledge that the scan has completed before moving on
echo ""
echo ""
echo "The remediate process has been completed."
pause
