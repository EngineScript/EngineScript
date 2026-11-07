#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------
# Cloudflare Functions
# The Cloudflare API (zones, DNS records, zone settings) and Cloudflare's IP ranges. Every API
# call goes through cloudflare_curl, which passes the account email and key to curl on stdin.
# Loaded by enginescript-common.sh.
#----------------------------------------------------------------------------------


CF_API_BASE="https://api.cloudflare.com/client/v4"


# ----------------------------------------------------------------
# Run curl with the Cloudflare account's email and Global API key (CF_ACCOUNT_EMAIL,
# CF_GLOBAL_API_KEY) as headers. They go in on standard input (-K -), as in notify_admin:
# command-line arguments are visible to every user, and the key controls the whole account.
# Usage: cloudflare_curl <curl arguments>
function cloudflare_curl() {
    local email="${CF_ACCOUNT_EMAIL:-}" key="${CF_GLOBAL_API_KEY:-}"

    # Quoted values in a curl config file take backslash escapes
    email="${email//\\/\\\\}"
    email="${email//\"/\\\"}"
    key="${key//\\/\\\\}"
    key="${key//\"/\\\"}"
    printf 'header = "X-Auth-Email: %s"\nheader = "X-Auth-Key: %s"\n' "${email}" "${key}" | curl -K - "$@"
}


# ----------------------------------------------------------------
# True when the install options hold a Cloudflare email and key (not the PLACEHOLDER defaults)
function cf_enabled() {
    [[ -n "${CF_GLOBAL_API_KEY:-}" && "${CF_GLOBAL_API_KEY}" != "PLACEHOLDER" \
        && -n "${CF_ACCOUNT_EMAIL:-}" && "${CF_ACCOUNT_EMAIL}" != "PLACEHOLDER" ]]
}


# ----------------------------------------------------------------
# Call the Cloudflare API and print its JSON answer (nothing when there is no answer)
# Usage: cf_request <METHOD> <path after /client/v4> [JSON body]
function cf_request() {
    local args=(-s --max-time 30 -X "$1" "${CF_API_BASE}$2" -H "Content-Type: application/json")
    if [[ -n "${3:-}" ]]; then
        args+=(--data "$3")
    fi
    cloudflare_curl "${args[@]}"
}


# True when a Cloudflare answer says "success": true (compact or pretty-printed JSON)
function cf_succeeded() {
    grep -Eq '"success"[[:space:]]*:[[:space:]]*true' <<< "$1"
}


# Print the first error message of a Cloudflare answer
function cf_error_message() {
    grep -oE '"message"[[:space:]]*:[[:space:]]*"[^"]*"' <<< "$1" | head -n 1 \
        | sed -E 's/^"message"[[:space:]]*:[[:space:]]*"(.*)"$/\1/'
    return 0
}


# Print the first value of a field in a Cloudflare answer (for a record list, the first record's)
# Usage: cf_field <answer> <id|type|content|...>
function cf_field() {
    grep -o "\"$2\":\"[^\"]*" <<< "$1" | head -n 1 | cut -d'"' -f4
    return 0
}


# ----------------------------------------------------------------
# Print the ID of a domain's active Cloudflare zone (nothing when there is none)
# Usage: cf_zone_id <domain>
function cf_zone_id() {
    cf_field "$(cf_request GET "/zones?name=$1&status=active")" "id"
}


# Look up the first DNS record with a name (and a type, when given) in a zone. Sets
# CF_RECORD_ID, CF_RECORD_TYPE, and CF_RECORD_CONTENT, which are empty when there is no record.
# Returns 1 when Cloudflare did not answer.
# Usage: cf_find_dns_record <zone ID> <name> [type]
function cf_find_dns_record() {
    local zone="$1" name="$2" type="${3:-}" query response
    CF_RECORD_ID="" CF_RECORD_TYPE="" CF_RECORD_CONTENT=""
    query="name=${name}"
    if [[ -n "${type}" ]]; then
        query="type=${type}&${query}"
    fi
    response="$(cf_request GET "/zones/${zone}/dns_records?${query}")"
    cf_succeeded "${response}" || return 1
    CF_RECORD_ID="$(cf_field "${response}" "id")"
    # shellcheck disable=SC2034  # read by the callers
    CF_RECORD_TYPE="$(cf_field "${response}" "type")"
    # shellcheck disable=SC2034
    CF_RECORD_CONTENT="$(cf_field "${response}" "content")"
    return 0
}


# ----------------------------------------------------------------
# Make one change to a zone (a setting or a DNS record) and print one line for it: a check mark,
# or a cross with Cloudflare's error message, instead of the raw JSON. Failures are counted in
# CF_FAILED. Returns 1 when Cloudflare did not report success.
# Usage: cf_apply <zone ID> "<what it sets>" <METHOD> <path after /zones/ZONE_ID> [JSON body]
function cf_apply() {
    local zone="$1" label="$2" method="$3" path="$4" body="${5:-}" response message
    response="$(cf_request "${method}" "/zones/${zone}${path}" "${body}")"
    if cf_succeeded "${response}"; then
        echo "  ✓ ${label}"
        return 0
    fi
    message="$(cf_error_message "${response}")"
    echo "  ✗ ${label}: ${message:-no answer from Cloudflare}"
    CF_FAILED=$(( ${CF_FAILED:-0} + 1 ))
    return 1
}


# Add a DNS record, or update the first record with its name and type, and print the result
# (cf_apply). The body is the record's JSON.
# Usage: cf_upsert_dns_record <zone ID> <type> <full name> "<label>" <JSON body>
function cf_upsert_dns_record() {
    local zone="$1" type="$2" name="$3" label="$4" body="$5"
    if ! cf_find_dns_record "${zone}" "${name}" "${type}"; then
        echo "  ✗ ${label}: no answer from Cloudflare"
        CF_FAILED=$(( ${CF_FAILED:-0} + 1 ))
        return 1
    fi
    if [[ -z "${CF_RECORD_ID}" ]]; then
        cf_apply "${zone}" "${label}, added" POST "/dns_records" "${body}"
    else
        cf_apply "${zone}" "${label}, updated" PUT "/dns_records/${CF_RECORD_ID}" "${body}"
    fi
}


# ----------------------------------------------------------------
# Print Cloudflare's IPv4 or IPv6 ranges, one per line, from cloudflare.com. Every line must be
# an address range (CIDR); returns 1, printing nothing, when the download fails or any line is
# not a range, so a bad download can never reach the Nginx configuration or the firewall.
# Usage: cf_ip_ranges v4|v6
function cf_ip_ranges() {
    local family="$1" regex body range ranges=()
    case "${family}" in
        v4) regex='^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])/([0-9]|[1-2][0-9]|3[0-2])$' ;;
        # 3 to 8 colon-separated groups of up to four hex digits (:: leaves groups empty), then
        # /0 to /128. Enough to keep anything but an address range out.
        v6) regex='^[0-9A-Fa-f]{0,4}(:[0-9A-Fa-f]{0,4}){2,7}/([0-9]|[1-9][0-9]|1[01][0-9]|12[0-8])$' ;;
        *)
            echo "Error: cf_ip_ranges takes v4 or v6, not '${family}'." >&2
            return 1
            ;;
    esac

    if ! body="$(curl -fsS --proto '=https' --max-time 30 --retry 3 "https://www.cloudflare.com/ips-${family}")"; then
        echo "Error: Could not download Cloudflare's IP${family} ranges." >&2
        return 1
    fi
    while IFS= read -r range || [[ -n "${range}" ]]; do
        range="${range%$'\r'}"
        [[ -z "${range}" ]] && continue
        if [[ ! "${range}" =~ ${regex} ]]; then
            echo "Error: Cloudflare's IP${family} list has a line that is not an address range: [${range}]" >&2
            return 1
        fi
        ranges+=("${range}")
    done <<< "${body}"
    if [[ "${#ranges[@]}" -eq 0 ]]; then
        echo "Error: Cloudflare's IP${family} list is empty." >&2
        return 1
    fi
    printf '%s\n' "${ranges[@]}"
}
