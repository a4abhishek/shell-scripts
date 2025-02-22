#!/usr/bin/env bash

# Setup test environment
setup() {
    load '../lib/logging.sh'
    load '../lib/input.sh'

    # Create a temporary script that sources our library and runs the function
    TEST_SCRIPT=$(mktemp)
    cat > "$TEST_SCRIPT" << EOF
#!/usr/bin/env bash
. "$BATS_TEST_DIRNAME/../lib/input.sh"
read_multiline_input
EOF
    chmod +x "$TEST_SCRIPT"
}

# Cleanup after each test
teardown() {
    rm -f "$TEST_SCRIPT"
}

@test "read_multiline_input" {
    # Mock the input and capture output
    input="Line1\nLine2"
    run bash -c "echo -e '$input' | $TEST_SCRIPT"
    
    # Assert output contains expected lines
    echo "# Output: $output" >&3  # Debug output
    [[ "$output" == *"Line1"* ]]
    [[ "$output" == *"Line2"* ]]
}
