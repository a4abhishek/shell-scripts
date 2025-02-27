#!/usr/bin/env bash

# Prevent duplicate sourcing
if [[ -n "${_LIB_LOGGING_LOADED:-}" ]]; then return; fi
_LIB_LOGGING_LOADED=true

# Ensure script stops on errors and propagates failures properly.
set -euo pipefail

# Source feature detection
CORE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$CORE_LIB_DIR/features.sh"

# Logging behavior:
# - By default, logs at or above LOG_LEVEL (default: info) are shown when output is to a terminal
# - When LOG_LEVEL=debug is set, all logs are shown regardless of terminal or LOG_LEVEL
# - Use LOG_LEVEL=debug when you need to see debug logs in pipelines or redirections
#
# Log levels (from lowest to highest priority):
# - debug   : Detailed information for debugging
# - info    : General information about script progress
# - success : Successful completion of a task
# - warning : Potential issues that don't stop execution
# - error   : Error conditions that may stop execution
# - fatal   : Critical errors that will stop execution
#
# Example: LOG_LEVEL=warning ./script.sh # Only show warning and above

# Define log levels and their numeric values
declare -A _LOG_LEVELS=(
    ["debug"]=0
    ["info"]=1
    ["success"]=2
    ["warning"]=3
    ["error"]=4
    ["fatal"]=5
)

# Set default log level to info
LOG_LEVEL="${LOG_LEVEL:-info}"
_CURRENT_LEVEL="${_LOG_LEVELS[${LOG_LEVEL,,}]:-1}"

_detect_terminal_capabilities() {
    # Allow test override, but NO_COLOR takes precedence
    if [[ -n "${NO_COLOR:-}" ]]; then
        export HAS_COLOR_SUPPORT=false
    elif [[ -n "${FORCE_COLOR:-}" ]]; then
        export HAS_COLOR_SUPPORT=true
    fi

    # Define fallback symbols for non-unicode terminals
    declare -gA _SYMBOLS=(
        ["debug"]="DEBUG:"
        ["info"]="INFO:"
        ["success"]="OK:"
        ["warning"]="WARN:"
        ["error"]="ERROR:"
        ["fatal"]="FATAL:"
    )

    # Define unicode symbols if supported
    if [[ "${HAS_UNICODE_SUPPORT:-false}" == "true" ]]; then
        _SYMBOLS["debug"]="🔍"
        _SYMBOLS["info"]="📌"
        _SYMBOLS["success"]="✅"
        _SYMBOLS["warning"]="⚠️"
        _SYMBOLS["error"]="❌"
        _SYMBOLS["fatal"]="💥"
    fi

    # Define color codes if supported
    if [[ "${HAS_COLOR_SUPPORT:-false}" == "true" ]]; then
        _COLOR_DEBUG="\033[1;34m"   # Bold Blue
        _COLOR_INFO="\033[1;32m"    # Bold Green
        _COLOR_SUCCESS="\033[1;32m" # Bold Green
        _COLOR_WARNING="\033[1;33m" # Bold Yellow
        _COLOR_ERROR="\033[1;31m"   # Bold Red
        _COLOR_FATAL="\033[1;31m"   # Bold Red
        _COLOR_RESET="\033[0m"
    else
        _COLOR_DEBUG=""
        _COLOR_INFO=""
        _COLOR_SUCCESS=""
        _COLOR_WARNING=""
        _COLOR_ERROR=""
        _COLOR_FATAL=""
        _COLOR_RESET=""
    fi
}

# Function to reinitialize terminal capabilities (useful for testing)
reinit_terminal_capabilities() {
    _detect_terminal_capabilities
}

# Initialize terminal capabilities
_detect_terminal_capabilities

# Internal logging function
_log() {
    local level="$1"
    local message="$2"
    local level_num="${_LOG_LEVELS[${level,,}]}"

    # Show logs if:
    # 1. We're in debug mode (LOG_LEVEL=debug), or
    # 2. Level is high enough AND writing to a terminal
    if [[ "${LOG_LEVEL,,}" == "debug" ]] || { [[ $level_num -ge $_CURRENT_LEVEL ]] && [[ -t 1 ]]; }; then
        local symbol="${_SYMBOLS[${level,,}]}"
        local timestamp
        timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

        echo "$message" | while IFS= read -r line || [[ -n "$line" ]]; do
            printf "%s [%s] [%s] %s%b\n" \
                "$symbol" "${level^^}" "$timestamp" "$line" "$_COLOR_RESET"
        done
    fi
}

log_debug() {
    _log "debug" "$1" >&2
}

log_info() {
    _log "info" "$1"
}

log_success() {
    _log "success" "$1"
}

log_warning() {
    _log "warning" "$1"
}

log_error() {
    _log "error" "$1" >&2
}

log_fatal() {
    _log "fatal" "$1" >&2
    exit 1
}
