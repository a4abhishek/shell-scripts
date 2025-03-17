#!/usr/bin/env bash
set -euo pipefail

# @file polling.sh
# @brief Professional polling library for Bash scripts
# @description
#   This library provides a flexible and configurable polling mechanism
#   for Bash scripts. It follows key software engineering principles:
#   - Separation of concerns: The library handles polling mechanics, while
#     response processing is the responsibility of the client script
#   - DRY: Common polling patterns are abstracted into reusable functions
#   - KISS: Simple API with sensible defaults
#   - Fail Fast: Validates inputs early and provides clear error messages
#   - Open/Closed: Extensible through configuration and callbacks
#
# @usage
#   #!/usr/bin/env bash
#   source "lib/core/polling.sh"
#
#   # Define your callback function that will be called on each poll
#   my_poll_callback() {
#     # Your logic to check status
#     # Return 0 if polling should continue
#     # Return 1 if polling is complete (success)
#     # Return >1 for errors
#   }
#
#   # Basic polling with callback
#   polling_run "Checking status" 5 my_poll_callback
#
#   # Polling with max attempts and timeout
#   polling_run "Checking status" 5 my_poll_callback 10 60
#
#   # Polling with custom countdown configuration
#   polling_run "Checking status" 5 my_poll_callback 10 60 "fill" 40 0.5
#
#   # Run an external command with timeout and custom countdown
#   polling_with_timeout "Running command" 30 my_command arg1 arg2 -- "circle" 50 0.5
#
#   # Check the result
#   if [[ $? -eq 0 ]]; then
#     echo "Polling completed successfully"
#   else
#     echo "Polling failed with status $?"
#   fi
#

# Prevent duplicate sourcing
if [[ -n "${_LIB_POLLING_LOADED:-}" ]]; then return; fi
_LIB_POLLING_LOADED=true

# Save original shell options
_POLLING_ORIGINAL_OPTIONS=$(set +o)

# Source required libraries
CORE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$CORE_LIB_DIR/logging.sh"
# shellcheck source=/dev/null
. "$CORE_LIB_DIR/features.sh"
# shellcheck source=/dev/null
. "$CORE_LIB_DIR/progress.sh"

# Restore original shell options to prevent strict mode from affecting our script
eval "$_POLLING_ORIGINAL_OPTIONS"

# Error codes
declare -gr POLLING_ERR_INVALID_ARGS=1
# Export error codes for external use
export POLLING_ERR_INVALID_NUMBER=2
export POLLING_ERR_CALLBACK_FAILED=3
declare -gr POLLING_ERR_MAX_ATTEMPTS=4
declare -gr POLLING_ERR_TIMEOUT=5
export POLLING_ERR_INTERRUPTED=6
declare -gr POLLING_ERR_UNKNOWN=99

# Polling status codes (for callback functions to return)
declare -gr POLLING_STATUS_CONTINUE=0 # Continue polling
declare -gr POLLING_STATUS_COMPLETE=1 # Polling completed successfully
export POLLING_STATUS_ERROR=2         # Error occurred, stop polling

# Polling states (internal)
declare -gr _POLLING_STATE_INACTIVE=0
declare -gr _POLLING_STATE_ACTIVE=1
declare -gr _POLLING_STATE_COMPLETE=2
declare -gr _POLLING_STATE_ERROR=3

# Global polling state
declare -g _POLLING_STATE=$_POLLING_STATE_INACTIVE
declare -g _POLLING_INTERVAL=5
declare -g _POLLING_MESSAGE=""
declare -g _POLLING_MAX_ATTEMPTS=-1 # -1 means unlimited
declare -g _POLLING_CURRENT_ATTEMPT=0
declare -g _POLLING_COUNTDOWN_STYLE="standard"
declare -g _POLLING_COUNTDOWN_WIDTH=30
declare -g _POLLING_COUNTDOWN_INTERVAL=1
declare -g _POLLING_TIMEOUT=-1 # -1 means no timeout
declare -g _POLLING_START_TIME=0
declare -g _POLLING_LAST_STATUS=0

# ANSI color codes
if [[ "${HAS_COLOR_SUPPORT:-false}" == "true" ]]; then
    declare -gr _POLLING_COLOR_RESET="\033[0m"
    declare -gr _POLLING_COLOR_BLUE="\033[0;34m"
    declare -gr _POLLING_COLOR_GREEN="\033[0;32m"
    declare -gr _POLLING_COLOR_YELLOW="\033[0;33m"
    declare -gr _POLLING_COLOR_CYAN="\033[0;36m"
    declare -gr _POLLING_COLOR_RED="\033[0;31m"
else
    declare -gr _POLLING_COLOR_RESET=""
    declare -gr _POLLING_COLOR_BLUE=""
    declare -gr _POLLING_COLOR_GREEN=""
    declare -gr _POLLING_COLOR_YELLOW=""
    declare -gr _POLLING_COLOR_CYAN=""
    declare -gr _POLLING_COLOR_RED=""
fi

# Constants for fancy mode (Unicode)
if [[ "${HAS_UNICODE_SUPPORT:-false}" == "true" ]]; then
    declare -gr _POLLING_CHECK="✓"
    declare -gr _POLLING_CROSS="✗"
    declare -gr _POLLING_WAITING="⏳"
    declare -gr _POLLING_PROCESSING="⟳"
    declare -gr _POLLING_BAR_START="│"
    declare -gr _POLLING_BAR_END="│"
    declare -gr _POLLING_BAR_FILL="━"
    declare -gr _POLLING_BAR_EMPTY="─"
else
    declare -gr _POLLING_CHECK="+"
    declare -gr _POLLING_CROSS="x"
    declare -gr _POLLING_WAITING="*"
    declare -gr _POLLING_PROCESSING=">"
    declare -gr _POLLING_BAR_START="["
    declare -gr _POLLING_BAR_END="]"
    declare -gr _POLLING_BAR_FILL="#"
    declare -gr _POLLING_BAR_EMPTY="-"
fi

# @function polling_init
# @brief Initialize polling with configuration parameters
# @arg $1 message Message to display during polling
# @arg $2 interval Interval between polls in seconds
# @arg $3 max_attempts Optional maximum number of attempts (-1 for unlimited)
# @arg $4 timeout Optional timeout in seconds (-1 for no timeout)
# @return 0 on success, POLLING_ERR_INVALID_ARGS if arguments are missing
polling_init() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: polling_init <message> <interval> [max_attempts] [timeout]"
        return "$POLLING_ERR_INVALID_ARGS"
    fi

    local message="$1"
    local interval="$2"
    local max_attempts="${3:--1}" # Default to unlimited
    local timeout="${4:--1}"      # Default to no timeout

    # Validate numeric arguments
    if ! [[ "$interval" =~ ^[0-9]+$ ]]; then
        log_error "Invalid interval value: $interval"
        return "$POLLING_ERR_INVALID_ARGS"
    fi

    if ! [[ "$max_attempts" =~ ^-?[0-9]+$ ]]; then
        log_error "Invalid max_attempts value: $max_attempts"
        return "$POLLING_ERR_INVALID_ARGS"
    fi

    if ! [[ "$timeout" =~ ^-?[0-9]+$ ]]; then
        log_error "Invalid timeout value: $timeout"
        return "$POLLING_ERR_INVALID_ARGS"
    fi

    # Initialize polling state
    _POLLING_STATE=$_POLLING_STATE_ACTIVE
    _POLLING_INTERVAL="$interval"
    _POLLING_MESSAGE="$message"
    _POLLING_MAX_ATTEMPTS="$max_attempts"
    _POLLING_TIMEOUT="$timeout"
    _POLLING_CURRENT_ATTEMPT=0
    _POLLING_START_TIME=$(date +%s)
    _POLLING_LAST_STATUS=0

    # Log initialization
    log_info "Polling initialized: $message (interval: ${interval}s, max attempts: $max_attempts, timeout: $timeout)"

    return 0
}

# @function polling_is_active
# @brief Check if polling should continue
# @return 0 if polling should continue, non-zero with appropriate error code otherwise
polling_is_active() {
    # Check if polling is already complete or in error state
    if [[ "$_POLLING_STATE" != "$_POLLING_STATE_ACTIVE" ]]; then
        return "$POLLING_STATUS_COMPLETE"
    fi

    # Check if we've reached max attempts
    if [[ "$_POLLING_MAX_ATTEMPTS" -gt 0 ]] && [[ "$_POLLING_CURRENT_ATTEMPT" -ge "$_POLLING_MAX_ATTEMPTS" ]]; then
        log_warning "Reached maximum polling attempts ($_POLLING_MAX_ATTEMPTS)"
        _POLLING_STATE=$_POLLING_STATE_ERROR
        return "$POLLING_ERR_MAX_ATTEMPTS"
    fi

    # Check if we've exceeded timeout
    if [[ "$_POLLING_TIMEOUT" -gt 0 ]]; then
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - _POLLING_START_TIME))

        if ((elapsed >= _POLLING_TIMEOUT)); then
            log_warning "Polling timed out after ${elapsed}s (timeout: ${_POLLING_TIMEOUT}s)"
            _POLLING_STATE=$_POLLING_STATE_ERROR
            return "$POLLING_ERR_TIMEOUT"
        fi
    fi

    return 0
}

# @function polling_wait
# @brief Wait for the next polling interval with visual feedback
# @arg $1 message Optional message to display during waiting
# @return 0 on success
polling_wait() {
    local message="${1:-$_POLLING_MESSAGE}"

    # Increment attempt counter
    ((_POLLING_CURRENT_ATTEMPT++))

    # Update message if provided
    if [[ -n "$message" ]]; then
        _POLLING_MESSAGE="$message"
    fi

    # Show waiting message
    log_info "Waiting ${_POLLING_INTERVAL}s before next poll (attempt $_POLLING_CURRENT_ATTEMPT)"

    # Use countdown timer with configured settings
    if type countdown_timer &> /dev/null; then
        # Use set +e to prevent script from exiting if countdown_timer fails
        set +e
        countdown_timer "$_POLLING_INTERVAL" "Waiting for next poll" "$_POLLING_COUNTDOWN_STYLE" "$_POLLING_COUNTDOWN_WIDTH" "$_POLLING_COUNTDOWN_INTERVAL"
        local status=$?
        set -e

        # If countdown_timer failed, use simple sleep
        if [[ $status -ne 0 ]]; then
            log_debug "Countdown timer failed, using simple sleep"
            sleep "$_POLLING_INTERVAL"
        fi
    else
        # Fallback to simple sleep if countdown_timer is not available
        log_debug "Countdown timer not available, using simple sleep"
        sleep "$_POLLING_INTERVAL"
    fi

    return 0
}

# @function polling_complete
# @brief Mark polling as complete
# @arg $1 message Optional success message
# @return 0 on success
polling_complete() {
    local message="${1:-$_POLLING_MESSAGE}"

    # Update state
    _POLLING_STATE=$_POLLING_STATE_COMPLETE

    # Show success message
    log_success "$message"

    log_info "Polling completed successfully after $_POLLING_CURRENT_ATTEMPT attempts"

    return 0
}

# @function polling_error
# @brief Mark polling as failed
# @arg $1 message Optional error message
# @arg $2 error_code Optional error code (default: POLLING_ERR_UNKNOWN)
# @return The provided error code
polling_error() {
    local message="${1:-$_POLLING_MESSAGE}"
    local error_code="${2:-$POLLING_ERR_UNKNOWN}"

    # Update state
    _POLLING_STATE=$_POLLING_STATE_ERROR

    # Show error message
    log_error "$message"

    log_error "Polling failed after $_POLLING_CURRENT_ATTEMPT attempts with error code $error_code"

    return "$error_code"
}

# @function polling_get_attempt
# @brief Get the current attempt number
# @return Current attempt number
polling_get_attempt() {
    echo "$_POLLING_CURRENT_ATTEMPT"
}

# @function polling_get_elapsed_time
# @brief Get the elapsed time since polling started (in seconds)
# @return Elapsed time in seconds
polling_get_elapsed_time() {
    local current_time
    current_time=$(date +%s)
    echo $((current_time - _POLLING_START_TIME))
}

# @function polling_reset
# @brief Reset polling state
# @return 0 on success
polling_reset() {
    _POLLING_STATE=$_POLLING_STATE_INACTIVE
    _POLLING_INTERVAL=5
    _POLLING_MESSAGE=""
    _POLLING_MAX_ATTEMPTS=-1
    _POLLING_TIMEOUT=-1
    _POLLING_CURRENT_ATTEMPT=0
    _POLLING_COUNTDOWN_STYLE="standard"
    _POLLING_COUNTDOWN_WIDTH=30
    _POLLING_COUNTDOWN_INTERVAL=1
    _POLLING_START_TIME=0
    _POLLING_LAST_STATUS=0

    return 0
}

# @function polling_run
# @brief Run a complete polling operation with a callback function
# @arg $1 message Message to display during polling
# @arg $2 interval Interval between polls in seconds
# @arg $3 callback Function to call for each poll attempt
# @arg $4 max_attempts Optional maximum number of attempts (-1 for unlimited)
# @arg $5 timeout Optional timeout in seconds (-1 for no timeout)
# @arg $6 countdown_style Optional style for countdown (standard, fill, circle, square, clock, moon, blocks)
# @arg $7 countdown_width Optional width for countdown bar
# @arg $8 countdown_interval Optional interval for countdown updates
# @return 0 on success, non-zero on error
polling_run() {
    if [[ $# -lt 3 ]]; then
        log_error "Usage: polling_run <message> <interval> <callback> [max_attempts] [timeout] [countdown_style] [countdown_width] [countdown_interval]"
        return "$POLLING_ERR_INVALID_ARGS"
    fi

    local message="$1"
    local interval="$2"
    local callback="$3"
    local max_attempts="${4:--1}"
    local timeout="${5:--1}"
    local countdown_style="${6:-standard}"
    local countdown_width="${7:-30}"
    local countdown_interval="${8:-1}"

    # Validate callback is a function
    if ! declare -F "$callback" > /dev/null; then
        log_error "Callback '$callback' is not a valid function"
        return "$POLLING_ERR_INVALID_ARGS"
    fi

    # Initialize polling
    polling_init "$message" "$interval" "$max_attempts" "$timeout"

    # Configure countdown if non-default values are provided
    if [[ "$countdown_style" != "standard" || "$countdown_width" != "30" || "$countdown_interval" != "1" ]]; then
        _POLLING_COUNTDOWN_STYLE="$countdown_style"
        _POLLING_COUNTDOWN_WIDTH="$countdown_width"
        _POLLING_COUNTDOWN_INTERVAL="$countdown_interval"
        log_debug "Countdown configured: style=$countdown_style, width=$countdown_width, interval=$countdown_interval"
    fi

    # Main polling loop
    while polling_is_active; do
        # Call the callback function
        local status

        # Use set +e to prevent script from exiting if callback fails
        set +e
        "$callback"
        status=$?
        set -e

        _POLLING_LAST_STATUS=$status

        # Process the callback status
        case $status in
            "$POLLING_STATUS_CONTINUE")
                # Continue polling
                ;;
            "$POLLING_STATUS_COMPLETE")
                # Polling completed successfully
                polling_complete "$message completed successfully"
                return 0
                ;;
            *)
                # Error occurred
                polling_error "$message failed with status $status" "$status"
                return "$status"
                ;;
        esac

        # Wait for next poll
        polling_wait
    done

    # If we get here, polling_is_active returned non-zero
    # Return the last status code from polling_is_active
    return "$?"
}

# @function polling_get_last_status
# @brief Get the status code from the last callback execution
# @return Last status code
polling_get_last_status() {
    echo "$_POLLING_LAST_STATUS"
}

# @function polling_with_timeout
# @brief Run a command with timeout and polling
# @arg $1 message Message to display during polling
# @arg $2 timeout Timeout in seconds
# @arg $3 command Command to run
# @arg $4... Additional arguments for the command
# @arg $-3 countdown_style Optional style for countdown (standard, fill, circle, square, clock, moon, blocks)
# @arg $-2 countdown_width Optional width for countdown bar
# @arg $-1 countdown_interval Optional interval for countdown updates
# @return 0 on success, non-zero on error
polling_with_timeout() {
    if [[ $# -lt 3 ]]; then
        log_error "Usage: polling_with_timeout <message> <timeout> <command> [args...] [-- countdown_style countdown_width countdown_interval]"
        return "$POLLING_ERR_INVALID_ARGS"
    fi

    local message="$1"
    local timeout="$2"
    local command="$3"
    shift 3

    # Default countdown values
    local countdown_style="standard"
    local countdown_width=30
    local countdown_interval=1

    # Check if we have countdown configuration
    local args=()
    local found_separator=false

    for arg in "$@"; do
        if [[ "$arg" == "--" ]]; then
            found_separator=true
            break
        fi
        args+=("$arg")
    done

    # If we found the separator, extract countdown configuration
    if [[ "$found_separator" == "true" ]]; then
        # Remove all arguments up to and including the separator
        shift ${#args[@]}
        shift 1 # Remove the separator

        # Get countdown configuration
        if [[ $# -ge 1 ]]; then
            countdown_style="$1"
            shift
        fi
        if [[ $# -ge 1 ]]; then
            countdown_width="$1"
            shift
        fi
        if [[ $# -ge 1 ]]; then
            countdown_interval="$1"
        fi
    else
        # No separator found, all arguments are for the command
        args=("$@")
    fi

    # Create a temporary file for the command output
    local tmp_file
    tmp_file=$(mktemp)

    # Run the command in the background
    "$command" "${args[@]}" > "$tmp_file" 2>&1 &
    local pid=$!

    # Set global variables for the check function
    _POLLING_WITH_TIMEOUT_PID=$pid
    _POLLING_WITH_TIMEOUT_TMP_FILE=$tmp_file

    # Run polling with countdown configuration
    polling_run "$message" 1 _polling_check_process_status -1 "$timeout" "$countdown_style" "$countdown_width" "$countdown_interval"
    local status=$?

    # Clean up
    rm -f "$tmp_file"
    unset _POLLING_WITH_TIMEOUT_PID
    unset _POLLING_WITH_TIMEOUT_TMP_FILE

    return "$status"
}

# Global variables for polling_with_timeout
declare -g _POLLING_WITH_TIMEOUT_PID=""
declare -g _POLLING_WITH_TIMEOUT_TMP_FILE=""

# @function _polling_check_process_status
# @brief Internal callback function for polling_with_timeout
# @return Status code based on process state
_polling_check_process_status() {
    # Check if the process is still running
    if kill -0 "$_POLLING_WITH_TIMEOUT_PID" 2> /dev/null; then
        # Process is still running, continue polling
        return "$POLLING_STATUS_CONTINUE"
    else
        # Process has finished, check exit status
        wait "$_POLLING_WITH_TIMEOUT_PID"
        local status=$?

        if [[ $status -eq 0 ]]; then
            # Command completed successfully
            return "$POLLING_STATUS_COMPLETE"
        else
            # Command failed
            log_error "Command failed with status $status"
            log_error "Command output:"
            cat "$_POLLING_WITH_TIMEOUT_TMP_FILE"
            return "$status"
        fi
    fi
}
