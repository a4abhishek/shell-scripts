#!/usr/bin/env bats

load test_helper.bash

# Set up the test environment
setup() {
    setup_test_env  # Use the helper's setup function

    # Set REPO_ROOT to the repository root
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export REPO_ROOT

    # Create test directory
    TEST_DIR=$(mktemp -d)

    # Create a test config file.
    cat > "$TEST_DIR/test.conf" << 'EOF'
# Test configuration
verbose=true
count=42
name=Config User
EOF

    # Unset variables that might interfere with tests.
    unset USER_NAME
    unset INPUT_FILE

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

    # Initialize test context
    init_flag_context "test"
}

# Clean up test environment
teardown() {
    cleanup_flag_context "test"
    rm -rf "$TEST_DIR"
    # Close file descriptors and remove temporary files.
    exec 5>&-
    exec 6>&-
    rm -f "$TEST_NONERROR_LOG" "$TEST_ERROR_LOG"
    teardown_test_env  # Call the helper's teardown function
}

# Helper functions to read log file contents.
get_nonerror_log_contents() {
    cat "$TEST_NONERROR_LOG"
}

get_error_log_contents() {
    cat "$TEST_ERROR_LOG"
}

###############################################################################
# Helper function: Create a test script that uses flags.sh.
###############################################################################
create_test_script() {
    cat > "$TEST_DIR/test.sh" << EOF
#!/usr/bin/env bash
# Use an absolute path to the library.
source "\$REPO_ROOT/lib/core/flags.sh"

set_script_info "Test script for flags library." "\${0##*/} [options] <input-file>"

register_flag "verbose" "bool" "Enable verbose output" "v"
register_flag "count" "int" "Number of iterations" "n" "1"
register_flag "name" "string" "Your name" "u" "Default User" "" "USER_NAME"
register_flag "mode" "string" "Operation mode" "m" "start" "start|stop|restart"

parse_flags "\$@" || exit 1

# Output flag values directly without logging
echo "verbose=\$(get_flag verbose)"
echo "count=\$(get_flag count)"
echo "name=\$(get_flag name)"
echo "mode=\$(get_flag mode)"
EOF
    chmod +x "$TEST_DIR/test.sh"
}

###############################################################################
# Register Flag Tests
###############################################################################
@test "register_flag sets up flag correctly" {
    run bash -c 'source "$REPO_ROOT/lib/core/flags.sh" && register_flag "test" "string" "Test flag" "t" "default"'
    [ "$status" -eq 0 ]
    # Check non-error log for the debug message.
    nonerr=$(get_nonerror_log_contents)
    [[ "$nonerr" =~ "Registered flag 'test' of type 'string'" ]]
}

@test "register_flag validates flag names" {
    # Test invalid characters in flag name
    run bash -c 'source "$REPO_ROOT/lib/core/flags.sh" && register_flag "test@flag" "string" "Test flag" "t"'
    [ "$status" -eq 1 ]
    err=$(get_error_log_contents)
    [[ "$err" =~ "Invalid flag name" ]]

    # Test flag name starting with a number
    run bash -c 'source "$REPO_ROOT/lib/core/flags.sh" && register_flag "1test" "string" "Test flag" "t"'
    [ "$status" -eq 1 ]
    err=$(get_error_log_contents)
    [[ "$err" =~ "Invalid flag name" ]]

    # Test flag name with spaces
    run bash -c 'source "$REPO_ROOT/lib/core/flags.sh" && register_flag "test flag" "string" "Test flag" "t"'
    [ "$status" -eq 1 ]
    err=$(get_error_log_contents)
    [[ "$err" =~ "Invalid flag name" ]]
}

@test "register_flag validates flag types" {
    # Test invalid flag type
    run register_flag "test" "invalid" "Test" "t" "value"
    [ "$status" -eq 1 ]
    err=$(get_error_log_contents)
    [[ "$err" =~ "Invalid flag type: 'invalid'. Must be one of: bool int string" ]]
}

@test "register_flag validates shorthand length" {
    run bash -c 'source "$REPO_ROOT/lib/core/flags.sh" && register_flag "test" "string" "Test" "tt"'
    [ "$status" -eq 1 ]
    err=$(get_error_log_contents)
    [[ "$err" =~ "Shorthand must be a single character" ]]
}

@test "register_flag prevents duplicate shorthands" {
    run bash -c 'source "$REPO_ROOT/lib/core/flags.sh" && register_flag "test1" "string" "Test 1" "t" && register_flag "test2" "string" "Test 2" "t"'
    [ "$status" -eq 1 ]
    err=$(get_error_log_contents)
    [[ "$err" =~ "Shorthand 't' already used by flag" ]]
}

@test "register_flag validates environment variable names" {
    # Test invalid environment variable name with hyphen
    run bash -c 'source "$REPO_ROOT/lib/core/flags.sh" && register_flag "test" "string" "Test" "t" "" "" "INVALID-ENV"'
    [ "$status" -eq 1 ]
    err=$(get_error_log_contents)
    [[ "$err" =~ "Invalid environment variable name" ]]

    # Test invalid environment variable name starting with number
    run bash -c 'source "$REPO_ROOT/lib/core/flags.sh" && register_flag "test" "string" "Test" "t" "" "" "1TEST_ENV"'
    [ "$status" -eq 1 ]
    err=$(get_error_log_contents)
    [[ "$err" =~ "Invalid environment variable name" ]]
}

###############################################################################
# Flag Parsing Tests
###############################################################################
@test "parse_flags handles boolean flags correctly" {
    create_test_script
    run "$TEST_DIR/test.sh" -v
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "verbose=true" ]]
}

@test "parse_flags handles integer flags correctly" {
    create_test_script
    run "$TEST_DIR/test.sh" -n 42
    [ "$status" -eq 0 ]
    [[ "${lines[1]}" == "count=42" ]]
}

@test "parse_flags handles negative integer values" {
    create_test_script
    run "$TEST_DIR/test.sh" -n -5
    [ "$status" -eq 0 ]
    [[ "${lines[1]}" == "count=-5" ]]
}

@test "parse_flags handles string flags correctly" {
    create_test_script
    run "$TEST_DIR/test.sh" -u "John Doe"
    [ "$status" -eq 0 ]
    [[ "${lines[2]}" == "name=John Doe" ]]
}

@test "parse_flags validates integer values" {
    create_test_script
    run "$TEST_DIR/test.sh" -n invalid
    [ "$status" -eq 1 ]
    err=$(get_error_log_contents)
    [[ "$err" =~ "requires an integer value" ]]
}

@test "parse_flags handles combined short flags" {
    create_test_script
    # Combined short flags: -v (boolean) and -n expects a value.
    run "$TEST_DIR/test.sh" -vn 5
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "verbose=true" ]]
    [[ "${lines[1]}" == "count=5" ]]
}

###############################################################################
# Environment Variable Tests
###############################################################################
@test "environment variables are used as fallback" {
    create_test_script
    export USER_NAME="Env User"
    run "$TEST_DIR/test.sh"
    [ "$status" -eq 0 ]
    [[ "${lines[2]}" == "name=Env User" ]]
}

@test "command line arguments override environment variables" {
    create_test_script
    export USER_NAME="Env User"
    run "$TEST_DIR/test.sh" -u "CLI User"
    [ "$status" -eq 0 ]
    [[ "${lines[2]}" == "name=CLI User" ]]
}

###############################################################################
# Configuration File Tests
###############################################################################
@test "configuration file values are loaded" {
    create_test_script
    # Insert config file command after sourcing the library
    sed -i.bak '/source.*flags.sh/a\
set_config_file "'"$TEST_DIR"'/test.conf"' "$TEST_DIR/test.sh"
    
    run "$TEST_DIR/test.sh"
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "verbose=true" ]]
    [[ "${lines[1]}" == "count=42" ]]
    [[ "${lines[2]}" == "name=Config User" ]]
}

@test "configuration file validates format" {
    create_test_script
    
    # Create config file with invalid format
    cat > "$TEST_DIR/invalid.conf" << 'EOF'
# Invalid configuration
verbose:true
count=42
name = Config User
invalid-key=value
EOF

    # Insert config file command after sourcing the library
    sed -i.bak '/source.*flags.sh/a\
set_config_file "'"$TEST_DIR"'/invalid.conf"' "$TEST_DIR/test.sh"
    
    run "$TEST_DIR/test.sh"
    [ "$status" -eq 1 ]
    err=$(get_error_log_contents)
    [[ "$err" =~ "Invalid configuration file format" ]]
}

@test "command line arguments override config file" {
    create_test_script
    # Insert config file command after sourcing the library
    sed -i.bak '/source.*flags.sh/a\
set_config_file "'"$TEST_DIR"'/test.conf"' "$TEST_DIR/test.sh"
    run "$TEST_DIR/test.sh" -n 10
    [ "$status" -eq 0 ]
    [[ "${lines[1]}" == "count=10" ]]
}

###############################################################################
# Allowed Values Tests
###############################################################################
@test "allowed values are enforced" {
    create_test_script
    run "$TEST_DIR/test.sh" -m invalid
    [ "$status" -eq 1 ]
    err=$(get_error_log_contents)
    [[ "$err" =~ "must be one of: start,stop,restart" ]]
}

@test "allowed values accept valid options" {
    create_test_script
    run "$TEST_DIR/test.sh" -m restart
    [ "$status" -eq 0 ]
    [[ "${lines[3]}" == "mode=restart" ]]
}

###############################################################################
# Mutually Exclusive Flags Tests
###############################################################################
@test "mutually exclusive flags cannot be used together" {
    cat > "$TEST_DIR/mutex_test.sh" << EOF
#!/usr/bin/env bash
source "\$REPO_ROOT/lib/core/flags.sh"
register_flag "force" "bool" "Force operation" "F" "false"
register_flag "dry-run" "bool" "Show what would be done" "D" "false"
register_mutex_flags "force dry-run"
parse_flags "\$@"
EOF
    chmod +x "$TEST_DIR/mutex_test.sh"
    run "$TEST_DIR/mutex_test.sh" --force=true --dry-run=true
    [ "$status" -eq 1 ]
    err=$(get_error_log_contents)
    [[ "$err" =~ "Flags cannot be used together: force, dry-run" ]]
}

###############################################################################
# Required Positional Arguments Tests
###############################################################################
@test "required positional arguments are enforced" {
    cat > "$TEST_DIR/required_test.sh" << EOF
#!/usr/bin/env bash
source "\$REPO_ROOT/lib/core/flags.sh"
register_required_positional 1 "Input file required"
parse_flags "\$@"
EOF
    chmod +x "$TEST_DIR/required_test.sh"
    run "$TEST_DIR/required_test.sh"
    [ "$status" -eq 1 ]
    err=$(get_error_log_contents)
    [[ "$err" =~ "Expected at least 1 positional argument" ]]
}

@test "required positional arguments accept valid input" {
    cat > "$TEST_DIR/required_test.sh" << EOF
#!/usr/bin/env bash
source "\$REPO_ROOT/lib/core/flags.sh"
register_required_positional 1 "Input file required"
parse_flags "\$@"
get_positional_args
EOF
    chmod +x "$TEST_DIR/required_test.sh"
    
    run "$TEST_DIR/required_test.sh" "input.txt"
    [ "$status" -eq 0 ]
    [ "$output" = "input.txt" ]
}

###############################################################################
# Help Message Tests
###############################################################################
@test "help message shows all components" {
    create_test_script
    run "$TEST_DIR/test.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Test script for flags library." ]]
    [[ "$output" =~ "Usage:" ]]
    [[ "$output" =~ "Options:" ]]
    [[ "$output" =~ "-v, --verbose" ]]
    [[ "$output" =~ "-n, --count" ]]
    [[ "$output" =~ "-u, --name" ]]
    [[ "$output" =~ "-m, --mode" ]]
    [[ "$output" =~ "env: USER_NAME" ]]
    [[ "$output" =~ "start, stop, restart" ]]
}

@test "help message handles very long flag names and descriptions" {
    cat > "$TEST_DIR/long_help_test.sh" << EOF
#!/usr/bin/env bash
source "\$REPO_ROOT/lib/core/flags.sh"
register_flag "very-long-flag-name" "string" "This is an extremely long description that provides detailed information about what this flag does and how it affects the behavior of the script in various scenarios" "v"
register_flag "another-long-flag" "int" "Another very long description that continues well beyond the typical terminal width to test proper text wrapping and formatting in the help message output" "a"
parse_flags "\$@"
EOF
    chmod +x "$TEST_DIR/long_help_test.sh"

    run "$TEST_DIR/long_help_test.sh" --help
    [ "$status" -eq 0 ]
    
    # Verify that long flag names are properly aligned
    [[ "$output" =~ "--very-long-flag-name" ]]
    [[ "$output" =~ "--another-long-flag" ]]
    
    # Verify that descriptions are properly wrapped
    [[ "$output" =~ "This is an extremely long description" ]]
    [[ "$output" =~ "Another very long description" ]]
    
    # Check that the output maintains readable formatting
    [[ ! "$output" =~ "  --very-long-flag-name  --another-long-flag" ]]
}

###############################################################################
# Special Cases Tests
###############################################################################
@test "handles empty input gracefully" {
    create_test_script
    run "$TEST_DIR/test.sh"
    [ "$status" -eq 0 ]
}

@test "handles special characters in values" {
    create_test_script
    run "$TEST_DIR/test.sh" -u 'John "The Rock" Johnson'
    [ "$status" -eq 0 ]
    [[ "${lines[2]}" == 'name=John "The Rock" Johnson' ]]
}

@test "handles Unicode characters in values" {
    create_test_script
    run "$TEST_DIR/test.sh" -u "John 🚀 Doe"
    [ "$status" -eq 0 ]
    [[ "${lines[2]}" == "name=John 🚀 Doe" ]]
}

@test "handles very long values" {
    create_test_script
    long_name=$(printf 'x%.0s' {1..1000})
    run "$TEST_DIR/test.sh" -u "$long_name"
    [ "$status" -eq 0 ]
    [[ "${#output}" -gt 1000 ]]
}

@test "validates complex regex patterns" {
    cat > "$TEST_DIR/regex_test.sh" << EOF
#!/usr/bin/env bash
source "\$REPO_ROOT/lib/core/flags.sh"
# Test complex email pattern with additional constraints
register_flag "email" "string" "Email address" "e" "" "" "" "^[a-zA-Z0-9]([a-zA-Z0-9_%+-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9_%+-]*[a-zA-Z0-9])?)*@[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$"
parse_flags "\$@"
get_flag email
EOF
    chmod +x "$TEST_DIR/regex_test.sh"

    # Test invalid email starting with dot
    run "$TEST_DIR/regex_test.sh" -e ".test.user@example.com"
    [ "$status" -eq 1 ]
    err=$(get_error_log_contents)
    [[ "$err" =~ "value does not match required pattern" ]]

    # Test valid email with dots between alphanumeric segments
    run "$TEST_DIR/regex_test.sh" -e "test.user@example.com"
    [ "$status" -eq 0 ]
    [[ "$output" == "test.user@example.com" ]]

    # Test invalid email with consecutive dots
    run "$TEST_DIR/regex_test.sh" -e "test..user@example.com"
    [ "$status" -eq 1 ]
    err=$(get_error_log_contents)
    [[ "$err" =~ "value does not match required pattern" ]]

    # Test invalid email with dot at start
    run "$TEST_DIR/regex_test.sh" -e ".test@example.com"
    [ "$status" -eq 1 ]
    err=$(get_error_log_contents)
    [[ "$err" =~ "value does not match required pattern" ]]

    # Test invalid email with dot at end of local part
    run "$TEST_DIR/regex_test.sh" -e "test.@example.com"
    [ "$status" -eq 1 ]
    err=$(get_error_log_contents)
    [[ "$err" =~ "value does not match required pattern" ]]

    # Test invalid email with special chars between dots
    run "$TEST_DIR/regex_test.sh" -e "test.@#$.user@example.com"
    [ "$status" -eq 1 ]
    err=$(get_error_log_contents)
    [[ "$err" =~ "value does not match required pattern" ]]

    # Test valid email with subdomains
    run "$TEST_DIR/regex_test.sh" -e "test@sub.example.com"
    [ "$status" -eq 0 ]
    [[ "$output" == "test@sub.example.com" ]]
}

@test "email validation handles various cases" {
    # Create test script for email validation
    cat > "$TEST_DIR/email_test.sh" << 'EOF'
#!/usr/bin/env bash
source "$REPO_ROOT/lib/core/flags.sh"
register_flag "email" "string" "Email" "e" "" "" "" "$EMAIL_PATTERN"
parse_flags "$@"
get_flag email
EOF
    chmod +x "$TEST_DIR/email_test.sh"

    local -A test_cases=(
        [".test@example.com"]="invalid:starts with dot"
        ["test.user@example.com"]="valid:standard email"
        ["test..user@example.com"]="invalid:consecutive dots"
        ["test.@example.com"]="invalid:ends with dot"
        ["test@example"]="invalid:missing TLD"
        ["test.user@sub.example.com"]="valid:with subdomain"
        ["test+label@example.com"]="valid:with plus addressing"
        ["test@.com"]="invalid:missing domain"
        ["test@com"]="invalid:missing domain part"
    )
    
    for email in "${!test_cases[@]}"; do
        local expected="${test_cases[$email]%%:*}"
        local desc="${test_cases[$email]#*:}"
        
        echo "Testing: $email (expected: $expected, desc: $desc)"
        
        run "$TEST_DIR/email_test.sh" --email="$email"
        
        if [[ "$expected" == "valid" ]]; then
            [ "$status" -eq 0 ] || fail "Expected valid email for: $desc ($email)"
            [ "$output" == "$email" ] || fail "Expected $email but got $output for: $desc"
        else
            [ "$status" -eq 1 ] || fail "Expected invalid email for: $desc ($email)"
            err=$(get_error_log_contents)
            [[ "$err" =~ "value does not match required pattern" ]] || fail "Expected error about invalid pattern"
        fi
    done
}

# Consolidate boolean flag tests
@test "boolean flags handle various formats" {
    local -A test_cases=(
        ["--verbose"]="valid:true"
        ["--verbose=true"]="valid:true"
        ["--verbose=false"]="valid:false"
        ["--verbose true"]="valid:true"
        ["--verbose false"]="valid:false"
        ["--verbose=yes"]="invalid:invalid boolean"
        ["--verbose=1"]="invalid:invalid boolean"
        ["-v"]="valid:true"
    )
    
    # Create test script
    cat > "$TEST_DIR/bool_test.sh" << 'EOF'
#!/usr/bin/env bash
source "$REPO_ROOT/lib/core/flags.sh"
register_flag "verbose" "bool" "Verbose mode" "v"
register_required_positional 0
parse_flags "$@"
get_flag verbose
EOF
    chmod +x "$TEST_DIR/bool_test.sh"
    
    for args in "${!test_cases[@]}"; do
        local expected="${test_cases[$args]%%:*}"
        local desc="${test_cases[$args]#*:}"
        
        # Convert string args to array and run test script
        local -a arg_array
        read -ra arg_array <<< "$args"

        run "$TEST_DIR/bool_test.sh" "${arg_array[@]}"
        
        if [[ "$expected" == "valid" ]]; then
            [ "$status" -eq 0 ] || fail "Expected valid boolean for: $desc ($args)"
            expected_value="${desc#*:}"
            [ "$output" == "$expected_value" ] || fail "Expected $expected_value but got $output for: $desc ($args)"
        else
            [ "$status" -eq 1 ] || fail "Expected invalid boolean for: $desc ($args)"
            err=$(get_error_log_contents)
            [[ "$err" =~ "requires a boolean value" ]] || fail "Expected error about invalid boolean value"
        fi
    done
}

# Consolidate integer flag tests
@test "integer flags handle various formats" {
    local -A test_cases=(
        ["--count=42"]="valid:42"
        ["--count=-5"]="valid:-5"
        ["--count 100"]="valid:100"
        ["-n 0"]="valid:0"
        ["--count=abc"]="invalid:not a number"
        ["--count=1.5"]="invalid:not an integer"
        ["--count="]="invalid:empty value"
    )
    
    # Create test script
    cat > "$TEST_DIR/int_test.sh" << 'EOF'
#!/usr/bin/env bash
source "$REPO_ROOT/lib/core/flags.sh"
register_flag "count" "int" "Count" "n"
register_required_positional 0
parse_flags "$@"
get_flag count
EOF
    chmod +x "$TEST_DIR/int_test.sh"
    
    for args in "${!test_cases[@]}"; do
        local expected="${test_cases[$args]%%:*}"
        local desc="${test_cases[$args]#*:}"
        
        echo "Testing: $args (expected: $expected, desc: $desc)"
        
        # Convert string args to array
        local -a arg_array
        read -ra arg_array <<< "$args"
        
        run "$TEST_DIR/int_test.sh" "${arg_array[@]}"
        
        if [[ "$expected" == "valid" ]]; then
            [ "$status" -eq 0 ] || fail "Expected valid integer for: $desc ($args)"
            expected_value="${desc#*:}"
            [ "$output" == "$expected_value" ] || fail "Expected $expected_value but got $output for: $desc ($args)"
        else
            [ "$status" -eq 1 ] || fail "Expected invalid integer for: $desc ($args)"
            err=$(get_error_log_contents)
            [[ "$err" =~ "Flag 'count' requires an integer value" ]] || fail "Expected error about invalid integer value"
        fi
    done
}

# Test flag context management
@test "flag contexts are properly isolated" {
    # Create two contexts
    init_flag_context "ctx1"
    init_flag_context "ctx2"
    
    # Register same flag name in both contexts with different shorthands
    _CURRENT_CONTEXT="ctx1"
    register_flag "verbose" "bool" "Verbose mode" "v"
    
    _CURRENT_CONTEXT="ctx2"
    register_flag "verbose" "bool" "Verbose mode 2" "w"
    
    # Set different values in each context
    _CURRENT_CONTEXT="ctx1"
    parse_flags --verbose=true
    
    _CURRENT_CONTEXT="ctx2"
    parse_flags --verbose=false
    
    # Verify values are isolated
    _CURRENT_CONTEXT="ctx1"
    value1=$(get_flag verbose)
    [ "$value1" = "true" ]
    
    _CURRENT_CONTEXT="ctx2"
    value2=$(get_flag verbose)
    [ "$value2" = "false" ]
    
    # Clean up
    cleanup_flag_context "ctx1"
    cleanup_flag_context "ctx2"
}
