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
# - Logs are written to the specified file descriptor (default: stdout).
# - Logs are displayed in color if the output FD is a TTY and color support is enabled.
# - Color support is automatically detected but can be overridden:
#   - Set NO_COLOR to disable color output.
#   - Set FORCE_COLOR to enable color output (even if not a TTY).
# - By default, logs at or above LOG_LEVEL (default: info) are shown.
# - When LOG_LEVEL=debug is set, all level based logs are shown regardless of terminal or redirection.
# - Non-error logs (debug, info, success) are written to LOG_NONERROR_FD (default: stdout).
# - Error logs (warning, error, fatal) are written to LOG_ERROR_FD (default: stderr).
# - You can use log with a custom prefix, label, timestamp format, message, output FD, and color code.
# - Set NOLOG to suppress all logging output (except when FORCE_LOG is set)
# - Set FORCE_LOG to force logging regardless of NOLOG or terminal settings (still honors LOG_LEVEL)
#
# Log levels (from lowest to highest priority):
# - debug   : Detailed information for debugging
# - info    : General information about script progress
# - success : Successful completion of a task
# - warning : Potential issues that don't stop execution
# - error   : Error conditions that may stop execution
# - fatal   : Critical errors that will stop execution
#
# Define log levels and their numeric values
declare -gA _LOG_LEVELS=(
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

# Default log output to stdout (fd 1) for informational messages.
LOG_NONERROR_FD="${LOG_NONERROR_FD:-1}"
# Default log output to stderr (fd 2) for error messages.
LOG_ERROR_FD="${LOG_ERROR_FD:-2}"

# Default timestamp format for logging
_DEFAULT_TIMESTAMP_FORMAT="%Y-%m-%d %H:%M:%S"

# Initialize color variables (will be populated in _detect_terminal_capabilities)
declare -gA _SYMBOLS=()

declare _COLOR_DEBUG=""
declare _COLOR_INFO=""
declare _COLOR_SUCCESS=""
declare _COLOR_WARNING=""
declare _COLOR_ERROR=""
declare _COLOR_FATAL=""
declare _COLOR_RESET=""

_detect_terminal_capabilities() {
    # Initialize the fallback symbols
    _SYMBOLS=(
        ["debug"]="DEBUG:"
        ["info"]="INFO:"
        ["success"]="OK:"
        ["warning"]="WARN:"
        ["error"]="ERROR:"
        ["fatal"]="FATAL:"
    )

    # Replace with Unicode symbols if supported.
    if [[ "${HAS_UNICODE_SUPPORT:-false}" == "true" ]]; then
        _SYMBOLS["debug"]="🔍"
        _SYMBOLS["info"]="📌"
        _SYMBOLS["success"]="✅"
        _SYMBOLS["warning"]="⚠️"
        _SYMBOLS["error"]="❌"
        _SYMBOLS["fatal"]="💥"
    fi

    # Set ANSI color codes if color is supported; otherwise, explicitly set them to empty.
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
    _detect_terminal_features
    _detect_terminal_capabilities
}

# Initialize terminal capabilities
_detect_terminal_capabilities

# Generic logging function that formats and outputs log messages.
# If no label is provided, the message is logged unconditionally.
log() {
    local prefix="${1:-}"
    local label="${2:-}"
    local timestamp_format="${3:-}"
    local message="$4"
    local output_fd="${5:-1}" # Default to stdout
    local color_code="${6:-}"
    local color_reset="${7:-}" # Default color reset

    # Only check log level if a label is provided.
    # Unlabeled logs are always shown regardless of settings.
    if [[ -n "$label" ]]; then
        if ! log_is_enabled "${label,,}"; then
            return 0
        fi
    fi

    if [[ -n "$color_code" && -z "$color_reset" ]]; then
        color_reset="$_COLOR_RESET"
    fi

    local timestamp=""
    if [[ -n "$timestamp_format" ]]; then
        # Use a fallback in case the date command fails (for invalid formats)
        timestamp=$(date "+$timestamp_format" 2> /dev/null || echo "TIMESTAMP")
        timestamp="[$timestamp]"
    fi

    # Check if the output file descriptor is valid and writable
    if ! { : >&"$output_fd"; } 2> /dev/null; then
        return 1
    fi

    # Ensure proper spacing between components
    local formatted_prefix="$prefix"
    local formatted_label="$label"
    local formatted_timestamp="$timestamp"

    [[ -n "$formatted_prefix" ]] && formatted_prefix="$formatted_prefix "
    [[ -n "$formatted_label" ]] && formatted_label="$formatted_label "
    [[ -n "$formatted_timestamp" ]] && formatted_timestamp="$formatted_timestamp "

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Use printf with %b to interpret escape sequences
        printf "%s%s%s%b%s%b\n" \
            "$formatted_prefix" "$formatted_label" "$formatted_timestamp" "$color_code" "$line" "$color_reset" >&"$output_fd"
    done <<< "$message"
}

# Internal function for level-based logging.
_leveled_log() {
    local level="$1"
    local message="$2"
    local level_num="${_LOG_LEVELS[${level,,}]:-1}"

    local output_fd
    case "$level" in
        debug | info | success)
            output_fd="$LOG_NONERROR_FD"
            ;;
        warning | error | fatal)
            output_fd="$LOG_ERROR_FD"
            ;;
        *)
            output_fd="$LOG_NONERROR_FD"
            ;;
    esac

    if [[ "${LOG_LEVEL,,}" == "debug" ]] || [[ "$level_num" -ge "$_CURRENT_LEVEL" ]]; then
        local symbol="${_SYMBOLS[${level,,}]}"
        local color_var="_COLOR_${level^^}"
        local color_code="${!color_var:-}"
        log "$symbol" "${level^^}" "$_DEFAULT_TIMESTAMP_FORMAT" "$message" "$output_fd" "$color_code"
    fi
}

log_debug() {
    _leveled_log "debug" "$1"
}

log_info() {
    _leveled_log "info" "$1"
}

log_success() {
    _leveled_log "success" "$1"
}

log_warning() {
    _leveled_log "warning" "$1"
}

log_error() {
    _leveled_log "error" "$1"
}

log_fatal() {
    local message="$1"
    local exit_code="${2:-1}"
    _leveled_log "fatal" "$message"
    exit "$exit_code"
}

# Check if logging is enabled for a given level.
log_is_enabled() {
    local level="$1"
    local level_num="${_LOG_LEVELS[${level,,}]:-1}"

    # NOLOG takes precedence over everything
    if [[ -n "${NOLOG:-}" ]]; then
        return 1
    fi

    # If FORCE_LOG is set, enable logging.
    if [[ -n "${FORCE_LOG:-}" ]]; then
        return 0
    fi

    # If we're in debug mode, always enable logging
    if [[ "${LOG_LEVEL,,}" == "debug" ]]; then
        return 0
    fi

    # Check if the level is enabled based on current log level
    if [[ "$level_num" -ge "$_CURRENT_LEVEL" ]]; then
        # For non-error logs, check if we should suppress based on TTY
        if [[ "$level_num" -le 2 ]]; then # debug, info, success
            if [[ ! -t "$LOG_NONERROR_FD" && "${FORCE_COLOR:-}" != "true" ]]; then
                return 1
            fi
        else # warning, error, fatal
            if [[ ! -t "$LOG_ERROR_FD" && "${FORCE_COLOR:-}" != "true" ]]; then
                return 1
            fi
        fi
        return 0
    fi

    return 1
}
