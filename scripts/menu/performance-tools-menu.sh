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

# Wait for a key before the menu redraws
pause() {
  echo ""
  read -n 1 -s -r -p "Press any key to continue"
  echo ""
  echo ""
}

# Run a tool, or say how to install it: servers set up before a tool was added get it from
# Update Software > Update Server Tools
run_tool() {
  local tool="$1"
  shift
  if ! command -v "${tool}" > /dev/null 2>&1; then
    echo "${tool} is not installed. Install it with: es.menu > Update Software > Update Server Tools"
    return 1
  fi
  "$@"
}

# The processes reading or writing the disk now. Ubuntu's kernel leaves I/O accounting off, so
# turn it on while iotop runs and put the old setting back afterwards.
show_disk_io() {
  local accounting
  accounting="$(sysctl -n kernel.task_delayacct 2> /dev/null)"
  [[ "${accounting}" == "0" ]] && sysctl -q -w kernel.task_delayacct=1
  iotop -o
  [[ "${accounting}" == "0" ]] && sysctl -q -w kernel.task_delayacct=0
}

# One fio test on the benchmark file; prints MB/s for 1 MB blocks and IOPS for 4 KB blocks.
# fio's terse output (version 3) has the read KiB/s and IOPS in fields 7 and 8, and the write
# ones in fields 48 and 49.
run_disk_test() {
  local file="$1" rw="$2" bs="$3" depth="$4" out field result
  field=7
  [[ "${rw}" == *write ]] && field=48
  if ! out="$(fio --name=es-benchmark --filename="${file}" --size=512M --bs="${bs}" --rw="${rw}" --direct=1 \
    --ioengine=libaio --iodepth="${depth}" --time_based --runtime=10 --output-format=terse 2> /dev/null)"; then
    echo "failed"
    return
  fi
  if [[ "${bs}" == "1M" ]]; then
    result="$(awk -F';' -v f="${field}" 'NR == 1 { print int($f * 1024 / 1000000) }' <<< "${out}")"
    [[ "${result}" =~ ^[1-9][0-9]*$ ]] && echo "${result} MB/s" || echo "failed"
  else
    result="$(awk -F';' -v f="$((field + 1))" 'NR == 1 { print int($f) }' <<< "${out}")"
    [[ "${result}" =~ ^[1-9][0-9]*$ ]] && echo "${result} IOPS" || echo "failed"
  fi
}

# Sequential and random reads and writes, 10 seconds each, on a 512 MB file in /var/lib (the
# disk the databases are on). Direct I/O skips the file cache, so this measures the disk itself.
benchmark_disk() {
  local file=/var/lib/.enginescript-disk-benchmark free answer
  free="$(df -Pm /var/lib | awk 'NR == 2 { print $4 }')"
  if [[ "${free:-0}" -lt 1024 ]]; then
    echo "There is less than 1 GB free in /var/lib; the benchmark needs room for a 512 MB test file."
    return 1
  fi
  echo "The benchmark keeps the disk busy for about 40 seconds. Sites stay up but may be slower meanwhile."
  read -r -p "Run it now? [y/N] " answer
  [[ "${answer}" =~ ^[Yy]$ ]] || return 0
  trap 'rm -f "${file}"; exit 130' INT
  echo ""
  printf '  %-34s %s\n' "Sequential write (1 MB blocks)" "$(run_disk_test "${file}" write 1M 8)"
  printf '  %-34s %s\n' "Sequential read (1 MB blocks)" "$(run_disk_test "${file}" read 1M 8)"
  printf '  %-34s %s\n' "Random write (4 KB blocks)" "$(run_disk_test "${file}" randwrite 4k 32)"
  printf '  %-34s %s\n' "Random read (4 KB blocks)" "$(run_disk_test "${file}" randread 4k 32)"
  trap - INT
  rm -f "${file}"
  echo ""
  echo "Random 4 KB results matter most for databases. A local SSD usually reaches tens of thousands of"
  echo "IOPS; network block storage often stays at a few thousand."
}

# The saved tuning plan, with the administrator's overrides marked
show_tuning_plan() {
  local conf=/etc/enginescript/tuning.conf overrides=/etc/enginescript/tuning-overrides.conf key value
  local -A override=()
  echo ""
  if [[ ! -r "${conf}" ]]; then
    echo "There is no tuning plan yet (${conf}). Create one with: es.menu > Update Software > Re-tune Services"
    return 1
  fi
  while IFS='=' read -r key value; do
    override["${key}"]="${value}"
  done < <(tuning_read_file "${overrides}")
  echo "The tuning plan in ${conf}:"
  sed -n 's/^# EngineScript tuning plan, written by tuning_write_plan /(written /p' "${conf}" | sed 's/^/  /'
  echo ""
  while IFS='=' read -r key value; do
    if [[ -n "${override[${key}]:-}" ]]; then
      printf '  %-26s %-10s overridden: %s\n' "${key}" "${value}" "${override[${key}]}"
    else
      printf '  %-26s %s\n' "${key}" "${value}"
    fi
  done < <(tuning_read_file "${conf}")
  echo ""
  if [[ -e /etc/enginescript/tuning.pending ]]; then
    echo "The last re-tune did not finish: run es.menu > Update Software > Re-tune Services again."
  elif tuning_needs_replan; then
    echo "The server's memory or CPU count changed since this plan was written: run es.menu > Update Software > Re-tune Services."
  fi
  echo "To change a value, add KEY=value to ${overrides}, then run es.menu > Update Software > Re-tune Services."
}

# Main Menu
while true
  do
    clear
    echo -e "Performance Tools" | boxes -a c -d shell -p a1l2
    echo ""
    echo ""
    PS3='Please enter your choice: '
    secoptions=(
      "Disk I/O Monitor (iotop)"
      "Disk Speed Benchmark (fio)"
      "Live Resource Monitor (htop)"
      "Network Traffic (vnstat)"
      "View Tuning Plan"
      "Exit Performance Tools"
    )
    select secopt in "${secoptions[@]}"
    do
      case $secopt in
        "Disk I/O Monitor (iotop)")
          run_tool iotop show_disk_io
          break
          ;;
        "Disk Speed Benchmark (fio)")
          run_tool fio benchmark_disk
          pause
          break
          ;;
        "Live Resource Monitor (htop)")
          run_tool htop htop
          break
          ;;
        "Network Traffic (vnstat)")
          run_tool vnstat vnstat
          pause
          break
          ;;
        "View Tuning Plan")
          show_tuning_plan
          pause
          break
          ;;
        "Exit Performance Tools")
          exit
          ;;
        *) echo "Invalid option.";;
      esac
    done
  done
