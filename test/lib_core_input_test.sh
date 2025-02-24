#!/usr/bin/env bash

# Setup test environment
setup() {
    # Load bats test helpers
    load '../lib/core/logging.sh'
    load '../lib/core/input.sh'

    # Create temp directory for test files
    TEST_DIR="$(mktemp -d)"

    # Export for subshells
    export TEST_DIR
    export BATS_TEST_DIRNAME
}

# Cleanup after each test
teardown() {
    rm -rf "$TEST_DIR"
}

@test "read_multiline_input handles multiple lines" {
    # Create test script
    cat > "$TEST_DIR/test.sh" << EOF
#!/usr/bin/env bash
source "\${BATS_TEST_DIRNAME}/../lib/core/input.sh"
read_multiline_input
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Run test
    input="Line1\nLine2"
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo -e '$input' | $TEST_DIR/test.sh"
    
    echo "# Output: $output" >&3  # Debug output
    [[ "$output" == *"Line1"* ]]
    [[ "$output" == *"Line2"* ]]
}

@test "get_input_with_editor uses specified editor" {
    # Create mock editor
    cat > "$TEST_DIR/mock_editor.sh" << EOF
#!/bin/bash
echo "test content" > "\$1"
EOF
    chmod +x "$TEST_DIR/mock_editor.sh"

    # Create test script
    cat > "$TEST_DIR/test.sh" << EOF
#!/usr/bin/env bash
source "\${BATS_TEST_DIRNAME}/../lib/core/input.sh"
EDITOR="$TEST_DIR/mock_editor.sh" get_input_with_editor
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Run test
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run "$TEST_DIR/test.sh"
    
    echo "# Output: $output" >&3
    [[ "$output" == "test content" ]]
}

@test "confirm accepts yes/y answers" {
    # Create test script
    cat > "$TEST_DIR/test.sh" << EOF
#!/usr/bin/env bash
source "\${BATS_TEST_DIRNAME}/../lib/core/input.sh"
if confirm "Continue?" "y"; then
    echo "Confirmed"
else
    echo "Rejected"
fi
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Test various forms of "yes"
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo 'yes' | $TEST_DIR/test.sh"
    [[ "$output" == *"Confirmed"* ]]
    
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo 'y' | $TEST_DIR/test.sh"
    [[ "$output" == *"Confirmed"* ]]
    
    # Test default
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo '' | $TEST_DIR/test.sh"
    [[ "$output" == *"Confirmed"* ]]
}

@test "confirm rejects no/n answers" {
    # Create test script
    cat > "$TEST_DIR/test.sh" << EOF
#!/usr/bin/env bash
source "\${BATS_TEST_DIRNAME}/../lib/core/input.sh"
if confirm "Continue?" "n"; then
    echo "Confirmed"
else
    echo "Rejected"
fi
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Test various forms of "no"
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo 'no' | $TEST_DIR/test.sh"
    [[ "$output" == *"Rejected"* ]]
    
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo 'n' | $TEST_DIR/test.sh"
    [[ "$output" == *"Rejected"* ]]
    
    # Test default
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo '' | $TEST_DIR/test.sh"
    [[ "$output" == *"Rejected"* ]]
}

@test "prompt_with_default returns input or default" {
    # Create test script
    cat > "$TEST_DIR/test.sh" << EOF
#!/usr/bin/env bash
source "\${BATS_TEST_DIRNAME}/../lib/core/input.sh"
result=\$(prompt_with_default "Enter value" "default")
echo "\$result"
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Test with provided input
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo 'custom' | $TEST_DIR/test.sh"
    [[ "$output" == "custom" ]]
    
    # Test with empty input (should return default)
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo '' | $TEST_DIR/test.sh"
    [[ "$output" == "default" ]]
}
