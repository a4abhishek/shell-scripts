#!/usr/bin/env bash

# Prevent duplicate sourcing
if [[ -n "${_LIB_INPUT_LOADED:-}" ]]; then return; fi
_LIB_INPUT_LOADED=true

# Ensure script stops on errors and propagates failures properly.
set -euo pipefail

# Source logging functions
CORE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$CORE_LIB_DIR/logging.sh"

# Read Multi-Line Input
read_multiline_input() {
    local input_file
    input_file=$(mktemp)

    trap 'rm -f '"$input_file"'' EXIT

    log_info "Enter your input (Press Ctrl+D when done):"
    cat > "$input_file"

    # Read and output the file line by line to handle large inputs
    while IFS= read -r line || [[ -n "$line" ]]; do
        echo "$line"
    done < "$input_file"
}

# Open Editor for Input
get_input_with_editor() {
    local temp_file
    temp_file="$(mktemp)"

    trap 'rm -f '"$temp_file"'' EXIT

    # Populate with initial content (if provided)
    local initial_content
    initial_content="${1:-}"
    if [[ -n "$initial_content" ]]; then
        echo "$initial_content" > "$temp_file"
    fi

    local editor
    editor="${EDITOR:-${VISUAL:-nano}}" # Fallback to nano if neither is set

    # Run the editor directly connected to the terminal
    "$editor" "$temp_file" < /dev/tty > /dev/tty 2>&1

    local editor_exit_status=$?
    if [[ $editor_exit_status -ne 0 ]]; then
        log_error "Editor exited with status $editor_exit_status"
        return 1
    fi

    # Read the result from the temp file
    cat "$temp_file"
}

# Prompt for Yes/No Confirmation
confirm() {
    local prompt="$1"
    local default="$2"

    if [[ "$default" == "y" ]]; then
        prompt="${prompt} [Y/n]"
    elif [[ "$default" == "n" ]]; then
        prompt="${prompt} [y/N]"
    else
        prompt="${prompt} [y/n]"
    fi

    while true; do
        read -r -p "$prompt: " yn
        yn=$(echo "$yn" | tr '[:upper:]' '[:lower:]') # Convert to lowercase
        case $yn in
            y | yes) return 0 ;;
            n | no) return 1 ;;
            "") # Handle empty input based on default
                if [[ "$default" == "y" ]]; then
                    return 0
                elif [[ "$default" == "n" ]]; then
                    return 1
                fi
                ;;
            *) log_error "Please answer yes or no." ;;
        esac
    done
}

# Prompt for user input with optional default value and validation.
#
# Arguments:
#   message           The prompt message to display to the user
#   default           Optional default value if user enters nothing
#   validation_regex  Optional regex pattern to validate input
#
# Output:
#   Prints the validated user input or default value to stdout
#
# Returns:
#   0 if input was successfully obtained and validated
#   1 if validation fails (user will be re-prompted)
#
# Examples:
#   prompt "Enter name"                    # Basic prompt
#   prompt "Enter age" "" "^[0-9]+$"       # With validation
#   prompt "Enter name" "John"             # With default
#   prompt "Enter age" "25" "^[0-9]+$"     # With default and validation
prompt() {
    local message="$1"
    local default="$2"
    local validation_regex="${3:-}"
    local input

    # If a default value is provided, append it to the prompt message.
    if [[ -n "$default" ]]; then
        message="${message} [$default]"
    fi

    while true; do
        read -r -p "$message: " input

        # If no input is provided...
        if [[ -z "$input" ]]; then
            if [[ -n "$default" ]]; then
                echo "$default"
                return 0
            elif [[ -n "$validation_regex" ]]; then
                log_error "Input cannot be empty"
                continue
            else
                echo ""
                return 0
            fi
        fi

        # If a validation regex is provided, ensure input matches.
        if [[ -n "$validation_regex" ]]; then
            if [[ "$input" =~ $validation_regex ]]; then
                echo "$input"
                return 0
            else
                log_error "Invalid input. Must match pattern: $validation_regex"
                continue
            fi
        else
            # No validation required, return the input.
            echo "$input"
            return 0
        fi
    done
}
