#!/usr/bin/env bash

# Prevent duplicate sourcing
if [[ -n "${_LIB_LOGGING_LOADED:-}" ]]; then return; fi
_LIB_LOGGING_LOADED=true

# Logging Functions
log_debug() {
    if [[ "${LOG_LEVEL:-}" == "debug" ]]; then
        echo -e "\033[1;34m🔍 [DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')]\033[0m $1"
    fi
}

log_info() {
    echo -e "\033[1;32m📌 [INFO] [$(date '+%Y-%m-%d %H:%M:%S')]\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m✅ [SUCCESS] [$(date '+%Y-%m-%d %H:%M:%S')]\033[0m $1"
}

log_warning() {
    echo -e "\033[1;33m⚠️ [WARNING] [$(date '+%Y-%m-%d %H:%M:%S')]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m❌ [ERROR] [$(date '+%Y-%m-%d %H:%M:%S')]\033[0m $1" >&2
}

log_fatal() {
    echo -e "\033[1;31m💥 [FATAL] [$(date '+%Y-%m-%d %H:%M:%S')]\033[0m $1" >&2
    exit 1
}
