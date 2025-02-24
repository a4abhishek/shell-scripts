#!/usr/bin/env bash

setup() {
    load '../lib/core/logging.sh'
    
    # Force unicode and color support for consistent testing
    export FORCE_COLOR=1
    export FORCE_UNICODE=1
    
    # Reinitialize terminal capabilities with new settings
    reinit_terminal_capabilities
    
    # Save original stdout and stderr
    exec {ORIG_STDOUT}>&1
    exec {ORIG_STDERR}>&2
}

teardown() {
    # Restore original stdout and stderr
    exec 1>&${ORIG_STDOUT}
    exec 2>&${ORIG_STDERR}
    
    # Clear test overrides
    unset FORCE_COLOR
    unset FORCE_UNICODE
}

# Helper function to strip ANSI color codes and timestamps
strip_formatting() {
    # Remove ANSI codes and standardize timestamp
    echo "$1" | sed -E 's/\x1B\[[0-9;]*[mK]//g' | sed -E 's/\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]/[TIMESTAMP]/g'
}

@test "log_debug only prints when LOG_LEVEL=debug" {
    # Should not print without LOG_LEVEL=debug
    run log_debug "Test debug message"
    [ "$output" = "" ]
    
    # Should print with LOG_LEVEL=debug
    LOG_LEVEL=debug run log_debug "Test debug message"
    stripped=$(strip_formatting "$output")
    [ "$stripped" = "🔍 [DEBUG] [TIMESTAMP] Test debug message" ]
}

@test "log_info prints to stdout" {
    run log_info "Test info message"
    stripped=$(strip_formatting "$output")
    [ "$stripped" = "📌 [INFO] [TIMESTAMP] Test info message" ]
}

@test "log_success prints to stdout" {
    run log_success "Test success message"
    stripped=$(strip_formatting "$output")
    [ "$stripped" = "✅ [SUCCESS] [TIMESTAMP] Test success message" ]
}

@test "log_warning prints to stdout" {
    run log_warning "Test warning message"
    stripped=$(strip_formatting "$output")
    [ "$stripped" = "⚠️ [WARNING] [TIMESTAMP] Test warning message" ]
}

@test "log_error prints to stderr" {
    # Redirect stderr to stdout for testing
    run bash -c "source '${BATS_TEST_DIRNAME}/../lib/core/logging.sh' && log_error 'Test error message' 2>&1"
    stripped=$(strip_formatting "$output")
    [ "$stripped" = "❌ [ERROR] [TIMESTAMP] Test error message" ]
}

@test "log_fatal prints to stderr and exits" {
    # Redirect stderr to stdout and capture exit code
    run bash -c "source '${BATS_TEST_DIRNAME}/../lib/core/logging.sh' && log_fatal 'Test fatal message' 2>&1"
    stripped=$(strip_formatting "$output")
    [ "$stripped" = "💥 [FATAL] [TIMESTAMP] Test fatal message" ]
    [ "$status" -eq 1 ]
}

@test "logging functions handle special characters" {
    special_chars="Special * ? [] {} characters!"
    run log_info "$special_chars"
    stripped=$(strip_formatting "$output")
    [ "$stripped" = "📌 [INFO] [TIMESTAMP] $special_chars" ]
}

@test "logging functions handle empty messages" {
    run log_info ""
    stripped=$(strip_formatting "$output")
    [ "$stripped" = "📌 [INFO] [TIMESTAMP] " ]
}

@test "logging functions handle multiline messages" {
    # Create a multiline message with explicit newline
    run bash -c "source '${BATS_TEST_DIRNAME}/../lib/core/logging.sh' && log_info $'Line 1\nLine 2'"
    
    # Debug output
    echo "# Raw output: $output" >&3
    echo "# Stripped output: $(strip_formatting "$output")" >&3
    
    # Split output into lines for comparison
    stripped=$(strip_formatting "$output")
    expected1="📌 [INFO] [TIMESTAMP] Line 1"
    expected2="📌 [INFO] [TIMESTAMP] Line 2"
    
    echo "# Checking line 1" >&3
    [[ "$stripped" == *"$expected1"* ]] || false
    echo "# Checking line 2" >&3
    [[ "$stripped" == *"$expected2"* ]] || false
}
