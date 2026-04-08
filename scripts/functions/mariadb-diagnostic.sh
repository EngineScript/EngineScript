#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# EngineScript Variables
source /usr/local/bin/enginescript/enginescript-variables.txt || { echo "Error: Failed to source /usr/local/bin/enginescript/enginescript-variables.txt" >&2; exit 1; }
source /home/EngineScript/enginescript-install-options.txt

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }


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
echo "Open files limit in config: $(grep 'open_files_limit' /etc/mysql/my.cnf || echo 'Not found')"
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
grep -E "(SED[A-Z]+|SEDMYSQL)" /etc/mysql/my.cnf | head -5
echo ""

# Attempt to fix common issues
echo "============================================================="
echo "CORRECTIVE MEASURES"
echo "============================================================="
echo ""

# Fix 1: Systemd override file
if prompt_yes_no "[1/5] Recreate systemd override file with proper environment variables?"; then
    mkdir -p /etc/systemd/system/mariadb.service.d
    cat > /etc/systemd/system/mariadb.service.d/enginescript-limits.conf << 'EOF'
[Service]
# EngineScript MariaDB Performance Tuning
LimitNOFILE=60556
LimitMEMLOCK=524288

# Environment variables to prevent startup errors
Environment="MYSQLD_OPTS="
Environment="_WSREP_NEW_CLUSTER="
EOF
    echo "✓ Created/updated systemd override file."
else
    echo "⊘ Skipped systemd override file update."
fi
echo ""

# Fix 2: Reload systemd daemon
if prompt_yes_no "[2/5] Reload systemd daemon?"; then
    systemctl daemon-reload
    echo "✓ Reloaded systemd daemon."
else
    echo "⊘ Skipped systemd daemon reload."
fi
echo ""

# Fix 3: Initialize MariaDB data directory if needed
echo "[3/5] Initialize MariaDB data directory if not already initialized?"
if [ ! -d /var/lib/mysql/mysql ]; then
    echo "MariaDB data directory not properly initialized."
    if prompt_yes_no "Proceed with mysql_install_db?"; then
        /usr/bin/mysql_install_db --user=mysql --datadir=/var/lib/mysql
        echo "✓ Initialized MariaDB data directory."
    else
        echo "⊘ Skipped data directory initialization."
    fi
else
    echo "MariaDB data directory already initialized. Skipping."
fi
echo ""

# Fix 4: Fix file ownership
if prompt_yes_no "[4/5] Fix file ownership for MariaDB directories?"; then
    chown -R mysql:mysql /var/lib/mysql
    chown -R mysql:adm /var/log/mysql
    echo "✓ Fixed file ownership."
else
    echo "⊘ Skipped file ownership fix."
fi
echo ""

# Fix 5: Start MariaDB service
if prompt_yes_no "[5/5] Attempt to start MariaDB service?"; then
    systemctl start mariadb.service
    echo "Attempting to start MariaDB..."
    sleep 3
    if systemctl is-active mariadb.service --quiet; then
        echo "✓ SUCCESS: MariaDB is now running!"
    else
        echo "✗ FAILED: MariaDB still not running. Manual intervention required."
        echo ""
        echo "Recent systemd journal entries for mariadb:"
        journalctl -u mariadb.service --no-pager -n 20
    fi
else
    echo "⊘ Skipped MariaDB service start."
fi
echo ""

echo "============================================================="
echo "Diagnostic complete."
echo "============================================================="
