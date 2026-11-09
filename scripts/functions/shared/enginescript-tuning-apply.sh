#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------
# Tuning Appliers
# Apply the tuning plan (enginescript-tuning.sh) to Redis, MariaDB, and Nginx on a
# running server (retune-services.sh), each change tested and rolled back on failure.
# Loaded by enginescript-common.sh.
#----------------------------------------------------------------------------------


# ----------------------------------------------------------------
# Redis systemd override: if memory runs out, the kernel's OOM killer picks a PHP-FPM worker
# (replaced at once) before Redis (-300), and Redis before MariaDB (-600). Losing Redis shows
# Redis Object Cache's error page on every site until it restarts.
function install_redis_service_override() {
    mkdir -p /etc/systemd/system/redis-server.service.d
    cat > /etc/systemd/system/redis-server.service.d/enginescript.conf << 'EOF'
[Service]
OOMScoreAdjust=-300
EOF
    systemctl daemon-reload
}


# ----------------------------------------------------------------
# Load a redis.conf in a throwaway Redis (own socket, no TCP, temporary directory) and stop it.
# Returns 0 when it answered PING. Its output and log go to the file given as the second argument
# (Redis prints configuration errors on stderr, not in its log).
function test_redis_conf() {
    local candidate="$1" output="$2" test_dir test_pid ok=1

    test_dir="$(mktemp -d)"
    chown redis:redis "${test_dir}"
    chmod 644 "${candidate}"
    # The root-owned output file is opened by this shell on purpose; Redis only writes to it
    # shellcheck disable=SC2024
    sudo -u redis redis-server "${candidate}" --port 0 --unixsocket "${test_dir}/test.sock" --daemonize no \
        --supervised no --logfile "${test_dir}/test.log" --dir "${test_dir}" --pidfile "${test_dir}/test.pid" > "${output}" 2>&1 &
    test_pid=$!
    for _ in $(seq 1 20); do
        if [[ "$(redis-cli -s "${test_dir}/test.sock" PING 2> /dev/null)" == "PONG" ]]; then ok=0; break; fi
        kill -0 "${test_pid}" 2> /dev/null || break
        sleep 0.25
    done
    redis-cli -s "${test_dir}/test.sock" SHUTDOWN NOSAVE > /dev/null 2>&1
    wait "${test_pid}" 2> /dev/null
    cat "${test_dir}/test.log" >> "${output}" 2> /dev/null
    rm -rf "${test_dir}"
    return "${ok}"
}


# ----------------------------------------------------------------
# Apply the shared tuning plan to an installed Redis without restarting it
#
# Rebuilds /etc/redis/redis.conf from the repo template with the plan's maxmemory, keeping the
# server's current "databases" count (it doubles when every number is taken). The new file is
# loaded by a throwaway Redis on a temporary socket first; if that fails, nothing changes.
# maxmemory and activedefrag are applied to the running Redis with CONFIG SET; settings that
# need a restart (io-threads) take effect at Redis's next restart. Redis Object Cache shows an
# error page on every site while Redis is down, so this never restarts it.
function apply_redis_tuning() {
    local conf=/etc/redis/redis.conf template=/usr/local/bin/enginescript/config/etc/redis/redis.conf
    local sock=/run/redis/redis-server.sock candidate test_output databases maxmemory defrag=yes

    [[ -f "${conf}" && -f "${template}" ]] || return 0
    tuning_load
    maxmemory="$(tuning_get REDIS_MAXMEMORY_MB)"
    [[ -n "${maxmemory}" ]] || { echo "Error: No Redis maxmemory in the tuning plan." >&2; return 1; }
    databases="$(awk '$1 == "databases" {print $2; exit}' "${conf}")"
    [[ "${databases}" =~ ^[0-9]+$ ]] && (( databases > REDIS_MIN_DATABASES )) || databases="${REDIS_MIN_DATABASES}"

    candidate="$(mktemp)"
    test_output="$(mktemp)"
    sed -e "s|SEDREDISMAXMEM|${maxmemory}|g" -e "s|^databases .*|databases ${databases}|" "${template}" > "${candidate}"
    if cmp -s "${candidate}" "${conf}"; then
        rm -f "${candidate}" "${test_output}"
        return 0
    fi

    if ! test_redis_conf "${candidate}" "${test_output}"; then
        # Ubuntu's own Redis package is built without the jemalloc that active defragmentation
        # needs and refuses "activedefrag yes"; keep the rest of the plan on those servers
        if grep -q 'Active defragmentation cannot be enabled' "${test_output}"; then
            sed -i 's|^activedefrag yes$|activedefrag no|' "${candidate}"
            defrag=no
            if cmp -s "${candidate}" "${conf}"; then
                rm -f "${candidate}" "${test_output}"
                return 0
            fi
        fi
        if [[ "${defrag}" == "yes" ]] || ! test_redis_conf "${candidate}" "${test_output}"; then
            echo "Error: The new redis.conf did not load in a test instance; kept the current one." >&2
            tail -5 "${test_output}" >&2
            rm -f "${candidate}" "${test_output}"
            return 1
        fi
    fi
    rm -f "${test_output}"

    cp -p "${conf}" "${conf}.bak"
    mv -f "${candidate}" "${conf}"
    set_redis_permissions
    if [[ -S "${sock}" ]]; then
        redis-cli -s "${sock}" CONFIG SET maxmemory "${maxmemory}mb" > /dev/null
        redis-cli -s "${sock}" CONFIG SET activedefrag "${defrag}" > /dev/null
    fi
    echo "Redis: applied the tuning plan (maxmemory ${maxmemory} MB) without a restart."
    if [[ "${defrag}" == "no" ]]; then
        echo "Redis: this Redis cannot run active defragmentation (Ubuntu's own package), so it stays off."
        echo "       EngineScript installs Redis from packages.redis.io, which supports it."
    fi
}


# ----------------------------------------------------------------
# Set the OOM killer priority of a running service's processes (its systemd override applies
# from its next start). Usage: set_running_oom_score_adj <process name> <score>
function set_running_oom_score_adj() {
    local pid
    for pid in $(pgrep -x "$1"); do
        echo "$2" > "/proc/${pid}/oom_score_adj" 2> /dev/null || true
    done
}


# ----------------------------------------------------------------
# Apply the shared tuning plan to an installed MariaDB without restarting it
#
# Builds the new my.cnf from the repo template in a staging file (mariadb-tune.sh), checks it
# with mariadbd --help --verbose, installs it, and applies every setting MariaDB can change while
# running with SET GLOBAL. aria_pagecache_buffer_size, innodb_log_buffer_size, and
# innodb_open_files take effect at MariaDB's next restart. The previous file is kept as
# /etc/mysql/my.cnf.enginescript-previous.
function apply_mariadb_tuning() {
    local staged=/etc/mysql/my.cnf.enginescript-new check rc io_max statement refused=0 have want

    [[ -e /etc/mysql/my.cnf ]] && command -v mariadbd > /dev/null 2>&1 || return 0
    cp -f /usr/local/bin/enginescript/config/etc/mysql/my.cnf "${staged}"
    install -d -o mysql -g mysql -m 750 /var/lib/mysql-files
    install -d -o mysql -g mysql -m 750 /var/lib/mysql-tmp
    if ! /usr/local/bin/enginescript/scripts/install/mariadb/mariadb-tune.sh "${staged}" 2>> "${ES_STEP_ERROR_LOG}"; then
        echo "Error: Tuning the new MariaDB configuration failed; kept the current one." >&2
        rm -f "${staged}"
        return 1
    fi
    check="$(mariadbd --defaults-file="${staged}" --help --verbose 2>&1 > /dev/null)"
    rc=$?
    if [[ "${rc}" -ne 0 ]] || grep -q '\[ERROR\]' <<< "${check}"; then
        echo "Error: The new MariaDB configuration failed its check; kept the current one:" >&2
        grep -E '\[(ERROR|Warning)\]' <<< "${check}" | head -5 >&2
        rm -f "${staged}"
        return 1
    fi
    if cmp -s "${staged}" /etc/mysql/my.cnf; then
        rm -f "${staged}"
        return 0
    fi

    # cp writes through /etc/mysql/my.cnf, the MariaDB packages' link to mariadb.cnf
    cp -fL /etc/mysql/my.cnf /etc/mysql/my.cnf.enginescript-previous
    cp -f "${staged}" /etc/mysql/my.cnf
    rm -f "${staged}"

    tuning_load
    io_max=$(( $(tuning_get MARIADB_IO_CAPACITY) * 2 ))
    (( io_max < 2000 )) && io_max=2000
    for statement in \
        "SET GLOBAL max_connections = $(tuning_get MARIADB_MAX_CONNECTIONS)" \
        "SET GLOBAL tmp_table_size = $(( $(tuning_get MARIADB_TMP_TABLE_MB) * 1048576 ))" \
        "SET GLOBAL max_heap_table_size = $(( $(tuning_get MARIADB_TMP_TABLE_MB) * 1048576 ))" \
        "SET GLOBAL table_open_cache = $(tuning_get MARIADB_TABLE_CACHE)" \
        "SET GLOBAL table_definition_cache = $(tuning_get MARIADB_TABLE_CACHE)" \
        "SET GLOBAL innodb_io_capacity_max = ${io_max}" \
        "SET GLOBAL innodb_io_capacity = $(tuning_get MARIADB_IO_CAPACITY)" \
        "SET GLOBAL innodb_flush_neighbors = 0" \
        "SET GLOBAL innodb_log_file_size = $(( $(tuning_get MARIADB_LOG_FILE_MB) * 1048576 ))" \
        "SET GLOBAL innodb_buffer_pool_size = $(( $(tuning_get MARIADB_BUFFER_POOL_MB) * 1048576 ))"; do
        if ! mariadb -e "${statement}" 2>> "${ES_STEP_ERROR_LOG}"; then
            echo "Warning: MariaDB refused \"${statement}\"; it applies at MariaDB's next restart." >&2
            refused=1
        fi
    done
    # Older MariaDB releases cap a live resize at the buffer pool size they started with
    # (innodb_buffer_pool_size_max), and keep the smaller pool without an error
    have="$(mariadb -N -B -e 'SELECT @@innodb_buffer_pool_size' 2> /dev/null)"
    want=$(( $(tuning_get MARIADB_BUFFER_POOL_MB) * 1048576 ))
    if [[ "${have}" =~ ^[0-9]+$ ]] && (( have + 67108864 < want )); then
        echo "Warning: MariaDB kept its buffer pool at $(( have / 1048576 )) MB, the most it allows without a restart." >&2
        refused=1
    fi
    set_running_oom_score_adj mariadbd -600
    if (( refused == 0 )); then
        echo "MariaDB: applied the tuning plan (buffer pool $(tuning_get MARIADB_BUFFER_POOL_MB) MB) without a restart."
    else
        echo "MariaDB: installed the tuning plan; the settings above apply at MariaDB's next restart."
    fi
}


# ----------------------------------------------------------------
# Apply the shared tuning plan's Nginx values to the running nginx.conf
#
# Patches the FastCGI cache index and disk limit, and the October 2026 tuning (cache inactive
# 3h with min_free, keepalive_timeout 900s, open_file_cache_errors off, worker_connections 4096,
# worker_rlimit_nofile 16384), tests with nginx -t, and reloads; the previous file is restored if
# the test or the reload fails. Other template changes arrive with the next Nginx update.
function apply_nginx_tuning() {
    local conf=/etc/nginx/nginx.conf backup

    [[ -f "${conf}" ]] && command -v nginx > /dev/null 2>&1 || return 0
    tuning_load
    backup="$(mktemp)"
    cp -p "${conf}" "${backup}"
    sed -i -E \
        -e "s|keys_zone=EngineScriptWP:[0-9]+m|keys_zone=EngineScriptWP:$(tuning_get NGINX_CACHE_ZONE_MB)m|" \
        -e "s|(fastcgi_cache_path [^;]*) inactive=[0-9]+[a-z]|\1 inactive=3h|" \
        -e "s|(fastcgi_cache_path [^;]*) max_size=[0-9]+m|\1 max_size=$(tuning_get NGINX_CACHE_MAX_MB)m|" \
        -e "/fastcgi_cache_path/{/min_free=/!s| use_temp_path=| min_free=1g use_temp_path=|}" \
        -e "s|^([[:space:]]*)keepalive_timeout [0-9]+s?;|\1keepalive_timeout 900s;|" \
        -e "s|^([[:space:]]*)open_file_cache_errors on;|\1open_file_cache_errors off;|" \
        -e "s|^([[:space:]]*)worker_connections [0-9]+;|\1worker_connections 4096;|" \
        -e "s|^worker_rlimit_nofile [0-9]+;|worker_rlimit_nofile 16384;|" \
        "${conf}"
    if cmp -s "${conf}" "${backup}"; then
        rm -f "${backup}"
        return 0
    fi
    if ! nginx -t > /dev/null 2>&1; then
        cp -p "${backup}" "${conf}"
        echo "Error: nginx -t failed with the tuned nginx.conf; restored the previous one." >&2
        nginx -t 2>&1 | tail -3 >&2
        rm -f "${backup}"
        return 1
    fi
    # A stopped Nginx reads the new file when it starts. If the reload fails, the previous file
    # is restored, so the next re-tune applies the plan again instead of finding nothing to change.
    if systemctl is-active --quiet nginx && ! systemctl reload nginx; then
        cp -p "${backup}" "${conf}"
        echo "Error: Nginx did not reload with the tuned nginx.conf; restored the previous one." >&2
        rm -f "${backup}"
        return 1
    fi
    echo "Nginx: applied the tuning plan (cache index $(tuning_get NGINX_CACHE_ZONE_MB) MB, cache limit $(tuning_get NGINX_CACHE_MAX_MB) MB)."
    rm -f "${backup}"
}
