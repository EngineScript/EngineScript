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
#
# Weekly jobs: checks that only need to come round once a week. Runs from cron through
# run-job.sh, which logs it to /var/log/EngineScript/cron-weekly-maintenance.log.

# PPAs skipped at install time because they had no packages for this Ubuntu release yet (such as
# Canonical's server backports on 26.04 at first): add each one once it has them
add_missing_ppas
