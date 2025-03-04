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

# Tune MariaDB
SERVER_MEMORY_TOTAL_45="$(free -m | awk 'NR==2{printf "%d", $2*0.45 }')"
SERVER_MEMORY_TOTAL_13="$(free -m | awk 'NR==2{printf "%d", $2*0.13 }')"

# tmp_table_size & max_heap_table_size
sed -i "s|SEDTMPTBLSZ|${SERVER_MEMORY_TOTAL_03}M|g" /etc/mysql/mariadb.cnf
sed -i "s|SEDMXHPTBLSZ|${SERVER_MEMORY_TOTAL_03}M|g" /etc/mysql/mariadb.cnf

# Max Connections
# Scales to be near the MariaDB default value on a 4GB server
sed -i "s|SEDMAXCON|${SERVER_MEMORY_TOTAL_05}|g" /etc/mysql/mariadb.cnf

if [ "${SERVER_MEMORY_TOTAL_80}" -lt 4000 ];
  then
    sed -i "s|SEDLBS|32|g" /etc/mysql/mariadb.cnf
  else
    sed -i "s|SEDLBS|64|g" /etc/mysql/mariadb.cnf
fi

if [ "${SERVER_MEMORY_TOTAL_80}" -lt 4000 ];
  then
    sed -i "s|SEDTCS|256|g" /etc/mysql/mariadb.cnf
  else
    sed -i "s|SEDTCS|${SERVER_MEMORY_TOTAL_07}|g" /etc/mysql/mariadb.cnf
fi

if [ "${SERVER_MEMORY_TOTAL_80}" -lt 4000 ];
  then
    sed -i "s|SEDTOC|2000|g" /etc/mysql/mariadb.cnf
  else
    sed -i "s|SEDTOC|4000|g" /etc/mysql/mariadb.cnf
fi

# For Servers with 1GB RAM
if [ "${SERVER_MEMORY_TOTAL_100}" -lt 1000 ];
  then
    sed -i "s|SEDINOF|1000|g" /etc/mysql/mariadb.cnf
fi

# For Servers with 2GB RAM
if [ "${SERVER_MEMORY_TOTAL_100}" -lt 2000 ];
  then
    sed -i "s|SEDINOF|2000|g" /etc/mysql/mariadb.cnf
fi

# For Servers with 4GB RAM
if [ "${SERVER_MEMORY_TOTAL_100}" -lt 4000 ];
  then
    sed -i "s|SEDINOF|4000|g" /etc/mysql/mariadb.cnf
fi

# For Servers with 8GB RAM+
if [ "${SERVER_MEMORY_TOTAL_100}" -lt 128000 ];
  then
    sed -i "s|SEDINOF|8000|g" /etc/mysql/mariadb.cnf
fi

sed -i "s|SEDMYSQL016PERCENT|${SERVER_MEMORY_TOTAL_016}|g" /etc/mysql/mariadb.cnf
sed -i "s|SEDMYSQL02PERCENT|${SERVER_MEMORY_TOTAL_02}|g" /etc/mysql/mariadb.cnf
sed -i "s|SEDMYSQL03PERCENT|${SERVER_MEMORY_TOTAL_03}|g" /etc/mysql/mariadb.cnf
sed -i "s|SEDMYSQL13PERCENT|${SERVER_MEMORY_TOTAL_13}|g" /etc/mysql/mariadb.cnf
sed -i "s|SEDMYSQL45PERCENT|${SERVER_MEMORY_TOTAL_45}|g" /etc/mysql/mariadb.cnf
sed -i "s|SEDMYSQL80PERCENT|${SERVER_MEMORY_TOTAL_80}|g" /etc/mysql/mariadb.cnf

# IOPS Benchmark

# Define variables
TEST_FILE="/tmp/fio_test_file"
MARIADB_CONFIG="/etc/mysql/mariadb.cnf"
IOPS_AVG_VAR="SEDAVGIOPS"  # Placeholder for avg IOPS
IOPS_MAX_VAR="SEDMAXIOPS"  # Placeholder for max IOPS

# Run fio and get results (with progress)
echo "Running fio test (read)..."
fio_full_output=$(sudo fio --ioengine=libaio --direct=1 --name=test --filename="$TEST_FILE" --bs=4k --size=500M --readwrite=read)

# Extract avg and max IOPS values
avg_iops=$(echo "$fio_full_output" | grep "iops" | awk -F',' '{print $3}' | awk -F'=' '{print $2}')
max_iops=$(echo "$fio_full_output" | grep "iops" | awk -F',' '{print $2}' | awk -F'=' '{print $2}')

# Remove decimals and ALL whitespace
avg_iops=$(echo "$avg_iops" | cut -d '.' -f 1 | xargs)
max_iops=$(echo "$max_iops" | cut -d '.' -f 1 | sed 's/^[ \t]*//;s/[ \t]*$//') # Remove leading/trailing whitespace

# Modify MariaDB config for avg IOPS
sed -i "s/$IOPS_AVG_VAR/$avg_iops/g" "$MARIADB_CONFIG"
echo "MariaDB $IOPS_AVG_VAR updated to $avg_iops."

# Modify MariaDB config for max IOPS
sed -i "s/$IOPS_MAX_VAR/$max_iops/g" "$MARIADB_CONFIG"
echo "MariaDB $IOPS_MAX_VAR updated to $max_iops."
