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
├── Makefile       # Build and release automation
├── install.sh (coming soon)
└── README.md
```

## Installation

There are several ways to install the shell scripts library:

### 1️⃣ Install via curl (Versioned Release)

Install a specific tagged release:

```bash
curl -o- https://raw.githubusercontent.com/a4abhishek/shell-scripts/v0.1.0/install.sh | bash -s -- INSTALL_VERSION=v0.1.0
```

This will:
- Download the specified version
- Install to a suitable location (preferring `~/.local/my-shell-scripts`)
- Add the scripts to your PATH

### 2️⃣ Install from Local Clone

Clone and install locally:

```bash
git clone https://github.com/a4abhishek/shell-scripts.git
cd shell-scripts
./install.sh
```

### 3️⃣ Development Installation

For testing the install script without re-downloading:

```bash
SKIP_DOWNLOAD=true ./install.sh
```

### Custom Installation Location

You can specify a custom installation directory:

```bash
INSTALL_DIR=/custom/path ./install.sh
```

### Verification

After installation:
1. Start a new terminal session or source your shell RC file
2. Verify the installation:
   ```bash
   command -v notify
   ```
   This should show the path to the installed notify script

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
# Using make (recommended)
make test

# Or directly
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

## Releases

This project uses GitHub Releases for version management. The release process is automated via the Makefile.

### Prerequisites

1. Install GitHub CLI (gh):
```bash
# Using make (recommended)
make gh-install

# Or manually from https://cli.github.com/
```

2. Authenticate with GitHub:
```bash
gh auth login
```

### Creating a Release

1. Set the version (default is v1.0.0):
```bash
# Either export the version
export VERSION=v1.2.3

# Or specify it directly in the make command
make release VERSION=v1.2.3
```

2. Run the release command:
```bash
make release
```

This will:
- Verify GitHub CLI installation and authentication
- Create and push a git tag
- Generate a release archive
- Create a GitHub release with:
  - Release notes from git commits
  - Download archive
  - Links to full changelog

### Individual Steps

You can also run individual steps:

```bash
# Just create and push the tag
make tag VERSION=v1.2.3

# Just create the release archive
make archive VERSION=v1.2.3

# Just create the GitHub release
make ghrelease VERSION=v1.2.3
```
