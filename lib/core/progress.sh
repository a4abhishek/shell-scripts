#!/usr/bin/env bash
#
# @file progress.sh
# @brief Professional progress & loader library for Bash scripts
# @description
#   This library provides several functions for displaying progress indicators
#   in Bash scripts. It includes:
#
#     • A spinner (rotating loader) that you can start and stop.
#     • A progress bar that updates in place given a current value and total.
#     • A "loader_run" function that runs a command while showing a spinner.
#
# @usage
#   #!/usr/bin/env bash
#   source "lib/core/progress.sh"
#
#   # To display a spinner:
#   spinner_start
#   # ... do some work ...
#   spinner_stop
#
#   # To show a progress bar (call repeatedly as work advances):
#   progress_bar 30 100   # for example, 30 of 100 done
#
#   # To run a command with an animated loader:
#   loader_run "Processing" your_command arg1 arg2
#
# @examples
#
# Example 1: Simple Spinner
#   spinner_start
#   sleep 3
#   spinner_stop
#
# Example 2: Progress Bar
#   total=100
#   for ((i=1; i<=total; i++)); do
#       progress_bar "$i" "$total"
#       sleep 0.1
#   done
#
# Example 3: Loader Run
#   loader_run "Executing task" sleep 5
#
# Note:
#   This library prints to stdout (for spinner and progress bar) using \r to update
#   the same line. If you need to log progress elsewhere, you may want to redirect output.
#
# Note:
#   For polling functionality, please use the polling.sh library.
#

# Prevent duplicate sourcing
if [[ -n "${_LIB_PROGRESS_LOADED:-}" ]]; then return; fi
_LIB_PROGRESS_LOADED=true

# Ensure script stops on errors and propagates failures properly.
set -euo pipefail

# Source required libraries
CORE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$CORE_LIB_DIR/logging.sh"
# shellcheck source=/dev/null
. "$CORE_LIB_DIR/preflight.sh"
# shellcheck source=/dev/null
. "$CORE_LIB_DIR/features.sh"

# Error codes
declare -gr ERR_INVALID_ARGS=1
declare -gr ERR_INVALID_NUMBER=2
declare -gr ERR_PROCESS_NOT_FOUND=3

# Global state (protected in our namespace)
declare -g _LIB_PROGRESS_SPINNER_PID=""
declare -g _LIB_PROGRESS_LAST_MSG=""
declare -g _LIB_PROGRESS_CURRENT_MSG=""

# ANSI color codes
if [[ "${HAS_COLOR_SUPPORT:-false}" == "true" ]]; then
    declare -gr _LIB_PROGRESS_COLOR_RESET="\033[0m"
    declare -gr _LIB_PROGRESS_COLOR_BLUE="\033[0;34m"
    declare -gr _LIB_PROGRESS_COLOR_GREEN="\033[0;32m"
    declare -gr _LIB_PROGRESS_COLOR_YELLOW="\033[0;33m"
    declare -gr _LIB_PROGRESS_COLOR_CYAN="\033[0;36m"
    declare -gr _LIB_PROGRESS_COLOR_RED="\033[0;31m"
    declare -gr _LIB_PROGRESS_BLINK="\033[5m"
else
    declare -gr _LIB_PROGRESS_COLOR_RESET=""
    declare -gr _LIB_PROGRESS_COLOR_BLUE=""
    declare -gr _LIB_PROGRESS_COLOR_GREEN=""
    declare -gr _LIB_PROGRESS_COLOR_YELLOW=""
    declare -gr _LIB_PROGRESS_COLOR_CYAN=""
    declare -gr _LIB_PROGRESS_COLOR_RED=""
    declare -gr _LIB_PROGRESS_BLINK=""
fi

# Constants for fancy mode (Unicode)
if [[ "${HAS_UNICODE_SUPPORT:-false}" == "true" ]]; then
    declare -gr _LIB_PROGRESS_SPINNER_CHARS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    declare -gr _LIB_PROGRESS_BAR_START="│"
    declare -gr _LIB_PROGRESS_BAR_END="│"
    declare -gr _LIB_PROGRESS_BAR_FILL="━"
    declare -gr _LIB_PROGRESS_BAR_EMPTY="─"
    declare -gr _LIB_PROGRESS_CHECK="✓"
    declare -gr _LIB_PROGRESS_CROSS="✗"
else
    declare -gr _LIB_PROGRESS_SPINNER_CHARS=("-" "\\" "|" "/")
    declare -gr _LIB_PROGRESS_BAR_START="["
    declare -gr _LIB_PROGRESS_BAR_END="]"
    declare -gr _LIB_PROGRESS_BAR_FILL="#"
    declare -gr _LIB_PROGRESS_BAR_EMPTY="-"
    declare -gr _LIB_PROGRESS_CHECK="+"
    declare -gr _LIB_PROGRESS_CROSS="x"
fi

# Progress/Countdown styles
if [[ "${HAS_UNICODE_SUPPORT:-false}" == "true" ]]; then
    # Shared styles for both progress and countdown
    declare -gr _LIB_PROGRESS_STYLE_CIRCLE=("⓿" "❶" "❷" "❸" "❹" "❺" "❻" "❼" "❽" "❾" "❿")
    declare -gr _LIB_PROGRESS_STYLE_SQUARE=("⬜" "▣" "▣" "▣" "▣" "▣" "▣" "▣" "▣" "▣" "▣")
    declare -gr _LIB_PROGRESS_STYLE_FILL=("□□□□□□□□□□" "■□□□□□□□□□" "■■□□□□□□□□" "■■■□□□□□□□" "■■■■□□□□□□" "■■■■■□□□□□" "■■■■■■□□□□" "■■■■■■■□□□" "■■■■■■■■□□" "■■■■■■■■■□" "■■■■■■■■■■")
    declare -gr _LIB_PROGRESS_STYLE_CLOCK=("🕛" "🕐" "🕑" "🕒" "🕓" "🕔" "🕕" "🕖" "🕗" "🕘" "🕙" "🕚")
    declare -gr _LIB_PROGRESS_STYLE_MOON=("🌘" "🌗" "🌖" "🌕" "🌔" "🌓" "🌒" "🌑")
    declare -gr _LIB_PROGRESS_STYLE_BLOCKS=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")

    # For backward compatibility - these will be deprecated
    declare -gr _LIB_PROGRESS_STYLE_EMPTY=("${_LIB_PROGRESS_STYLE_FILL[@]}")
    declare -gr _LIB_PROGRESS_STYLE_COUNTER_CLOCK=("${_LIB_PROGRESS_STYLE_CLOCK[@]}")
    declare -gr _LIB_PROGRESS_STYLE_MOON_REVERSE=("${_LIB_PROGRESS_STYLE_MOON[@]}")
    declare -gr _LIB_PROGRESS_STYLE_BLOCKS_REVERSE=("${_LIB_PROGRESS_STYLE_BLOCKS[@]}")
else
    # ASCII fallbacks
    declare -gr _LIB_PROGRESS_STYLE_CIRCLE=("0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "10")
    declare -gr _LIB_PROGRESS_STYLE_SQUARE=("[ ]" "[#]" "[#]" "[#]" "[#]" "[#]" "[#]" "[#]" "[#]" "[#]" "[#]")
    declare -gr _LIB_PROGRESS_STYLE_FILL=("[          ]" "[#         ]" "[##        ]" "[###       ]" "[####      ]" "[#####     ]" "[######    ]" "[#######   ]" "[########  ]" "[######### ]" "[##########]")
    declare -gr _LIB_PROGRESS_STYLE_CLOCK=("(12)" "(1)" "(2)" "(3)" "(4)" "(5)" "(6)" "(7)" "(8)" "(9)" "(10)" "(11)")
    declare -gr _LIB_PROGRESS_STYLE_MOON=("(0)" "(1)" "(2)" "(3)" "(4)" "(3)" "(2)" "(1)")
    declare -gr _LIB_PROGRESS_STYLE_BLOCKS=("_" "^" "^" "|" "|" "#" "#" "#")

    # For backward compatibility - these will be deprecated
    declare -gr _LIB_PROGRESS_STYLE_EMPTY=("${_LIB_PROGRESS_STYLE_FILL[@]}")
    declare -gr _LIB_PROGRESS_STYLE_COUNTER_CLOCK=("${_LIB_PROGRESS_STYLE_CLOCK[@]}")
    declare -gr _LIB_PROGRESS_STYLE_MOON_REVERSE=("${_LIB_PROGRESS_STYLE_MOON[@]}")
    declare -gr _LIB_PROGRESS_STYLE_BLOCKS_REVERSE=("${_LIB_PROGRESS_STYLE_BLOCKS[@]}")
fi

# Define style aliases for backward compatibility
declare -gr _LIB_PROGRESS_STYLE_ALIASES=(
    "empty:fill:true"            # empty is fill with reverse=true
    "counter_clock:clock:true"   # counter_clock is clock with reverse=true
    "moon_reverse:moon:true"     # moon_reverse is moon with reverse=true
    "blocks_reverse:blocks:true" # blocks_reverse is blocks with reverse=true
)

declare -gr _LIB_PROGRESS_SPINNER_DELAY=0.1
declare -gr _LIB_PROGRESS_DEFAULT_BAR_WIDTH=30

# Clear the current line and move cursor to start
_clear_line() {
    printf "\r%-${COLUMNS:-80}s\r" ""
}

# Format text with color if supported
_format_text() {
    local color="$1"
    local text="$2"
    local blink="${3:-false}"
    if [[ "${HAS_COLOR_SUPPORT:-false}" == "true" ]]; then
        if [[ "$blink" == "true" ]]; then
            echo -en "${color}${_LIB_PROGRESS_BLINK}${text}${_LIB_PROGRESS_COLOR_RESET}"
        else
            echo -en "${color}${text}${_LIB_PROGRESS_COLOR_RESET}"
        fi
    else
        echo -n "$text"
    fi
}

# Preflight check for required commands
_check_required_commands() {
    local cmds=("printf" "sleep" "kill")
    for cmd in "${cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command not found: $cmd"
            return 1
        fi
    done
    return 0
}

register_preflight _check_required_commands

# @function spinner_start
# @brief Starts an animated spinner in the background
# @description Displays a rotating spinner animation that updates in place
# @return 0 on success, ERR_PROCESS_NOT_FOUND if spinner process cannot be started
spinner_start() {
    # If spinner is already running, stop it first
    spinner_stop

    # Start a background loop that prints spinner characters in place
    (
        while :; do
            for char in "${_LIB_PROGRESS_SPINNER_CHARS[@]}"; do
                _clear_line
                _format_text "$_LIB_PROGRESS_COLOR_CYAN" "  $char "
                if [[ -n "${_LIB_PROGRESS_CURRENT_MSG:-}" ]]; then
                    _format_text "$_LIB_PROGRESS_COLOR_CYAN" "${_LIB_PROGRESS_CURRENT_MSG}"
                    _format_text "$_LIB_PROGRESS_COLOR_CYAN" "..." "true"
                fi
                sleep "$_LIB_PROGRESS_SPINNER_DELAY"
            done
        done
    ) &

    _LIB_PROGRESS_SPINNER_PID=$!

    # Verify the process started
    if ! kill -0 "$_LIB_PROGRESS_SPINNER_PID" 2> /dev/null; then
        log_error "Failed to start spinner process"
        return "$ERR_PROCESS_NOT_FOUND"
    fi
}

# @function spinner_stop
# @brief Stops the spinner and cleans up
# @description Stops the spinner animation and cleans up the display
# @return 0 on success
spinner_stop() {
    if [[ -n "$_LIB_PROGRESS_SPINNER_PID" ]]; then
        kill "$_LIB_PROGRESS_SPINNER_PID" &> /dev/null || true
        _LIB_PROGRESS_SPINNER_PID=""
        _clear_line
    fi
    return 0
}

# @function progress_bar
# @brief Displays a progress bar with percentage
# @arg $1 current Current progress value
# @arg $2 total Total value for 100% progress
# @arg $3 message Optional message to display before the progress bar
# @arg $4 bar_width Optional width of the progress bar (default: 30)
# @arg $5 style Optional style (default: standard, options: standard, fill, empty, circle, square, clock, moon, blocks)
# @arg $6 reverse Optional flag to reverse the direction (default: false)
# @return 0 on success, ERR_INVALID_ARGS if arguments are missing, ERR_INVALID_NUMBER if arguments are not numbers
progress_bar() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: progress_bar <current> <total> [message] [bar_width] [style] [reverse]"
        return "$ERR_INVALID_ARGS"
    fi

    local current="$1"
    local total="$2"
    local message="${3:-}"
    local bar_width="${4:-$_LIB_PROGRESS_DEFAULT_BAR_WIDTH}"
    local style="${5:-standard}"
    local reverse="${6:-false}"

    # Handle style aliases for backward compatibility
    for alias in "${_LIB_PROGRESS_STYLE_ALIASES[@]}"; do
        local alias_name="${alias%%:*}"
        local real_style="${alias#*:}"
        real_style="${real_style%:*}"
        local alias_reverse="${alias##*:}"

        if [[ "$style" == "$alias_name" ]]; then
            style="$real_style"
            # Only override reverse if it wasn't explicitly set
            if [[ "$reverse" == "false" ]]; then
                reverse="$alias_reverse"
            else
                # If reverse was explicitly set to true and the alias also has reverse=true,
                # they cancel each other out
                if [[ "$alias_reverse" == "true" && "$reverse" == "true" ]]; then
                    reverse="false"
                fi
            fi
            break
        fi
    done

    # Validate numeric arguments
    if ! [[ "$current" =~ ^-?[0-9]+$ && "$total" =~ ^-?[0-9]+$ ]]; then
        log_error "Invalid numeric value"
        return "$ERR_INVALID_NUMBER"
    fi

    # Compute progress percentage
    local percent=$((current * 100 / total))

    # Choose color based on progress
    local color="$_LIB_PROGRESS_COLOR_YELLOW"
    if ((percent >= 100)); then
        color="$_LIB_PROGRESS_COLOR_GREEN"
    elif ((percent >= 50)); then
        color="$_LIB_PROGRESS_COLOR_BLUE"
    fi

    # For countdown styles, reverse the color logic
    if [[ "$reverse" == "true" ]]; then
        if ((percent >= 75)); then
            color="$_LIB_PROGRESS_COLOR_CYAN"
        elif ((percent >= 50)); then
            color="$_LIB_PROGRESS_COLOR_YELLOW"
        elif ((percent >= 25)); then
            color="$_LIB_PROGRESS_COLOR_BLUE"
        else
            color="$_LIB_PROGRESS_COLOR_GREEN"
        fi
    fi

    # Handle different styles
    case "$style" in
        standard)
            # Standard progress bar
            local progress=$((current * bar_width / total))
            local bar=""
            local i

            # Build the bar string
            for ((i = 0; i < bar_width; i++)); do
                if [[ "$reverse" == "true" ]]; then
                    # Reverse fill (emptying)
                    if ((i < bar_width - progress)); then
                        bar+="$_LIB_PROGRESS_BAR_FILL"
                    else
                        bar+="$_LIB_PROGRESS_BAR_EMPTY"
                    fi
                else
                    # Normal fill
                    if ((i < progress)); then
                        bar+="$_LIB_PROGRESS_BAR_FILL"
                    else
                        bar+="$_LIB_PROGRESS_BAR_EMPTY"
                    fi
                fi
            done

            # Print the progress bar
            _clear_line
            if [[ -n "$message" ]]; then
                _format_text "$_LIB_PROGRESS_COLOR_CYAN" "$message "
            fi
            printf "%s" "$_LIB_PROGRESS_BAR_START"
            _format_text "$color" "$bar"
            printf "%s " "$_LIB_PROGRESS_BAR_END"
            _format_text "$color" "$percent"
            printf "%%"
            ;;

        fill | empty | square | circle)
            # Styles that use predefined arrays
            local style_array=()

            case "$style" in
                fill | empty)
                    style_array=("${_LIB_PROGRESS_STYLE_FILL[@]}")
                    ;;
                square)
                    style_array=("${_LIB_PROGRESS_STYLE_SQUARE[@]}")
                    ;;
                circle)
                    style_array=("${_LIB_PROGRESS_STYLE_CIRCLE[@]}")
                    ;;
            esac

            # Calculate index based on progress
            local total_steps=${#style_array[@]}
            local index=$((percent * (total_steps - 1) / 100))

            # Handle reversal for non-reversed styles
            if [[ "$reverse" == "true" ]]; then
                index=$(((total_steps - 1) - index))
            fi

            if ((index >= total_steps)); then
                index=$((total_steps - 1))
            fi

            # Print the progress indicator
            _clear_line
            if [[ -n "$message" ]]; then
                _format_text "$_LIB_PROGRESS_COLOR_CYAN" "$message "
            fi

            _format_text "$color" "${style_array[$index]}"
            printf " "
            _format_text "$color" "$percent"
            printf "%%"
            ;;

        clock | moon | blocks)
            # Styles that use continuous rotation
            local style_array=()
            local should_reverse=false

            # Determine if we need to reverse the index calculation
            # For styles that are already reversed, applying reverse again should cancel out
            if [[ "$reverse" == "true" ]]; then
                should_reverse=true
            fi

            case "$style" in
                clock)
                    style_array=("${_LIB_PROGRESS_STYLE_CLOCK[@]}")
                    ;;
                moon)
                    style_array=("${_LIB_PROGRESS_STYLE_MOON[@]}")
                    ;;
                blocks)
                    style_array=("${_LIB_PROGRESS_STYLE_BLOCKS[@]}")
                    ;;
            esac

            # Calculate index based on progress for continuous rotation
            local total_steps=${#style_array[@]}
            local index=$((percent * total_steps / 100 % total_steps))

            # Apply reversal if needed
            if [[ "$should_reverse" == "true" ]]; then
                index=$(((total_steps - 1) - (index % total_steps)))
            fi

            # Print the progress indicator
            _clear_line
            if [[ -n "$message" ]]; then
                _format_text "$_LIB_PROGRESS_COLOR_CYAN" "$message "
            fi

            _format_text "$color" "${style_array[$index]}"
            printf " "
            _format_text "$color" "$percent"
            printf "%%"
            ;;

        *)
            log_error "Invalid style: $style"
            return "$ERR_INVALID_ARGS"
            ;;
    esac

    # When finished, print a newline
    if ((current >= total)); then
        echo
        echo
    fi

    return 0
}

# @function show_progress
# @brief Shows a progress bar for a task with proper buffering and formatting
# @arg $1 current Current progress value
# @arg $2 total Total value for 100% progress
# @arg $3 message Optional message to display before the progress bar
# @arg $4 bar_width Optional width of the progress bar (default: 30)
# @arg $5 style Optional style (default: standard, options: standard, fill, empty, circle, square, clock, moon, blocks)
# @arg $6 reverse Optional flag to reverse the direction (default: false)
# @return 0 on success, ERR_INVALID_ARGS if arguments are missing
show_progress() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: show_progress <current> <total> [message] [bar_width] [style] [reverse]"
        return "$ERR_INVALID_ARGS"
    fi

    # Force stdout to be unbuffered if stdbuf is available
    if command -v stdbuf &> /dev/null; then
        stdbuf -o0 printf ""
    fi

    # Show progress bar
    progress_bar "$@"

    # Force flush if at 100%
    local current="$1"
    local total="$2"
    if ((current >= total)); then
        printf "" >&2
    fi
}

# @function loader_run
# @brief Runs a command while displaying a spinner
# @arg $1 message Message to display while running the command
# @arg $2... command and arguments to run
# @return Command's exit status
loader_run() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: loader_run <message> <command> [args...]"
        return "$ERR_INVALID_ARGS"
    fi

    local message="$1"
    shift

    # Save message for potential error handling
    _LIB_PROGRESS_LAST_MSG="$message"
    _LIB_PROGRESS_CURRENT_MSG="$message"

    spinner_start
    "$@"
    local ret=$?
    spinner_stop
    _LIB_PROGRESS_CURRENT_MSG=""

    _clear_line
    if ((ret == 0)); then
        _format_text "$_LIB_PROGRESS_COLOR_GREEN" "$_LIB_PROGRESS_CHECK "
        _format_text "$_LIB_PROGRESS_COLOR_GREEN" "$message"
    else
        _format_text "$_LIB_PROGRESS_COLOR_RED" "$_LIB_PROGRESS_CROSS "
        _format_text "$_LIB_PROGRESS_COLOR_RED" "$message"
    fi
    echo
    return $ret
}

# @function loader_wait
# @brief Shows a loading message until the given background process finishes
# @arg $1 message Message to display while waiting
# @arg $2 pid Process ID to wait for
# @return Process's exit status
loader_wait() {
    if [[ $# -ne 2 ]]; then
        log_error "Usage: loader_wait <message> <pid>"
        return "$ERR_INVALID_ARGS"
    fi

    local message="$1"
    local pid="$2"

    # Validate PID
    if ! kill -0 "$pid" 2> /dev/null; then
        log_error "Invalid or non-existent process ID: $pid"
        return "$ERR_PROCESS_NOT_FOUND"
    fi

    # Save message for potential error handling
    _LIB_PROGRESS_LAST_MSG="$message"
    _LIB_PROGRESS_CURRENT_MSG="$message"

    spinner_start
    wait "$pid"
    local ret=$?
    spinner_stop
    _LIB_PROGRESS_CURRENT_MSG=""

    _clear_line
    if ((ret == 0)); then
        _format_text "$_LIB_PROGRESS_COLOR_GREEN" "$_LIB_PROGRESS_CHECK "
        _format_text "$_LIB_PROGRESS_COLOR_GREEN" "$message"
    else
        _format_text "$_LIB_PROGRESS_COLOR_RED" "$_LIB_PROGRESS_CROSS "
        _format_text "$_LIB_PROGRESS_COLOR_RED" "$message"
    fi
    echo
    return $ret
}

# @function run_with_spinner
# @brief Runs a command while showing a spinner with proper formatting
# @arg $1 message Message to display while running
# @arg $2 duration Sleep duration in seconds
# @return Command's exit status
run_with_spinner() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: run_with_spinner <message> <duration>"
        return "$ERR_INVALID_ARGS"
    fi

    local message="$1"
    local duration="$2"
    loader_run "$message" sleep "$duration"
}

# @function run_in_background
# @brief Runs a command in background with a spinner
# @arg $1 message Message to display while waiting
# @arg $2 command Command to run
# @arg $3... Additional arguments for the command
# @return Background process's exit status
run_in_background() {
    if [[ $# -lt 2 ]]; then
        log_error "Usage: run_in_background <message> <command> [args...]"
        return "$ERR_INVALID_ARGS"
    fi

    local message="$1"
    shift
    local cmd=("$@")

    # Run command in background
    ("${cmd[@]}") &
    local pid=$!

    # Wait with spinner
    loader_wait "$message" "$pid"
}

# Extend cleanup handler to also stop spinner
_cleanup_progress() {
    # Only clean up if we're exiting the script and not in a subshell
    if [[ "${BASH_SUBSHELL:-0}" -eq 0 ]]; then
        spinner_stop
    fi
}

# Register cleanup handler
trap _cleanup_progress EXIT

# @function countdown_timer
# @brief Displays a time-based countdown timer with various styles
# @arg $1 seconds Number of seconds to count down
# @arg $2 message Optional message to display before the countdown
# @arg $3 style Optional style (standard, fill, empty, circle, square, clock, moon, blocks) - defaults to standard
# @arg $4 bar_width Optional width of the bar (default: 30)
# @arg $5 interval Optional interval between updates in seconds (default: 0.1)
# @return 0 on success, ERR_INVALID_ARGS if arguments are missing
countdown_timer() {
    if [[ $# -lt 1 ]]; then
        log_error "Usage: countdown_timer <seconds> [message] [style] [bar_width] [interval]"
        return "$ERR_INVALID_ARGS"
    fi

    local seconds="$1"
    local message="${2:-}"
    local style="${3:-standard}"
    local bar_width="${4:-$_LIB_PROGRESS_DEFAULT_BAR_WIDTH}"
    local interval="${5:-0.1}"

    # Validate numeric arguments
    if ! [[ "$seconds" =~ ^[0-9]+$ ]]; then
        log_error "Invalid seconds value: $seconds"
        return "$ERR_INVALID_NUMBER"
    fi

    # Calculate number of steps based on seconds and interval
    # Use bc for floating point calculation but store result as integer
    local steps
    steps=$(echo "scale=0; $seconds / $interval" | bc)
    if ((steps <= 0)); then
        steps=10 # Minimum number of steps for visual effect
    fi

    # Start countdown
    for ((i = 0; i <= steps; i++)); do
        # Calculate current percentage (from 0% to 100%)
        # Use bc for floating point calculation but store result as integer
        local percent
        percent=$(echo "scale=0; ($i * 100) / $steps" | bc)

        # Only print newlines for the last iteration (100%)
        if ((i == steps)); then
            show_progress 0 100 "$message" "$bar_width" "$style" "true"
            echo
        else
            # Use progress_bar directly to avoid extra newlines
            progress_bar "$percent" 100 "$message" "$bar_width" "$style" "true"
        fi

        sleep "$interval"
    done

    return 0
}
