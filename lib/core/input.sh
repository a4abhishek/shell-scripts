#!/usr/bin/env bash

# Prevent duplicate sourcing
if [[ -n "${_LIB_INPUT_LOADED:-}" ]]; then return; fi
_LIB_INPUT_LOADED=true

# Source logging functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/logging.sh"

# Read Multi-Line Input
read_multiline_input() {
  local input_file=$(mktemp)
  trap "rm -f '$input_file'" EXIT

  log_info "Enter your input (Press Ctrl+D when done):"
  cat > "$input_file"

  input=$(<"$input_file")
  echo -e "$input"
}

# Open Editor for Input
get_input_with_editor() {
  local temp_file="$(mktemp)"
  trap "rm -f '$temp_file'" EXIT

  if [[ -n "${EDITOR:-}" ]]; then
    # Optional: Try setting TERM if unset for Vim (might not fully resolve warning)
    if [[ -z "$TERM" ]]; then
      export TERM=xterm-256color # Or 'xterm', 'vt100' - common defaults
    fi
    "$EDITOR" "$temp_file"
    # Document the Vim warning:
    # NOTE: Vim might display "Vim: Warning: Output is not to a terminal"
    #       This is often benign and can be ignored if Vim still functions
    #       for input. If it's problematic, try setting EDITOR=nano
    #       or ensure your terminal environment is correctly configured.
  else
    nano "$temp_file"
  fi
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
    read -p "$prompt: " yn
    yn=$(echo "$yn" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
    case $yn in
      y|yes) return 0 ;;
      n|no) return 1 ;;
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

  read -p "$prompt: " input

  if [[ -z "$input" ]]; then
    echo "$default"
  else
    echo "$input"
  fi
}
