#!/usr/bin/env bash

# Logging Functions
log_info() {
    echo -e "\033[1;32m📌 [INFO] [$(date '+%Y-%m-%d %H:%M:%S')]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m❌ [ERROR] [$(date '+%Y-%m-%d %H:%M:%S')]\033[0m $1" >&2
}

log_fatal() {
    echo -e "\033[1;31m💥 [FATAL] [$(date '+%Y-%m-%d %H:%M:%S')]\033[0m $1" >&2
    exit 1
}
