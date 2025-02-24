#!/usr/bin/env bash

# Prevent duplicate sourcing
if [[ -n "${_LIB_LOGGING_LOADED:-}" ]]; then return; fi
_LIB_LOGGING_LOADED=true

# Ensure script stops on errors and propagates failures properly.
set -euo pipefail

# Detect if terminal supports colors and unicode
_detect_terminal_capabilities() {
    # Check if NO_COLOR is set (respect user preference)
    if [[ -n "${NO_COLOR:-}" ]]; then
        _USE_COLOR=false
    else
        # Check if output is to terminal and terminal supports colors
        if [[ -t 1 ]] && [[ -n "${TERM:-}" ]] && command -v tput >/dev/null 2>&1; then
            if [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
                _USE_COLOR=true
            else
                _USE_COLOR=false
            fi
        else
            _USE_COLOR=false
        fi
    fi

    # Check if terminal supports unicode
    if [[ "$(locale charmap 2>/dev/null)" == *"UTF-8"* ]]; then
        _USE_UNICODE=true
    else
        _USE_UNICODE=false
    fi
}

# Initialize terminal capabilities
_detect_terminal_capabilities

# Define fallback symbols for non-unicode terminals
declare -A _SYMBOLS=(
    ["debug"]="DEBUG:"
    ["info"]="INFO:"
    ["success"]="OK:"
    ["warning"]="WARN:"
    ["error"]="ERROR:"
    ["fatal"]="FATAL:"
)

# Define unicode symbols if supported
if [[ "${_USE_UNICODE:-false}" == "true" ]]; then
    _SYMBOLS["debug"]="🔍"
    _SYMBOLS["info"]="📌"
    _SYMBOLS["success"]="✅"
    _SYMBOLS["warning"]="⚠️"
    _SYMBOLS["error"]="❌"
    _SYMBOLS["fatal"]="💥"
fi

# Define color codes if supported
if [[ "${_USE_COLOR:-false}" == "true" ]]; then
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

# Internal logging function
_log() {
    local level="$1"
    local message="$2"
    local color="$3"
    local symbol="${_SYMBOLS[${level,,}]}"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # Handle multiline messages
    echo "$message" | while IFS= read -r line || [[ -n "$line" ]]; do
        printf "%b%s [%s] [%s] %s%b\n" \
            "$color" "$symbol" "${level^^}" "$timestamp" "$line" "$_COLOR_RESET"
    done
}

log_debug() {
    [[ "${LOG_LEVEL:-}" == "debug" ]] || return 0
    _log "debug" "$1" "$_COLOR_DEBUG" >&2
}

log_info() {
    _log "info" "$1" "$_COLOR_INFO"
}

log_success() {
    _log "success" "$1" "$_COLOR_SUCCESS"
}

log_warning() {
    _log "warning" "$1" "$_COLOR_WARNING"
}

log_error() {
    _log "error" "$1" "$_COLOR_ERROR" >&2
}

log_fatal() {
    _log "fatal" "$1" "$_COLOR_FATAL" >&2
    exit 1
}
