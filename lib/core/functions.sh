#!/usr/bin/env bash

# Prevent duplicate sourcing
if [[ -n "${_LIB_FUNCTIONS_LOADED:-}" ]]; then return; fi
_LIB_FUNCTIONS_LOADED=true

# Ensure script stops on errors
set -euo pipefail

# Source required libraries
CORE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CORE_LIB_DIR/logging.sh"

# Array to store registered functions
declare -a _REGISTERED_FUNCTIONS=()

# Register a function to be available in the shell
register_function() {
    local func_name="$1"
    
    # Check if function exists
    if ! declare -f "$func_name" > /dev/null; then
        log_error "Cannot register non-existent function: $func_name"
        return 1
    fi
    
    # Check if function is already registered
    if [[ " ${_REGISTERED_FUNCTIONS[*]} " == *" $func_name "* ]]; then
        log_debug "Function already registered: $func_name"
        return 0
    fi
    
    # Add to registered functions array
    _REGISTERED_FUNCTIONS+=("$func_name")
    
    # Export the function
    export -f "$func_name"
    
    log_debug "Registered function: $func_name"
    return 0
}

# List all registered functions
list_registered_functions() {
    if [[ ${#_REGISTERED_FUNCTIONS[@]} -eq 0 ]]; then
        log_info "No functions are currently registered"
        return 0
    fi
    
    log_info "Registered functions:"
    for func in "${_REGISTERED_FUNCTIONS[@]}"; do
        echo "  - $func"
    done
}

# Check if a function is registered
is_function_registered() {
    local func_name="$1"
    [[ " ${_REGISTERED_FUNCTIONS[*]} " == *" $func_name "* ]]
}
