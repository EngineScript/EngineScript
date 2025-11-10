#!/usr/bin/env bash
# ! /usr/bin/env bash

##############################################################################
# EngineScript Metrics Collection Script
# Purpose: Collect system metrics and store in JSON file for dashboard
# Run via cron: */5 * * * * /usr/local/bin/enginescript-collect-metrics
# 
# Metrics Collected:
#   - CPU usage (percentage)
#   - Memory usage (percentage)
#   - Disk usage (percentage)
#   - Timestamp (Unix epoch)
#
# Features:
#   - JSON-based storage (/var/lib/enginescript/metrics.json)
#   - 7-day rolling window (auto-rotation)
#   - Max 2,016 data points (288 per day × 7 days)
#   - Automatic cleanup of old entries
#
##############################################################################

set -e

# Configuration
METRICS_DIR="/var/lib/enginescript"
METRICS_FILE="${METRICS_DIR}/metrics.json"
MAX_ENTRIES=2016  # 7 days × 288 entries per day (5-min intervals)
RETENTION_DAYS=7

# Ensure metrics directory exists
if [[ ! -d "${METRICS_DIR}" ]]; then
    mkdir -p "${METRICS_DIR}"
    chmod 755 "${METRICS_DIR}"
fi

# Function to get CPU usage percentage
get_cpu_usage() {
    # Get CPU usage from /proc/stat
    # This method calculates CPU usage since last boot
    local cpu_info
    cpu_info=$(awk '/^cpu[^u]/ {print $2+$3+$4+$5+$6+$7+$8+$9+$10+$11, $5}' /proc/stat | head -1)
    
    # Fallback: use top if available
    if command -v top &> /dev/null; then
        top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}'
    else
        # Simple fallback: average of load average / CPU count
        local load_avg
        load_avg=$(awk '{print $1}' /proc/loadavg)
        local cpu_count
        cpu_count=$(grep -c "^processor" /proc/cpuinfo)
        echo "scale=1; ($load_avg / $cpu_count) * 100" | bc
    fi
}

# Function to get memory usage percentage
get_memory_usage() {
    # Parse /proc/meminfo for accurate memory calculation
    local total_mem
    local available_mem
    local used_mem
    local usage_percent
    
    total_mem=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
    available_mem=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
    
    if [[ -z "${available_mem}" ]]; then
        # Fallback for older kernels
        available_mem=$(awk '/^MemFree:/ {print $2}' /proc/meminfo)
    fi
    
    used_mem=$((total_mem - available_mem))
    usage_percent=$(awk "BEGIN {printf \"%.1f\", ($used_mem / $total_mem) * 100}")
    
    echo "${usage_percent}"
}

# Function to get disk usage percentage
get_disk_usage() {
    # Get disk usage of root partition
    df / | awk 'NR==2 {print $5}' | sed 's/%//'
}

# Function to initialize metrics file
init_metrics_file() {
    if [[ ! -f "${METRICS_FILE}" ]]; then
        echo "[]" > "${METRICS_FILE}"
        chmod 644 "${METRICS_FILE}"
    fi
}

# Function to add metric entry
add_metric_entry() {
    local timestamp=$1
    local cpu=$2
    local memory=$3
    local disk=$4
    
    local new_entry="{\"timestamp\":${timestamp},\"cpu\":${cpu},\"memory\":${memory},\"disk\":${disk}}"
    
    # Read existing metrics
    local current_metrics
    current_metrics=$(cat "${METRICS_FILE}")
    
    # Add new entry (remove closing bracket, add entry, close bracket)
    local updated_metrics
    updated_metrics=$(echo "${current_metrics}" | sed '$ s/\]//' | sed '$s/$/,/' )
    updated_metrics="${updated_metrics}${new_entry}]"
    
    # Write back
    echo "${updated_metrics}" > "${METRICS_FILE}"
}

# Function to prune old entries
prune_old_entries() {
    local current_metrics
    current_metrics=$(cat "${METRICS_FILE}")
    
    # Get array length
    local entry_count
    entry_count=$(echo "${current_metrics}" | grep -o '{"timestamp"' | wc -l)
    
    # If we have too many entries, remove oldest ones
    if (( entry_count > MAX_ENTRIES )); then
        local excess
        excess=$((entry_count - MAX_ENTRIES + 1))
        
        # Use jq if available, otherwise use awk
        if command -v jq &> /dev/null; then
            echo "${current_metrics}" | jq ".[${excess}:]" > "${METRICS_FILE}"
        else
            # Manual pruning using sed (remove first N entries)
            # This is a simple approach that works for most cases
            echo "${current_metrics}" | sed "1,${excess}d" > "${METRICS_FILE}"
        fi
    fi
}

# Function to prune entries older than retention period
prune_old_dates() {
    local current_metrics
    current_metrics=$(cat "${METRICS_FILE}")
    
    local cutoff_time
    cutoff_time=$(date +%s -d "${RETENTION_DAYS} days ago")
    
    if command -v jq &> /dev/null; then
        echo "${current_metrics}" | jq "[.[] | select(.timestamp > ${cutoff_time})]" > "${METRICS_FILE}"
    fi
}

# Main execution
main() {
    # Initialize metrics file if needed
    init_metrics_file
    
    # Collect current metrics
    local cpu_usage
    local memory_usage
    local disk_usage
    local timestamp
    
    timestamp=$(date +%s)
    cpu_usage=$(get_cpu_usage)
    memory_usage=$(get_memory_usage)
    disk_usage=$(get_disk_usage)
    
    # Validate metrics (ensure they're reasonable numbers)
    if ! [[ "${cpu_usage}" =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( $(echo "${cpu_usage} > 100" | bc -l) )); then
        cpu_usage="0"
    fi
    if ! [[ "${memory_usage}" =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( $(echo "${memory_usage} > 100" | bc -l) )); then
        memory_usage="0"
    fi
    if ! [[ "${disk_usage}" =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( $(echo "${disk_usage} > 100" | bc -l) )); then
        disk_usage="0"
    fi
    
    # Add metric entry
    add_metric_entry "${timestamp}" "${cpu_usage}" "${memory_usage}" "${disk_usage}"
    
    # Prune old entries
    prune_old_dates
    prune_old_entries
}

# Execute main
main
