#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - MariaDB Diagnostic and Recovery Script
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt

echo "============================================================="
echo "EngineScript MariaDB Diagnostic Tool"
echo "============================================================="
echo ""

# Check if MariaDB is running
echo "Checking MariaDB service status..."
systemctl status mariadb.service --no-pager
echo ""

# Check MariaDB configuration
echo "Checking MariaDB configuration..."
echo "Open files limit in config: $(grep 'open_files_limit' /etc/mysql/mariadb.cnf || echo 'Not found')"
echo "SystemD override file exists: $([ -f /etc/systemd/system/mariadb.service.d/enginescript-limits.conf ] && echo 'Yes' || echo 'No')"
echo ""

# Check systemd override configuration
if [ -f /etc/systemd/system/mariadb.service.d/enginescript-limits.conf ]; then
    echo "SystemD override configuration:"
    cat /etc/systemd/system/mariadb.service.d/enginescript-limits.conf
    echo ""
fi

# Check MariaDB error log
echo "Recent MariaDB error log entries:"
if [ -f /var/log/mysql/mysql-error.log ]; then
    tail -20 /var/log/mysql/mysql-error.log
else
    echo "MariaDB error log not found at /var/log/mysql/mysql-error.log"
fi
echo ""

# Check system limits
echo "System limits:"
echo "Current max open files: $(ulimit -n)"
echo "System max open files: $(cat /proc/sys/fs/file-max)"
echo ""

# Check memory variables
echo "Memory calculations:"
echo "Total RAM: ${SERVER_MEMORY_TOTAL_100}MB"
echo "45% RAM: ${SERVER_MEMORY_TOTAL_45}MB (for InnoDB buffer pool)"
echo "80% RAM: ${SERVER_MEMORY_TOTAL_80}MB (for comparison checks)"
echo ""

# Check if configuration placeholders are replaced
echo "Configuration placeholder check:"
grep -E "(SED[A-Z]+|SEDMYSQL)" /etc/mysql/mariadb.cnf | head -5
echo ""

# Attempt to fix common issues
echo "============================================================="
echo "Attempting automatic fixes..."
echo "============================================================="
echo ""

# Ensure systemd override directory exists
mkdir -p /etc/systemd/system/mariadb.service.d

# Recreate the override file with proper environment variables
cat > /etc/systemd/system/mariadb.service.d/enginescript-limits.conf << 'EOF'
[Service]
# EngineScript MariaDB Performance Tuning
LimitNOFILE=60556
LimitMEMLOCK=524288

# Environment variables to prevent startup errors
Environment="MYSQLD_OPTS="
Environment="_WSREP_NEW_CLUSTER="
EOF

echo "Created/updated systemd override file."

# Reload systemd and attempt to start MariaDB
systemctl daemon-reload
echo "Reloaded systemd daemon."

# Check if MariaDB data directory is properly initialized
if [ ! -d /var/lib/mysql/mysql ]; then
    echo "MariaDB data directory not properly initialized. Running mysql_install_db..."
    /usr/bin/mysql_install_db --user=mysql --datadir=/var/lib/mysql
fi

# Set proper ownership on MariaDB files
chown -R mysql:mysql /var/lib/mysql
chown -R mysql:adm /var/log/mysql

echo "Fixed file ownership."

# Try to start MariaDB
echo "Attempting to start MariaDB..."
systemctl start mariadb.service

# Check final status
sleep 3
if systemctl is-active mariadb.service --quiet; then
    echo "SUCCESS: MariaDB is now running!"
else
    echo "FAILED: MariaDB still not running. Manual intervention required."
    echo ""
    echo "Recent systemd journal entries for mariadb:"
    journalctl -u mariadb.service --no-pager -n 20
fi

echo ""
echo "============================================================="
echo "Diagnostic complete."
echo "============================================================="
