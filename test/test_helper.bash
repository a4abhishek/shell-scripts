#!/usr/bin/env bash

# Set REPO_ROOT to the repository root (assumes test_helper.bash is in the test/ folder)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"

# Load all core libraries
# shellcheck source=/dev/null
. "$REPO_ROOT/lib/core/features.sh"
# shellcheck source=/dev/null
. "$REPO_ROOT/lib/core/logging.sh"
# shellcheck source=/dev/null
. "$REPO_ROOT/lib/core/flags.sh"

# Helper function for test failures
fail() {
    echo "# $*" >&2
    return 1
}

# Helper function to skip tests that require interactive terminal
check_interactive() {
    # Skip if running under BATS
    if [[ -n "${BATS_VERSION:-}" ]]; then
        skip "Test requires interactive terminal"
    fi
    
    # Skip if no TTY available
    if [[ ! -t 0 ]] || [[ ! -t 1 ]] || [[ ! -t 2 ]] || [[ ! -e /dev/tty ]]; then
        skip "Test requires TTY access"
    fi
}

# Set up test environment
setup_test_env() {
    # Force color and Unicode support for tests.
    export FORCE_COLOR=true
    export HAS_UNICODE_SUPPORT=true
    export LOG_LEVEL=debug

    # Unset any logging overrides.
    unset FORCE_LOG
    unset NOLOG

    # Create two temporary files for logging: one for non-error logs and one for error logs.
    TEST_NONERROR_LOG=$(mktemp)
    TEST_ERROR_LOG=$(mktemp)

    # Open file descriptors 5 and 6 for non-error and error logs.
    exec 5>"$TEST_NONERROR_LOG"
    exec 6>"$TEST_ERROR_LOG"

    # Set logging file descriptors.
    export LOG_NONERROR_FD=5
    export LOG_ERROR_FD=6
}

# Clean up test environment
teardown_test_env() {
    # Close file descriptors and remove temporary files.
    exec 5>&-
    exec 6>&-
    rm -f "$TEST_NONERROR_LOG" "$TEST_ERROR_LOG"
}

# Helper functions to read log file contents.
get_nonerror_log_contents() {
    cat "$TEST_NONERROR_LOG"
}

get_error_log_contents() {
    cat "$TEST_ERROR_LOG"
}

setup_test_env
