#!/usr/bin/env bash

# Prevent duplicate sourcing
if [[ -n "${_LIB_CHECKS_LOADED:-}" ]]; then return; fi
_LIB_CHECKS_LOADED=true

# Ensure script stops on errors
set -euo pipefail

# Source required libraries
CORE_LIB_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)/../lib/core"
# shellcheck source=/dev/null
. "$CORE_LIB_DIR/logging.sh"

# Array to store seen guard variables
declare -A _SEEN_GUARD_VARS

# Check if a file has a valid bash shebang
check_shebang() {
    local file="$1"
    if ! head -n1 "$file" | grep -q "^#!.*bash"; then
        log_error "Missing or invalid shebang in $file"
        return 1
    fi
    return 0
}

# Check if a file has strict mode enabled
check_strict_mode() {
    local file="$1"
    if ! grep -q "set -euo pipefail" "$file"; then
        log_error "Missing strict mode in $file"
        return 1
    fi
    return 0
}

# Check if a bin/ script properly sources the core library
check_core_sourcing() {
    local file="$1"
    if [[ "$file" =~ ^bin/ ]] && ! grep -q '. "$SCRIPT_DIR/core.sh"' "$file"; then
        log_error "Missing core library import in $file"
        return 1
    fi
    return 0
}

# Check if library has unique guard variable and proper implementation
check_unique_guard() {
    local file="$1"
    
    # Only check files in lib directory
    if [[ ! "$file" =~ ^lib/ ]]; then
        return 0
    fi

    # Skip non-shell files
    if [[ ! "$file" =~ \.sh$ ]]; then
        return 0
    fi

    # First find the guard variable by looking at the assignment line
    local guard_var
    guard_var=$(grep -o '^[[:space:]]*_LIB_[A-Z_]*_LOADED=true' "$file" | grep -o '_LIB_[A-Z_]*_LOADED')
    
    if [[ -z "$guard_var" ]]; then
        log_error "Missing or invalid guard variable assignment in: $file"
        log_error "Expected pattern: _LIB_NAME_LOADED=true"
        return 1
    fi

    # Now verify the guard check using the found variable
    if ! grep -q "^[[:space:]]*if[[:space:]]*\[\[[[:space:]]*-n[[:space:]]*\"\${${guard_var}:-}\"[[:space:]]*\]\][[:space:]]*;[[:space:]]*then[[:space:]]*return[[:space:]]*;[[:space:]]*fi" "$file"; then
        log_error "Missing or invalid guard check in: $file"
        log_error "Expected: if [[ -n \"\${${guard_var}:-}\" ]]; then return; fi"
        return 1
    fi

    # Check for duplicate guard variables
    if [[ -n "${_SEEN_GUARD_VARS[$guard_var]:-}" ]]; then
        log_error "Duplicate guard variable '$guard_var' found in:"
        log_error "  - ${_SEEN_GUARD_VARS[$guard_var]}"
        log_error "  - $file"
        return 1
    fi

    _SEEN_GUARD_VARS[$guard_var]="$file"
    return 0
}

# Run all checks on a file
run_script_checks() {
    local file="$1"
    local failed=0

    log_info "Checking $file..."

    if ! check_shebang "$file"; then
        failed=1
    fi

    if ! check_strict_mode "$file"; then
        failed=1
    fi

    if ! check_core_sourcing "$file"; then
        failed=1
    fi

    if ! check_unique_guard "$file"; then
        failed=1
    fi

    return "$failed"
}
