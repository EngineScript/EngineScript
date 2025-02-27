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

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" -ne 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit 1
fi

#----------------------------------------------------------------------------------
# Start Main Script

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

# Select site
cd /var/www/sites
printf "Please select the site you want to remove infected files on:\n"
select d in *; do test -n "$d" && break; echo ">>> Invalid Selection"; done
cd "$d" && echo "Wordfence CLI will attempt to remediate infections of known files by reverting them back to their original version."
echo -e "\nEngineScript will now create a new database and full file backup for your site.
\n\nIf something goes wrong, the backup files can be found in in:
\n/home/EngineScript/site-backups/${d}/wordfence-cli-remediate-backup/${NOW}\n\n"

# Make backup directory
mkdir -p /home/EngineScript/site-backups/${d}/wordfence-cli-remediate-backup/${NOW}

# Export database
wp db export --path=/var/www/sites/${d}/html "/home/EngineScript/site-backups/${d}/wordfence-cli-remediate-backup/${NOW}/${DATABASE_FILE}" --add-drop-table --allow-root

# Export files locally
#cd /var/www/sites/${d}/html
tar -zcvf "/home/EngineScript/site-backups/${d}/wordfence-cli-remediate-backup/${NOW}/${FULLWPFILES}" html

echo -e "\nBackup completed.
\n\nIf something goes wrong, the backup files can be found in in:
\n/home/EngineScript/site-backups/${d}/wordfence-cli-remediate-backup/${NOW}\n\n"

# Remediate
echo -e "\nStarting the remediate process...
\n\nThis will take a while.\n\n"
sleep 3

wordfence remediate /var/www/sites/${d}/html

# Ask user to acknowledge that the scan has completed before moving on
echo ""
echo ""
echo "The remediate process has been completed."
echo ""
read -n 1 -s -r -p "Press any key to continue"
echo ""
echo ""
