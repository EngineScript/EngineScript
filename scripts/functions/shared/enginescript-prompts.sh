#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript - A High-Performance WordPress Server Built on Ubuntu and Cloudflare
#----------------------------------------------------------------------------------
# Website:      https://EngineScript.com
# GitHub:       https://github.com/Enginescript/EngineScript
# License:      GPL v3.0
#----------------------------------------------------------------------------------
# Prompt and Validation Functions
# Pauses, yes/no and text prompts with time limits, and domain and email checks.
# Loaded by enginescript-common.sh.
#----------------------------------------------------------------------------------


# ----------------------------------------------------------------
# Wait for a key, so a tool's output stays on screen before the menu redraws
function pause() {
    echo ""
    read -n 1 -s -r -p "Press any key to continue"
    echo ""
    echo ""
}


# ----------------------------------------------------------------
# Enhanced input validation functions
# Prompts user with timeout and exit options for basic continuation
function prompt_continue() {
    local prompt_text="${1:-Press [Enter] to continue or type 'exit' to abort}"
    local timeout_seconds="${2:-300}"  # 5 minute default timeout
    
    while true; do
        echo -e "\n${prompt_text}"
        if read -t "${timeout_seconds}" -p "> " user_input; then
            case "${user_input,,}" in  # Convert to lowercase
                ""|"y"|"yes"|"continue")
                    return 0
                    ;;
                "exit"|"quit"|"abort"|"stop")
                    echo -e "\nExiting script as requested."
                    exit 1
                    ;;
                *)
                    echo "Invalid input. Please press Enter to continue or type 'exit' to abort."
                    ;;
            esac
        else
            echo -e "\nTimeout reached (${timeout_seconds}s). Exiting script."
            exit 1
        fi
    done
}


# ----------------------------------------------------------------
# Prompts user for yes/no confirmation with validation and timeout
function prompt_yes_no() {
    local prompt_text="$1"
    local default_value="${2:-""}"  # Optional default (y/n)
    local timeout_seconds="${3:-300}"  # 5 minute default timeout
    
    local prompt_suffix=""
    if [[ -n "$default_value" ]]; then
        case "${default_value,,}" in
            "y"|"yes") prompt_suffix=" [Y/n/exit]" ;;
            "n"|"no") prompt_suffix=" [y/N/exit]" ;;
            *) prompt_suffix=" [y/n/exit]" ;;
        esac
    else
        prompt_suffix=" [y/n/exit]"
    fi
    
    while true; do
        echo -e "\n${prompt_text}${prompt_suffix}"
        if read -t "${timeout_seconds}" -p "> " user_input; then
            # Use default if empty input and default is set
            if [[ -z "$user_input" && -n "$default_value" ]]; then
                user_input="$default_value"
            fi
            
            case "${user_input,,}" in
                "y"|"yes")
                    return 0  # True/Yes
                    ;;
                "n"|"no") 
                    return 1  # False/No
                    ;;
                "exit"|"quit"|"abort"|"stop")
                    echo -e "\nExiting script as requested."
                    exit 1
                    ;;
                "")
                    if [[ -z "$default_value" ]]; then
                        echo "Please enter 'y' for yes, 'n' for no, or 'exit' to abort."
                    else
                        echo "Please enter 'y', 'n', or 'exit'."
                    fi
                    ;;
                *)
                    echo "Invalid input. Please enter 'y' for yes, 'n' for no, or 'exit' to abort."
                    ;;
            esac
        else
            echo -e "\nTimeout reached (${timeout_seconds}s). Exiting script."
            exit 1
        fi
    done
}


# ----------------------------------------------------------------
# Prompts user for text input with validation and timeout.
# Prints only the answer on stdout, so callers capture it with $(...); messages go to stderr.
# Inside $(...), the exit on "exit" or a timeout ends only that subshell: callers check the status.
function prompt_input() {
    local prompt_text="$1"
    local default_value="${2:-""}"
    local timeout_seconds="${3:-300}"  # 5 minute default timeout
    local validation_pattern="${4:-""}"  # Optional regex pattern
    local allow_empty="${5:-false}"  # Whether to allow empty input
    
    local prompt_suffix=""
    if [[ -n "$default_value" ]]; then
        prompt_suffix=" [${default_value}]"
    fi
    
    while true; do
        echo -e "\n${prompt_text}${prompt_suffix}" >&2
        echo "Type 'exit' to abort the script." >&2
        if read -t "${timeout_seconds}" -p "> " user_input; then
            case "${user_input,,}" in
                "exit"|"quit"|"abort"|"stop")
                    echo -e "\nExiting script as requested." >&2
                    exit 1
                    ;;
                "")
                    if [[ -n "$default_value" ]]; then
                        echo "$default_value"
                        return 0
                    elif [[ "$allow_empty" == "true" ]]; then
                        echo ""
                        return 0
                    else
                        echo "Input cannot be empty. Please enter a value or type 'exit' to abort." >&2
                    fi
                    ;;
                *)
                    # Validate against pattern if provided
                    if [[ -n "$validation_pattern" ]]; then
                        if [[ "$user_input" =~ $validation_pattern ]]; then
                            echo "$user_input"
                            return 0
                        else
                            echo "Invalid input format. Please try again or type 'exit' to abort." >&2
                        fi
                    else
                        echo "$user_input"
                        return 0
                    fi
                    ;;
            esac
        else
            echo -e "\nTimeout reached (${timeout_seconds}s). Exiting script." >&2
            exit 1
        fi
    done
}


# ----------------------------------------------------------------
# One label of a domain name (the "example" in example.com): 1 to 63 lowercase letters, digits,
# and hyphens, not starting or ending with a hyphen (RFC 952 / RFC 1123).
#
# IMPORTANT: Single-character labels (e.g., 'x' in 'x.com', 'a' in 'a.io') MUST pass. They are
# fully valid under DNS and ICANN rules, and EngineScript must support them. The optional group
# `([a-z0-9-]{0,61}[a-z0-9])?` makes everything after the first character optional, so a single
# character matches on its own; the group still stops a leading or trailing hyphen ("-bad",
# "bad-"). Do not "fix" this to require at least two characters.
# Usage: validate_domain_label <label>
function validate_domain_label() {
    [[ "$1" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]
}


# ----------------------------------------------------------------
# Full site domain validation: lowercase labels separated by dots (example.com, blog.example.co.uk),
# each 1 to 63 characters without a leading or trailing hyphen, ending in a TLD that starts
# with a letter (xn-- TLDs included)
function validate_site_domain() {
    local domain="$1"
    local label="[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?"

    [[ ${#domain} -le 253 && "${domain}" =~ ^(${label}\.)+[a-z]([a-z0-9-]{0,61}[a-z0-9])?$ ]]
}


# ----------------------------------------------------------------
# Email validation function
function validate_email() {
    local email="$1"
    local email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    
    if [[ "$email" =~ $email_regex ]]; then
        return 0
    else
        return 1
    fi
}
