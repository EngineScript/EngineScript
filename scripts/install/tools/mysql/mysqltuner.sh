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

# MYSQLTuner
mkdir -p /usr/local/bin/mysqltuner
safe_wget "https://raw.githubusercontent.com/major/MySQLTuner-perl/master/mysqltuner.pl" "/usr/local/bin/mysqltuner/mysqltuner.pl"
safe_wget "https://raw.githubusercontent.com/major/MySQLTuner-perl/master/basic_passwords.txt" "/usr/local/bin/mysqltuner/basic_passwords.txt"
safe_wget "https://raw.githubusercontent.com/major/MySQLTuner-perl/master/vulnerabilities.csv" "/usr/local/bin/mysqltuner/vulnerabilities.csv"
chmod +x /usr/local/bin/mysqltuner/mysqltuner.pl
chmod 644 /usr/local/bin/mysqltuner/vulnerabilities.csv

echo ""
echo ""
echo "============================================================="
echo ""
echo "${BOLD}MySQLTuner installed.${NORMAL}"
echo ""
echo "To run MySQLTuner:"
echo "perl /usr/local/bin/mysqltuner/mysqltuner.pl"
echo ""
echo "============================================================="
echo ""
echo ""
