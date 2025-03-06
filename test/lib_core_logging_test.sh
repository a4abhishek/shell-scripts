#!/usr/bin/env bats

###############################################################################
# Helper functions
###############################################################################

# Helper: Remove ANSI color codes and replace any timestamp with [TIMESTAMP]
strip_formatting() {
    echo "$1" \
        | sed -E 's/\x1B\[[0-9;]*[mK]//g' \
        | sed -E 's/\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]/[TIMESTAMP]/g'
}

###############################################################################
# Basic logging functionality tests
###############################################################################

@test "log_debug only prints when LOG_LEVEL=debug" {
    # Should not print with LOG_LEVEL=info
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log_debug "Test debug message"'
    [ -z "$output" ]

    # Should print with LOG_LEVEL=debug
    run bash -c 'export LOG_LEVEL=debug; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log_debug "Test debug message"'
    stripped=$(strip_formatting "$output")
    [[ "$stripped" =~ ^🔍[[:space:]]+DEBUG[[:space:]]+\[TIMESTAMP\][[:space:]]+Test[[:space:]]+debug[[:space:]]+message[[:space:]]*$ ]]
}

@test "log_info prints to stdout" {
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log_info "Test info message"'
    stripped=$(strip_formatting "$output")
    [[ "$stripped" =~ ^📌[[:space:]]+INFO[[:space:]]+\[TIMESTAMP\][[:space:]]+Test[[:space:]]+info[[:space:]]+message[[:space:]]*$ ]]
}

@test "log_success prints to stdout" {
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log_success "Test success message"'
    stripped=$(strip_formatting "$output")
    [[ "$stripped" =~ ^✅[[:space:]]+SUCCESS[[:space:]]+\[TIMESTAMP\][[:space:]]+Test[[:space:]]+success[[:space:]]+message[[:space:]]*$ ]]
}

@test "log_warning prints to stderr" {
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log_warning "Test warning message" 2>&1'
    stripped=$(strip_formatting "$output")
    [[ "$stripped" =~ ^⚠️[[:space:]]+WARNING[[:space:]]+\[TIMESTAMP\][[:space:]]+Test[[:space:]]+warning[[:space:]]+message[[:space:]]*$ ]]
}

@test "log_error prints to stderr" {
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log_error "Test error message" 2>&1'
    stripped=$(strip_formatting "$output")
    [[ "$stripped" =~ ^❌[[:space:]]+ERROR[[:space:]]+\[TIMESTAMP\][[:space:]]+Test[[:space:]]+error[[:space:]]+message[[:space:]]*$ ]]
}

@test "log_fatal prints to stderr and exits with custom exit code" {
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log_fatal "Test fatal message" 42 2>&1'
    [ "$status" -eq 42 ]
    stripped=$(strip_formatting "$output")
    [[ "$stripped" =~ ^💥[[:space:]]+FATAL[[:space:]]+\[TIMESTAMP\][[:space:]]+Test[[:space:]]+fatal[[:space:]]+message[[:space:]]*$ ]]
}

###############################################################################
# Log level and filtering tests
###############################################################################

@test "log level filtering respects hierarchy" {
    # Info messages should not appear when LOG_LEVEL=warning
    run bash -c 'export LOG_LEVEL=warning; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log_info "Should not appear"'
    [ -z "$output" ]

    # Warning messages should appear when LOG_LEVEL=warning
    run bash -c 'export LOG_LEVEL=warning; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log_warning "Should appear" 2>&1'
    stripped=$(strip_formatting "$output")
    [[ "$stripped" =~ ^⚠️[[:space:]]+WARNING[[:space:]]+\[TIMESTAMP\][[:space:]]+Should[[:space:]]+appear[[:space:]]*$ ]]
}

@test "log level comparison is case insensitive" {
    run bash -c 'export LOG_LEVEL=WARNING; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log_info "Should not appear"'
    [ -z "$output" ]
}

@test "invalid log levels default to info" {
    run bash -c 'export LOG_LEVEL=invalid_level; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log_info "Should appear"'
    stripped=$(strip_formatting "$output")
    [[ "$stripped" =~ ^📌[[:space:]]+INFO[[:space:]]+\[TIMESTAMP\][[:space:]]+Should[[:space:]]+appear[[:space:]]*$ ]]
}

@test "log_is_enabled returns correct status for different levels" {
    # Info level should be enabled when LOG_LEVEL=info
    result=$(bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                      source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && 
                      log_is_enabled "info" && echo "enabled" || echo "disabled"')
    [[ "$result" =~ enabled ]]

    # Debug level should be disabled when LOG_LEVEL=info
    result=$(bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                      source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && 
                      log_is_enabled "debug" && echo "enabled" || echo "disabled"')
    [[ "$result" =~ disabled ]]
}

###############################################################################
# Environment variable interaction tests
###############################################################################

@test "NO_COLOR takes precedence over FORCE_COLOR" {
    run bash -c 'export LOG_LEVEL=info; export NO_COLOR=1; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log_info "Test message"'
    [[ "$output" != *$'\033['* ]]  # Should not contain ANSI escape sequences
}

@test "NOLOG suppresses output regardless of other settings" {
    run bash -c 'export LOG_LEVEL=info; export NOLOG=1; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log_info "Should not appear"'
    [ -z "$output" ]
}

@test "unset environment variables use defaults" {
    # Unset LOG_LEVEL should default to info
    run bash -c 'unset LOG_LEVEL; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log_info "Default level"'
    stripped=$(strip_formatting "$output")
    [[ "$stripped" =~ ^📌[[:space:]]+INFO[[:space:]]+\[TIMESTAMP\][[:space:]]+Default[[:space:]]+level[[:space:]]*$ ]]

    # Unset HAS_UNICODE_SUPPORT should use fallback symbols
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; unset HAS_UNICODE_SUPPORT;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log_info "Fallback symbols"'
    stripped=$(strip_formatting "$output")
    [[ "$stripped" =~ INFO[[:space:]]+\[TIMESTAMP\][[:space:]]+Fallback[[:space:]]+symbols[[:space:]]*$ ]]
}

###############################################################################
# File descriptor tests
###############################################################################

@test "invalid file descriptors are handled gracefully" {
    # Non-existent file descriptor
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log "📌" "INFO" "" "Message" "999" "$_COLOR_INFO" 2>&1'
    [ "$status" -ne 0 ]

    # Closed file descriptor
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 exec 3>&-;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log "📌" "INFO" "" "Message" "3" "$_COLOR_INFO" 2>&1'
    [ "$status" -ne 0 ]
}

@test "custom file descriptors work correctly" {
    tmp_output=$(mktemp)
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 exec 3>"'"$tmp_output"'";
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log "📌" "INFO" "" "Custom FD" "3" "$_COLOR_INFO"'
    [ "$status" -eq 0 ]
    [ -s "$tmp_output" ]
    stripped=$(strip_formatting "$(cat "$tmp_output")")
    [[ "$stripped" =~ ^📌[[:space:]]+INFO[[:space:]]+Custom[[:space:]]+FD[[:space:]]*$ ]]
    rm -f "$tmp_output"
}

###############################################################################
# Message formatting tests
###############################################################################

@test "custom timestamp formats are respected" {
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && 
                 log "📌" "INFO" "%Y-%m-%d_%H-%M-%S" "Message" "1" "$_COLOR_INFO"'
    stripped=$(strip_formatting "$output")
    [[ "$stripped" =~ ^📌[[:space:]]+INFO[[:space:]]+\[[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{2}-[0-9]{2}-[0-9]{2}\][[:space:]]+Message[[:space:]]*$ ]]
}

@test "invalid timestamp formats are handled gracefully" {
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && 
                 log "📌" "INFO" "%Invalid" "Message" "1" "$_COLOR_INFO"'
    [ "$status" -eq 0 ]
    [[ -n "$output" ]]
}

@test "empty timestamp format omits brackets" {
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && 
                 log "📌" "INFO" "" "Message" "1" "$_COLOR_INFO"'
    stripped=$(strip_formatting "$output")
    [[ "$stripped" =~ ^📌[[:space:]]+INFO[[:space:]]+Message[[:space:]]*$ ]]
}

@test "whitespace in messages is preserved" {
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && 
                 log_info "   spaced message   "'
    stripped=$(strip_formatting "$output")
    [[ "$stripped" == *"   spaced message   "* ]]
}

@test "multiline messages maintain formatting" {
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && 
                 log_info $'"'"'First line\n\n\nLast line'"'"''
    stripped=$(strip_formatting "$output")
    line_count=$(echo "$stripped" | wc -l)
    [ "$line_count" -eq 4 ]
    first_line=$(echo "$stripped" | head -n1)
    last_line=$(echo "$stripped" | tail -n1)
    [[ "$first_line" =~ ^📌[[:space:]]+INFO[[:space:]]+\[TIMESTAMP\][[:space:]]+First[[:space:]]+line[[:space:]]*$ ]]
    [[ "$last_line" =~ ^📌[[:space:]]+INFO[[:space:]]+\[TIMESTAMP\][[:space:]]+Last[[:space:]]+line[[:space:]]*$ ]]
}

###############################################################################
# Special content tests
###############################################################################

@test "very long messages are handled correctly" {
    long_message=$(printf 'x%.0s' {1..1000})
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && log_info "'"$long_message"'"'
    [ "$status" -eq 0 ]
    [[ "${#output}" -gt 1000 ]]
}

@test "special shell characters are preserved" {
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && 
                 log_info "Special: & | ; < > ( ) $ \` \\"'
    stripped=$(strip_formatting "$output")
    # Verify each special character appears in the output
    [[ "$stripped" =~ "Special:" ]] &&
    [[ "$stripped" =~ "&" ]] &&
    [[ "$stripped" =~ "|" ]] &&
    [[ "$stripped" =~ ";" ]] &&
    [[ "$stripped" =~ "<" ]] &&
    [[ "$stripped" =~ ">" ]] &&
    [[ "$stripped" =~ "(" ]] &&
    [[ "$stripped" =~ ")" ]] &&
    [[ "$stripped" =~ "$" ]] &&
    [[ "$stripped" =~ "\`" ]] &&
    [[ "$stripped" =~ "\\" ]]
}

@test "Unicode characters are handled correctly" {
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && 
                 log_info "Unicode: 🌟 ❤️ 🎉 🚀"'
    stripped=$(strip_formatting "$output")
    [[ "$stripped" =~ Unicode.*🌟.*❤️.*🎉.*🚀 ]]
}

@test "ANSI escape sequences in messages are preserved" {
    run bash -c 'export LOG_LEVEL=info; export FORCE_COLOR=1; export HAS_UNICODE_SUPPORT=true;
                 source "'"${BATS_TEST_DIRNAME}/../lib/core/logging.sh"'" && 
                 log_info $'"'"'\033[31mRed\033[0m \033[32mGreen\033[0m'"'"''
    stripped=$(strip_formatting "$output")
    [[ "$stripped" =~ Red.*Green ]]
}
