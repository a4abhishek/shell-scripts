#!/usr/bin/env bash

# Prevent duplicate sourcing
if [[ -n "${_LIB_TABLE_LOADED:-}" ]]; then return; fi
_LIB_TABLE_LOADED=true

# Ensure script stops on errors
set -euo pipefail

# Source required libraries
CORE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
    
    # Find maximum width for each column
    local max_col1_length=${#col1_header}  # Minimum width (length of first header)
    local max_col2_length=${#col2_header}  # Minimum width (length of second header)

    for item in "${items[@]}"; do
        local col1=$(echo "$item" | cut -d'/' -f1)
        local col2=$(echo "$item" | cut -d'/' -f2)
        [[ ${#col1} -gt $max_col1_length ]] && max_col1_length=${#col1}
        [[ ${#col2} -gt $max_col2_length ]] && max_col2_length=${#col2}
    done

    # Print table headers
    local format="%-${max_col1_length}s | %-${max_col2_length}s\n"
    local line=$(printf '%*s' "$((max_col1_length + max_col2_length + 3))" '' | tr ' ' '-')

    echo -e "$line"
    printf "$format" "$col1_header" "$col2_header"
    echo -e "$line"

    # Print table rows
    for item in "${items[@]}"; do
        local col1=$(echo "$item" | cut -d'/' -f1)
        local col2=$(echo "$item" | cut -d'/' -f2)
        printf "$format" "$col1" "$col2"
    done

    echo -e "$line"
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
    local num_columns=$(echo "${items[0]}" | awk -F'/' '{print NF}')
    
    # Find maximum width for each column
    declare -a max_lengths
    for ((i=1; i<=num_columns; i++)); do
        max_lengths[$i-1]=${#headers[$i-1]}  # Initialize with header length
    done

    # Update max lengths based on data
    for item in "${items[@]}"; do
        for ((i=1; i<=num_columns; i++)); do
            local value=$(echo "$item" | cut -d'/' -f$i)
            [[ ${#value} -gt ${max_lengths[$i-1]} ]] && max_lengths[$i-1]=${#value}
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
    local line=$(printf '%*s' "$total_width" '' | tr ' ' '-')
    echo -e "$line"
    printf "$format" "${headers[@]}"
    echo -e "$line"

    # Print table rows
    for item in "${items[@]}"; do
        local row=()
        for ((i=1; i<=num_columns; i++)); do
            row+=("$(echo "$item" | cut -d'/' -f$i)")
        done
        printf "$format" "${row[@]}"
    done

    echo -e "$line"
}
