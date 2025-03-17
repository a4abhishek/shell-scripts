#!/usr/bin/env bash

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/core/progress.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/core/logging.sh"

# Available styles
STYLES=(
    "standard"
    "fill"
    "circle"
    "square"
    "clock"
    "moon"
    "blocks"
)

# Demonstrate time-based countdown timer
demo_countdown_timer() {
    log_info "Demonstrating time-based countdown timer..."
    echo
    
    for style in "${STYLES[@]}"; do
        log_info "Style: $style"
        echo
        
        # Use the countdown_timer function for a 3-second countdown
        # Parameters: seconds message style bar_width interval
        countdown_timer 3 "Countdown ($style)" "$style" 30 0.1
        
        echo
    done
    
    log_success "Countdown timer demo completed!"
}

# Main function
main() {
    # Show header
    echo "====================================="
    echo "  Countdown Timer Example"
    echo "====================================="
    echo
    
    # Run the demo
    demo_countdown_timer
}

# Run main function
main "$@"
