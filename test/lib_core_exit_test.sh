#!/usr/bin/env bash

setup() {
    load '../lib/core/logging.sh'
    load '../lib/core/exit.sh'
    
    # Create temp directory for test files
    TEST_DIR="$(mktemp -d)"
    
    # Export for subshells
    export TEST_DIR
    export BATS_TEST_DIRNAME
    
    # Save original stdout and stderr
    exec {ORIG_STDOUT}>&1
    exec {ORIG_STDERR}>&2

    # Clear any existing cleanup functions
    _CUSTOM_CLEANUP_FUNCS=()
}

teardown() {
    # Restore original stdout and stderr
    exec 1>&${ORIG_STDOUT}
    exec 2>&${ORIG_STDERR}
    
    # Cleanup test directory
    rm -rf "$TEST_DIR"
}

# Helper function to strip ANSI color codes and timestamps
strip_formatting() {
    echo "$1" | sed -E 's/\x1B\[[0-9;]*[mK]//g'
}

@test "register_cleanup adds function to cleanup list" {
    # Define test cleanup function
    test_cleanup() { echo "cleanup ran"; }
    
    # Register the cleanup
    register_cleanup "test_cleanup"
    
    # Check if function was added to array
    [[ " ${_CUSTOM_CLEANUP_FUNCS[*]} " == *" test_cleanup "* ]]
}

@test "_run_custom_cleanups executes registered functions" {
    # Create test script that doesn't inherit BATS environment
    cat > "$TEST_DIR/test.sh" << 'EOF'
#!/usr/bin/env bash
unset BATS_TEST_FILENAME
source "${BATS_TEST_DIRNAME}/../lib/core/exit.sh"

test_cleanup() { echo "cleanup executed"; }
register_cleanup "test_cleanup"
_run_custom_cleanups
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Run test
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run "$TEST_DIR/test.sh"
    
    [[ "$output" == *"cleanup executed"* ]]
}

@test "_run_custom_cleanups handles missing functions" {
    # Create test script that doesn't inherit BATS environment
    cat > "$TEST_DIR/test.sh" << 'EOF'
#!/usr/bin/env bash
export FORCE_COLOR=true
export HAS_UNICODE_SUPPORT=true
unset NOLOG
unset FORCE_LOG
unset BATS_TEST_FILENAME
source "${BATS_TEST_DIRNAME}/../lib/core/exit.sh"
register_cleanup "nonexistent_function"
_run_custom_cleanups 2>&1
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Run test and capture both stdout and stderr
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run "$TEST_DIR/test.sh"
    
    # Check error message in combined output
    stripped=$(strip_formatting "$output")
    [[ "$stripped" == *"Cleanup function 'nonexistent_function' not found!"* ]]
}

@test "_default_cleanup runs cleanups and exits gracefully" {
    # Create test script that doesn't inherit BATS environment
    cat > "$TEST_DIR/test.sh" << 'EOF'
#!/usr/bin/env bash
export FORCE_COLOR=true
export HAS_UNICODE_SUPPORT=true
unset NOLOG
unset FORCE_LOG
unset BATS_TEST_FILENAME
source "${BATS_TEST_DIRNAME}/../lib/core/exit.sh"

test_cleanup() { echo "cleanup ran"; }
register_cleanup "test_cleanup"
_default_cleanup
echo "This should not print"
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Run test
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run "$TEST_DIR/test.sh"
    
    # Check output
    [[ "$output" == *"cleanup ran"* ]]
    [[ "$output" == *"Exiting gracefully"* ]]
    [[ "$output" != *"This should not print"* ]]
    [ "$status" -eq 0 ]
}

@test "trap catches SIGINT signal" {
    # Create test script that doesn't inherit BATS environment
    cat > "$TEST_DIR/test.sh" << 'EOF'
#!/usr/bin/env bash
export FORCE_COLOR=true
export HAS_UNICODE_SUPPORT=true
unset NOLOG
unset FORCE_LOG
unset BATS_TEST_FILENAME
source "${BATS_TEST_DIRNAME}/../lib/core/exit.sh"

test_cleanup() { echo "cleanup ran"; }
register_cleanup "test_cleanup"
# Send SIGINT to self
kill -SIGINT $$
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Run test
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run "$TEST_DIR/test.sh"
    
    # Check output
    [[ "$output" == *"cleanup ran"* ]]
    [[ "$output" == *"Exiting gracefully"* ]]
    [ "$status" -eq 0 ]
}
