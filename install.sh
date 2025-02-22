#!/usr/bin/env bash
set -euo pipefail

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
log_success() {
    echo -e "\033[1;32m✅ [SUCCESS] [$(date '+%Y-%m-%d %H:%M:%S')]\033[0m $1"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Default install locations (in order of preference)
INSTALL_LOCATIONS=(
    "$HOME/.local/my-shell-scripts"      # User-specific installation
    "/usr/local/my-shell-scripts"        # System-wide installation
    "$HOME/my-shell-scripts"             # Fallback location
)

# Try to create installation directory
install_to_location() {
    local dir="$1"
    log_info "Attempting to install to: $dir"

    if [ -d "$dir" ]; then
        log_info "Directory '$dir' already exists. Existing files may be overwritten or updated."
        return 0
    fi

    if mkdir -p "$dir" 2>/dev/null; then
        INSTALL_DIR="$dir"
        return 0
    fi
    return 1
}

# Try each location until one works
for location in "${INSTALL_LOCATIONS[@]}"; do
    if install_to_location "$location"; then
        INSTALL_DIR="$location"
        BIN_DIR="$INSTALL_DIR/bin"
        break
    fi
    log_info "Cannot install to '$location', trying next location..."
done

if [ -z "${INSTALL_DIR:-}" ]; then
    log_fatal "Could not find a writable installation location. Available options:
    1. Run with sudo: sudo ./install.sh
    2. Specify custom location: INSTALL_DIR=/custom/path ./install.sh
    3. Grant write permission: sudo chown -R \$USER /usr/local/my-shell-scripts"
fi

# Detect user's shell and RC file
detect_shell_rc() {
    # Try to detect the parent process shell first
    local parent_shell
    parent_shell=$(ps -p $PPID -o comm= 2>/dev/null || true)
    
    case "${parent_shell##*/}" in
        zsh)
            if [ -f "$HOME/.zshrc" ]; then
                echo "$HOME/.zshrc"
            else
                log_info "ZSH RC file not found. Creating $HOME/.zshrc"
                touch "$HOME/.zshrc" || log_fatal "Failed to create $HOME/.zshrc"
                echo "$HOME/.zshrc"
            fi
            ;;
        bash)
            if [ -f "$HOME/.bashrc" ]; then
                echo "$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                echo "$HOME/.bash_profile"
            else
                log_info "Bash RC file not found. Creating $HOME/.bashrc"
                touch "$HOME/.bashrc" || log_fatal "Failed to create $HOME/.bashrc"
                echo "$HOME/.bashrc"
            fi
            ;;
        fish)
            local fish_config_dir="$HOME/.config/fish"
            local fish_config="$fish_config_dir/config.fish"
            if [ ! -f "$fish_config" ]; then
                log_info "Fish config not found. Creating $fish_config"
                mkdir -p "$fish_config_dir" || log_fatal "Failed to create fish config directory"
                touch "$fish_config" || log_fatal "Failed to create fish config file"
            fi
            echo "$fish_config"
            ;;
        *)
            # Fallback to environment detection without recursion
            if [ -n "${ZSH_VERSION:-}" ]; then
                [ -f "$HOME/.zshrc" ] || touch "$HOME/.zshrc"
                echo "$HOME/.zshrc"
            elif [ -n "${BASH_VERSION:-}" ]; then
                if [ -f "$HOME/.bashrc" ]; then
                    echo "$HOME/.bashrc"
                elif [ -f "$HOME/.bash_profile" ]; then
                    echo "$HOME/.bash_profile"
                else
                    touch "$HOME/.bashrc" || log_fatal "Failed to create $HOME/.bashrc"
                    echo "$HOME/.bashrc"
                fi
            elif [ -n "${FISH_VERSION:-}" ]; then
                local fish_config_dir="$HOME/.config/fish"
                local fish_config="$fish_config_dir/config.fish"
                [ -f "$fish_config" ] || { mkdir -p "$fish_config_dir" && touch "$fish_config"; }
                echo "$fish_config"
            else
                log_info "Could not detect shell type. Using ~/.profile"
                [ -f "$HOME/.profile" ] || touch "$HOME/.profile" || log_fatal "Failed to create .profile"
                echo "$HOME/.profile"
            fi
            ;;
    esac
}

SHELL_RC="$(detect_shell_rc)"
log_info "Detected shell configuration file: $SHELL_RC"

# Ensure required commands exist
for cmd in curl mkdir cp grep; do
    if ! command_exists "$cmd"; then
        log_fatal "Required command '$cmd' not found. Please install it and try again."
    fi
done

# Display install path and prompt user for confirmation
log_info "Installing shell scripts to: $INSTALL_DIR"
# read -rp "Do you want to proceed? [Y/n]: " response
# if [[ "$response" =~ ^[Nn]$ ]]; then
#     log_info "Installation aborted."
#     exit 0
# fi

# Download or copy files based on whether running from curl (versioned release) or local clone
if [[ -z "${SKIP_DOWNLOAD:-}" && -n "${INSTALL_VERSION:-}" ]]; then
    REPO_URL="https://github.com/a4abhishek/shell-scripts"
    TAR_URL="$REPO_URL/archive/refs/tags/$INSTALL_VERSION.tar.gz"
    TMP_DIR=$(mktemp -d)

    log_info "Downloading shell scripts (version: $INSTALL_VERSION)..."
    curl -sL "$TAR_URL" | tar -xz --strip-components=1 -C "$TMP_DIR" || log_fatal "Download failed."
    
    log_info "Copying files to '$INSTALL_DIR'..."
    cp -r "$TMP_DIR/bin" "$TMP_DIR/lib" "$INSTALL_DIR" || log_fatal "File copy failed."
    
    rm -rf "$TMP_DIR"
else
    log_info "Copying files from local repository to '$INSTALL_DIR'..."
    cp -r bin lib "$INSTALL_DIR" || log_fatal "File copy failed."
fi

# Update PATH in shell RC and verify
if ! echo "$PATH" | tr ':' '\n' | grep -q "^$BIN_DIR$"; then
    if ! grep -q "$BIN_DIR" "$SHELL_RC" 2>/dev/null; then
        log_info "Adding '$BIN_DIR' to PATH in $SHELL_RC"
        echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$SHELL_RC" && \
        log_success "Added '$BIN_DIR' to PATH. Please restart your terminal or run 'source $SHELL_RC'" || \
        log_error "Failed to update PATH in $SHELL_RC."
        log_info "If you're still having issues, try these steps:"
        log_info "   1. Add this line to $SHELL_RC:"
        log_info "      export PATH=\"$BIN_DIR:\$PATH\""
        log_info "   2. Then run: source $SHELL_RC"
    else
        log_info "PATH entry exists in $SHELL_RC but is not active in current session."
        log_info "Please restart your terminal or run 'source $SHELL_RC'"
        log_info "If the above steps don't work for you, manually add this line to your shell RC file:"
        log_info "   export PATH=\"$BIN_DIR:\$PATH\""
        log_info "   Then run: source <your_shell_rc_file>"
    fi
else
    log_success "'$BIN_DIR' is already in your active PATH."
fi

log_success "Installation complete! You can now run your shell scripts from anywhere."
