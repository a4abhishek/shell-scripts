# Shell Scripts Library

[![Shell Scripts CI](https://github.com/a4abhishek/shell-scripts/actions/workflows/shell-scripts.yml/badge.svg?branch=main)](https://github.com/a4abhishek/shell-scripts/actions/workflows/shell-scripts.yml)

A collection of robust shell script utilities and libraries for building reliable, maintainable command‐line tools.

## Features

- 📝 **Standardized Logging:** Colored log output for clear, consistent messaging.
- 🚩 **Command-line Flag Parsing:** Robust flag parsing with validation and configuration.
- ✅ **Preflight Checks:** Validate dependencies and environment before execution.
- 🔄 **Graceful Exit Handling:** Ensure proper cleanup on interruption.
- 📨 **Slack Notifications:** Optionally send notifications on command completion.
- ⌨️ **Interactive Input:** Simplify user input with built-in utilities.
- 📊 **Progress Indicators:** Beautiful progress bars and loading spinners with Unicode and color support.
- 🔄 **Polling Mechanism:** Implement API polling with visual feedback and state management.

## Progress and Polling

The library provides robust tools for displaying progress indicators and implementing polling mechanisms:

### Progress Indicators

```bash
#!/usr/bin/env bash
source "lib/core/progress.sh"

# Display a spinner while a command runs
loader_run "Processing data" sleep 5

# Show a progress bar
total=100
for ((i=1; i<=total; i++)); do
    progress_bar "$i" "$total" "Processing"
    sleep 0.05
done

# Display a countdown timer
countdown_timer 10 "Starting in"
```

### Polling Mechanism

A dedicated library for polling is comming soon.

## Command-line Flag Parsing

The flags library provides robust command-line argument parsing with extensive validation:

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
. "$SCRIPT_DIR/lib/core/flags.sh"

# Set script metadata
set_script_info \
    "My script description" \
    "myscript [options] <input-file>"

# Optional: Load defaults from config file
set_config_file ".myscript.conf"

# Register flags with all features
register_flag "verbose" "bool" "Enable verbose output" "v"
register_flag "count" "int" "Number of iterations" "n" "1"
register_flag "name" "string" "Your name" "u" "Default User" "" "USER_NAME"
register_flag "mode" "string" "Operation mode" "m" "start" "start|stop|restart"
register_flag "email" "string" "Email address" "e" "" "" "" "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"

# Register mutually exclusive flags
register_mutex_flags "start" "stop"

# Register required positional arguments
register_required_positional 1 "Input file to process"

# Parse command line arguments
parse_flags "$@" || exit 1

# Use parsed flags
if [[ "$(get_flag verbose)" == "true" ]]; then
    log_info "Verbose mode enabled"
fi

count=$(get_flag count)
name=$(get_flag name)
mode=$(get_flag mode)

# Process positional arguments
while IFS= read -r file; do
    process_file "$file"
done < <(get_positional_args)
```

### Features

- Support for boolean, integer, and string flags
- Short and long flag formats (e.g., `-v`, `--verbose`)
- Flag value assignment via space or equals (`--flag value`, `--flag=value`)
- Support for negative numbers in integer flags
- Environment variable fallbacks
- Configuration file support
- Regex pattern validation
- Mutually exclusive flags
- Required positional arguments
- Structured return values (JSON-like)

### Additional Examples

Here are more comprehensive examples of using the flags library:

#### Example 1: Basic Flag Usage
```bash
source "lib/core/flags.sh"

set_script_info "File processor" "process_files [options] <input_file>"
register_flag "verbose" "bool" "Enable verbose output" "v"
register_flag "output" "string" "Output file path" "o" "" "" "OUTPUT_FILE"

parse_flags "$@" || exit 1

if [[ "$(get_flag verbose)" == "true" ]]; then
    echo "Verbose mode enabled"
fi
```

#### Example 2: Advanced Validation and Mutually Exclusive Flags
```bash
source "lib/core/flags.sh"

set_script_info "User Manager" "user_manager [options]"

register_flag "create" "bool" "Create new user" "c"
register_flag "delete" "bool" "Delete user" "d"
register_flag "username" "string" "Username" "u" "" "" "" "^[a-zA-Z][a-zA-Z0-9_-]*$"
register_flag "email" "string" "Email address" "e" "" "" "USER_EMAIL" "$EMAIL_PATTERN"

register_mutex_flags "create" "delete"

parse_flags "$@" || exit 1
```

#### Example 3: Configuration File and Environment Variables
```bash
source "lib/core/flags.sh"

set_script_info "Database Backup" "db_backup [options]"
set_config_file ".dbbackup.conf"

register_flag "host" "string" "Database host" "h" "localhost" "" "DB_HOST"
register_flag "port" "int" "Database port" "p" "5432" "" "DB_PORT"
register_flag "compress" "bool" "Compress backup" "c" "false"

parse_flags "$@" || exit 1
```

#### Example 4: Required Positional Arguments
```bash
source "lib/core/flags.sh"

set_script_info "File Copy" "copy_files [options] <source> <destination>"

register_flag "force" "bool" "Overwrite existing files" "f"
register_required_positional 2 "Source and destination paths required"

parse_flags "$@" || exit 1

source_path=$(get_positional_args | head -n1)
dest_path=$(get_positional_args | tail -n1)
```

#### Example 5: Using Allowed Values and Transformers
```bash
source "lib/core/flags.sh"

set_script_info "Log Analyzer" "analyze_logs [options] <log_file>"

register_flag "level" "string" "Log level to analyze" "l" "info" "debug|info|warn|error"
register_flag "format" "string" "Output format" "f" "text" "text|json|csv"
register_required_positional 1 "Log file to analyze"

parse_flags "$@" || exit 1
```

### Flag Value Precedence

The flags library follows a strict precedence order when determining flag values:

1. **Command Line Arguments** (Highest Priority)
   - Values provided directly via command line flags take precedence over all other sources
   - Example: `--name="CLI User"` will override all other values

2. **Environment Variables**
   - If a flag has an associated environment variable and no command line value is provided
   - Example: `USER_NAME="Env User" ./script.sh` will be used if no --name flag is provided

3. **Configuration File**
   - Values from the config file are used if no command line or environment variable values exist
   - Example: `name=Config User` in `.script.conf`

4. **Default Values** (Lowest Priority)
   - Default values specified during flag registration are used if no other source provides a value
   - Example: Default value in `register_flag "name" "string" "Your name" "n" "Default User"`

This precedence order ensures predictable behavior and allows for flexible configuration through multiple methods.

### Flag Types and Formats

```bash
# Boolean flags
--flag          # Sets to true
--flag=true     # Explicit true
--flag false    # Explicit false
-f              # Short form (sets to true)

# Value flags
--name value    # Space separated
--name=value    # Equals separated
-n value        # Short form

# Combined short flags (boolean only)
-vdf            # Same as -v -d -f

# Integer flags (with negative numbers)
--count -5      # Negative values supported
--count=-5      # Equals syntax
-n -5           # Short form
```

### Validation Features

```bash
# Allowed values
register_flag "mode" "string" "Mode" "m" "start" "start|stop|restart"

# Regex pattern
register_flag "email" "string" "Email" "e" "" "" "" "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"

# Environment variable fallback
register_flag "name" "string" "Name" "n" "" "" "USER_NAME"

# Required flags
register_flag "required" "string" "Required value" "" "" "" "" "" "true"

# Mutually exclusive
register_mutex_flags "start" "stop"
```

### Configuration File Support

```bash
# .myscript.conf
verbose=true
count=5
name=John Doe
```

### Structured Output

```bash
# Get parsed arguments in JSON-like format
eval "$(get_parsed_args)"
echo "${flags}"      # {"verbose":"true","count":"5","name":"John Doe"}
echo "${positional}" # ["input.txt","output.txt"]
```

### Internal Functions and Implementation Details

#### Context Handling
The flags library uses a context-based system to manage multiple flag sets:

```bash
# Contexts are automatically initialized based on the calling script
source "lib/core/flags.sh"  # Auto-initializes context based on script name

# Manual context initialization (rarely needed)
init_flag_context "my_context"
```

#### Flag Types and Validation
The library supports three flag types with built-in validation:

1. **Boolean Flags**
   - Values: true/false, yes/no, 0/1
   - Example: `register_flag "verbose" "bool" "Enable verbose output" "v"`

2. **Integer Flags**
   - Supports negative numbers
   - Example: `register_flag "count" "int" "Count" "n" "1"`

3. **String Flags**
   - Optional pattern validation
   - Built-in patterns:
     ```bash
     # Email validation pattern
     register_flag "email" "string" "Email" "e" "" "" "" "$EMAIL_PATTERN"
     
     # Phone number validation (format: ###-###-####)
     register_flag "phone" "string" "Phone" "p" "" "" "" "$PHONE_PATTERN"
     
     # Custom pattern
     register_flag "username" "string" "Username" "u" "" "" "" "^[a-zA-Z][a-zA-Z0-9_-]*$"
     ```

#### Error Handling
The library uses specific error codes for different failure scenarios:

```bash
ERR_INVALID_FLAG=1      # Unknown or invalid flag
ERR_INVALID_VALUE=2     # Invalid value for flag type
ERR_INVALID_TYPE=3      # Unsupported flag type
ERR_CONTEXT_NOT_FOUND=4 # Invalid flag context
ERR_MUTEX_VIOLATION=5   # Mutually exclusive flags used together
ERR_MISSING_REQUIRED=6  # Required flag or argument missing
ERR_INVALID_CONFIG=7    # Invalid configuration file format
```

#### Internal Helper Functions

1. **_validate_context**
   - Validates if a flag context exists
   - Used internally by other functions
   ```bash
   if ! _validate_context "my_context"; then
       log_error "Invalid context"
       return 1
   fi
   ```

2. **_get_context_arrays**
   - Retrieves multiple context-specific arrays efficiently
   - Used for internal state management
   ```bash
   # Get multiple arrays at once
   read -r flags types defaults <<< $(_get_context_arrays "my_context" "FLAGS" "TYPES" "DEFAULTS")
   ```

3. **_auto_init_context**
   - Automatically initializes context based on calling script
   - Registers cleanup handlers
   - Called when the library is sourced

#### Configuration File Format
Configuration files should follow these rules:
- One flag per line in `key=value` format
- Lines starting with # are comments
- Keys must match registered flag names
- Values must be valid for the flag type
```bash
# Example .myscript.conf
verbose=true
count=5
name=John Doe
```

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
curl -o- https://raw.githubusercontent.com/a4abhishek/shell-scripts/v0.2.0/install.sh | bash -s -- INSTALL_VERSION=v0.2.0
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
# shellcheck source=/dev/null
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

# Logging functions handle terminal detection and color support automatically
log_info "Starting process..."
log_error "An error occurred!"
log_fatal "Critical failure, exiting!"  # This exits the script

# Logging functions write to appropriate file descriptors:
# - log_debug, log_info, log_success -> LOG_NONERROR_FD (default: stdout)
# - log_warning, log_error, log_fatal -> LOG_ERROR_FD (default: stderr)

# For returning values from functions, use echo (not logging functions)
get_user_count() {
    # Do NOT use log_info for returning values
    # log_info "5"  # Wrong! This might not show in pipelines/redirections
    
    echo "5"  # Correct! This always returns the value
    
    # Use log_* only for actual logging
    log_info "Successfully counted users"
}

# Example of proper output vs logging
user_count=$(get_user_count)  # Captures the echoed value
log_info "Found $user_count users"  # Logs the information
```

The logging library provides several safety features:
- Automatic terminal capability detection (colors, unicode)
- Proper handling of pipelines and redirections
- Separation of error (stderr) and non-error (stdout) logs
- Configurable log levels with LOG_LEVEL environment variable
- Color support that can be forced (FORCE_COLOR) or disabled (NO_COLOR)
- Complete log suppression with NOLOG environment variable
- Forced logging with FORCE_LOG (overrides NOLOG and terminal checks)

**Best Practices:**
1. Use `log_*` functions ONLY for logging information
2. Use `echo` or `printf` for returning values from functions
3. Never capture output from `log_*` functions in variables or pipelines
4. Set appropriate LOG_LEVEL for different environments (e.g., LOG_LEVEL=error in production)

**Environment Variables:**
```bash
# Set logging level (from lowest to highest priority)
# Available levels: debug=0, info=1, success=2, warning=3, error=4, fatal=5
export LOG_LEVEL=info    # Default: Show info and above
export LOG_LEVEL=debug   # Most verbose: Show all logs
export LOG_LEVEL=warning # Less verbose: Show only warning, error, and fatal
export LOG_LEVEL=error   # Show only error and fatal
export LOG_LEVEL=fatal   # Most quiet: Show only fatal errors

# Suppress all logging output
export NOLOG=1

# Force logging regardless of NOLOG or terminal settings (still honors LOG_LEVEL)
export FORCE_LOG=1

# Combine with LOG_LEVEL for fine-grained control
export FORCE_LOG=1
export LOG_LEVEL=warning  # Only show warning and above, but force them even if not terminal

# FORCE_LOG takes precedence over NOLOG
export NOLOG=1
export FORCE_LOG=1  # Logs will still be shown because FORCE_LOG overrides NOLOG

# Redirect different types of logs
export LOG_NONERROR_FD=3  # Redirect non-error logs (debug, info, success)
export LOG_ERROR_FD=4     # Redirect error logs (warning, error, fatal)
3>info.log 4>error.log   # Example: Split logs into separate files
```

**Log Level Priority:**
1. `debug` (0): Detailed debugging information
2. `info` (1): General information about script progress
3. `success` (2): Successful completion of tasks
4. `warning` (3): Potential issues that don't stop execution
5. `error` (4): Error conditions that may stop execution
6. `fatal` (5): Critical errors that will stop execution

Each level includes all higher priority levels. For example, `LOG_LEVEL=warning` will show warning, error, and fatal messages, but suppress debug, info, and success messages.

**Advanced Logging:**
The library also provides a generic `log` function for custom formatting:

```bash
# Generic log function parameters:
# log <prefix> <label> <timestamp_format> <message> <output_fd> <color_code> <color_reset>

# Examples of custom logging:
# Custom prefix and label with timestamp
log "🔹" "DEPLOY" "%H:%M:%S" "Deploying to production" 1 "\033[1;35m"

# Log without timestamp (empty timestamp format)
log ">>" "STEP" "" "Running migrations" 1 "\033[1;36m"

# Log to stderr with custom color
log "⚡" "PERF" "%Y-%m-%d" "High CPU usage detected" 2 "\033[1;33m"

# Simple log with just a message (other params empty)
log "" "" "" "Processing complete" 1 ""

# The log_* functions (log_info, log_error, etc.) are built on top of this generic log function,
# providing convenient defaults and standard formatting
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

# Basic prompt
name=$(prompt "Enter your name")

# Prompt with a default value
username=$(prompt "Enter username" "guest")

# Prompt with validation (numbers only)
age=$(prompt "Enter your age" "" "^[0-9]+$")

# Prompt with default and validation (valid IP address)
ip=$(prompt "Enter server IP" "192.168.1.1" "^([0-9]{1,3}\.){3}[0-9]{1,3}$")

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

### Progress Indicators

The progress library provides beautiful progress bars and loading indicators with Unicode and color support:

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
. "$SCRIPT_DIR/lib/core/progress.sh"

# Show a progress bar for a task with known total steps
total_steps=100
for ((i=0; i<=total_steps; i++)); do
    progress_bar "$i" "$total_steps" "Downloading package"
    sleep 0.1  # Simulate work
done
echo  # Add newline after progress completes

# Show a loading indicator for tasks with unknown duration
loader_run "Validating configuration" sleep 2

# Show a loading indicator for background tasks
(sleep 3) &
loader_wait "Running background task" "$!"
```

The progress library features:

1. **Progress Bars**
   - Shows percentage and visual progress
   - Unicode box-drawing characters when supported
   - Fallback to ASCII characters when Unicode is disabled
   - Color transitions based on progress (yellow → blue → green)

2. **Loading Indicators**
   - Animated spinner with task description
   - Success (✓) or failure (✗) indicators on completion
   - Blinking dots for in-progress state
   - Clean output formatting

3. **Automatic Feature Detection**
   - Unicode support detection (`HAS_UNICODE_SUPPORT`)
   - Color support detection (`HAS_COLOR_SUPPORT`)
   - Graceful fallbacks for limited environments

**Environment Variables:**
```bash
# Force or disable features
export HAS_UNICODE_SUPPORT=true   # Force Unicode characters
export HAS_COLOR_SUPPORT=true     # Force colored output
export NO_COLOR=1                 # Disable colors (takes precedence)
export NO_UNICODE=1              # Disable Unicode (takes precedence)

# Locale settings also affect Unicode support
export LC_ALL=C                  # Disable Unicode
export LANG=en_US.UTF-8         # Enable Unicode (if supported)
```

**Example Output:**

With Unicode and color support:
```
Downloading package [██████████████▌              ] 48% 
✓ Configuration validated
✗ Background task failed
```

Without Unicode or color support:
```
Downloading package [==============>             ] 48% 
[OK] Configuration validated
[FAILED] Background task failed
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

We welcome contributions to help improve the Shell Scripts Library! Whether you're fixing bugs, adding new features, or updating documentation, your input is appreciated. To contribute, please follow these steps in the [CONTRIBUTING.md](CONTRIBUTING.md).

## License

This project is licensed under the [APACHE LICENSE, VERSION 2.0](LICENSE).

---

Happy scripting, and thank you for contributing to the Shell Scripts Library! 🚀
