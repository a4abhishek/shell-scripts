#!/usr/bin/env bash

set -euo pipefail

# Source core library which will load all other libraries
LIB_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/lib" && pwd)"
. "$LIB_DIR/core.sh"

# Define checks before they run
check_bats() {
    if ! command -v bats &>/dev/null; then
        log_error "'bats' is not installed."
        log_error "👉 Please install BATS before running tests."

        # Provide installation instructions based on OS
        case "$(uname -s)" in
            Linux)
                log_error "🔹 On Linux (Debian/Ubuntu), install it with: 'sudo apt install bats'"
                ;;
            Darwin)
                log_error "🔹 On macOS, install it with: 'brew install bats-core'"
                ;;
            *)
                log_error "🔹 Refer to https://github.com/bats-core/bats-core for installation instructions."
                ;;
        esac

        exit 1
    fi
}

# Register the check
register_preflight check_bats

# Now run the checks explicitly
_run_preflight_checks

# Track test failures
failed_tests=0

# Run all .sh files in test/ with Bats
for t in test/*_test.sh; do
    echo "Running $t..."
    if ! bats "$t"; then
        failed_tests=$((failed_tests + 1))
    fi
done

# Exit with failure if any tests failed
if [ "$failed_tests" -gt 0 ]; then
    log_error "$failed_tests test files had failures"
    exit 1
fi

exit 0
