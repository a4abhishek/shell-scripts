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

# Demonstrate progress styles
demo_progress_styles() {
    log_info "Demonstrating progress styles (0% to 100%)..."
    echo
    
    for style in "${STYLES[@]}"; do
        log_info "Style: $style"
        echo
        
        # Show progress from 0 to 100%
        for ((i=0; i<=10; i++)); do
            local percent=$((i * 10))
            
            # Only print newlines for the last iteration (100%)
            if ((i == 10)); then
                show_progress "$percent" 100 "Progress ($style)" 30 "$style" "false"
            else
                # Use progress_bar directly to avoid extra newlines
                progress_bar "$percent" 100 "Progress ($style)" 30 "$style" "false"
            fi
            
            sleep 0.2
        done
        
        echo
    done
    
    log_success "Progress styles demo completed!"
}

# Main function
main() {
    # Show header
    echo "====================================="
    echo "  Progress Bar Styles Example"
    echo "====================================="
    echo
    
    # Run the demo
    demo_progress_styles
}

# Run main function
main "$@" 