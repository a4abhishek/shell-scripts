#!/usr/bin/env bats

###############################################################################
# Test setup and teardown
###############################################################################

setup() {
    # Load bats test helpers
    load '../lib/core/logging.sh'
    load '../lib/core/input.sh'

    # Create temp directory for test files
    TEST_DIR="$(mktemp -d)"
    export TEST_DIR
    export BATS_TEST_DIRNAME

    # Ensure logging works in tests
    export FORCE_COLOR=true
    export HAS_UNICODE_SUPPORT=true
    unset NOLOG
    unset FORCE_LOG
}

teardown() {
    rm -rf "$TEST_DIR"
}

###############################################################################
# Multiline input tests
###############################################################################

@test "read_multiline_input captures all input lines" {
    cat > "$TEST_DIR/test.sh" << 'EOF'
#!/usr/bin/env bash
export FORCE_COLOR=true
export HAS_UNICODE_SUPPORT=true
unset NOLOG
unset FORCE_LOG
source "${BATS_TEST_DIRNAME}/../lib/core/input.sh"
read_multiline_input
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Test with multiple lines including empty lines
    input="Line 1\n\nLine 3\nLine 4"
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo -e '$input' | $TEST_DIR/test.sh"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Enter your input"* ]]  # Check for prompt
    [[ "$output" == *"Line 1"* ]]
    [[ "$output" == *"Line 3"* ]]
    [[ "$output" == *"Line 4"* ]]
    [[ "$(echo -e "$output" | tail -n +2 | grep -c '^')" -eq 4 ]]  # Skip prompt line
}

@test "read_multiline_input handles special characters" {
    cat > "$TEST_DIR/test.sh" << 'EOF'
#!/usr/bin/env bash
source "${BATS_TEST_DIRNAME}/../lib/core/input.sh"
read_multiline_input
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Test with special characters
    input='Special chars: & | ; < > ( ) $ ` \\'
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo '$input' | $TEST_DIR/test.sh"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Special chars:"* ]]
    [[ "$output" == *"&"* ]]
    [[ "$output" == *"|"* ]]
    [[ "$output" == *";"* ]]
    [[ "$output" == *"<"* ]]
    [[ "$output" == *">"* ]]
    [[ "$output" == *"("* ]]
    [[ "$output" == *")"* ]]
    [[ "$output" == *"$"* ]]
    [[ "$output" == *"\`"* ]]
    [[ "$output" == *"\\"* ]]
}

@test "read_multiline_input handles empty input" {
    cat > "$TEST_DIR/test.sh" << 'EOF'
#!/usr/bin/env bash
export FORCE_COLOR=true
export HAS_UNICODE_SUPPORT=true
unset NOLOG
unset FORCE_LOG
source "${BATS_TEST_DIRNAME}/../lib/core/input.sh"
read_multiline_input
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Test with empty input (immediate Ctrl+D)
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "$TEST_DIR/test.sh < /dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Enter your input"* ]]
    [[ "$(echo -e "$output" | tail -n +2 | grep -c '^')" -eq 0 ]]
}

@test "read_multiline_input handles large input" {
    cat > "$TEST_DIR/test.sh" << 'EOF'
#!/usr/bin/env bash
export FORCE_COLOR=true
export HAS_UNICODE_SUPPORT=true
unset NOLOG
unset FORCE_LOG
source "${BATS_TEST_DIRNAME}/../lib/core/input.sh"
read_multiline_input
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Generate large input (1000 lines)
    input=$(for i in {1..1000}; do echo "Line $i"; done)
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo '$input' | $TEST_DIR/test.sh"
    [ "$status" -eq 0 ]
    [[ "$(echo -e "$output" | tail -n +2 | grep -c '^')" -eq 1000 ]]
}

@test "read_multiline_input handles cleanup" {
    cat > "$TEST_DIR/test.sh" << 'EOF'
#!/usr/bin/env bash
source "${BATS_TEST_DIRNAME}/../lib/core/input.sh"
# Count temp files before
temp_files_before=$(find /tmp -maxdepth 1 -name 'tmp.*' 2>/dev/null | wc -l)
echo "Before: $temp_files_before"

# Run the function and capture its output
output=$(read_multiline_input)

# Count temp files after
temp_files_after=$(find /tmp -maxdepth 1 -name 'tmp.*' 2>/dev/null | wc -l)
echo "After: $temp_files_after"
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Test cleanup after normal execution
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo 'test' | $TEST_DIR/test.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Before: "* ]]
    [[ "$output" == *"After: "* ]]
    before=$(echo "$output" | grep "Before:" | cut -d' ' -f2)
    after=$(echo "$output" | grep "After:" | cut -d' ' -f2)
    [ "$before" = "$after" ]
}

@test "read_multiline_input handles special content" {
    cat > "$TEST_DIR/test.sh" << 'EOF'
#!/usr/bin/env bash
source "${BATS_TEST_DIRNAME}/../lib/core/input.sh"
read_multiline_input
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Test with null characters
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "printf 'before\0after\n' | $TEST_DIR/test.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"before"* ]]
    [[ "$output" == *"after"* ]]

    # Test with ANSI escape sequences
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "printf '\e[31mred\e[0m\n' | $TEST_DIR/test.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"red"* ]]
}

###############################################################################
# Editor input tests
###############################################################################

@test "get_input_with_editor uses specified editor" {
    # Create mock editor that writes content
    cat > "$TEST_DIR/mock_editor.sh" << 'EOF'
#!/bin/bash
echo "test content" > "$1"
EOF
    chmod +x "$TEST_DIR/mock_editor.sh"

    # Create test script
    cat > "$TEST_DIR/test.sh" << 'EOF'
#!/usr/bin/env bash
source "${BATS_TEST_DIRNAME}/../lib/core/input.sh"
EDITOR="$TEST_DIR/mock_editor.sh" get_input_with_editor
EOF
    chmod +x "$TEST_DIR/test.sh"

    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run "$TEST_DIR/test.sh"
    
    [ "$status" -eq 0 ]
    [[ "$output" == "test content" ]]
}

@test "get_input_with_editor preserves initial content" {
    # Create mock editor that appends to existing content
    cat > "$TEST_DIR/mock_editor.sh" << 'EOF'
#!/bin/bash
echo "$(cat $1)" > "$1"
echo "additional content" >> "$1"
EOF
    chmod +x "$TEST_DIR/mock_editor.sh"

    # Create test script
    cat > "$TEST_DIR/test.sh" << 'EOF'
#!/usr/bin/env bash
source "${BATS_TEST_DIRNAME}/../lib/core/input.sh"
EDITOR="$TEST_DIR/mock_editor.sh" get_input_with_editor "initial content"
EOF
    chmod +x "$TEST_DIR/test.sh"

    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run "$TEST_DIR/test.sh"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"initial content"* ]]
    [[ "$output" == *"additional content"* ]]
}

@test "get_input_with_editor handles editor failures" {
    # Create mock editor that fails
    cat > "$TEST_DIR/mock_editor.sh" << 'EOF'
#!/bin/bash
echo "Editor failed" >&2
exit 1
EOF
    chmod +x "$TEST_DIR/mock_editor.sh"

    # Create test script
    cat > "$TEST_DIR/test.sh" << 'EOF'
#!/usr/bin/env bash
source "${BATS_TEST_DIRNAME}/../lib/core/input.sh"
export EDITOR="$TEST_DIR/mock_editor.sh"
get_input_with_editor 2>&1 || echo "Editor failed with status $?"
EOF
    chmod +x "$TEST_DIR/test.sh"

    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run "$TEST_DIR/test.sh"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Editor failed with status 1"* ]]
}

###############################################################################
# Confirmation prompt tests
###############################################################################

@test "confirm handles various forms of yes/no answers" {
    cat > "$TEST_DIR/test.sh" << 'EOF'
#!/usr/bin/env bash
source "${BATS_TEST_DIRNAME}/../lib/core/input.sh"
if confirm "Continue?" "y"; then
    echo "yes"
else
    echo "no"
fi
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Test various affirmative answers
    for answer in "y" "Y" "yes" "YES" "Yes"; do
        BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo '$answer' | $TEST_DIR/test.sh"
        [ "$status" -eq 0 ]
        [[ "$output" == *"yes"* ]]
    done

    # Test various negative answers
    for answer in "n" "N" "no" "NO" "No"; do
        BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo '$answer' | $TEST_DIR/test.sh"
        [ "$status" -eq 0 ]  # The command itself should succeed
        [[ "$output" == *"no"* ]]
    done
}

@test "confirm respects default values" {
    # Test with default yes
    cat > "$TEST_DIR/test_yes.sh" << 'EOF'
#!/usr/bin/env bash
source "${BATS_TEST_DIRNAME}/../lib/core/input.sh"
if confirm "Continue?" "y"; then
    echo "yes"
else
    echo "no"
fi
EOF
    chmod +x "$TEST_DIR/test_yes.sh"

    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo '' | $TEST_DIR/test_yes.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"yes"* ]]

    # Test with default no
    cat > "$TEST_DIR/test_no.sh" << 'EOF'
#!/usr/bin/env bash
source "${BATS_TEST_DIRNAME}/../lib/core/input.sh"
if confirm "Continue?" "n"; then
    echo "yes"
else
    echo "no"
fi
EOF
    chmod +x "$TEST_DIR/test_no.sh"

    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo '' | $TEST_DIR/test_no.sh"
    [ "$status" -eq 0 ]  # The command itself should succeed
    [[ "$output" == *"no"* ]]
}

@test "confirm handles invalid input" {
    cat > "$TEST_DIR/test.sh" << 'EOF'
#!/usr/bin/env bash
export FORCE_COLOR=true
export HAS_UNICODE_SUPPORT=true
unset NOLOG
unset FORCE_LOG
source "${BATS_TEST_DIRNAME}/../lib/core/input.sh"
confirm "Continue?" "" && echo "yes" || echo "no"
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Test invalid input followed by valid input
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "printf 'invalid\ny\n' | $TEST_DIR/test.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Please answer yes or no"* ]]
    [[ "$output" == *"yes"* ]]
}

###############################################################################
# Prompt tests
###############################################################################

@test "prompt handles basic input correctly" {
  # Test with non-empty input.
  result=$(echo "test input" | prompt "Enter value" "default")
  [[ "$result" == "test input" ]]
  
  # Test with empty input: expect the default.
  result=$(echo "" | prompt "Enter value" "default")
  [[ "$result" == "default" ]]
}

@test "prompt respects default values" {
    cat > "$TEST_DIR/test.sh" << 'EOF'
#!/usr/bin/env bash
source "${BATS_TEST_DIRNAME}/../lib/core/input.sh"
prompt "Enter value" "default"
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Test with custom input
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo 'custom' | $TEST_DIR/test.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == "custom" ]]

    # Test with empty input (should use default)
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo '' | $TEST_DIR/test.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == "default" ]]
}

@test "prompt validates input correctly" {
    cat > "$TEST_DIR/test.sh" << 'EOF'
#!/usr/bin/env bash
export FORCE_COLOR=true
export HAS_UNICODE_SUPPORT=true
unset NOLOG
unset FORCE_LOG
source "${BATS_TEST_DIRNAME}/../lib/core/input.sh"
prompt "Enter number" "" "^[0-9]+$"
EOF
    chmod +x "$TEST_DIR/test.sh"

    # Test valid input
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "echo '123' | $TEST_DIR/test.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == "123" ]]

    # Test invalid input followed by valid input
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "printf 'abc\n123\n' | $TEST_DIR/test.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Invalid input"* ]]
    [[ "$output" == *"123"* ]]

    # Test empty input with validation
    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run bash -c "printf '\n123\n' | $TEST_DIR/test.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Input cannot be empty"* ]]
    [[ "$output" == *"123"* ]]
}

@test "prompt handles complex input" {
    cat > "$TEST_DIR/test.sh" << 'EOF'
#!/usr/bin/env bash
source "${BATS_TEST_DIRNAME}/../lib/core/input.sh"
# Test complex regex pattern
result1=$(echo "test123" | prompt "Enter alphanumeric" "" "^[a-zA-Z0-9]+$")
echo "Result1: $result1"

# Test Unicode input
result2=$(echo "Hello 世界" | prompt "Enter Unicode" "")
echo "Result2: $result2"

# Test long input
long_input=$(printf 'x%.0s' {1..1000})
result3=$(echo "$long_input" | prompt "Enter long text" "")
echo "Result3: $result3"

# Test control characters
result4=$(echo $'\x01\x02\x03' | prompt "Enter control chars" "")
echo "Result4: $result4"
EOF
    chmod +x "$TEST_DIR/test.sh"

    BATS_TEST_DIRNAME="$BATS_TEST_DIRNAME" run "$TEST_DIR/test.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Result1: test123"* ]]
    [[ "$output" == *"Result2: Hello 世界"* ]]
    [[ "${#output}" -gt 1000 ]]  # Long input is preserved
    [[ "$output" == *"Result4: "* ]]  # Control characters are handled
}
