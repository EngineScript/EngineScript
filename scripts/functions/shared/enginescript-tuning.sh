#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------

# Shared tuning plan for NGINX, PHP-FPM, MariaDB, and Redis. Sourced by enginescript-common.sh.
#
# One memory budget, worked out from total RAM (MemTotal, or the container limit if lower) and
# the CPU count, so the services together fit in memory instead of each taking its own share:
#
#   1. System reserve: 192 MB + 5% of RAM
#   2. Redis maxmemory: 10% of RAM (at most 2 GB; 64 MB below 1.5 GB), counted at 125%
#   3. OPcache, by tier (the interned strings buffer is part of it)
#   4. MariaDB: buffer pool floor of 20% of RAM (at least 128 MB), plus about 160 MB, the Aria
#      page cache, and 1 MB per connection
#   5. PHP-FPM workers: what is left / 70 MB, at most 6 per vCPU, at least 3
#   6. 75% of any RAM still left goes to the MariaDB buffer pool; the rest stays free for the
#      Linux file cache
#
# The plan is saved to /etc/enginescript/tuning.conf. An administrator can override any value in
# /etc/enginescript/tuning-overrides.conf (same KEY=value format). Both files are read with a
# strict parser (KEY=number lines only), never sourced: /etc/enginescript is writable by the web
# server user. ES_TUNING_CONF and ES_TUNING_OVERRIDES override the paths (for tests).

# Bump when the plan's keys or formulas change, so EngineScript updates apply the new plan once
ES_TUNING_VERSION=1


# ----------------------------------------------------------------
# Inputs

# Total memory in MB: MemTotal, or the cgroup (container) memory limit if lower
function tuning_detect_memory_mb() {
    local mem limit
    mem="$(awk '/^MemTotal:/ {printf "%d", $2 / 1024}' /proc/meminfo 2> /dev/null)"
    if [[ -r /sys/fs/cgroup/memory.max ]]; then
        limit="$(cat /sys/fs/cgroup/memory.max 2> /dev/null)"
        if [[ "${limit}" =~ ^[0-9]+$ ]] && (( limit / 1048576 < mem )); then
            mem=$((limit / 1048576))
        fi
    fi
    echo "${mem}"
}

# CPUs available to this system: nproc, or the cgroup CPU quota if lower
function tuning_detect_cpus() {
    local cpus quota period
    cpus="$(nproc 2> /dev/null || echo 1)"
    if [[ -r /sys/fs/cgroup/cpu.max ]]; then
        read -r quota period < /sys/fs/cgroup/cpu.max
        if [[ "${quota}" =~ ^[0-9]+$ && "${period}" =~ ^[0-9]+$ && "${period}" -gt 0 ]]; then
            quota=$(((quota + period - 1) / period))
            (( quota < cpus )) && cpus="${quota}"
        fi
    fi
    (( cpus < 1 )) && cpus=1
    echo "${cpus}"
}

# Size in MB of the filesystem holding the Nginx FastCGI cache
function tuning_detect_cache_disk_mb() {
    local dir=/var/cache/nginx
    [[ -d "${dir}" ]] || dir=/var/cache
    df -Pm "${dir}" 2> /dev/null | awk 'NR == 2 {print $2}'
}


# ----------------------------------------------------------------
# The plan

# Usage: tuning_calculate <memory MB> <CPUs> <cache disk MB>
# Prints the plan as KEY=value lines (sizes in MB unless the key says otherwise).
function tuning_calculate() {
    local mem="$1" cpus="$2" disk="$3"
    local reserve redis opcache interned max_files aria pool_floor table_cache rest workers
    local conns used left pool redo log_buffer tmp memory_limit zone cache_max
    local start min_spare max_spare

    reserve=$((192 + mem * 5 / 100))

    if (( mem < 1536 )); then
        redis=64
    else
        redis=$((mem * 10 / 100))
        (( redis > 2048 )) && redis=2048
    fi

    if (( mem < 1536 )); then opcache=192; interned=48; max_files=20000
    elif (( mem < 3072 )); then opcache=256; interned=64; max_files=40000
    elif (( mem < 6144 )); then opcache=384; interned=64; max_files=80000
    elif (( mem < 12288 )); then opcache=768; interned=96; max_files=160000
    else opcache=1536; interned=128; max_files=320000
    fi

    if (( mem < 1536 )); then aria=64
    elif (( mem < 2560 )); then aria=96
    elif (( mem < 3584 )); then aria=112
    elif (( mem < 12288 )); then aria=128
    else aria=256
    fi

    pool_floor=$((mem * 20 / 100))
    (( pool_floor < 128 )) && pool_floor=128

    # Workers: each costs 70 MB plus its 1 MB MariaDB connection; 30 connections are reserved
    # for cron, WP-CLI, backups, and administration
    rest=$((mem - reserve - redis * 125 / 100 - opcache - pool_floor - (160 + aria + 30)))
    (( rest < 0 )) && rest=0
    workers=$((rest / 71))
    (( workers > cpus * 6 )) && workers=$((cpus * 6))
    (( workers < 3 )) && workers=3
    conns=$((workers + 30))

    used=$((reserve + redis * 125 / 100 + opcache + pool_floor + 160 + aria + conns + workers * 70))
    left=$((mem - used))
    pool="${pool_floor}"
    (( left > 0 )) && pool=$((pool_floor + left * 75 / 100))

    redo=$((pool / 4))
    (( redo < 96 )) && redo=96
    (( redo > 2048 )) && redo=2048

    # Stepped values use boundaries halfway between droplet sizes, so a server lands on its
    # tier whatever the kernel reserves (a 4 GB droplet reports about 3.9 GB)
    if (( mem < 3072 )); then tmp=32; memory_limit=256; else tmp=64; memory_limit=512; fi
    if (( mem < 3072 )); then table_cache=2000; elif (( mem < 6144 )); then table_cache=4000; else table_cache=8000; fi
    if (( mem * 80 / 100 < 4000 )); then log_buffer=32; else log_buffer=64; fi
    if (( mem < 6144 )); then zone=32; else zone=64; fi

    cache_max=$((disk * 5 / 100))
    (( cache_max < 512 )) && cache_max=512
    (( cache_max > 10240 )) && cache_max=10240

    # PHP-FPM spare workers by CPU count, never more than the pool allows
    if (( cpus <= 1 )); then start=2; min_spare=1; max_spare=3
    elif (( cpus == 2 )); then start=3; min_spare=2; max_spare=5
    elif (( cpus <= 4 )); then start=4; min_spare=3; max_spare=6
    elif (( cpus <= 8 )); then start=5; min_spare=4; max_spare=7
    else start=8; min_spare=6; max_spare=14
    fi
    (( max_spare > workers )) && max_spare="${workers}"
    (( start > max_spare )) && start="${max_spare}"
    (( min_spare > start )) && min_spare="${start}"

    cat << EOF
TUNING_VERSION=${ES_TUNING_VERSION}
TUNING_MEM_MB=${mem}
TUNING_CPUS=${cpus}
PHP_MAX_CHILDREN=${workers}
PHP_START_SERVERS=${start}
PHP_MIN_SPARE_SERVERS=${min_spare}
PHP_MAX_SPARE_SERVERS=${max_spare}
PHP_MEMORY_LIMIT_MB=${memory_limit}
OPCACHE_MEMORY_MB=${opcache}
OPCACHE_INTERNED_MB=${interned}
OPCACHE_MAX_FILES=${max_files}
MARIADB_BUFFER_POOL_MB=${pool}
MARIADB_MAX_CONNECTIONS=${conns}
MARIADB_TMP_TABLE_MB=${tmp}
MARIADB_ARIA_MB=${aria}
MARIADB_TABLE_CACHE=${table_cache}
MARIADB_LOG_FILE_MB=${redo}
MARIADB_LOG_BUFFER_MB=${log_buffer}
REDIS_MAXMEMORY_MB=${redis}
NGINX_CACHE_ZONE_MB=${zone}
NGINX_CACHE_MAX_MB=${cache_max}
EOF
}


# ----------------------------------------------------------------
# Reading and writing the plan

# Print the KEY=value lines of a tuning file that pass the strict format (UPPER_CASE=number)
function tuning_read_file() {
    [[ -r "$1" ]] || return 0
    grep -E '^[A-Z][A-Z0-9_]*=[0-9]+$' "$1"
}

# Load the plan and the administrator's overrides into the TUNING associative array
function tuning_load() {
    local key value
    declare -gA TUNING=()
    while IFS='=' read -r key value; do
        TUNING["${key}"]="${value}"
    done < <(tuning_read_file "${ES_TUNING_CONF:-/etc/enginescript/tuning.conf}"; tuning_read_file "${ES_TUNING_OVERRIDES:-/etc/enginescript/tuning-overrides.conf}")
}

# Print one value of the loaded plan (tuning_load first)
function tuning_get() {
    echo "${TUNING[$1]:-}"
}

# True when there is no usable plan, it was written by an older plan version, RAM or the CPU
# count changed (more than 5% for RAM) since it was written, or the last re-tune did not finish
# (retune-services.sh keeps tuning.pending until every service has taken the plan)
function tuning_needs_replan() {
    local conf="${ES_TUNING_CONF:-/etc/enginescript/tuning.conf}" saved_mem saved_cpus saved_version mem cpus
    [[ -e "${ES_TUNING_PENDING:-/etc/enginescript/tuning.pending}" ]] && return 0
    saved_version="$(tuning_read_file "${conf}" | sed -n 's/^TUNING_VERSION=//p')"
    saved_mem="$(tuning_read_file "${conf}" | sed -n 's/^TUNING_MEM_MB=//p')"
    saved_cpus="$(tuning_read_file "${conf}" | sed -n 's/^TUNING_CPUS=//p')"
    [[ -n "${saved_version}" && -n "${saved_mem}" && -n "${saved_cpus}" ]] || return 0
    (( saved_version != ES_TUNING_VERSION )) && return 0
    mem="${1:-$(tuning_detect_memory_mb)}"
    cpus="${2:-$(tuning_detect_cpus)}"
    (( cpus != saved_cpus )) && return 0
    (( (mem > saved_mem ? mem - saved_mem : saved_mem - mem) * 100 > saved_mem * 5 )) && return 0
    return 1
}

# Work out the plan for this server and save it, keeping the saved disk benchmark result
# (MARIADB_IO_CAPACITY). Usage: tuning_write_plan [memory MB] [CPUs] [cache disk MB]
function tuning_write_plan() {
    local conf="${ES_TUNING_CONF:-/etc/enginescript/tuning.conf}" io tmp mem cpus disk
    mem="${1:-$(tuning_detect_memory_mb)}"
    cpus="${2:-$(tuning_detect_cpus)}"
    disk="${3:-$(tuning_detect_cache_disk_mb)}"
    if ! [[ "${mem}" =~ ^[0-9]+$ && "${cpus}" =~ ^[0-9]+$ && "${disk}" =~ ^[0-9]+$ ]] || (( mem < 256 )); then
        echo "Error: Could not read the server's memory, CPU count, or cache disk size; the tuning plan was not written." >&2
        return 1
    fi
    io="$(tuning_read_file "${conf}" | sed -n 's/^MARIADB_IO_CAPACITY=//p')"
    mkdir -p "$(dirname "${conf}")"
    tmp="$(mktemp "${conf}.XXXXXX")" || return 1
    {
        echo "# EngineScript tuning plan, written by tuning_write_plan $(date -u +%Y-%m-%dT%H:%M:%SZ)."
        echo "# Do not edit: put changes in $(dirname "${conf}")/tuning-overrides.conf (same KEY=value format)."
        tuning_calculate "${mem}" "${cpus}" "${disk}"
        [[ -n "${io}" ]] && echo "MARIADB_IO_CAPACITY=${io}"
    } > "${tmp}"
    chmod 644 "${tmp}"
    mv -f "${tmp}" "${conf}"
}

# Save one value in the plan (for example the disk benchmark result), replacing an old one
function tuning_set_value() {
    local conf="${ES_TUNING_CONF:-/etc/enginescript/tuning.conf}" key="$1" value="$2" tmp
    [[ "${key}" =~ ^[A-Z][A-Z0-9_]*$ && "${value}" =~ ^[0-9]+$ ]] || return 1
    mkdir -p "$(dirname "${conf}")"
    tmp="$(mktemp "${conf}.XXXXXX")" || return 1
    { grep -v "^${key}=" "${conf}" 2> /dev/null; echo "${key}=${value}"; } > "${tmp}"
    chmod 644 "${tmp}"
    mv -f "${tmp}" "${conf}"
}


# ----------------------------------------------------------------
# MariaDB disk benchmark

# Measure random 16 KB writes (InnoDB's page size) on the database disk for 30 seconds and save
# innodb_io_capacity as half the measured rate, between 200 and 20000. Run while MariaDB is
# stopped and no sites are serving (the MariaDB install step), or on request.
function tuning_benchmark_disk() {
    local dir="${1:-/var/lib/mysql}" file json iops capacity
    [[ -d "${dir}" ]] || dir=/var/lib
    file="${dir}/.enginescript-fio-test"
    json="$(mktemp)"
    echo "Measuring the database disk's write rate (30 seconds)..."
    fio --name=es-write --filename="${file}" --size=256M --bs=16k --rw=randwrite --direct=1 \
        --ioengine=libaio --iodepth=32 --time_based --runtime=30 --output-format=json --output="${json}" > /dev/null 2>&1
    iops="$(jq -r '.jobs[0].write.iops // 0' "${json}" 2> /dev/null | cut -d. -f1)"
    rm -f "${file}" "${json}"
    if ! [[ "${iops}" =~ ^[0-9]+$ ]] || (( iops == 0 )); then
        echo "Warning: The disk benchmark failed; using innodb_io_capacity 200 (MariaDB's default)." >&2
        iops=400
    fi
    capacity=$((iops / 2))
    (( capacity < 200 )) && capacity=200
    (( capacity > 20000 )) && capacity=20000
    echo "Write rate ${iops} IOPS (16 KB); innodb_io_capacity ${capacity}."
    tuning_set_value MARIADB_IO_CAPACITY "${capacity}"
}
