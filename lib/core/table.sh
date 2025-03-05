#!/usr/bin/env bash

# Prevent duplicate sourcing
if [[ -n "${_LIB_TABLE_LOADED:-}" ]]; then return; fi
_LIB_TABLE_LOADED=true

# Ensure script stops on errors
set -euo pipefail

# Source required libraries
CORE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
. "$CORE_LIB_DIR/logging.sh"

# Helper: Calculate maximum column widths.
# Arguments:
#   $1: delimiter (optional, default '/')
#   $2: name of array variable containing headers
#   $3: name of array variable containing items
# Returns: Each maximum length on its own line.
calculate_max_widths() {
    local delimiter="${1:-/}"
    local headers_name="$2"
    local items_name="$3"

    # Use namerefs (requires Bash 4.3+) to avoid eval and brace expansion issues.
    declare -n headers_ref="$headers_name"
    local -a headers=("${headers_ref[@]}")
    declare -n items_ref="$items_name"
    local -a items=("${items_ref[@]}")

    local num_columns=${#headers[@]}
    local -a max_lengths=()
    local i

    # Initialize with header lengths.
    for ((i = 0; i < num_columns; i++)); do
        max_lengths[i]=${#headers[i]}
    done

    local item fields j
    for item in "${items[@]}"; do
        IFS="$delimiter" read -r -a fields <<< "$item"
        # Pad missing fields if needed.
        while ((${#fields[@]} < num_columns)); do
            fields+=("")
        done
        for ((j = 0; j < num_columns; j++)); do
            local field_length=${#fields[j]}
            if ((field_length > max_lengths[j])); then
                max_lengths[j]=$field_length
            fi
        done
    done

    for val in "${max_lengths[@]}"; do
        echo "$val"
    done
}

# Generic multi-column table printer.
# Arguments:
#   $1: Title (printed via log_info)
#   $2: Delimiter for splitting items (optional, default '/')
#   $3: name of array variable containing headers
#   $4: name of array variable containing rows
print_table() {
    local title="$1"
    local delimiter="${2:-/}"
    local headers_name="$3"
    local items_name="$4"

    # Use namerefs to safely get the arrays.
    declare -n headers_ref="$headers_name"
    local -a headers=("${headers_ref[@]}")
    declare -n items_ref="$items_name"
    local -a items=("${items_ref[@]}")

    if [[ ${#items[@]} -eq 0 ]]; then
        log_info "$title: No items found."
        return
    fi

    log_info "$title:"

    # Use mapfile to avoid word-splitting issues (SC2207).
    mapfile -t max_lengths < <(calculate_max_widths "$delimiter" "$headers_name" "$items_name")

    local num_columns=${#headers[@]}

    # Build the format string (adds 1 extra character per column for padding).
    local format=""
    local total_width=0
    local i col_width
    for ((i = 0; i < num_columns; i++)); do
        col_width=$((max_lengths[i] + 1))
        if ((i < num_columns - 1)); then
            format+="%-${col_width}s| "
            total_width=$((total_width + col_width + 2))
        else
            format+="%-${col_width}s"
            total_width=$((total_width + col_width))
        fi
    done
    format="${format}\n"

    # Create a horizontal separator.
    local line
    line=$(printf '%*s' "$total_width" '' | tr ' ' '-')

    # Print header and rows.
    echo "$line"
    # Disable SC2059 warning here since the format string is built internally.
    # shellcheck disable=SC2059
    printf -- "$format" "${headers[@]}"
    echo "$line"
    local item fields
    for item in "${items[@]}"; do
        IFS="$delimiter" read -r -a fields <<< "$item"
        while ((${#fields[@]} < num_columns)); do
            fields+=("")
        done
        # shellcheck disable=SC2059
        printf -- "$format" "${fields[@]}"
    done
    echo "$line"
}

# Two-column table printer (wrapper around print_table).
# Arguments:
#   $1: Title (log_info)
#   $2: Column 1 header (default: COLUMN1)
#   $3: Column 2 header (default: COLUMN2)
#   $4...: Items (each item should have fields separated by the delimiter, default '/')
print_two_column_table() {
    local title="$1"
    local col1_header="${2:-COLUMN1}"
    local col2_header="${3:-COLUMN2}"
    shift 3
    local -a items=("$@")
    local -a headers=("$col1_header" "$col2_header")
    print_table "$title" "/" headers items
}

# Optional helper to format a table row from an array of fields.
# Usage: row=$(format_table_row "/" "field1" "field2" "field3")
format_table_row() {
    local delimiter="${1:-|}"
    shift
    local IFS="$delimiter"
    echo "$*"
}
