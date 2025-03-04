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
    # Use single quotes to prevent expansion
    trap 'rm -f '"$input_file"'' EXIT

    log_info "Enter your input (Press Ctrl+D when done):"
    cat > "$input_file"

    local input
    input=$(< "$input_file")
    echo -e "$input"
}

# Open Editor for Input
get_input_with_editor() {
    local temp_file
    temp_file="$(mktemp)"
    trap 'rm -f "$temp_file"' EXIT

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
        # log_error "Editor exited with status $editor_exit_status"
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
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Prompt for Input with Default
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local input

    if [[ -n "$default" ]]; then
        prompt="${prompt} [$default]"
    fi

    read -r -p "$prompt: " input

    if [[ -z "$input" ]]; then
        echo "$default"
    else
        echo "$input"
    fi
}
