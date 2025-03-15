#!/usr/bin/env bash

# Prevent duplicate sourcing
if [[ -n "${_LIB_FEATURES_LOADED:-}" ]]; then return; fi
_LIB_FEATURES_LOADED=true

set -euo pipefail

# Detect terminal capabilities and set environment variables
_detect_terminal_features() {
    # OS detection
    if command -v uname > /dev/null 2>&1; then
        case "$(uname -s)" in
            Darwin*)
                export OS_NAME="darwin"
                export OS_FAMILY="bsd"
                ;;
            Linux*)
                export OS_NAME="linux"
                export OS_FAMILY="linux"
                ;;
            *)
                export OS_NAME="unknown"
                export OS_FAMILY="unknown"
                ;;
        esac
    else
        export OS_NAME="unknown"
        export OS_FAMILY="unknown"
    fi

    # Architecture detection
    if command -v uname > /dev/null 2>&1; then
        case "$(uname -m)" in
            x86_64 | amd64)
                export ARCH_NAME="x86_64"
                export ARCH_FAMILY="x86"
                ;;
            arm64 | aarch64)
                export ARCH_NAME="arm64"
                export ARCH_FAMILY="arm"
                ;;
            armv7l)
                export ARCH_NAME="arm32"
                export ARCH_FAMILY="arm"
                ;;
            *)
                export ARCH_NAME="unknown"
                export ARCH_FAMILY="unknown"
                ;;
        esac
    else
        export ARCH_NAME="unknown"
        export ARCH_FAMILY="unknown"
    fi

    # Package manager detection
    if command -v brew > /dev/null 2>&1; then
        export HAS_HOMEBREW=true
    else
        export HAS_HOMEBREW=false
    fi

    if command -v apt-get > /dev/null 2>&1; then
        export HAS_APT=true
    else
        export HAS_APT=false
    fi

    if command -v yum > /dev/null 2>&1; then
        export HAS_YUM=true
    else
        export HAS_YUM=false
    fi

    # Shell features detection
    if [[ "${BASH_VERSINFO[0]:-0}" -ge 4 ]]; then
        export HAS_MODERN_BASH=true
    else
        export HAS_MODERN_BASH=false
    fi

    # Common tools detection
    if command -v curl > /dev/null 2>&1; then
        export HAS_CURL=true
    else
        export HAS_CURL=false
    fi

    if command -v wget > /dev/null 2>&1; then
        export HAS_WGET=true
    else
        export HAS_WGET=false
    fi

    if command -v git > /dev/null 2>&1; then
        export HAS_GIT=true
    else
        export HAS_GIT=false
    fi

    # Color support detection
    if [[ -n "${NO_COLOR:-}" ]]; then
        # NO_COLOR takes precedence over everything else
        export HAS_COLOR_SUPPORT=false
    elif [[ -n "${FORCE_COLOR:-}" ]]; then
        # FORCE_COLOR takes precedence if NO_COLOR is not set
        export HAS_COLOR_SUPPORT=true
    elif [[ -n "${HAS_COLOR_SUPPORT:-}" ]]; then
        # Use the pre-set value if neither NO_COLOR nor FORCE_COLOR is set
        :
    else
        # Check if we're outputting to a terminal
        if [[ ! -t 1 ]]; then
            export HAS_COLOR_SUPPORT=false
        else
            # Check for tput and TERM
            if ! command -v tput > /dev/null 2>&1; then
                export HAS_COLOR_SUPPORT=false
            elif [[ -z "${TERM:-}" ]]; then
                export HAS_COLOR_SUPPORT=false
            else
                if [[ $(tput colors 2> /dev/null || echo 0) -ge 8 ]]; then
                    export HAS_COLOR_SUPPORT=true
                else
                    export HAS_COLOR_SUPPORT=false
                fi
            fi
        fi
    fi

    # Unicode support detection
    if [[ -n "${NO_UNICODE:-}" ]]; then
        # NO_UNICODE takes precedence over everything else
        export HAS_UNICODE_SUPPORT=false
    elif [[ -n "${FORCE_UNICODE:-}" ]]; then
        # FORCE_UNICODE takes precedence if NO_UNICODE is not set
        export HAS_UNICODE_SUPPORT=true
    elif [[ -n "${HAS_UNICODE_SUPPORT:-}" ]]; then
        # Use the pre-set value if neither NO_UNICODE nor FORCE_UNICODE is set
        :
    elif [[ "${LC_ALL:-}" == "C" ]] || [[ "${LC_ALL:-}" == "POSIX" ]]; then
        # C/POSIX locale disables Unicode
        export HAS_UNICODE_SUPPORT=false
    else
        # Default to true if we have a UTF-8 locale
        if [[ -n "${LANG:-}" ]] && [[ "${LANG:-}" != "C" ]] && [[ "${LANG:-}" != "POSIX" ]]; then
            export HAS_UNICODE_SUPPORT=true
        else
            export HAS_UNICODE_SUPPORT=false
        fi
    fi

    # Date command feature detection
    if command -v gdate > /dev/null 2>&1; then
        export HAS_GNU_DATE=true
    elif command -v date > /dev/null 2>&1; then
        # On Linux, the default date is GNU date
        if [[ "${OS_NAME}" == "linux" ]]; then
            export HAS_GNU_DATE=true
        else
            export HAS_GNU_DATE=false
        fi
    else
        export HAS_GNU_DATE=false
    fi

    # CI environment detection
    if [[ -n "${CI:-}" ]]; then
        export IS_CI=true
        if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
            export CI_PLATFORM="github"
        elif [[ -n "${GITLAB_CI:-}" ]]; then
            export CI_PLATFORM="gitlab"
        elif [[ -n "${TRAVIS:-}" ]]; then
            export CI_PLATFORM="travis"
        else
            export CI_PLATFORM="unknown"
        fi
    else
        export IS_CI=false
        export CI_PLATFORM="none"
    fi
}

# Run detection on source
_detect_terminal_features
