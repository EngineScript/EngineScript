#!/usr/bin/env bash
#----------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
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

source /usr/local/bin/enginescript/enginescript-variables.txt
source /home/EngineScript/enginescript-install-options.txt

RUN_SQL=/tmp/analyze_all_tables.sql
RUN_LOG=/tmp/analyze_all_tables.log

MYSQL_HOST=localhost
MYSQL_USER=root
MYSQL_AUTH="-u${MYSQL_USER} -p${MARIADB_ADMIN_PASSWORD}"

SQL="SELECT CONCAT('ANALYZE LOCAL TABLE \`',table_schema,'\`.\`',table_name,'\`;')"
SQL="${SQL} FROM information_schema.tables WHERE table_schema NOT IN"
SQL="${SQL} ('information_schema','performance_schema','mysql','sys','innodb')"
SQL="${SQL} AND engine IS NOT NULL"

# Create SQL Commands to run ANALYZE TABLE
mysql ${MYSQL_AUTH} -ANe"${SQL}" > ${RUN_SQL}

# Execute ANALYZE TABLE Commands
mysql ${MYSQL_AUTH} --table < ${RUN_SQL} > ${RUN_LOG} 2>&1

# Ask user to acknowledge that the scan has completed before moving on
echo ""
echo "${BOLD}Done${NORMAL}"
echo "Analyze Table Log: /tmp/analyze_all_tables.log"
echo ""
read -n 1 -s -r -p "Press any key to continue"
echo ""
echo ""
