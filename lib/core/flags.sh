#!/usr/bin/env bash

# @file flags.sh
# @brief Command-line flag parsing and validation library
# @description
#   A robust library for parsing and validating command-line flags in shell scripts.
#   Features:
#   - Support for boolean, integer, and string flags
#   - Short and long flag formats (e.g., -v, --verbose)
#   - Flag value assignment via space or equals (--flag value, --flag=value)
#   - Support for negative numbers in integer flags
#   - Environment variable fallbacks
#   - Configuration file support (which overrides defaults)
#   - Regex pattern validation
#   - Mutually exclusive flags
#   - Required positional arguments
#   - Structured return values (JSON-like)
#
# @usage
#   #!/usr/bin/env bash
#   source "lib/core/flags.sh"
#
#   # Initialize flags
#   set_script_info "My script description" "myscript [options] <input>"
#   set_config_file ".myscript.conf"
#
#   # Register flags
#   register_flag "verbose" "bool" "Enable verbose output" "v"
#   register_flag "count" "int" "Number of iterations" "n" "1"
#   register_flag "name" "string" "Your name" "u" "Default User" "" "USER_NAME"
#   register_flag "mode" "string" "Operation mode" "m" "start" "start|stop|restart"
#   register_flag "email" "string" "Email address" "e" "" "" "" "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
#
#   # Register mutually exclusive flags
#   register_mutex_flags "start" "stop"
#
#   # Register required positional arguments
#   register_required_positional 1 "Input file to process"
#
#   # Parse flags
#   parse_flags "$@" || exit 1
#
#   # Use flags
#   [[ "$(get_flag verbose)" == "true" ]] && log_info "Verbose mode enabled"
#   count=$(get_flag count)
#   name=$(get_flag name)
#
# @examples
#
# Example 1: Basic flag usage
#   source "lib/core/flags.sh"
#
#   set_script_info "File processor" "process_files [options] <input_file>"
#   register_flag "verbose" "bool" "Enable verbose output" "v"
#   register_flag "output" "string" "Output file path" "o" "" "" "OUTPUT_FILE"
#
#   parse_flags "$@" || exit 1
#
#   if [[ "$(get_flag verbose)" == "true" ]]; then
#     echo "Verbose mode enabled"
#   fi
#
# Example 2: Advanced validation and mutually exclusive flags
#   source "lib/core/flags.sh"
#
#   set_script_info "User Manager" "user_manager [options]"
#
#   register_flag "create" "bool" "Create new user" "c"
#   register_flag "delete" "bool" "Delete user" "d"
#   register_flag "username" "string" "Username" "u" "" "" "" "^[a-zA-Z][a-zA-Z0-9_-]*$"
#   register_flag "email" "string" "Email address" "e" "" "" "USER_EMAIL" "$EMAIL_PATTERN"
#
#   register_mutex_flags "create" "delete"
#
#   parse_flags "$@" || exit 1
#
# Example 3: Configuration file and environment variables
#   source "lib/core/flags.sh"
#
#   set_script_info "Database Backup" "db_backup [options]"
#   set_config_file ".dbbackup.conf"
#
#   register_flag "host" "string" "Database host" "h" "localhost" "" "DB_HOST"
#   register_flag "port" "int" "Database port" "p" "5432" "" "DB_PORT"
#   register_flag "compress" "bool" "Compress backup" "c" "false"
#
#   parse_flags "$@" || exit 1
#
# Example 4: Required positional arguments
#   source "lib/core/flags.sh"
#
#   set_script_info "File Copy" "copy_files [options] <source> <destination>"
#
#   register_flag "force" "bool" "Overwrite existing files" "f"
#   register_required_positional 2 "Source and destination paths required"
#
#   parse_flags "$@" || exit 1
#
#   source_path=$(get_positional_args | head -n1)
#   dest_path=$(get_positional_args | tail -n1)
#
# Example 5: Using allowed values and transformers
#   source "lib/core/flags.sh"
#
#   set_script_info "Log Analyzer" "analyze_logs [options] <log_file>"
#
#   register_flag "level" "string" "Log level to analyze" "l" "info" "debug|info|warn|error"
#   register_flag "format" "string" "Output format" "f" "text" "text|json|csv"
#   register_required_positional 1 "Log file to analyze"
#
#   parse_flags "$@" || exit 1

# Prevent duplicate sourcing
if [[ -n "${_LIB_FLAGS_LOADED:-}" ]]; then return; fi
_LIB_FLAGS_LOADED=true

# Ensure script stops on errors and propagates failures properly.
set -euo pipefail

# Error codes for different failure types
declare -gr ERR_INVALID_FLAG=1
declare -gr ERR_INVALID_VALUE=2
declare -gr ERR_INVALID_TYPE=3
declare -gr ERR_CONTEXT_NOT_FOUND=4
declare -gr ERR_MUTEX_VIOLATION=5
declare -gr ERR_MISSING_REQUIRED=6
declare -gr ERR_INVALID_CONFIG=7

CORE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$CORE_LIB_DIR/logging.sh"
# shellcheck source=/dev/null
. "$CORE_LIB_DIR/preflight.sh"

# Function to check minimum required Bash version
_check_bash_version() {
    local min_version="4.3"
    if [[ "${BASH_VERSION:-0}" < "$min_version" ]]; then
        log_error "This script requires Bash version $min_version or higher"
        log_error "Current version: $BASH_VERSION"
        return 1
    fi
    return 0
}

register_preflight _check_bash_version

# Constants and type definitions
declare -gr VALID_FLAG_TYPES=("bool" "int" "string")
declare -gr EMAIL_PATTERN='^[a-zA-Z0-9]([a-zA-Z0-9_%+-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9_%+-]*[a-zA-Z0-9])?)*@[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$'
declare -gr PHONE_PATTERN='^[0-9]{3}-[0-9]{3}-[0-9]{4}$'

# Initialize global arrays
declare -gA _FLAG_CONTEXTS=()
declare -g _CURRENT_CONTEXT=""
declare -gA _FLAGS=()
declare -gA _FLAG_DESCRIPTIONS=()
declare -gA _FLAG_DEFAULTS=()
declare -gA _FLAG_TYPES=()
declare -gA _FLAG_SHORTHANDS=()
declare -gA _FLAG_REQUIRED=()
declare -gA _FLAG_ALLOWED_VALUES=()
declare -gA _FLAG_ENV_VARS=()
declare -gA _FLAG_REGEX_PATTERNS=()
declare -gA _FLAG_GROUPS=()
declare -gA _FLAG_TRANSFORMERS=()
declare -ga _POSITIONAL_ARGS=()
declare -ga _REQUIRED_POSITIONAL=()
declare -ga _MUTUALLY_EXCLUSIVE_GROUPS=()

# Script metadata for help message
declare -g _SCRIPT_DESCRIPTION=""
declare -g _SCRIPT_USAGE=""
declare -g _SCRIPT_EXAMPLES=""
declare -g _CONFIG_FILE=""

# Structured return value for parsed arguments
declare -gA ARGS=([flags]="" [positional]="")

# Function to set configuration file
set_config_file() {
    _CONFIG_FILE="$1"
}

# Function to initialize arrays for a context
_init_context_arrays() {
    local context="$1"
    # Initialize all arrays with empty values
    declare -gA "_FLAGS_${context}=()"
    declare -gA "_FLAG_DESCRIPTIONS_${context}=()"
    declare -gA "_FLAG_DEFAULTS_${context}=()"
    declare -gA "_FLAG_TYPES_${context}=()"
    declare -gA "_FLAG_SHORTHANDS_${context}=()"
    declare -gA "_FLAG_REQUIRED_${context}=()"
    declare -gA "_FLAG_ALLOWED_VALUES_${context}=()"
    declare -gA "_FLAG_ENV_VARS_${context}=()"
    declare -gA "_FLAG_REGEX_PATTERNS_${context}=()"
    declare -gA "_FLAG_GROUPS_${context}=()"
    declare -gA "_FLAG_TRANSFORMERS_${context}=()"
    declare -ga "_POSITIONAL_ARGS_${context}=()"
    declare -ga "_REQUIRED_POSITIONAL_${context}=()"
    declare -ga "_MUTUALLY_EXCLUSIVE_GROUPS_${context}=()"
}

# Initialize a new flag context
init_flag_context() {
    local context="$1"
    if [[ -v "_FLAG_CONTEXTS[$context]" ]]; then
        log_error "Context '$context' already exists"
        return 1
    fi

    # Initialize context
    _FLAG_CONTEXTS["$context"]=""
    _init_context_arrays "$context"
    _CURRENT_CONTEXT="$context"
    return 0
}

# Automatically initialize context based on the calling script
_auto_init_context() {
    local calling_script="${BASH_SOURCE[1]}"
    local script_name
    script_name="$(basename "$calling_script" .sh)"
    local script_name
    script_name="${script_name//-/_}"
    script_name="${script_name//./_}"

    # If context already exists, return
    if [[ -v "_FLAG_CONTEXTS[$script_name]" ]]; then
        _CURRENT_CONTEXT="$script_name"
        return 0
    fi

    # Initialize new context
    init_flag_context "$script_name"

    # Register cleanup trap for this context
    # Create a function with a unique name to handle cleanup
    eval "_cleanup_context_${script_name}() {
        cleanup_flag_context '${script_name}' 2>/dev/null || true
    }"

    # Register the cleanup function as the trap
    # shellcheck disable=SC2064
    trap "_cleanup_context_${script_name}" EXIT
}

# Call auto init when the library is sourced
_auto_init_context

# Clean up a flag context
cleanup_flag_context() {
    local context="$1"
    if [[ ! -v "_FLAG_CONTEXTS[$context]" ]]; then
        log_error "Context '$context' does not exist"
        return 1
    fi

    # Clean up context-specific arrays
    unset "_FLAG_CONTEXTS[$context]"
    unset "_FLAGS_${context}"
    unset "_FLAG_DESCRIPTIONS_${context}"
    unset "_FLAG_DEFAULTS_${context}"
    unset "_FLAG_TYPES_${context}"
    unset "_FLAG_SHORTHANDS_${context}"
    unset "_FLAG_REQUIRED_${context}"
    unset "_FLAG_ALLOWED_VALUES_${context}"
    unset "_FLAG_ENV_VARS_${context}"
    unset "_FLAG_REGEX_PATTERNS_${context}"
    unset "_FLAG_GROUPS_${context}"
    unset "_FLAG_TRANSFORMERS_${context}"
    unset "_POSITIONAL_ARGS_${context}"
    unset "_REQUIRED_POSITIONAL_${context}"
    unset "_MUTUALLY_EXCLUSIVE_GROUPS_${context}"

    [[ "$_CURRENT_CONTEXT" == "$context" ]] && _CURRENT_CONTEXT=""
    return 0
}

# Helper function to get context-specific array name
_get_context_array() {
    local array_name="$1"
    local context="${2:-$_CURRENT_CONTEXT}"

    if [[ -z "$context" ]]; then
        log_error "No active context"
        return 1
    fi

    echo "_${array_name}_${context}"
}

# Helper function to set flag property
_set_flag_property() {
    local property="$1"
    local flag_name="$2"
    local value="$3"

    local array_name
    array_name=$(_get_context_array "FLAG_$property") || return 1

    declare -n array_ref="$array_name"
    array_ref["${flag_name}"]="$value"
    return 0
}

# Function to validate flag name
_validate_flag_name() {
    local flag_name="$1"
    # Flag name must start with a letter and contain only letters, numbers, underscores, and hyphens
    if ! [[ "$flag_name" =~ ^[a-zA-Z][a-zA-Z0-9_-]*$ ]]; then
        log_error "Invalid flag name: '$flag_name'. Flag names must start with a letter and contain only letters, numbers, underscores, and hyphens."
        return 1
    fi
    return 0
}

# Function to validate environment variable name
_validate_env_var_name() {
    local env_var="$1"
    # Environment variable names must start with a letter and contain only uppercase letters, numbers, and underscores
    if ! [[ "$env_var" =~ ^[A-Z][A-Z0-9_]*$ ]]; then
        log_error "Invalid environment variable name: '$env_var'. Environment variable names must start with a letter and contain only uppercase letters, numbers, and underscores."
        return 1
    fi
    return 0
}

# Function to validate configuration file format
_validate_config_line() {
    local line="$1"
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && return 0
    # Line must be in key=value format with optional whitespace
    if ! [[ "$line" =~ ^[[:space:]]*[a-zA-Z][a-zA-Z0-9_]*[[:space:]]*=[[:space:]]*.*$ ]]; then
        log_error "Invalid configuration file format. Each line must be in 'key=value' format, where key starts with a letter and contains only letters, numbers, and underscores."
        return 1
    fi
    return 0
}

# Function to validate flag type
_validate_flag_type() {
    local type="$1"
    local valid=false
    for valid_type in "${VALID_FLAG_TYPES[@]}"; do
        if [[ "$type" == "$valid_type" ]]; then
            valid=true
            break
        fi
    done
    if [[ "$valid" != "true" ]]; then
        log_error "Invalid flag type: '$type'. Must be one of: ${VALID_FLAG_TYPES[*]}"
        return 1
    fi
    return 0
}

# Function to validate regex pattern
_validate_regex_pattern() {
    local pattern="$1"
    local test_value="$2"

    # Handle special patterns
    case "$pattern" in
        "$EMAIL_PATTERN")
            _validate_email_pattern "$test_value"
            return $?
            ;;
        "$PHONE_PATTERN")
            _validate_phone_pattern "$test_value"
            return $?
            ;;
        *)
            # For non-special patterns, check against the provided pattern
            if ! echo "$test_value" | grep -qE "$pattern"; then
                return 1
            fi
            ;;
    esac

    return 0
}

# Function to validate email pattern
_validate_email_pattern() {
    local email="$1"

    # Split email into local and domain parts
    local local_part domain
    IFS='@' read -r local_part domain <<< "$email"

    # Check for consecutive dots in either part
    if [[ "$local_part" =~ \.\. ]] || [[ "$domain" =~ \.\. ]]; then
        log_error "Email address cannot contain consecutive dots"
        return 1
    fi

    # Check for dots or hyphens at start/end of parts
    if [[ "$local_part" =~ ^[.-] ]] || [[ "$local_part" =~ [.-]$ ]] \
        || [[ "$domain" =~ ^[.-] ]] || [[ "$domain" =~ [.-]$ ]]; then
        log_error "Email parts cannot start or end with dots or hyphens"
        return 1
    fi

    # Check for invalid characters in local part
    if [[ ! "$local_part" =~ ^[a-zA-Z0-9][a-zA-Z0-9._%+-]*[a-zA-Z0-9]$ ]]; then
        log_error "Email local part must start and end with alphanumeric characters"
        return 1
    fi

    # Check for invalid characters in domain part
    if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]\.[a-zA-Z]{2,}$ ]]; then
        log_error "Email domain must start and end with alphanumeric characters"
        return 1
    fi

    return 0
}

# Function to validate phone pattern
_validate_phone_pattern() {
    local phone="$1"

    if [[ ! "$phone" =~ ^[0-9]{3}-[0-9]{3}-[0-9]{4}$ ]]; then
        log_error "Phone number must be in format: ###-###-####"
        return 1
    fi

    return 0
}

# Function to validate type with improved error messages
_validate_type() {
    local type="$1"
    local value="${2:-}"
    local flag="${3:-}"

    case "$type" in
        bool)
            if [[ -n "$value" ]]; then
                case "$value" in
                    true | false | 0 | 1 | yes | no) return 0 ;;
                    *)
                        [[ -n "$flag" ]] && log_error "Flag '$flag' requires a boolean value (true/false/0/1/yes/no)"
                        return "$ERR_INVALID_VALUE"
                        ;;
                esac
            fi
            ;;
        int)
            # Empty value is not allowed for integers
            if [[ -z "$value" ]]; then
                [[ -n "$flag" ]] && log_error "Flag '$flag' requires an integer value"
                return "$ERR_INVALID_VALUE"
            fi
            # Check for valid integer format (no decimals, only digits with optional sign)
            if ! [[ "$value" =~ ^[+-]?[0-9]+$ ]]; then
                [[ -n "$flag" ]] && log_error "Flag '$flag' requires an integer value"
                return "$ERR_INVALID_VALUE"
            fi
            ;;
        string)
            # All strings are valid
            return 0
            ;;
        *)
            log_error "Invalid flag type: '$type'. Must be one of: bool int string"
            return "$ERR_INVALID_TYPE"
            ;;
    esac
    return 0
}

# @function register_flag
# @brief Register a command-line flag with its properties
# @param flag_name    The name of the flag (e.g., "verbose" for --verbose)
# @param flag_type    The type of the flag: "bool", "int", or "string"
# @param description  A description of the flag for help messages
# @param shorthand    Optional: Single-character shorthand (e.g., "v" for -v)
# @param default      Optional: Default value if flag is not provided
# @param allowed      Optional: Pipe-separated list of allowed values
# @param env_var      Optional: Environment variable to use as fallback
# @param pattern      Optional: Regex pattern for value validation
# @return 0 on success, 1 on failure
# @example
#   register_flag "verbose" "bool" "Enable verbose output" "v"
#   register_flag "count" "int" "Number of iterations" "n" "1"
#   register_flag "mode" "string" "Operation mode" "m" "start" "start|stop|restart"
register_flag() {
    local flag_name="$1"
    local flag_type="$2"
    local description="$3"
    local shorthand="${4:-}"
    local default_value="${5:-}"
    local allowed_values="${6:-}"
    local env_var="${7:-}"
    local regex_pattern="${8:-}"

    # Validate required parameters
    if [[ -z "$flag_name" ]]; then
        log_error "Flag name is required"
        return 1
    fi

    if [[ -z "$flag_type" ]]; then
        log_error "Flag type is required"
        return 1
    fi

    if [[ -z "$description" ]]; then
        log_error "Flag description is required"
        return 1
    fi

    # Get context-specific arrays
    local flags_array
    flags_array=$(_get_context_array "FLAGS") || return 1

    # Validate flag name
    if ! _validate_flag_name "$flag_name"; then
        return 1
    fi

    # Validate flag type
    if ! _validate_flag_type "$flag_type"; then
        return 1
    fi

    # Validate shorthand
    if [[ -n "$shorthand" ]]; then
        if [[ ${#shorthand} -ne 1 ]]; then
            log_error "Shorthand must be a single character"
            return 1
        fi
        # Check if shorthand is already used
        local shorthands_array
        shorthands_array=$(_get_context_array "FLAG_SHORTHANDS") || return 1
        declare -n shorthands_ref="$shorthands_array"
        for existing_flag in "${!shorthands_ref[@]}"; do
            if [[ "${shorthands_ref[$existing_flag]}" == "$shorthand" ]]; then
                log_error "Shorthand '$shorthand' already used by flag '$existing_flag'"
                return 1
            fi
        done
    fi

    # Validate env var
    if [[ -n "$env_var" ]]; then
        if ! _validate_env_var_name "$env_var"; then
            return 1
        fi
    fi

    # Initialize flag with appropriate default value
    declare -n flags_ref="$flags_array"
    if [[ "$flag_type" == "bool" ]]; then
        flags_ref["$flag_name"]="false"
    else
        flags_ref["$flag_name"]=""
    fi

    # Set flag properties
    _set_flag_property "DESCRIPTIONS" "$flag_name" "$description"
    _set_flag_property "TYPES" "$flag_name" "$flag_type"
    [[ -n "$shorthand" ]] && _set_flag_property "SHORTHANDS" "$flag_name" "$shorthand"
    [[ -n "$default_value" ]] && _set_flag_property "DEFAULTS" "$flag_name" "$default_value"
    [[ -n "$allowed_values" ]] && _set_flag_property "ALLOWED_VALUES" "$flag_name" "$allowed_values"
    [[ -n "$env_var" ]] && _set_flag_property "ENV_VARS" "$flag_name" "$env_var"
    [[ -n "$regex_pattern" ]] && _set_flag_property "REGEX_PATTERNS" "$flag_name" "$regex_pattern"

    # Initialize with default value if provided
    if [[ -n "$default_value" ]]; then
        if ! _validate_flag_value "$flag_name" "$default_value"; then
            log_error "Invalid default value for flag '$flag_name': $default_value"
            return 1
        fi
        flags_ref["$flag_name"]="$default_value"
    fi

    log_debug "Registered flag '$flag_name' of type '$flag_type'"
    return 0
}

# Function to get flag name from shorthand
_get_flag_from_shorthand() {
    local shorthand="$1"
    local shorthands_array
    shorthands_array=$(_get_context_array "FLAG_SHORTHANDS") || return 1
    declare -n shorthands_ref="$shorthands_array"

    for flag in "${!shorthands_ref[@]}"; do
        if [[ "${shorthands_ref[$flag]}" == "$shorthand" ]]; then
            echo "$flag"
            return 0
        fi
    done
    return 1
}

# Function to validate flag value based on type and constraints
_validate_flag_value() {
    local flag="$1"
    local value="$2"

    # Get context-specific arrays
    local types_array allowed_values_array required_array regex_patterns_array
    types_array=$(_get_context_array "FLAG_TYPES") || return 1
    allowed_values_array=$(_get_context_array "FLAG_ALLOWED_VALUES") || return 1
    required_array=$(_get_context_array "FLAG_REQUIRED") || return 1
    regex_patterns_array=$(_get_context_array "FLAG_REGEX_PATTERNS") || return 1

    declare -n types_ref="$types_array"
    declare -n allowed_values_ref="$allowed_values_array"
    declare -n required_ref="$required_array"
    declare -n regex_patterns_ref="$regex_patterns_array"

    local type="${types_ref[$flag]}"

    # Skip validation for empty optional values
    if [[ -z "$value" ]] && [[ -v "required_ref[$flag]" ]] && [[ "${required_ref[$flag]:-false}" != "true" ]]; then
        return 0
    fi

    # Type validation
    if ! _validate_type "$type" "$value" "$flag"; then
        return 1
    fi

    # Allowed values validation
    if [[ -v "allowed_values_ref[$flag]" ]]; then
        local allowed_values="${allowed_values_ref[$flag]}"
        local valid=false
        local IFS='|'
        for allowed in $allowed_values; do
            if [[ "$value" == "$allowed" ]]; then
                valid=true
                break
            fi
        done
        if [[ "$valid" == "false" ]]; then
            log_error "Flag '$flag' must be one of: ${allowed_values//|/,}"
            return 1
        fi
    fi

    # Regex pattern validation
    if [[ -v "regex_patterns_ref[$flag]" ]]; then
        local pattern="${regex_patterns_ref[$flag]}"
        if ! _validate_regex_pattern "$pattern" "$value"; then
            log_error "Flag '$flag' value does not match required pattern: $pattern"
            return 1
        fi
    fi

    return 0
}

# Function to validate mutually exclusive flags
_validate_mutex_flags() {
    local mutex_groups_array flags_array
    mutex_groups_array=$(_get_context_array "MUTUALLY_EXCLUSIVE_GROUPS") || return 1
    flags_array=$(_get_context_array "FLAGS") || return 1

    declare -n mutex_groups_ref="$mutex_groups_array"
    declare -n flags_ref="$flags_array"

    for group in "${mutex_groups_ref[@]}"; do
        local set_count=0
        local set_flags=""
        for flag in $group; do
            if [[ "${flags_ref[$flag]}" == "true" ]]; then
                set_count=$((set_count + 1))
                [[ -n "$set_flags" ]] && set_flags+=", "
                set_flags+="$flag"
            fi
        done
        if [[ $set_count -gt 1 ]]; then
            log_error "Flags cannot be used together: $set_flags"
            return 1
        fi
    done
    return 0
}

# Function to load configuration from file
_load_config_file() {
    local config_file="$1"
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi

    # Get context-specific flags array
    local flags_array
    flags_array=$(_get_context_array "FLAGS") || return 1
    declare -n flags_ref="$flags_array"

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue

        # Validate line format
        if ! _validate_config_line "$line"; then
            return 1
        fi

        # Trim whitespace
        key="${line%%=*}"
        value="${line#*=}"
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"

        # Only set if flag exists and not already set
        if [[ -v "flags_ref[$key]" ]]; then
            if ! _validate_flag_value "$key" "$value"; then
                log_error "Invalid value in config file for flag '$key': $value"
                return 1
            fi
            flags_ref["$key"]="$value"
        fi
    done < "$config_file"
    return 0
}

# Function to escape JSON string
_escape_json() {
    local str="$1"
    str="${str//\\/\\\\}" # Must come first
    str="${str//\"/\\\"}"
    str="${str//\b/\\b}"
    str="${str//\f/\\f}"
    str="${str//\n/\\n}"
    str="${str//\r/\\r}"
    str="${str//\t/\\t}"
    # Handle control characters - must use sed here due to complex pattern
    # shellcheck disable=SC2001
    str=$(echo "$str" | sed 's/[\x00-\x1F\x7F]/\\u00&/g')
    echo "$str"
}

# @function parse_flags
# @brief Parse command line arguments according to registered flags
# @param args...  Command line arguments to parse
# @return 0 on success, 1 on failure
# @example
#   parse_flags "$@" || exit 1
parse_flags() {
    # Get context-specific arrays
    local flags_array positional_array types_array defaults_array env_vars_array
    flags_array=$(_get_context_array "FLAGS") || return 1
    positional_array=$(_get_context_array "POSITIONAL_ARGS") || return 1
    types_array=$(_get_context_array "FLAG_TYPES") || return 1
    defaults_array=$(_get_context_array "FLAG_DEFAULTS") || return 1
    env_vars_array=$(_get_context_array "FLAG_ENV_VARS") || return 1

    # Clear positional args array and ARGS
    declare -n positional_ref="$positional_array"
    declare -n types_ref="$types_array"
    declare -n flags_ref="$flags_array"
    declare -n defaults_ref="$defaults_array"
    declare -n env_vars_ref="$env_vars_array"
    positional_ref=()
    ARGS=([flags]="" [positional]="")

    # First, initialize all flags with appropriate default values
    for flag in "${!types_ref[@]}"; do
        if [[ "${types_ref[$flag]}" == "bool" ]]; then
            flags_ref["$flag"]="false"
        else
            flags_ref["$flag"]=""
        fi
    done

    # Second, set default values for all flags
    for flag in "${!defaults_ref[@]}"; do
        flags_ref["$flag"]="${defaults_ref[$flag]}"
    done

    # Third, load config file if specified
    if [[ -n "$_CONFIG_FILE" ]] && [[ -f "$_CONFIG_FILE" ]]; then
        if ! _load_config_file "$_CONFIG_FILE"; then
            show_help
            return 1
        fi
    fi

    # Fourth, load environment variables (overriding config file values)
    for flag in "${!env_vars_ref[@]}"; do
        local env_var="${env_vars_ref[$flag]}"
        if [[ -n "${!env_var:-}" ]]; then
            if ! _validate_flag_value "$flag" "${!env_var}"; then
                log_error "Invalid environment variable value for flag '$flag': ${!env_var}"
                show_help
                return 1
            fi
            flags_ref["$flag"]="${!env_var}"
        fi
    done

    # Parse command line arguments (highest precedence)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help | -h)
                show_help
                exit 0
                ;;
            --*=*)
                local flag="${1#--}"
                local value="${flag#*=}"
                flag="${flag%%=*}"

                if [[ ! -v "flags_ref[$flag]" ]]; then
                    log_error "Unknown flag: --$flag"
                    show_help
                    return 1
                fi

                # Get flag type
                if [[ "${types_ref[$flag]}" == "bool" ]]; then
                    case "$value" in
                        true | false)
                            flags_ref["$flag"]="$value"
                            ;;
                        *)
                            log_error "Flag '--$flag' requires a boolean value (true/false), got: $value"
                            show_help
                            return 1
                            ;;
                    esac
                    shift
                    continue
                fi

                # Validate value
                if ! _validate_flag_value "$flag" "$value"; then
                    show_help
                    return 1
                fi

                flags_ref["$flag"]="$value"
                shift
                continue
                ;;
            --*)
                local flag="${1#--}"

                if [[ ! -v "flags_ref[$flag]" ]]; then
                    log_error "Unknown flag: --$flag"
                    show_help
                    return 1
                fi

                # Handle boolean flags
                if [[ "${types_ref[$flag]}" == "bool" ]]; then
                    if [[ $# -ge 2 ]] && [[ "$2" =~ ^(true|false)$ ]]; then
                        flags_ref["$flag"]="$2"
                        shift
                    else
                        flags_ref["$flag"]="true"
                    fi
                else
                    # Non-boolean flags require a value
                    if [[ $# -lt 2 || "$2" =~ ^- && ! "$2" =~ ^-?[0-9]+$ ]]; then
                        log_error "Flag --$flag requires a value"
                        show_help
                        return 1
                    fi
                    # Validate value
                    if ! _validate_flag_value "$flag" "$2"; then
                        show_help
                        return 1
                    fi
                    flags_ref["$flag"]="$2"
                    shift
                fi
                ;;
            -*)
                local shorthand="${1#-}"
                # Handle combined shorthand flags (-abc)
                while [[ -n "$shorthand" ]]; do
                    local curr_flag="${shorthand:0:1}"
                    shorthand="${shorthand:1}"

                    local flag
                    if ! flag=$(_get_flag_from_shorthand "$curr_flag"); then
                        log_error "Unknown shorthand flag: -$curr_flag"
                        show_help
                        return 1
                    fi

                    # Handle boolean flags
                    if [[ "${types_ref[$flag]}" == "bool" ]]; then
                        flags_ref["$flag"]="true"
                    else
                        # If there are more shorthand flags, it's an error
                        if [[ -n "$shorthand" ]]; then
                            log_error "Non-boolean shorthand flag -$curr_flag cannot be combined"
                            show_help
                            return 1
                        fi
                        # Use next argument as value
                        if [[ $# -lt 2 || "$2" =~ ^- && ! "$2" =~ ^-?[0-9]+$ ]]; then
                            log_error "Flag -$curr_flag requires a value"
                            show_help
                            return 1
                        fi
                        # Validate value
                        if ! _validate_flag_value "$flag" "$2"; then
                            show_help
                            return 1
                        fi
                        flags_ref["$flag"]="$2"
                        shift
                    fi
                done
                ;;
            *)
                positional_ref+=("$1")
                ;;
        esac
        shift
    done

    # Validate mutually exclusive flags
    if ! _validate_mutex_flags; then
        show_help
        return 1
    fi

    # Validate required positional arguments
    local required_positional_array
    required_positional_array=$(_get_context_array "REQUIRED_POSITIONAL") || return 1
    declare -n required_positional_ref="$required_positional_array"
    if [[ ${#required_positional_ref[@]} -gt 0 ]]; then
        local required_count="${required_positional_ref[0]}"
        if [[ ${#positional_ref[@]} -lt $required_count ]]; then
            log_error "Expected at least $required_count positional argument(s)"
            [[ -n "${required_positional_ref[1]}" ]] && log_error "${required_positional_ref[1]}"
            show_help
            return 1
        fi
    fi

    # Build the structured return value with sorted keys
    local flags_json="{"
    local first=true
    # Sort flags alphabetically if there are any flags
    if [[ ${#flags_ref[@]} -gt 0 ]]; then
        while IFS= read -r flag; do
            if [[ "$first" != "true" ]]; then
                flags_json+=","
            fi
            first=false
            local value="${flags_ref[$flag]}"
            if [[ -z "$value" ]]; then
                flags_json+="\"$flag\":null"
            else
                flags_json+="\"$flag\":\"$(_escape_json "$value")\""
            fi
        done < <(printf '%s\n' "${!flags_ref[@]}" | sort)
    fi
    flags_json+="}"
    ARGS[flags]="$flags_json"

    local args_json="["
    first=true
    for arg in "${positional_ref[@]}"; do
        if [[ "$first" != "true" ]]; then
            args_json+=","
        fi
        first=false
        args_json+="\"$(_escape_json "$arg")\""
    done
    args_json+="]"
    ARGS[positional]="$args_json"

    return 0
}

# @function get_flag
# @brief Get the value of a flag
# @arg $1 Flag name
# @return Flag value
get_flag() {
    local flag_name="$1"
    local flags_array types_array
    flags_array=$(_get_context_array "FLAGS") || return 1
    types_array=$(_get_context_array "FLAG_TYPES") || return 1

    declare -n flags_ref="$flags_array"
    declare -n types_ref="$types_array"

    if [[ ! -v "flags_ref[$flag_name]" ]]; then
        log_error "Unknown flag: $flag_name"
        return 1
    fi

    # Special handling for boolean flags
    if [[ "${types_ref[$flag_name]}" == "bool" ]]; then
        local value="${flags_ref[$flag_name]}"
        if [[ "$value" == "true" ]]; then
            echo "true"
        else
            echo "false"
        fi
    else
        echo "${flags_ref[$flag_name]}"
    fi
}

# @function get_positional_args
# @brief Get all positional arguments
# @return One positional argument per line
# @example
#   while IFS= read -r arg; do
#     process_file "$arg"
#   done < <(get_positional_args)
get_positional_args() {
    local positional_array
    positional_array=$(_get_context_array "POSITIONAL_ARGS") || return 1
    declare -n positional_ref="$positional_array"

    # Only output if there are positional arguments
    if [[ ${#positional_ref[@]} -gt 0 ]]; then
        printf "%s\n" "${positional_ref[@]}"
    fi
}

# @function get_parsed_args
# @brief Get all parsed arguments in a structured format
# @return JSON-like string of parsed flags and positional arguments
# @example
#   eval "$(get_parsed_args)"
#   echo "${flags}"     # JSON object of flag values
#   echo "${positional}" # JSON array of positional args
get_parsed_args() {
    echo "flags=${ARGS[flags]}"
    [[ "${ARGS[positional]}" != "[]" ]] && echo "positional=${ARGS[positional]}"
}

# @function show_help
# @brief Display help message with all registered flags
# @return None
show_help() {
    # Get context-specific arrays
    local flags_array descriptions_array defaults_array types_array shorthands_array
    local required_array allowed_values_array env_vars_array regex_patterns_array transformers_array
    flags_array=$(_get_context_array "FLAGS") || return 1
    descriptions_array=$(_get_context_array "FLAG_DESCRIPTIONS") || return 1
    defaults_array=$(_get_context_array "FLAG_DEFAULTS") || return 1
    types_array=$(_get_context_array "FLAG_TYPES") || return 1
    shorthands_array=$(_get_context_array "FLAG_SHORTHANDS") || return 1
    required_array=$(_get_context_array "FLAG_REQUIRED") || return 1
    allowed_values_array=$(_get_context_array "FLAG_ALLOWED_VALUES") || return 1
    env_vars_array=$(_get_context_array "FLAG_ENV_VARS") || return 1
    regex_patterns_array=$(_get_context_array "FLAG_REGEX_PATTERNS") || return 1
    transformers_array=$(_get_context_array "FLAG_TRANSFORMERS") || return 1

    declare -n flags_ref="$flags_array"
    declare -n descriptions_ref="$descriptions_array"
    declare -n defaults_ref="$defaults_array"
    declare -n types_ref="$types_array"
    declare -n shorthands_ref="$shorthands_array"
    declare -n required_ref="$required_array"
    declare -n allowed_values_ref="$allowed_values_array"
    declare -n env_vars_ref="$env_vars_array"
    declare -n regex_patterns_ref="$regex_patterns_array"
    declare -n transformers_ref="$transformers_array"

    # Get terminal width or use a default
    local COLUMNS
    COLUMNS=$(tput cols 2> /dev/null || echo 80)

    # Show script description if available
    if [[ -n "$_SCRIPT_DESCRIPTION" ]]; then
        echo "$_SCRIPT_DESCRIPTION"
        echo
    fi

    # Show usage if provided, otherwise show default usage
    if [[ -n "$_SCRIPT_USAGE" ]]; then
        echo "Usage: $_SCRIPT_USAGE"
    else
        echo "Usage: ${0##*/} [options] [arguments]"
    fi
    echo

    # Show configuration file if specified
    if [[ -n "$_CONFIG_FILE" ]]; then
        echo "Config file: $_CONFIG_FILE"
        echo
    fi

    # Function to print a wrapped line with proper indentation
    print_wrapped_line() {
        local indent="$1"
        local text="$2"
        local width=$((COLUMNS - indent))
        [[ $width -lt 20 ]] && width=50

        local line=""
        for word in $text; do
            if [[ ${#line} -eq 0 ]]; then
                line="$word"
            elif [[ $((${#line} + ${#word} + 1)) -le $width ]]; then
                line+=" $word"
            else
                printf "%*s%s\n" "$indent" "" "$line"
                line="$word"
            fi
        done
        [[ -n "$line" ]] && printf "%*s%s\n" "$indent" "" "$line"
    }

    # Get maximum flag length for alignment
    local max_len=0
    for flag in "${!flags_ref[@]}"; do
        local shorthand="${shorthands_ref[$flag]:-}"
        local len=$((${#flag} + ${#shorthand} + 4)) # +4 for "--" and ", -" if shorthand exists
        ((len > max_len)) && max_len=$len
    done

    # Add padding for readability
    max_len=$((max_len + 2))

    # First, show flags by groups if any groups exist
    local groups_array
    if groups_array=$(_get_context_array "FLAG_GROUPS" 2> /dev/null); then
        declare -n groups_ref="$groups_array"
        if [[ ${#groups_ref[@]} -gt 0 ]]; then
            echo "Options by group:"
            echo

            # Sort groups alphabetically
            while IFS= read -r group; do
                echo "  ${group}:"
                for flag in ${groups_ref[$group]}; do
                    _print_flag_help "$flag" "$max_len"
                done
                echo
            done < <(printf '%s\n' "${!groups_ref[@]}" | sort)

            # Show ungrouped flags if any
            local ungrouped=()
            for flag in "${!flags_ref[@]}"; do
                local is_grouped=false
                for group_flags in "${groups_ref[@]}"; do
                    # Split group_flags into array for proper word matching
                    local -a group_array
                    read -ra group_array <<< "$group_flags"
                    for group_flag in "${group_array[@]}"; do
                        if [[ "$group_flag" == "$flag" ]]; then
                            is_grouped=true
                            break 2
                        fi
                    done
                done
                if [[ "$is_grouped" == "false" ]]; then
                    ungrouped+=("$flag")
                fi
            done

            if [[ ${#ungrouped[@]} -gt 0 ]]; then
                echo "  Other options:"
                for flag in "${ungrouped[@]}"; do
                    _print_flag_help "$flag" "$max_len"
                done
                echo
            fi
        else
            # If no groups, show all flags
            echo "Options:"
            echo
            while IFS= read -r flag; do
                _print_flag_help "$flag" "$max_len"
            done < <(printf '%s\n' "${!flags_ref[@]}" | sort)
            echo
        fi
    else
        # If groups array doesn't exist, show all flags
        echo "Options:"
        echo
        while IFS= read -r flag; do
            _print_flag_help "$flag" "$max_len"
        done < <(printf '%s\n' "${!flags_ref[@]}" | sort)
        echo
    fi

    # Show required positional arguments if any
    local required_positional_array
    required_positional_array=$(_get_context_array "REQUIRED_POSITIONAL") || return 1
    declare -n required_positional_ref="$required_positional_array"
    if [[ ${#required_positional_ref[@]} -gt 0 ]]; then
        echo "Required Arguments:"
        echo "  At least ${required_positional_ref[0]} argument(s) required"
        if [[ -n "${required_positional_ref[1]}" ]]; then
            print_wrapped_line 4 "${required_positional_ref[1]}"
        fi
        echo
    fi

    # Show mutually exclusive groups if any
    local mutex_groups_array
    mutex_groups_array=$(_get_context_array "MUTUALLY_EXCLUSIVE_GROUPS") || return 1
    declare -n mutex_groups_ref="$mutex_groups_array"
    if [[ ${#mutex_groups_ref[@]} -gt 0 ]]; then
        echo "Mutually Exclusive Flags:"
        for group in "${mutex_groups_ref[@]}"; do
            print_wrapped_line 2 "$group"
        done
        echo
    fi

    # Show examples if available
    if [[ -n "$_SCRIPT_EXAMPLES" ]]; then
        echo "Examples:"
        echo "$_SCRIPT_EXAMPLES"
    fi
}

# Helper function to print flag help
_print_flag_help() {
    local flag="$1"
    local max_len="$2"

    # Get context-specific arrays
    local descriptions_array defaults_array types_array shorthands_array
    local required_array allowed_values_array env_vars_array regex_patterns_array transformers_array
    descriptions_array=$(_get_context_array "FLAG_DESCRIPTIONS") || return 1
    defaults_array=$(_get_context_array "FLAG_DEFAULTS") || return 1
    types_array=$(_get_context_array "FLAG_TYPES") || return 1
    shorthands_array=$(_get_context_array "FLAG_SHORTHANDS") || return 1
    required_array=$(_get_context_array "FLAG_REQUIRED") || return 1
    allowed_values_array=$(_get_context_array "FLAG_ALLOWED_VALUES") || return 1
    env_vars_array=$(_get_context_array "FLAG_ENV_VARS") || return 1
    regex_patterns_array=$(_get_context_array "FLAG_REGEX_PATTERNS") || return 1
    transformers_array=$(_get_context_array "FLAG_TRANSFORMERS") || return 1

    declare -n descriptions_ref="$descriptions_array"
    declare -n defaults_ref="$defaults_array"
    declare -n types_ref="$types_array"
    declare -n shorthands_ref="$shorthands_array"
    declare -n required_ref="$required_array"
    declare -n allowed_values_ref="$allowed_values_array"
    declare -n env_vars_ref="$env_vars_array"
    declare -n regex_patterns_ref="$regex_patterns_array"
    declare -n transformers_ref="$transformers_array"

    local default="${defaults_ref[$flag]:-}"
    local desc="${descriptions_ref[$flag]}"
    local type="${types_ref[$flag]}"
    local shorthand="${shorthands_ref[$flag]:-}"
    local required="${required_ref[$flag]:-false}"
    local allowed="${allowed_values_ref[$flag]:-}"
    local env_var="${env_vars_ref[$flag]:-}"
    local pattern="${regex_patterns_ref[$flag]:-}"
    local transformer="${transformers_ref[$flag]:-}"

    # Build the flag string with proper alignment
    printf "  "
    local flag_str=""
    if [[ -n "$shorthand" ]]; then
        flag_str="-$shorthand, --$flag"
    else
        flag_str="--$flag"
    fi
    printf "%-*s" "$max_len" "$flag_str"

    # Add type, default value, and constraints
    local meta=""
    [[ "$required" == "true" ]] && meta+="required, "
    meta+="$type"
    [[ -n "$default" ]] && meta+=", default: $default"
    [[ -n "$allowed" ]] && meta+=", must be one of: ${allowed//|/, }"
    [[ -n "$env_var" ]] && meta+=", env: $env_var"
    [[ -n "$pattern" ]] && meta+=", pattern: $pattern"
    [[ -n "$transformer" ]] && meta+=", transformer: $transformer"
    printf "  (%s)" "$meta"
    echo

    # Word wrap the description with proper indentation
    local desc_indent=$((max_len + 6)) # 6 = 2 spaces before flag + 4 spaces before description
    print_wrapped_line "$desc_indent" "$desc"
}

# Function to register mutually exclusive flags
register_mutex_flags() {
    local mutex_groups_array
    mutex_groups_array=$(_get_context_array "MUTUALLY_EXCLUSIVE_GROUPS") || return 1
    declare -n mutex_groups_ref="$mutex_groups_array"
    mutex_groups_ref+=("$*")
}

# Function to register required positional arguments
register_required_positional() {
    local count="$1"
    local description="${2:-}"

    local required_positional_array
    required_positional_array=$(_get_context_array "REQUIRED_POSITIONAL") || return 1
    declare -n required_positional_ref="$required_positional_array"
    required_positional_ref=("$count" "$description")
}

# Function to set script metadata for help message
set_script_info() {
    _SCRIPT_DESCRIPTION="$1"
    _SCRIPT_USAGE="${2:-}"
    _SCRIPT_EXAMPLES="${3:-}"
}

# @function _validate_context
# @brief Validates if a given flag context exists
# @description
#   Internal function that checks if a specified flag context exists in the global
#   _FLAG_CONTEXTS array. This is used by other functions to ensure operations are
#   performed on valid contexts.
#
# @param context  The name of the context to validate
#
# @return 0 if context exists, ERR_CONTEXT_NOT_FOUND if not
#
# @example
#   if ! _validate_context "my_script"; then
#     log_error "Invalid context"
#     return 1
#   fi
_validate_context() {
    local context="$1"
    if [[ ! -v "_FLAG_CONTEXTS[$context]" ]]; then
        log_error "Context '$context' does not exist"
        return "$ERR_CONTEXT_NOT_FOUND"
    fi
    return 0
}

# @function _get_context_arrays
# @brief Retrieves multiple context-specific arrays at once
# @description
#   Internal helper function that retrieves references to multiple context-specific
#   arrays in a single call. This reduces the number of individual _get_context_array
#   calls needed when multiple arrays are required.
#
# @param context      The context name to get arrays from
# @param array_names  List of array names to retrieve
#
# @return Space-separated list of "name=value" pairs
#
# @example
#   # Get multiple arrays at once
#   read -r flags types defaults <<< $(_get_context_arrays "my_script" "FLAGS" "TYPES" "DEFAULTS")
#
#   # Use with declare
#   declare -A flags types
#   eval "$(_get_context_arrays "my_script" "FLAGS" "TYPES")"
_get_context_arrays() {
    local context="$1"
    shift

    if ! _validate_context "$context"; then
        return "$ERR_CONTEXT_NOT_FOUND"
    fi

    local -A results
    for array_name in "$@"; do
        local array_ref
        array_ref=$(_get_context_array "$array_name" "$context") || return 1
        results[$array_name]=$array_ref
    done

    # Return results as space-separated list of "name=value" pairs
    local output=""
    for name in "${!results[@]}"; do
        output+="$name=${results[$name]} "
    done
    echo "${output% }" # Remove trailing space
}
