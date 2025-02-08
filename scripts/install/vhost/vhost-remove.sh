#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

# Check current user's ID. If user is not 0 (root), exit.
if [ "${EUID}" != 0 ];
  then
    echo "${BOLD}ALERT:${NORMAL}"
    echo "EngineScript should be executed as the root user."
    exit
fi

#----------------------------------------------------------------------------
# Start Main Script

# Intro Warning
echo ""
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo "|   Domain Removal                                    |"
echo "-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-==-"
echo ""
echo -e "WARNING: This script will remove a site from your installation.\n\n${BOLD}This removal is non-reversible and everything will be destroyed, including backups.${NORMAL}\nPlease be 100% sure of your choice before continuing on with this process.\n\n"
sleep 1

while true; do
  read -p "Are you sure you want to remove a domain from your server? Please type Yes or No: " yn
    case $yn in
      [Yy][Ee][Ss] ) echo "Continuing"; break;;
      [Nn][Oo] ) echo "Exiting"; exit 1;;
      * ) echo "Please answer Yes or No.";;
    esac
done

# Domain Input
echo "For domain name, enter only the domain without https:// or trailing /"
echo "note:   lowercase text only"
echo ""
echo "Examples:    wordpresstesting.com"
echo "             wordpresstesting.net"
echo ""
read -p "Enter Domain name: " DOMAIN
echo ""
echo "You entered:  ${DOMAIN}"

# Remove domain from site list
if grep -Fxq "${DOMAIN}" /home/EngineScript/sites-list/sites.sh
then
  echo -e "${BOLD}Site List Removal Check: Passed\n\n${NORMAL}Removing ${DOMAIN} from site list...\n\n"
  grep -v "\"${DOMAIN}\"" /home/EngineScript/sites-list/sites.sh > /home/EngineScript/sites-list/sites.sh.old; mv /home/EngineScript/sites-list/sites.sh.old /home/EngineScript/sites-list/sites.sh
else
  echo -e "${BOLD}Site List Removal Check: Failed\n\n${NORMAL}${DOMAIN} was not found on the site list.\n\n"
fi

# Remove MySQL credentials
if test -f /home/EngineScript/mysql-credentials/${DOMAIN}.txt
then
  echo -e "${BOLD}MySQL Credentials Removal Check: Passed\n\n${NORMAL}Removing MySQL credentials for ${DOMAIN}...\n\n"
  source /home/EngineScript/mysql-credentials/${DOMAIN}.txt
  sudo mariadb -e "DROP DATABASE ${DB};"
  sudo mariadb -e "DROP USER '${USR}'@'localhost';"
  rm -f /home/EngineScript/mysql-credentials/${DOMAIN}.txt
else
  echo -e "${BOLD}MySQL Credentials Check: Failed\n\n${NORMAL}${DOMAIN} did not have MySQL credentials.\n\n"
fi

# Remove Nginx vhost
if test -f /etc/nginx/sites-enabled/${DOMAIN}.conf
then
  echo -e "${BOLD}Nginx Vhost Removal Check: Passed\n\n${NORMAL}Removing ${DOMAIN} from Nginx...\n\n"
  rm -rf /etc/nginx/sites-enabled/${DOMAIN}.conf
else
  echo -e "${BOLD}Nginx Vhost Removal Check: Failed\n\n${NORMAL}${DOMAIN} did not have an Nginx vhost.\n\n"
fi

# Remove SSL certificates
if [ -d "/etc/nginx/ssl/${DOMAIN}" ];
then
  echo -e "${BOLD}SSL Certificates Removal Check: Passed\n\n${NORMAL}Removing SSL certificates for ${DOMAIN}...\n\n"
  rm -rf /etc/nginx/ssl/${DOMAIN}
else
  echo -e "${BOLD}SSL Certificates Removal Check: Failed\n\n${NORMAL}${DOMAIN} did not have SSL Certificates.\n\n"
fi

# Remove main directory
if [ -d "/var/www/sites/${DOMAIN}" ];
then
  echo -e "${BOLD}Main Directory Removal Check: Passed\n\n${NORMAL}Removing main directory for ${DOMAIN}...\n\n"
  rm -rf /var/www/sites/${DOMAIN}
else
  echo -e "${BOLD}Main Directory Removal Check: Failed\n\n${NORMAL}${DOMAIN} did not have a main directory.\n\n"
fi

# Remove backup directory
if [ -d "/home/EngineScript/site-backups/${DOMAIN}" ];
then
  echo -e "${BOLD}Backup Directory Removal Check: Passed\n\n${NORMAL}Removing backup directory for ${DOMAIN}...\n\n"
  rm -rf /home/EngineScript/site-backups/${DOMAIN}
else
  echo -e "${BOLD}Backup Directory Removal Check: Failed\n\n${NORMAL}${DOMAIN} did not have a backup directory.\n\n"
fi

# Remove log directory
if [ -d "/var/log/domains/${DOMAIN}" ];
then
  echo -e "${BOLD}Log Directory Removal Check: Passed\n\n${NORMAL}Removing log directory for ${DOMAIN}...\n\n"
  rm -rf /var/log/domains/${DOMAIN}
else
  echo -e "${BOLD}Log Directory Removal Check: Failed\n\n${NORMAL}${DOMAIN} did not have a log directory.\n\n"
fi

# Restart Services
echo "Restarting Nginx and PHP"
/usr/local/bin/enginescript/scripts/functions/alias/alias-restart.sh
echo ""

echo ""
echo "============================================================="
echo ""
echo "              Domain removal completed."
echo ""
echo "        Returning to main menu in 5 seconds."
echo ""
echo "============================================================="
echo ""

sleep 5
