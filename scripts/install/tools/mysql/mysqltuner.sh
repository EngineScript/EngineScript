#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - High-Performance WordPress LEMP Server
#----------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# Company:      VisiStruct / EngineScript
# License:      GPL v3.0
# OS:           Ubuntu 22.04 (jammy)
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

sleep 5
