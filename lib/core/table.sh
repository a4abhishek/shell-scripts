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

# Print a two-column table with dynamic column widths
print_two_column_table() {
    local title="$1"
    local col1_header="${2:-COLUMN1}"
    local col2_header="${3:-COLUMN2}"
    shift 3
    local items=("$@")

    if [[ ${#items[@]} -eq 0 ]]; then
        log_info "$title: No items found."
        return
    fi

    log_info "$title:"

    # Determine maximum widths for each column (start with header lengths)
    local max_col1_length=${#col1_header}
    local max_col2_length=${#col2_header}
    local col1 col2

    for item in "${items[@]}"; do
        col1=$(echo "$item" | cut -d'/' -f1)
        col2=$(echo "$item" | cut -d'/' -f2)
        [[ ${#col1} -gt $max_col1_length ]] && max_col1_length=${#col1}
        [[ ${#col2} -gt $max_col2_length ]] && max_col2_length=${#col2}
    done

    # Calculate the total width for the horizontal separator (columns plus " | " separator)
    local total_width=$((max_col1_length + max_col2_length + 3))
    local line
    line=$(printf '%*s' "$total_width" '' | tr ' ' '-')

    # Print the table: separator, header, separator, rows, and final separator.
    echo "$line"
    printf "%-*s | %-*s\n" "$max_col1_length" "$col1_header" "$max_col2_length" "$col2_header"
    echo "$line"
    for item in "${items[@]}"; do
        col1=$(echo "$item" | cut -d'/' -f1)
        col2=$(echo "$item" | cut -d'/' -f2)
        printf "%-*s | %-*s\n" "$max_col1_length" "$col1" "$max_col2_length" "$col2"
    done
    echo "$line"
}

# Print a multi-column table with dynamic column widths
print_table() {
    local title="$1"
    shift
    local headers=("$1")
    shift
    local items=("$@")

    if [[ ${#items[@]} -eq 0 ]]; then
        log_info "$title: No items found."
        return
    fi

    log_info "$title:"

    # Calculate number of columns from first item
    local num_columns
    num_columns=$(echo "${items[0]}" | awk -F'/' '{print NF}')

    # Find maximum width for each column
    declare -a max_lengths
    for ((i = 1; i <= num_columns; i++)); do
        max_lengths[i - 1]=${#headers[i - 1]} # Initialize with header length
    done

    # Update max lengths based on data
    for item in "${items[@]}"; do
        for ((i = 1; i <= num_columns; i++)); do
            local value
            value=$(echo "$item" | cut -d'/' -f"$i")
            [[ ${#value} -gt ${max_lengths[i - 1]} ]] && max_lengths[i - 1]=${#value}
        done
    done

    # Build format string
    local format=""
    local total_width=0
    for length in "${max_lengths[@]}"; do
        format+="%-${length}s | "
        total_width=$((total_width + length + 3))
    done
    format+="\n"

    # Print table headers
    local line
    line=$(printf '%*s' "$total_width" '' | tr ' ' '-')
    echo -e "$line"
    # Use printf with explicit format for each argument
    printf "%-*s | " "${max_lengths[@]}" "${headers[@]}"
    printf "\n"
    echo -e "$line"

    # Print table rows
    for item in "${items[@]}"; do
        local row=()
        for ((i = 1; i <= num_columns; i++)); do
            row+=("$(echo "$item" | cut -d'/' -f"$i")")
        done
        # Use printf with explicit format for each argument
        printf "%-*s | " "${max_lengths[@]}" "${row[@]}"
        printf "\n"
    done

    echo -e "$line"
}

format_table_2col() {
    local col1 col2
    for item in "$@"; do
        col1=$(echo "$item" | cut -d'/' -f1)
        col2=$(echo "$item" | cut -d'/' -f2)
        # Rest of the loop...
    done

    local line
    line=$(printf '%*s' "$((max_col1_length + max_col2_length + 3))" '' | tr ' ' '-')

    # Fix printf format string usage
    printf "| %-${max_col1_length}s | %-${max_col2_length}s |\n" "$col1_header" "$col2_header"
}
