#!/usr/bin/env bash
#
# @file completely_standalone_polling.sh
# @brief Completely standalone polling implementation
# @description
#   This script demonstrates a simple polling implementation without
#   any external dependencies. It shows how to implement polling
#   with visual feedback in a completely self-contained script.
#

# Save original shell options
ORIGINAL_OPTIONS=$(set +o)

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/core/progress.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/core/logging.sh"

# Restore original shell options to prevent strict mode from affecting our script
eval "$ORIGINAL_OPTIONS"

# Constants
MAX_ATTEMPTS=5
POLL_INTERVAL=3

# ANSI color codes
COLOR_RESET="\033[0m"
COLOR_GREEN="\033[0;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_CYAN="\033[0;36m"
COLOR_RED="\033[0;31m"
COLOR_BLUE="\033[0;34m"

# Symbols
CHECK_MARK="✓"
WAITING="⏳"
PROCESSING="⟳"
CROSS="✗"

# Function to simulate an API call
# Returns different responses based on the attempt number
simulate_api_call() {
    local attempt="$1"
    
    # Simulate API processing time
    sleep 2
    
    # Return different responses based on attempt
    if ((attempt >= MAX_ATTEMPTS)); then
        echo "complete"
    elif ((attempt == MAX_ATTEMPTS - 1)); then
        echo "almost_ready"
    else
        progress=$((attempt * 20))
        echo "in_progress:$progress"
    fi
}

# Function to display colored text
print_colored() {
    local color="$1"
    local text="$2"
    echo -e "${color}${text}${COLOR_RESET}"
}

# Wrapper for countdown_timer that handles errors
safe_countdown_timer() {
    local seconds="$1"
    local message="$2"
    local style="$3"
    local width="$4"
    local interval="$5"
    
    # Try to use the library function, but fall back if it fails
    if type countdown_timer &>/dev/null; then
        countdown_timer "$seconds" "$message" "$style" "$width" "$interval"
    fi
}

# Main function
main() {
    echo
    echo "===== Standalone Polling Example ====="
    echo
    
    # Initialize variables
    local attempt=0
    local max_attempts="$MAX_ATTEMPTS"
    local interval="$POLL_INTERVAL"
    local polling_active=true
    
    log_info "Starting standalone polling demonstration"
    
    # Main polling loop
    while [[ "$polling_active" == "true" ]]; do
        # Increment attempt counter
        ((attempt++))
        
        # Check if we've reached max attempts
        if ((attempt > max_attempts)); then
            log_info "Reached maximum polling attempts ($max_attempts)"
            polling_active=false
            continue
        fi
        
        # Make API call
        log_info "Making API call (attempt $attempt of $max_attempts)"
        echo -n "  Making API call... "
        response=$(simulate_api_call "$attempt")
        echo "Done"
        
        # Show the response
        log_info "Received response: $response"
        
        # Process API response
        case "$response" in
            "complete")
                # Resource is ready
                print_colored "$COLOR_GREEN" "  $CHECK_MARK Resource is ready and available"
                polling_active=false
                ;;
            "almost_ready")
                # Almost done
                print_colored "$COLOR_YELLOW" "  $WAITING Resource is almost ready"
                ;;
            in_progress:*)
                # Extract progress percentage
                progress="${response#in_progress:}"
                print_colored "$COLOR_CYAN" "  $PROCESSING Resource is being provisioned (${progress}% complete)"
                ;;
            *)
                # Unknown response
                print_colored "$COLOR_RED" "  $CROSS Received unknown response: $response"
                polling_active=false
                ;;
        esac
        
        # If polling is still active, wait before next attempt
        if [[ "$polling_active" == "true" ]]; then
            log_info "Waiting ${interval}s before next poll"
            
            # Use our safe wrapper for countdown_timer
            safe_countdown_timer "$interval" "Waiting for next poll" "standard" 30 1
        fi
    done
    
    log_success "Polling demonstration completed"
    print_colored "$COLOR_GREEN" "✓ Example completed successfully"
    
    return 0
}

# Run main function
main "$@"
