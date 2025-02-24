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
    # Skip if we're in a test environment
    if [[ "${BATS_TEST_FILENAME:-}" != "" ]]; then
        return 0
    fi

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
    # Do not exit if we're in a test environment
    if [[ "${BATS_TEST_FILENAME:-}" != "" ]]; then
        return 0
    fi

    _run_custom_cleanups
    echo -e "\n\033[1;33m⚠️  [EXIT] Script completed gracefully.\033[0m"
    exit 0
}

# Set the trap only once (so users don't have to)
if [[ "${BATS_TEST_FILENAME:-}" == "" ]]; then
    trap _default_cleanup SIGINT SIGTERM EXIT
fi
