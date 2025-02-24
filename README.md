# Shell Scripts Library

A collection of robust shell script utilities and libraries for building reliable, maintainable command‐line tools.

## Features

- 📝 **Standardized Logging:** Colored log output for clear, consistent messaging.
- ✅ **Preflight Checks:** Validate dependencies and environment before execution.
- 🔄 **Graceful Exit Handling:** Ensure proper cleanup on interruption.
- 📨 **Slack Notifications:** Optionally send notifications on command completion.
- ⌨️ **Interactive Input:** Simplify user input with built-in utilities.

## Directory Structure

```
shell-scripts/
├── bin/           # Executable scripts
│   └── ...
├── lib/           # Reusable library scripts
│   ├── core/      # Core libraries (universally required)
│   │   ├── logging.sh
│   │   ├── preflight.sh
│   │   ├── exit.sh
│   │   ├── input.sh
│   │   └── ...
│   ├── core.sh    # Core library loader (loads all core functions)
│   ├── slack.sh   # Optional: Slack integration (requires SLACK_WEBHOOK_URL)
│   └── ...
├── test/          # Automated test scripts (using BATS)
│   └── ...
├── run_tests.sh   # Script to run all tests
├── Makefile       # Build, test, and release automation
├── install.sh     # Installation script
└── README.md
```

## Installation

You can install the Shell Scripts Library in several ways:

### 1️⃣ Install via curl (Versioned Release)

To install a specific tagged release, run:

```bash
curl -o- https://raw.githubusercontent.com/a4abhishek/shell-scripts/v0.1.0/install.sh | bash -s -- INSTALL_VERSION=v0.1.0
```

This command will:
- Download the specified version.
- Install to a default location (preferring `~/.local/my-shell-scripts`).
- Add the scripts to your PATH.

### 2️⃣ Install from Local Clone

Clone the repository and run the installer:

```bash
git clone https://github.com/a4abhishek/shell-scripts.git
cd shell-scripts
./install.sh
```

### 3️⃣ Development Installation

For testing purposes (without re-downloading):

```bash
SKIP_DOWNLOAD=true ./install.sh
```

### 4️⃣ Custom Installation Location

Specify a custom directory:

```bash
INSTALL_DIR=/custom/path ./install.sh
```

### Verification

After installation, start a new terminal session or source your shell RC file, then verify:

```bash
command -v notify
```

This should display the path to the installed `notify` script.

## Usage

### Including Libraries in Your Scripts

To use the library functions, source the core loader. This will automatically load all essential libraries:

```bash
#!/usr/bin/env bash

# Determine the library directory and load core functions
LIB_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../lib" && pwd)"
. "$LIB_DIR/core.sh"

# Your script logic here...
```

### Best Practices for Creating Libraries

#### Prevent Duplicate Sourcing

Include a load guard in every library:

```bash
#!/usr/bin/env bash
# Prevent duplicate sourcing with a unique variable
if [[ -n "${_LIB_MYLIB_LOADED:-}" ]]; then
  return
fi
_LIB_MYLIB_LOADED=true
```

#### Source Dependencies

Reference dependencies relative to the current library:

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
. "$SCRIPT_DIR/logging.sh"
. "$SCRIPT_DIR/preflight.sh"
```

#### Define Functions and Preflight Checks

Example of defining a function and registering a preflight check:

```bash
#!/usr/bin/env bash
my_function() {
    log_info "Performing an action..."
    # Function logic here
}

check_my_requirements() {
    if ! command -v required-tool >/dev/null 2>&1; then
        log_error "The required tool 'required-tool' is not installed."
        return 1
    fi
    return 0
}
register_preflight "check_my_requirements"
```

## Examples

### Logging

Use the logging library for consistent, colored output:

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
. "$SCRIPT_DIR/lib/logging.sh"

log_info "Starting process..."
log_error "An error occurred!"
log_fatal "Critical failure, exiting!"  # This exits the script
```

### Preflight Checks

Validate your environment before running main logic:

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
. "$SCRIPT_DIR/lib/preflight.sh"

check_required_tool() {
    if ! command -v my-tool >/dev/null 2>&1; then
        log_error "Required tool 'my-tool' is not installed."
        return 1
    fi
    return 0
}

register_preflight "check_required_tool"

# Main script logic here...
```

### Graceful Exit Handling

Ensure cleanup operations occur on exit:

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
. "$SCRIPT_DIR/lib/exit.sh"

cleanup_temp_files() {
    rm -f /tmp/my-temp-file
}

register_cleanup "cleanup_temp_files"

# Main script logic here...
```

### Interactive Input

Use helper functions for user input:

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
. "$SCRIPT_DIR/lib/input.sh"

# Confirmation prompt
if confirm "Do you want to proceed?" "y"; then
    echo "Proceeding..."
fi

# Prompt with a default value
name=$(prompt_with_default "Enter your name" "guest")

# Multi-line input
content=$(read_multiline_input)
```

### Slack Notifications

Send Slack messages (ensure you set `SLACK_WEBHOOK_URL` if using this feature):

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
. "$SCRIPT_DIR/lib/slack.sh"

export SLACK_WEBHOOK_URL="your-webhook-url"
send_slack_message "Deployment completed successfully!"
```

### Command Execution with Notifications

Wrap long-running commands to automatically send notifications:

```bash
./bin/notify long-running-command --with arguments
```

This wrapper will:
- Execute the command.
- Track its execution time.
- Send a Slack notification upon completion or failure, including duration details.

## Testing

This project uses [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core) for automated testing.

### Prerequisites

Install BATS on your system:

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

To run all tests, use:

```bash
make test   # Recommended via the Makefile
# Or directly:
./run_tests.sh
```

To run a specific test file:

```bash
bats test/logging_test.sh
```

### Writing Tests

Tests follow the BATS format. For example:

```bash
#!/usr/bin/env bash

setup() {
    load '../lib/logging.sh'
}

teardown() {
    # No cleanup needed
    :
}

@test "log_info prints messages correctly" {
    run log_info "Test message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Test message" ]]
}
```

Key points:
- Use `setup()` to load dependencies.
- Use `teardown()` for cleanup.
- Define tests with `@test` blocks.
- Use `run` to capture output and status.
- Assert expected results with standard Bash assertions.

## Releases

The Shell Scripts Library uses GitHub Releases for version management, automated via the Makefile.

### Prerequisites

1. **Install GitHub CLI (gh):**

   ```bash
   make gh-install   # Or install manually from https://cli.github.com/
   ```

2. **Authenticate with GitHub:**

   ```bash
   gh auth login
   ```

### Creating a Release

To create a new release:

1. **Set the version:**

   ```bash
   export VERSION=v1.2.3   # Or pass it directly via make: make release VERSION=v1.2.3
   ```

2. **Run the release command:**

   ```bash
   make release
   ```

This process will:
- Verify GitHub CLI installation and authentication.
- Create and push a git tag.
- Generate a release archive.
- Create a GitHub release with release notes, the download archive, and a link to the changelog.

### Individual Steps

You can also run specific release steps:

```bash
make tag VERSION=v1.2.3         # Create and push a git tag
make archive VERSION=v1.2.3     # Generate the release archive
make ghrelease VERSION=v1.2.3   # Create the GitHub release
```

## Contributing

We welcome contributions to help improve the Shell Scripts Library! Whether you’re fixing bugs, adding new features, or updating documentation, your input is appreciated. To contribute, please follow these steps the [CONTRIBUTING.md](CONTRIBUTING.md).

## License

This project is licensed under the [APACHE LICENSE, VERSION 2.0](LICENSE).

---

Happy scripting, and thank you for contributing to the Shell Scripts Library! 🚀
