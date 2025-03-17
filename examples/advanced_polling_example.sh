#!/usr/bin/env bash
#
# @file advanced_polling_example.sh
# @brief Advanced example of using the polling library
# @description
#   This script demonstrates the advanced features of the polling library
#   including error handling, timeout management, and different polling
#   strategies.
#

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/core/polling.sh"

# Constants
MAX_ATTEMPTS=5
POLL_INTERVAL=3

# Function to simulate an API call with different response patterns
# Returns different responses based on the attempt number and scenario
simulate_api_call() {
    local attempt="$1"
    local scenario="${2:-success}"
    
    # Simulate API processing time
    sleep 1
    
    case "$scenario" in
        "success")
            # Normal success path
            case $attempt in
                1) echo "Starting resource provisioning" ;;
                2) echo "Resource 25% provisioned" ;;
                3) echo "Resource 50% provisioned" ;;
                4) echo "Resource 75% provisioned" ;;
                *) echo "Resource fully provisioned" ;;
            esac
            ;;
        "error")
            # Error path
            if [[ $attempt -eq 3 ]]; then
                echo "ERROR: Resource provisioning failed"
            else
                case $attempt in
                    1) echo "Starting resource provisioning" ;;
                    2) echo "Resource 25% provisioned" ;;
                    4) echo "Resource 50% provisioned" ;;
                    *) echo "Resource 75% provisioned" ;;
                esac
            fi
            ;;
        "timeout")
            # Timeout path - never completes
            case $attempt in
                1) echo "Starting resource provisioning" ;;
                2) echo "Resource 10% provisioned" ;;
                3) echo "Resource 15% provisioned" ;;
                4) echo "Resource 20% provisioned" ;;
                *) echo "Resource 25% provisioned" ;;
            esac
            ;;
        "intermittent")
            # Intermittent failures
            if [[ $attempt -eq 2 || $attempt -eq 4 ]]; then
                echo "ERROR: Temporary connection issue"
            else
                case $attempt in
                    1) echo "Starting resource provisioning" ;;
                    3) echo "Resource 50% provisioned" ;;
                    5) echo "Resource fully provisioned" ;;
                    *) echo "Resource 75% provisioned" ;;
                esac
            fi
            ;;
        *)
            echo "Unknown scenario: $scenario"
            ;;
    esac
}

# Basic success callback
success_callback() {
    local attempt=$(( $(polling_get_attempt) + 1 ))
    
    echo "Making API call (attempt $attempt, scenario: success)..."
    local response=$(simulate_api_call "$attempt" "success")
    
    echo "Received response: $response"
    
    if [[ "$response" == *"fully provisioned"* ]]; then
        echo "Resource is ready!"
        return $POLLING_STATUS_COMPLETE
    elif [[ "$response" == *"ERROR"* ]]; then
        echo "Error detected: $response"
        return 2  # Custom error code
    else
        echo "Resource is still being provisioned..."
        return $POLLING_STATUS_CONTINUE
    fi
}

# Error callback
error_callback() {
    local attempt=$(( $(polling_get_attempt) + 1 ))
    
    echo "Making API call (attempt $attempt, scenario: error)..."
    local response=$(simulate_api_call "$attempt" "error")
    
    echo "Received response: $response"
    
    if [[ "$response" == *"fully provisioned"* ]]; then
        echo "Resource is ready!"
        return $POLLING_STATUS_COMPLETE
    elif [[ "$response" == *"ERROR"* ]]; then
        echo "Error detected: $response"
        return 2  # Custom error code
    else
        echo "Resource is still being provisioned..."
        return $POLLING_STATUS_CONTINUE
    fi
}

# Timeout callback
timeout_callback() {
    local attempt=$(( $(polling_get_attempt) + 1 ))
    
    echo "Making API call (attempt $attempt, scenario: timeout)..."
    local response=$(simulate_api_call "$attempt" "timeout")
    
    echo "Received response: $response"
    
    if [[ "$response" == *"fully provisioned"* ]]; then
        echo "Resource is ready!"
        return $POLLING_STATUS_COMPLETE
    elif [[ "$response" == *"ERROR"* ]]; then
        echo "Error detected: $response"
        return 2  # Custom error code
    else
        echo "Resource is still being provisioned..."
        return $POLLING_STATUS_CONTINUE
    fi
}

# Intermittent failure callback
intermittent_callback() {
    local attempt=$(( $(polling_get_attempt) + 1 ))
    
    echo "Making API call (attempt $attempt, scenario: intermittent)..."
    local response=$(simulate_api_call "$attempt" "intermittent")
    
    echo "Received response: $response"
    
    if [[ "$response" == *"fully provisioned"* ]]; then
        echo "Resource is ready!"
        return $POLLING_STATUS_COMPLETE
    elif [[ "$response" == *"ERROR"* ]]; then
        # For intermittent errors, we continue polling
        echo "Temporary error detected, will retry: $response"
        return $POLLING_STATUS_CONTINUE
    else
        echo "Resource is still being provisioned..."
        return $POLLING_STATUS_CONTINUE
    fi
}

# Example 1: Basic success path
example_success_path() {
    echo
    echo "===== Example 1: Success Path ====="
    echo
    
    if polling_run "Checking resource status (success path)" "$POLL_INTERVAL" success_callback "$MAX_ATTEMPTS"; then
        echo "✅ Polling completed successfully!"
    else
        local status=$?
        echo "❌ Polling failed with status $status"
    fi
    
    echo
}

# Example 2: Error handling
example_error_handling() {
    echo
    echo "===== Example 2: Error Handling ====="
    echo
    
    if polling_run "Checking resource status (error path)" "$POLL_INTERVAL" error_callback "$MAX_ATTEMPTS"; then
        echo "✅ Polling completed successfully!"
    else
        local status=$?
        echo "❌ Polling failed with status $status (expected)"
    fi
    
    echo
}

# Example 3: Timeout handling
example_timeout_handling() {
    echo
    echo "===== Example 3: Timeout Handling ====="
    echo
    
    # Configure a short timeout (8 seconds)
    if polling_run "Checking resource status (timeout path)" "$POLL_INTERVAL" timeout_callback "$MAX_ATTEMPTS" 8; then
        echo "✅ Polling completed successfully!"
    else
        local status=$?
        echo "❌ Polling timed out with status $status (expected)"
    fi
    
    echo
}

# Example 4: Intermittent failures
example_intermittent_failures() {
    echo
    echo "===== Example 4: Intermittent Failures ====="
    echo
    
    if polling_run "Checking resource status (intermittent failures)" "$POLL_INTERVAL" intermittent_callback "$MAX_ATTEMPTS"; then
        echo "✅ Polling completed successfully despite intermittent failures!"
    else
        local status=$?
        echo "❌ Polling failed with status $status"
    fi
    
    echo
}

# Example 5: Custom countdown configuration
example_custom_countdown() {
    echo
    echo "===== Example 5: Custom Countdown Configuration ====="
    echo
    
    # Run polling with custom countdown configuration
    if polling_run "Checking resource status (custom countdown)" "$POLL_INTERVAL" success_callback "$MAX_ATTEMPTS" -1 "fill" 40 0.5; then
        echo "✅ Polling completed successfully!"
    else
        local status=$?
        echo "❌ Polling failed with status $status"
    fi
    
    echo
}

# Example 6: Using polling_with_timeout for external commands
example_external_command() {
    echo
    echo "===== Example 6: External Command with Timeout ====="
    echo
    
    # Create a temporary script that simulates a long-running command
    local temp_script
    temp_script=$(mktemp)
    
    cat > "$temp_script" << 'EOF'
#!/bin/bash
echo "Starting long-running command..."
for i in {1..10}; do
    echo "Processing step $i of 10..."
    sleep 1
done
echo "Command completed successfully!"
exit 0
EOF
    
    chmod +x "$temp_script"
    
    # Run the command with timeout and custom countdown
    if polling_with_timeout "Running external command" 5 "$temp_script" -- "circle" 50 0.5; then
        echo "✅ Command completed successfully!"
    else
        local status=$?
        echo "❌ Command timed out with status $status (expected)"
    fi
    
    # Clean up
    rm -f "$temp_script"
    
    echo
}

# Main function
main() {
    echo
    echo "===== Advanced Polling Library Examples ====="
    echo
    
    # Run examples
    example_success_path
    example_error_handling
    example_timeout_handling
    example_intermittent_failures
    example_custom_countdown
    example_external_command
    
    echo "All examples completed"
    
    return 0
}

# Run main function
main "$@" 