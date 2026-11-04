#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# Runs one scheduled job: skips it if its previous run is still going, and logs its output and
# exit status to /var/log/EngineScript/cron-<job>.log (rotated by logrotate.d/enginescript).
#
# Usage: run-job.sh <script under /usr/local/bin/enginescript/scripts> [arguments]

JOB="/usr/local/bin/enginescript/scripts/$1"
shift
NAME="$(basename "${JOB}" .sh)"
LOG="/var/log/EngineScript/cron-${NAME}.log"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "${LOG}"
}

mkdir -p /var/log/EngineScript
if [[ ! -e "${LOG}" ]]; then
  (umask 077 && : > "${LOG}")
fi

# In /run, which only root can write to, unlike /run/lock and /tmp
exec 9> "/run/enginescript-cron-${NAME}.lock"
if ! flock -n 9; then
  log "Skipped: the previous run is still going."
  exit 0
fi

log "Started."
cd "$(dirname "${JOB}")" || { log "Error: Failed to change to the folder of ${JOB}"; exit 1; }
# The job does not inherit the lock: a process it leaves running must not block the next run
bash "${JOB}" "$@" >> "${LOG}" 2>&1 9>&-
STATUS=$?
log "Finished with exit status ${STATUS}."
exit "${STATUS}"
