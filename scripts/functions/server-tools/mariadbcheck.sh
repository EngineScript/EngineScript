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

# Check every table (repairing the ones that need it, which on InnoDB is rare) and update the
# index statistics the query planner uses. Both are light: neither rebuilds a table.
# --optimize also rebuilds every table (OPTIMIZE TABLE). On InnoDB that copies each table and
# its indexes, with heavy disk work while it runs and a lock at its start and end, for space
# that is usually small; the menu offers it as its own choice, after a warning.
# root logs in over the Unix socket, so no password is needed. --skip-write-binlog keeps the
# statements out of the binary log. --silent shows only problems.
STATUS=0

echo "Checking all tables..."
mariadb-check --check --auto-repair --all-databases --skip-write-binlog --silent || STATUS=1

echo "Analyzing all tables..."
mariadb-check --analyze --all-databases --skip-write-binlog --silent || STATUS=1

if [[ "${1:-}" == "--optimize" ]]; then
  echo "Optimizing (rebuilding) all tables. This can take a long time on large sites..."
  mariadb-check --optimize --all-databases --skip-write-binlog --silent || STATUS=1
fi

echo ""
if [[ "${STATUS}" -eq 0 ]]; then
  echo "${BOLD}Done${NORMAL}: no problems found."
else
  echo "${BOLD}Done, with errors${NORMAL}: see the messages above."
fi

# Ask user to acknowledge that the scan has completed before moving on
pause
