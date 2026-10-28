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
source /home/EngineScript/enginescript-install-options.txt || { echo "Error: Failed to source /home/EngineScript/enginescript-install-options.txt" >&2; exit 1; }

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh || { echo "Error: Failed to source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh" >&2; exit 1; }


#----------------------------------------------------------------------------------
# Start Main Script

# Tune MariaDB

# The configuration file to tune: /etc/mysql/my.cnf by default, or a staging copy (the
# MariaDB update tunes a copy while MariaDB keeps running, then swaps it in).
# /etc/mysql/my.cnf is the MariaDB packages' link to /etc/mysql/mariadb.cnf; sed
# --follow-symlinks edits that file and keeps the link (plain sed -i would replace the link
# with a regular file and leave the untuned template in mariadb.cnf, which a package upgrade
# then links back in).
MARIADB_CONFIG="${1:-/etc/mysql/my.cnf}"

# Service limits and settings: a systemd override instead of editing MariaDB's own unit file
mkdir -p "/etc/systemd/system/mariadb.service.d"
cat > /etc/systemd/system/mariadb.service.d/enginescript-limits.conf << 'EOF'
[Service]
# EngineScript MariaDB Performance Tuning
LimitNOFILE=60556
LimitMEMLOCK=524288

Restart=always

# If memory runs out, the kernel's OOM killer picks a PHP-FPM worker (replaced at once) or Redis
# (-300) before MariaDB, whose loss takes every site down
OOMScoreAdjust=-600

# Environment variables to prevent startup errors
Environment="MYSQLD_OPTS="
Environment="_WSREP_NEW_CLUSTER="
EOF

# The shared tuning plan (enginescript-tuning.sh): written first if the server has none yet
tuning_load
if [[ -z "$(tuning_get MARIADB_BUFFER_POOL_MB)" ]]; then
  tuning_write_plan || exit 1
  tuning_load
fi

# innodb_io_capacity from the database disk's measured write rate, measured once and saved
if [[ -z "$(tuning_get MARIADB_IO_CAPACITY)" ]]; then
  tuning_benchmark_disk /var/lib/mysql
  tuning_load
fi

sed -i --follow-symlinks \
  -e "s|SEDMAXCON|$(tuning_get MARIADB_MAX_CONNECTIONS)|g" \
  -e "s|SEDTMPTBLSZ|$(tuning_get MARIADB_TMP_TABLE_MB)M|g" \
  -e "s|SEDMXHPTBLSZ|$(tuning_get MARIADB_TMP_TABLE_MB)M|g" \
  -e "s|SEDTOC|$(tuning_get MARIADB_TABLE_CACHE)|g" \
  -e "s|SEDARIA|$(tuning_get MARIADB_ARIA_MB)M|g" \
  -e "s|SEDLOGFILE|$(tuning_get MARIADB_LOG_FILE_MB)M|g" \
  -e "s|SEDPOOL|$(tuning_get MARIADB_BUFFER_POOL_MB)M|g" \
  -e "s|SEDLBS|$(tuning_get MARIADB_LOG_BUFFER_MB)M|g" \
  -e "s|SEDIOCAP|$(tuning_get MARIADB_IO_CAPACITY)|g" \
  "${MARIADB_CONFIG}"

if grep -qE 'SED[A-Z]+' "${MARIADB_CONFIG}"; then
  echo "Error: ${MARIADB_CONFIG} still has placeholders: $(grep -oE 'SED[A-Z]+' "${MARIADB_CONFIG}" | sort -u | paste -sd' ' -)" >&2
  exit 1
fi

# Reload systemd daemon to apply the new override configuration
systemctl daemon-reload


# References:
# https://mariadb.com/docs/server/server-usage/storage-engines/innodb/innodb-page-flushing
# https://mariadb.com/docs/server/server-management/install-and-upgrade-mariadb/configuring-mariadb/mariadb-performance-advanced-configurations/configuring-mariadb-for-optimal-performance
# https://mariadb.com/docs/server/server-management/starting-and-stopping-mariadb/systemd/configuring
