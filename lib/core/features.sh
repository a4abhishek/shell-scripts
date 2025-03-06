#!/usr/bin/env bash

# Prevent duplicate sourcing
if [[ -n "${_LIB_FEATURES_LOADED:-}" ]]; then return; fi
_LIB_FEATURES_LOADED=true

set -euo pipefail

# Detect terminal capabilities and set environment variables
_detect_terminal_features() {
    # OS detection
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

    # Architecture detection
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
        export HAS_COLOR_SUPPORT=false
    elif [[ -n "${FORCE_COLOR:-}" ]]; then
        export HAS_COLOR_SUPPORT=true
    else
        if [[ -t 1 ]] && [[ -n "${TERM:-}" ]] && command -v tput > /dev/null 2>&1; then
            if [[ $(tput colors 2> /dev/null || echo 0) -ge 8 ]]; then
                export HAS_COLOR_SUPPORT=true
            else
                export HAS_COLOR_SUPPORT=false
            fi
        else
            export HAS_COLOR_SUPPORT=false
        fi
    fi

    # Unicode support detection
    if [[ -n "${FORCE_UNICODE:-}" ]]; then
        export HAS_UNICODE_SUPPORT=true
    else
        if [[ "$(locale charmap 2> /dev/null)" == *"UTF-8"* ]]; then
            export HAS_UNICODE_SUPPORT=true
        else
            export HAS_UNICODE_SUPPORT=false
        fi
    fi

    # Date command feature detection
    if command -v gdate > /dev/null 2>&1; then
        export HAS_GNU_DATE=true
    else
        # On Linux, the default date is GNU date
        if [[ "${OS_NAME}" == "linux" ]]; then
            export HAS_GNU_DATE=true
        else
            export HAS_GNU_DATE=false
        fi
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
