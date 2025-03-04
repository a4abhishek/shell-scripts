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
# - When LOG_LEVEL=debug is set, all level based logs are shown regardless of terminal or redirection
# - Non-error logs (debug, info, success) are written to LOG_NONERROR_FD (default: stdout)
# - Error logs (warning, error, fatal) are written to LOG_ERROR_FD (default: stderr)
# - You can use log with a custom prefix, label, timestamp format, message, output FD, and color code.
#
# Log levels (from lowest to highest priority):
# - debug   : Detailed information for debugging
# - info    : General information about script progress
# - success : Successful completion of a task
# - warning : Potential issues that don't stop execution
# - error   : Error conditions that may stop execution
# - fatal   : Critical errors that will stop execution
#
#
# Function Usage:
#   log <prefix> <label> <timestamp_format> <message> <output_fd> <color_code>
#
# Examples:
#   log_info "This is an informational message."  # Uses predefined level-based logging.
#   log ">>" "CUSTOM" "%H:%M:%S" "My custom message." "" "\033[1;34m"  # Custom message with blue color.
#   log "" "" "" "Message with no prefix, label, or timestamp." # Only message
#   LOG_LEVEL=warning ./script.sh   # Only show warnings and errors.
#   LOG_LEVEL=debug ./script.sh    # Show all level-based log messages.
#   LOG_NONERROR_FD=3 ./script.sh 3> info.log   # Redirect non-error logs.
#   LOG_ERROR_FD=4 ./script.sh 4> error.log      # Redirect error logs.
#   FORCE_COLOR=true ./script.sh  # Force color output, even if not a TTY.
#   NO_COLOR=true ./script.sh     # Disable color output.

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

# Default log output to stdout (fd 1) for informational messages.
LOG_NONERROR_FD="${LOG_NONERROR_FD:-1}"
# Default log output to stderr (fd 2) for error messages.
LOG_ERROR_FD="${LOG_ERROR_FD:-2}"

# Default timestamp format for logging
_DEFAULT_TIMESTAMP_FORMAT="%Y-%m-%d %H:%M:%S"

# Initialize color variables (will be populated in _detect_terminal_capabilities)
declare _COLOR_DEBUG=""
declare _COLOR_INFO=""
declare _COLOR_SUCCESS=""
declare _COLOR_WARNING=""
declare _COLOR_ERROR=""
declare _COLOR_FATAL=""
declare _COLOR_RESET=""

_detect_terminal_capabilities() {
    # Allow test override, but NO_COLOR takes precedence
    if [[ -n "${NO_COLOR:-}" ]]; then
        export HAS_COLOR_SUPPORT=false
    elif [[ -n "${FORCE_COLOR:-}" ]]; then
        export HAS_COLOR_SUPPORT=true
    else
        export HAS_COLOR_SUPPORT=true # Default to color support if a TTY
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

    # Define color codes if color support is enabled
    if [[ "${HAS_COLOR_SUPPORT:-false}" == "true" ]]; then
        _COLOR_DEBUG="\033[1;34m"   # Bold Blue
        _COLOR_INFO="\033[1;32m"    # Bold Green
        _COLOR_SUCCESS="\033[1;32m" # Bold Green
        _COLOR_WARNING="\033[1;33m" # Bold Yellow
        _COLOR_ERROR="\033[1;31m"   # Bold Red
        _COLOR_FATAL="\033[1;31m"   # Bold Red
        _COLOR_RESET="\033[0m"
    fi
}

# Function to reinitialize terminal capabilities (useful for testing)
reinit_terminal_capabilities() {
    _detect_terminal_capabilities
}

# Initialize terminal capabilities
_detect_terminal_capabilities

# Generic logging function.  Takes ALL formatting parameters.
log() {
    local prefix="${1:-}"
    local label="${2:-}"
    local timestamp_format="${3:-}"
    local message="$4"
    local output_fd="${5:-1}" # Default to stdout
    local color_code="${6:-}"
    local color_reset="${7:-}" # Default color reset
    if [[ -n "$color_code" && -z "$color_reset" ]]; then
        color_reset="$_COLOR_RESET"
    fi

    # Check if output should be generated (TTY check and FORCE_COLOR)
    if [[ -t "$output_fd" ]] || [[ "${FORCE_COLOR:-}" == "true" ]]; then
        local timestamp=""
        # Only generate timestamp if format is provided
        if [[ -n "$timestamp_format" ]]; then
            timestamp="$(date "+$timestamp_format")"
            timestamp="[$timestamp]"
        fi

        while IFS= read -r line || [[ -n "$line" ]]; do
            printf "%s %s %s %b%b%b\n" \
                "$prefix" "$label" "$timestamp" "$color_code" "$line" "$color_reset" >&"$output_fd"
        done <<< "$message"
    fi
}

# Internal function for level-based logging
_leveled_log() {
    local level="$1"
    local message="$2"
    local level_num="${_LOG_LEVELS[${level,,}]:-1}"

    # Determine output FD and other parameters based on level
    local output_fd
    case "$level" in
        debug | info | success)
            output_fd="$LOG_NONERROR_FD"
            ;;
        warning | error | fatal)
            output_fd="$LOG_ERROR_FD"
            ;;
        *)                            # Unknown level - should not happen with _leveled_log
            output_fd="$LOG_ERROR_FD" # Default to stderr
            ;;
    esac

    # Check if logging is enabled for this level
    if [[ "${LOG_LEVEL,,}" == "debug" ]] || [[ $level_num -ge $_CURRENT_LEVEL ]]; then
        local symbol="${_SYMBOLS[${level,,}]}"
        local color_var="_COLOR_${level^^}"
        local color_code="${!color_var}" #Indirect variable
        # Call the generic log function
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
    local exit_code="${2:-1}" # Default to exit code 1 if not provided

    _leveled_log "fatal" "$message"
    exit "$exit_code"
}

# Check if logging is enabled for a given level.  (Still useful for external scripts)
log_is_enabled() {
    local level="$1"
    local level_num="${_LOG_LEVELS[${level,,}]:-1}"
    # Check if the corresponding FD is a TTY *before* doing expensive checks
    local output_fd
    case "$level" in
        debug | info | success)
            output_fd="$LOG_NONERROR_FD"
            ;;
        warning | error | fatal)
            output_fd="$LOG_ERROR_FD"
            ;;
        *)                               # Handle potentially empty level
            output_fd="$LOG_NONERROR_FD" # Default to stdout
            ;;
    esac
    { [[ -t "$output_fd" ]] || [[ "${FORCE_COLOR:-}" == "true" ]]; } && { [[ "${LOG_LEVEL,,}" == "debug" ]] || [[ "$level_num" -ge "$_CURRENT_LEVEL" ]]; }
}
