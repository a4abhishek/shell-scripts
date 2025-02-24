#!/usr/bin/env bash

# Prevent duplicate sourcing
if [[ -n "${_LIB_EXIT_LOADED:-}" ]]; then return; fi
_LIB_EXIT_LOADED=true

# Ensure script stops on errors and propagates failures properly.
set -euo pipefail

# Array to store user-defined cleanup functions
declare -a _CUSTOM_CLEANUP_FUNCS

# Function to register a custom cleanup function
register_cleanup() {
    local func_name="$1"
    _CUSTOM_CLEANUP_FUNCS+=("$func_name")
}

# Internal function to call all registered cleanup functions
_run_custom_cleanups() {
    for func in "${_CUSTOM_CLEANUP_FUNCS[@]}"; do
        if declare -f "$func" > /dev/null; then
            "$func"
        else
            echo -e "\033[1;31m❌ [ERROR] Cleanup function '$func' not found!\033[0m" >&2
        fi
    done
}

# Default cleanup handler
_default_cleanup() {
    _run_custom_cleanups
    echo -e "\n\033[1;33m⚠️  [EXIT] Received Ctrl+C. Exiting gracefully...\033[0m"
    exit 0
}

# Set the trap only once (so users don’t have to)
trap _default_cleanup SIGINT SIGTERM EXIT
