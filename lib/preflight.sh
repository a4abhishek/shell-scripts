#!/usr/bin/env bash

# Prevent duplicate sourcing
if [[ -n "${_LIB_PREFLIGHT_LOADED:-}" ]]; then return; fi
_LIB_PREFLIGHT_LOADED=true

SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
. "$SCRIPT_DIR/logging.sh"

# Ensure script stops on errors and propagates failures properly.
set -euo pipefail

# Array to store registered preflight checks
declare -a _PREFLIGHT_CHECKS

# Function to register a preflight check
register_preflight() {
    local func_name="$1"
    _PREFLIGHT_CHECKS+=("$func_name")
}

# Internal function to run all registered preflight checks
_run_preflight_checks() {
    log_info "Running preflight checks..."

    local failed_checks=0

    for func in "${_PREFLIGHT_CHECKS[@]}"; do
        if declare -f "$func" > /dev/null; then
            if ! "$func"; then
                log_error "Preflight check '$func' failed."
                failed_checks=$((failed_checks + 1))
            fi
        else
            log_error "Preflight check function '$func' not found!"
            failed_checks=$((failed_checks + 1))
        fi
    done

    if [[ $failed_checks -gt 0 ]]; then
        log_fatal "$failed_checks preflight checks failed. Exiting."
    fi

    log_info "All preflight checks passed!"
}

# Ensure preflight checks run at the start of the script
_run_preflight_checks
