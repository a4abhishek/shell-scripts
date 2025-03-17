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

# Demonstrate countdown styles
demo_countdown_styles() {
    log_info "Demonstrating countdown styles..."
    echo
    
    for style in "${STYLES[@]}"; do
        log_info "Style: $style"
        echo
        
        # Show progress from 0% to 100% with reverse=true to display as countdown
        for ((i=0; i<=10; i++)); do
            local percent=$((i * 10))
            
            # Only print newlines for the last iteration (100%)
            if ((i == 10)); then
                # show_progress needs proper percentage i.e. 0 in this case
                show_progress 0 100 "Countdown ($style)" 30 "$style" "true"
            else
                # Use progress_bar directly to avoid extra newlines
                progress_bar "$percent" 100 "Countdown ($style)" 30 "$style" "true"
            fi
            
            sleep 0.2
        done
        
        echo
    done
    
    log_success "Countdown styles demo completed!"
}

# Main function
main() {
    # Show header
    echo "====================================="
    echo "  Countdown Styles Example"
    echo "====================================="
    echo
    
    # Run the demo
    demo_countdown_styles
}

# Run main function
main "$@"
