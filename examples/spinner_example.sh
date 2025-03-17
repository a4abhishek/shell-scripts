#!/usr/bin/env bash

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/core/progress.sh"
# shellcheck source=/dev/null
. "$SCRIPT_DIR/lib/core/logging.sh"

# Demonstrate spinner with loader_run
demo_spinner() {
    log_info "Demonstrating spinner with loader_run..."
    echo
    
    # Run a command with a spinner
    loader_run "Running a short task" sleep 2
    
    # Run a command that takes longer
    loader_run "Running a longer task" sleep 5
    
    # Run multiple commands in sequence
    loader_run "Task 1 of 3" sleep 1
    loader_run "Task 2 of 3" sleep 2
    loader_run "Task 3 of 3" sleep 1
    
    log_success "Spinner demo completed!"
}

# Demonstrate manual spinner control
demo_manual_spinner() {
    log_info "Demonstrating manual spinner control..."
    echo
    
    # Start spinner with a message
    _LIB_PROGRESS_CURRENT_MSG="Manual spinner control"
    spinner_start
    
    # Simulate work
    sleep 3
    
    # Stop spinner
    spinner_stop
    
    # Show success message
    _format_text "$_LIB_PROGRESS_COLOR_GREEN" "$_LIB_PROGRESS_CHECK "
    _format_text "$_LIB_PROGRESS_COLOR_GREEN" "Manual spinner control"
    echo
    
    log_success "Manual spinner demo completed!"
}

# Demonstrate run_in_background
demo_background() {
    log_info "Demonstrating run_in_background..."
    echo
    
    # Run a command in background with spinner
    run_in_background "Running in background" sleep 4
    
    log_success "Background task demo completed!"
}

# Main function
main() {
    # Show header
    echo "====================================="
    echo "  Spinner Examples"
    echo "====================================="
    echo
    
    # Run all spinner demos
    demo_spinner
    echo
    demo_manual_spinner
    echo
    demo_background
}

# Run main function
main "$@"
