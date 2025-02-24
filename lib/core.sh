#!/usr/bin/env bash

################################################################################
# This file will:
# - Source all other libraries (so scripts don't need to source them manually).
# - Ensure preflight checks run only once, even if core.sh is sourced multiple times.
# - Ensure cleanup handlers are registered only once, avoiding duplicate function calls.
################################################################################

set -euo pipefail

# Prevent duplicate sourcing
if [[ -n "${_LIB_CORE_LOADED:-}" ]]; then return; fi
_LIB_CORE_LOADED=true

# Check if realpath is installed
check_realpath() {
    if ! command -v realpath &>/dev/null; then
        echo -e "\033[1;31m❌ [ERROR] 'realpath' is not installed.\033[0m"
        echo "👉 Please install 'realpath' before running this script."
        if [[ "$(uname -s)" == "Darwin" ]]; then
            echo "🔹 macOS users can install it with: 'brew install coreutils'"
        fi
        return 1
    fi
    return 0
}

# Load all library files (excluding core.sh itself)
CORE_LIB_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)/core"
for lib_file in "$CORE_LIB_DIR"/*.sh; do
    if [[ "$lib_file" != "${BASH_SOURCE[0]}" ]]; then  # Skip core.sh itself
        . "$lib_file"
    fi
done

# Prevent duplicate preflight checks
if [[ -z "${_PREFLIGHT_REGISTERED:-}" ]]; then
    _PREFLIGHT_REGISTERED=true
    register_preflight check_realpath  # Ensure realpath is installed
fi

# Prevent duplicate cleanup registrations
if [[ -z "${_CLEANUP_REGISTERED:-}" ]]; then
    _CLEANUP_REGISTERED=true
    register_cleanup() {
        local func_name="$1"
        if [[ ! " ${_REGISTERED_CLEANUP_FUNCS[*]} " =~ " $func_name " ]]; then
            _REGISTERED_CLEANUP_FUNCS+=("$func_name")
        fi
    }
fi
