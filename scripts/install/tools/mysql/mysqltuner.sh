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


#----------------------------------------------------------------------------------
# Start Main Script

# MYSQLTuner
mkdir -p /usr/local/bin/mysqltuner
download_file "https://raw.githubusercontent.com/major/MySQLTuner-perl/master/mysqltuner.pl" "/usr/local/bin/mysqltuner/mysqltuner.pl"
download_file "https://raw.githubusercontent.com/major/MySQLTuner-perl/master/basic_passwords.txt" "/usr/local/bin/mysqltuner/basic_passwords.txt"
download_file "https://raw.githubusercontent.com/major/MySQLTuner-perl/master/vulnerabilities.csv" "/usr/local/bin/mysqltuner/vulnerabilities.csv"
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
