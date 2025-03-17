#!/usr/bin/env bash
#
# @file minimal_polling_example.sh
# @brief Minimal example of using the polling library
# @description
#   This script demonstrates the core functionality of the polling library
#   with a simple API polling simulation.
#

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/core/polling.sh"

# Constants
MAX_ATTEMPTS=5
POLL_INTERVAL=3

# Function to simulate an API call
# Returns different responses based on the attempt number
simulate_api_call() {
    local attempt="$1"
    
    # Simulate API processing time
    sleep 1
    
    # Return different responses based on attempt
    case $attempt in
        1)
            echo "Starting resource provisioning"
            ;;
        2)
            echo "Resource 25% provisioned"
            ;;
        3)
            echo "Resource 50% provisioned"
            ;;
        4)
            echo "Resource 75% provisioned"
            ;;
        5)
            echo "Resource fully provisioned"
            ;;
        *)
            echo "Resource fully provisioned"
            ;;
    esac
}

# Callback function for polling
# This function is called on each polling attempt
# It should return:
#   POLLING_STATUS_CONTINUE (0) to continue polling
#   POLLING_STATUS_COMPLETE (1) to indicate successful completion
#   Any other value to indicate an error
check_resource_status() {
    # Get current attempt number (add 1 because polling starts at 0)
    local attempt=$(( $(polling_get_attempt) + 1 ))
    
    # Make API call
    echo "Making API call (attempt $attempt)..."
    local response=$(simulate_api_call "$attempt")
    
    echo "Received response: $response"
    
    # Process the response based on your business logic
    if [[ "$response" == *"fully provisioned"* ]]; then
        echo "Resource is ready!"
        return $POLLING_STATUS_COMPLETE
    elif [[ "$response" == *"75% provisioned"* ]]; then
        echo "Resource is almost ready..."
        return $POLLING_STATUS_CONTINUE
    elif [[ "$response" == *"provisioning"* || "$response" == *"provisioned"* ]]; then
        echo "Resource is still being provisioned..."
        return $POLLING_STATUS_CONTINUE
    else
        echo "Unexpected response: $response"
        return 2  # Custom error code
    fi
}

# Example with custom countdown configuration
example_with_custom_countdown() {
    echo
    echo "===== Example with Custom Countdown ====="
    echo
    
    # Run polling with callback and custom countdown configuration
    if polling_run "Checking resource status" "$POLL_INTERVAL" check_resource_status "$MAX_ATTEMPTS" -1 "fill" 40 0.5; then
        echo "Polling completed successfully!"
    else
        local status=$?
        echo "Polling failed with status $status"
    fi
}

# Example with timeout
example_with_timeout() {
    echo
    echo "===== Example with Timeout ====="
    echo
    
    # Run polling with callback and timeout
    if polling_run "Checking resource status with timeout" "$POLL_INTERVAL" check_resource_status "$MAX_ATTEMPTS" 10; then
        echo "Polling completed successfully!"
    else
        local status=$?
        echo "Polling failed with status $status"
    fi
}

# Main function
main() {
    echo
    echo "===== Minimal Polling Library Example ====="
    echo
    
    # Basic example
    if polling_run "Checking resource status" "$POLL_INTERVAL" check_resource_status "$MAX_ATTEMPTS"; then
        echo "Basic polling completed successfully!"
    else
        local status=$?
        echo "Basic polling failed with status $status"
    fi
    
    # Run examples with different configurations
    example_with_custom_countdown
    example_with_timeout
    
    echo
    echo "All examples completed"
    
    return 0
}

# Run main function
main "$@" 