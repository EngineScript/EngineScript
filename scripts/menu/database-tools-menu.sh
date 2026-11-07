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

# Each database's size and the site it belongs to (from /home/EngineScript/mysql-credentials),
# then each site's largest tables
show_database_sizes() {
  local SITES=() site db size free tables table
  local -A site_of=()
  es_sites
  for site in "${SITES[@]}"; do
    db="$(sed -n 's/^DB="\([A-Za-z0-9_]*\)"$/\1/p' "/home/EngineScript/mysql-credentials/${site}.txt" 2> /dev/null)"
    [[ -n "${db}" ]] && site_of["${db}"]="${site}"
    db="$(sed -n 's/^DB="\([A-Za-z0-9_]*\)"$/\1/p' "/home/EngineScript/staging-credentials/staging.${site}.txt" 2> /dev/null)"
    [[ -n "${db}" ]] && site_of["${db}"]="staging.${site}"
  done
  echo ""
  echo "Databases, largest first (Free is space inside the tables that OPTIMIZE TABLE could give back):"
  echo ""
  printf '  %-34s %-26s %9s %9s %7s\n' "Site" "Database" "Size MB" "Free MB" "Tables"
  while IFS=$'\t' read -r db size free tables; do
    printf '  %-34s %-26s %9s %9s %7s\n' "${site_of[${db}]:-(not an EngineScript site)}" "${db}" "${size}" "${free}" "${tables}"
  done < <(mariadb -N -B -e "SELECT table_schema, ROUND(SUM(data_length + index_length) / 1048576, 1),
      ROUND(SUM(data_free) / 1048576, 1), COUNT(*) FROM information_schema.tables
      WHERE table_schema NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
      GROUP BY table_schema ORDER BY SUM(data_length + index_length) DESC")
  for db in "${!site_of[@]}"; do
    echo ""
    echo "The largest tables of ${site_of[${db}]}:"
    while IFS=$'\t' read -r table size; do
      printf '  %-50s %9s MB\n' "${table}" "${size}"
    done < <(mariadb -N -B -e "SELECT table_name, ROUND((data_length + index_length) / 1048576, 1)
        FROM information_schema.tables WHERE table_schema = '${db}'
        ORDER BY data_length + index_length DESC LIMIT 5")
  done
}

# Main Menu
while true
  do
    clear
    echo -e "Database Tools" | boxes -a c -d shell -p a1l2
    echo ""
    echo ""
    PS3='Please enter your choice: '
    secoptions=(
      "Analyze All Tables & Databases"
      "Database Size per Site"
      "MariaDB Diagnostic & Recovery"
      "MariaDB-Check Database Optimizer"
      "MySQLreport"
      "MySQLtuner"
      "Reset a Site's Database Password"
      "Exit Database Tools"
    )
    select secopt in "${secoptions[@]}"
    do
      case $secopt in
        "Analyze All Tables & Databases")
          /usr/local/bin/enginescript/scripts/functions/server-tools/analyze-tables.sh
          break
          ;;
        "Database Size per Site")
          show_database_sizes
          pause
          break
          ;;
        "MariaDB Diagnostic & Recovery")
          /usr/local/bin/enginescript/scripts/functions/mariadb-diagnostic.sh
          pause
          break
          ;;
        "MariaDB-Check Database Optimizer")
          /usr/local/bin/enginescript/scripts/functions/server-tools/mariadbcheck.sh
          break
          ;;
        "MySQLreport")
          mysqlreport
          pause
          break
          ;;
        "MySQLtuner")
          /usr/local/bin/enginescript/scripts/functions/server-tools/mysqltuner.sh
          break
          ;;
        "Reset a Site's Database Password")
          if select_site; then
            echo "This gives ${SELECTED_SITE}'s database user a new random password and updates wp-config.php."
            echo "For about a second while the password changes, the site cannot reach its database."
            if prompt_yes_no "Reset the database password of ${SELECTED_SITE}?" "n"; then
              bash /usr/local/bin/enginescript/scripts/functions/vhost/vhost-db-password.sh "${SELECTED_SITE}"
            fi
          fi
          pause
          break
          ;;
        "Exit Database Tools")
          exit
          ;;
        *) echo "Invalid option.";;
      esac
    done
  done
