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
#
# Runs the daily jobs one after another, so they cannot overlap: the update replaces the scripts
# and modes that permissions.sh is working on. Each job has its own log; one failing does not
# stop the rest. The update goes last, since it replaces this script too.

RUN="bash /usr/local/bin/enginescript/scripts/functions/cron/run-job.sh"

# Tool Updates
${RUN} update/wp-cli-update.sh
${RUN} update/wordfence-cli-update.sh

# Permissions and Security
${RUN} functions/cron/permissions.sh
${RUN} functions/cron/uploads-php-scan.sh
${RUN} functions/cron/checksums.sh

# EngineScript Update
if [[ "${ENGINESCRIPT_AUTO_UPDATE}" == "1" ]]; then
  ${RUN} update/enginescript-update.sh
fi
