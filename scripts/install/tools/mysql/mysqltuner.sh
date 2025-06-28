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



#----------------------------------------------------------------------------------
# Start Main Script

# MYSQLTuner
mkdir -p /usr/local/bin/mysqltuner
wget -O /usr/local/bin/mysqltuner/mysqltuner.pl https://raw.githubusercontent.com/major/MySQLTuner-perl/master/mysqltuner.pl --no-check-certificate
wget -O /usr/local/bin/mysqltuner/basic_passwords.txt https://raw.githubusercontent.com/major/MySQLTuner-perl/master/basic_passwords.txt --no-check-certificate
wget -O /usr/local/bin/mysqltuner/vulnerabilities.csv https://raw.githubusercontent.com/major/MySQLTuner-perl/master/vulnerabilities.csv --no-check-certificate
chmod +x /usr/local/bin/mysqltuner/mysqltuner.pl

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
