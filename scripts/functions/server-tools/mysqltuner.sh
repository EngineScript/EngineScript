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

# Source shared functions library
source /usr/local/bin/enginescript/scripts/functions/shared/enginescript-common.sh


#----------------------------------------------------------------------------------
# Start Main Script

# CVE vulnerabilities CSV file used by MySQLTuner for exploit scanning
CVE_FILE="/usr/local/bin/mysqltuner/vulnerabilities.csv"

# Ensure CVE file exists and is reasonably up-to-date (update if older than 7 days)
if [ ! -f "${CVE_FILE}" ] || [ $(( $(date +%s) - $(stat -c %Y "${CVE_FILE}" 2>/dev/null || echo 0) )) -gt $((7 * 24 * 60 * 60)) ]; then
	echo "Updating MySQLTuner CVE database..."
	mkdir -p "$(dirname "${CVE_FILE}")"
	if wget -q -O "${CVE_FILE}" https://raw.githubusercontent.com/major/MySQLTuner-perl/master/vulnerabilities.csv --no-check-certificate; then
		chmod 644 "${CVE_FILE}" 2>/dev/null || true
		echo "Vulnerabilities CVE database updated: ${CVE_FILE}"
	else
		echo "Warning: Failed to download vulnerabilities.csv; continuing without CVE scan" >&2
	fi
fi

# Run MySQLTuner with CVE exploit scanning enabled (if file present)
if [ -f "${CVE_FILE}" ]; then
	echo "Running MySQLTuner with CVE scanning enabled (using ${CVE_FILE})..."
	perl /usr/local/bin/mysqltuner/mysqltuner.pl --cvefile="${CVE_FILE}"
else
	perl /usr/local/bin/mysqltuner/mysqltuner.pl
fi

# Ask user to acknowledge that the scan has completed before moving on
echo ""
echo ""
read -n 1 -s -r -p "Press any key to continue"
echo ""
echo ""
