# Shell Scripts Library

A collection of robust shell script utilities and libraries for building reliable command-line tools.

## Features

- 📝 Standardized logging with colored output
- ✅ Preflight checks system
- 🔄 Graceful exit handling
- 📨 Slack notifications
- ⌨️ Interactive input utilities

## Directory Structure

```
shell-scripts/
├── bin/           # Executable scripts
│   └── ...
├── lib/           # Reusable library scripts
│   ├── core.sh
│   ├── logging.sh
│   ├── preflight.sh
│   ├── exit.sh
│   ├── input.sh
│   └── ...
├── test/          # Test scripts
│   └── ...
├── run_tests.sh   # Run all tests
├── install.sh (coming soon)
└── README.md          
```

## Installation

Clone the repository:

```bash
git clone https://github.com/a4abhishek/shell-scripts.git
cd shell-scripts
```

## Usage

### Including Libraries in Your Scripts

The recommended way to use these libraries is to source the core library, which will automatically load all other libraries:

```bash
#!/usr/bin/env bash

# Source the core library
LIB_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../lib" && pwd)"
. "$LIB_DIR/core.sh"

# Your script logic here...
```
### Creating Robust Libraries

When creating new libraries, follow these best practices:

#### Prevent Duplicate Sourcing
```bash
#!/usr/bin/env bash

# Prevent duplicate sourcing using a globally unique variable
if [[ -n "${_LIB_MYLIB_LOADED:-}" ]]; then return; fi
_LIB_MYLIB_LOADED=true
```

#### Source Dependencies
```bash
# Get the library directory and source dependencies
SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
. "$SCRIPT_DIR/logging.sh"
. "$SCRIPT_DIR/preflight.sh"
```

#### Define Library Functions
```bash
# Your library functions
my_function() {
    log_info "Doing something..."
    # Function logic here
}

# Register any preflight checks if needed
check_my_requirements() {
    if ! command -v required-tool >/dev/null 2>&1; then
        log_error "required-tool is not installed"
        return 1
    fi
    return 0
}
register_preflight "check_my_requirements"
```

### Example Usage
Here are some examples of using the libraries after sourcing core.sh:

#### Logging

The logging library provides consistent, colored log messages:

```bash
#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
. "$SCRIPT_DIR/lib/logging.sh"

log_info "Starting process..."
log_error "Something went wrong!"
log_fatal "Critical error, exiting!"  # This will exit the script
```

#### Preflight Checks

Add validation checks that run before your script's main logic:

```bash
#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
. "$SCRIPT_DIR/lib/preflight.sh"

check_required_tool() {
    if ! command -v my-tool >/dev/null 2>&1; then
        log_error "Required tool 'my-tool' is not installed"
        return 1
    fi
    return 0
}

# Register the check
register_preflight "check_required_tool"

# Your script logic here...
```

#### Graceful Exit Handling

Ensure cleanup operations run when your script exits:

```bash
#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
. "$SCRIPT_DIR/lib/exit.sh"

cleanup_temp_files() {
    rm -f /tmp/my-temp-file
}

# Register cleanup function
register_cleanup "cleanup_temp_files"

# Your script logic here...
```

#### Interactive Input

Get user input with various helper functions:

```bash
#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
. "$SCRIPT_DIR/lib/input.sh"

# Yes/No confirmation
if confirm "Do you want to proceed?" "y"; then
    echo "Proceeding..."
fi

# Input with default value
name=$(prompt_with_default "Enter your name" "guest")

# Multi-line input
content=$(read_multiline_input)
```

#### Slack Notifications

Send notifications to Slack:

```bash
#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
. "$SCRIPT_DIR/lib/slack.sh"

export SLACK_WEBHOOK_URL="your-webhook-url"
send_slack_message "Deploy completed successfully!"
```

### Command Execution with Notifications

Use the `notify` wrapper to get Slack notifications for long-running commands:

```bash
./bin/notify long-running-command --with arguments
```

This will:
- Execute your command
- Track execution time
- Send a Slack notification on completion/failure
- Include execution duration in the notification

## Testing

This project uses [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core) for testing. BATS provides a TAP-compliant testing framework for Bash scripts.

### Prerequisites

Install BATS:

```bash
# macOS
brew install bats-core

# Debian/Ubuntu
sudo apt install bats

# Other systems
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local
```

### Running Tests

Run all tests:
```bash
./run_tests.sh
```

Run a specific test file:
```bash
bats test/logging_test.sh
```

### Writing Tests

Tests are located in the `test/` directory and follow the BATS format:

```bash
#!/usr/bin/env bash

# Load dependencies
setup() {
    load '../lib/logging.sh'
}

# Optional cleanup
teardown() {
    true  # No cleanup needed
}

@test "Check that log_info prints messages" {
    run log_info "Test message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Test message" ]]
}
```

Key testing concepts:
- Use `setup()` to load dependencies and prepare test environment
- Use `teardown()` to clean up after tests
- Use `@test` blocks to define test cases
- Use `run` to capture command output and status
- Use assertions like `[ "$status" -eq 0 ]` to verify results
