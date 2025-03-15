#!/usr/bin/env bash

setup() {
    load '../lib/core/features.sh'
    load '../lib/core/logging.sh'
    
    # Save original stdout and stderr
    exec {ORIG_STDOUT}>&1
    exec {ORIG_STDERR}>&2
    
    # Create temp directory for test files
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
}

teardown() {
    # Restore original stdout and stderr
    exec 1>&${ORIG_STDOUT}
    exec 2>&${ORIG_STDERR}
    
    # Clear all test overrides and environment variables
    unset FORCE_COLOR
    unset NO_COLOR
    unset FORCE_UNICODE
    unset NO_UNICODE
    unset TERM
    unset HAS_COLOR_SUPPORT
    unset HAS_UNICODE_SUPPORT
    unset LC_ALL
    unset LANG
    
    # Cleanup test directory
    rm -rf "$TEST_DIR" || true
}

@test "terminal detection respects FORCE_COLOR" {
    # Force color on
    FORCE_COLOR=1
    unset NO_COLOR
    _detect_terminal_features
    reinit_terminal_capabilities
    [[ "${HAS_COLOR_SUPPORT}" == "true" ]]
    
    # Force color off with NO_COLOR (NO_COLOR takes precedence)
    NO_COLOR=1
    _detect_terminal_features
    reinit_terminal_capabilities
    [[ "${HAS_COLOR_SUPPORT}" == "false" ]]
}

@test "terminal detection respects FORCE_UNICODE" {
    # Save original environment
    local orig_lang="${LANG:-}"
    local orig_lc_all="${LC_ALL:-}"
    
    # Force unicode on
    FORCE_UNICODE=1
    _detect_terminal_features
    reinit_terminal_capabilities
    echo "HAS_UNICODE_SUPPORT=$HAS_UNICODE_SUPPORT"
    echo "info symbol=${_SYMBOLS[info]}"
    [[ "${HAS_UNICODE_SUPPORT}" == "true" ]]
    [[ "${_SYMBOLS[info]}" == "📌" ]]
    
    # Force unicode off
    unset FORCE_UNICODE
    NO_UNICODE=1
    LC_ALL=C
    LANG=C
    _detect_terminal_features
    reinit_terminal_capabilities
    echo "After LC_ALL=C:"
    echo "HAS_UNICODE_SUPPORT=$HAS_UNICODE_SUPPORT"
    echo "info symbol=${_SYMBOLS[info]}"
    [[ "${_SYMBOLS[info]}" == "INFO:" ]]
    
    # Restore original environment
    if [[ -n "$orig_lang" ]]; then
        LANG="$orig_lang"
    else
        unset LANG
    fi
    if [[ -n "$orig_lc_all" ]]; then
        LC_ALL="$orig_lc_all"
    else
        unset LC_ALL
    fi
    unset NO_UNICODE
}

@test "color codes are set when color is enabled" {
    FORCE_COLOR=1
    _detect_terminal_features
    reinit_terminal_capabilities
    [[ -n "${_COLOR_INFO}" ]]
    [[ -n "${_COLOR_ERROR}" ]]
    [[ -n "${_COLOR_RESET}" ]]
}

@test "color codes are empty when color is disabled" {
    NO_COLOR=1
    _detect_terminal_features
    reinit_terminal_capabilities
    [[ -z "${_COLOR_INFO}" ]]
    [[ -z "${_COLOR_ERROR}" ]]
    [[ -z "${_COLOR_RESET}" ]]
}

@test "all required symbols are defined" {
    _detect_terminal_features
    reinit_terminal_capabilities
    local required_symbols=(debug info success warning error fatal)
    
    for symbol in "${required_symbols[@]}"; do
        [[ -n "${_SYMBOLS[$symbol]}" ]] || false
    done
}

@test "terminal detection handles missing tput" {
    # Save original PATH and environment
    local orig_path="$PATH"
    local orig_has_color="${HAS_COLOR_SUPPORT:-}"
    
    # Remove tput from PATH and reset environment
    PATH=""
    unset FORCE_COLOR
    unset NO_COLOR
    unset HAS_COLOR_SUPPORT
    
    # Re-detect features with empty PATH
    _detect_terminal_features
    reinit_terminal_capabilities
    [[ "${HAS_COLOR_SUPPORT}" == "false" ]]
    
    # Restore original environment
    PATH="$orig_path"
    if [[ -n "$orig_has_color" ]]; then
        HAS_COLOR_SUPPORT="$orig_has_color"
    else
        unset HAS_COLOR_SUPPORT
    fi
}

@test "terminal detection handles non-terminal output" {
    # Save original environment
    local orig_has_color="${HAS_COLOR_SUPPORT:-}"
    
    # Redirect stdout to file to simulate non-terminal output
    exec 1> /dev/null
    
    # Reset environment variables
    unset FORCE_COLOR
    unset NO_COLOR
    unset HAS_COLOR_SUPPORT
    
    # Re-detect features
    _detect_terminal_features
    reinit_terminal_capabilities
    [[ "${HAS_COLOR_SUPPORT}" == "false" ]]
    
    # Restore stdout and environment
    exec 1>&${ORIG_STDOUT}
    if [[ -n "$orig_has_color" ]]; then
        HAS_COLOR_SUPPORT="$orig_has_color"
    else
        unset HAS_COLOR_SUPPORT
    fi
}

@test "symbols are consistent across reinitializations" {
    # First initialization
    FORCE_UNICODE=1
    reinit_terminal_capabilities
    local first_info_symbol="${_SYMBOLS[info]}"
    
    # Second initialization
    reinit_terminal_capabilities
    local second_info_symbol="${_SYMBOLS[info]}"
    
    # Symbols should be the same
    [[ "$first_info_symbol" == "$second_info_symbol" ]]
}

@test "register_preflight adds function to preflight list" {
    source "${BATS_TEST_DIRNAME}/../lib/core/preflight.sh"
    
    # Define test preflight function
    test_preflight() { return 0; }
    
    # Register the preflight check
    register_preflight "test_preflight"
    
    # Check if function was added to array
    [[ " ${_PREFLIGHT_CHECKS[*]} " == *" test_preflight "* ]]
}

@test "_run_preflight_checks executes registered functions" {
    source "${BATS_TEST_DIRNAME}/../lib/core/preflight.sh"
    
    # Define test preflight function that creates a marker file
    test_preflight() {
        touch "$TEST_DIR/preflight_ran"
        return 0
    }
    
    # Register and run the preflight check
    register_preflight "test_preflight"
    _run_preflight_checks
    
    # Check if marker file was created
    [ -f "$TEST_DIR/preflight_ran" ]
}

@test "_run_preflight_checks fails if any check fails" {
    source "${BATS_TEST_DIRNAME}/../lib/core/preflight.sh"
    
    # Define failing preflight function
    failing_preflight() { return 1; }
    
    # Register the failing check
    register_preflight "failing_preflight"
    
    # Run preflight checks and expect failure
    run _run_preflight_checks
    [ "$status" -eq 1 ]
}
