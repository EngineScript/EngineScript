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

# Update the index statistics of every table, which the query planner uses to choose indexes.
# root logs in over the Unix socket, so no password is needed. --skip-write-binlog keeps the
# statements out of the binary log (ANALYZE LOCAL TABLE). --silent shows only problems.
echo "Analyzing all tables..."
if mariadb-check --analyze --all-databases --skip-write-binlog --silent; then
  echo ""
  echo "${BOLD}Done${NORMAL}: every table was analyzed."
else
  echo ""
  echo "${BOLD}Done, with errors${NORMAL}: see the messages above."
fi

# Ask user to acknowledge that the scan has completed before moving on
pause
