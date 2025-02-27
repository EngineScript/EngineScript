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

# WP-CLI
cd /usr/local/src
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
mkdir -p /tmp/wp-cli-phar
chown -R www-data:www-data /tmp/wp-cli-phar
chmod 775 /tmp/wp-cli-phar
mkdir -p .wp-cli/cache
chown -R www-data:www-data .wp-cli/cache
chmod 775 .wp-cli/cache

# Install WP-CLI Extensions
wp package install 10up/wpcli-vulnerability-scanner:@stable --allow-root
wp package install pantheon-systems/wp_launch_check:@stable --allow-root
wp package install wp-cli/doctor-command:@stable --allow-root

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}WP-CLI installed.${NORMAL}"
echo ""
echo "Learn about WP-CLI"
echo "https://make.wordpress.org/cli/handbook/"
echo ""
echo "============================================================="
echo ""
echo ""

sleep 5
