#!/bin/bash
#
# Bootstrap a fresh macOS machine. Safe to re-run: every step is idempotent and
# gracefully adopts anything that is already installed.
#
# Usage: ./setup.sh [--no-macos]

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
RUN_MACOS_DEFAULTS=true
FAILED_STEPS=()

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

print_step()    { echo -e "${BLUE}==>${NC} $1"; }
print_success() { echo -e "${GREEN}==>${NC} $1"; }
print_warn()    { echo -e "${YELLOW}==>${NC} $1"; }
print_error()   { echo -e "${RED}==>${NC} $1"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# Run an install step; record the failure but keep going.
run_step() {
    local name="$1"; shift
    if ! "$@"; then
        print_error "$name failed - continuing"
        FAILED_STEPS+=("$name")
    fi
}

# Symlink dotfiles/<name> to ~/.<name>, backing up whatever is there.
link_dotfile() {
    local src="$REPO_DIR/dotfiles/$1"
    local dest="$HOME/.$1"

    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        print_success "~/.$1 already linked"
        return
    fi

    if [ -e "$dest" ]; then
        cp -R "$dest" "$dest.backup"
        print_warn "Backed up ~/.$1 to ~/.$1.backup"
    fi

    ln -sfn "$src" "$dest"
    print_success "Linked ~/.$1"
}

install_homebrew() {
    if command_exists brew; then
        print_success "Homebrew already installed"
    else
        print_step "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || return 1
    fi
    eval "$(/opt/homebrew/bin/brew shellenv)"
}

install_packages() {
    print_step "Installing packages from Brewfile..."
    # --adopt lets brew take over apps that were installed by hand instead of
    # aborting with "It seems there is already an App at ...".
    HOMEBREW_CASK_OPTS="--adopt" brew bundle --file="$REPO_DIR/Brewfile"
}

install_oh_my_zsh() {
    if [ -d "$HOME/.oh-my-zsh" ]; then
        print_success "Oh My Zsh already installed"
        return
    fi
    print_step "Installing Oh My Zsh..."
    # KEEP_ZSHRC stops the installer writing its own ~/.zshrc over ours.
    KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
}

clone_if_missing() {
    local repo="$1" dest="$2"
    if [ -d "$dest" ]; then
        print_success "$(basename "$dest") already installed"
    else
        print_step "Installing $(basename "$dest")..."
        git clone --depth=1 "$repo" "$dest" || return 1
    fi
}

install_zsh_plugins() {
    clone_if_missing https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k" &&
    clone_if_missing https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" &&
    clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
}

link_dotfiles() {
    print_step "Linking dotfiles..."
    link_dotfile zshrc
    link_dotfile zprofile
    link_dotfile gitconfig
    link_dotfile p10k.zsh
}

install_nvm_node() {
    if [ -d "$HOME/.nvm" ]; then
        print_success "nvm already installed"
    else
        print_step "Installing nvm..."
        curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash || return 1
    fi

    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    . "$NVM_DIR/nvm.sh" || return 1

    print_step "Installing current Node LTS..."
    nvm install --lts || return 1
    nvm alias default 'lts/*'

    print_step "Installing global npm packages..."
    npm install -g aws-cdk defuddle
}

install_sdkman_java() {
    if [ -d "$HOME/.sdkman" ]; then
        print_success "SDKMAN already installed"
    else
        print_step "Installing SDKMAN..."
        curl -s "https://get.sdkman.io?rcupdate=false" | bash || return 1
    fi

    set +u  # sdkman-init.sh reads unset vars
    # shellcheck disable=SC1091
    . "$HOME/.sdkman/bin/sdkman-init.sh" || { set -u; return 1; }

    # No version argument: SDKMAN resolves the current default (latest stable).
    local rc=0
    for candidate in java gradle; do
        if sdk current "$candidate" >/dev/null 2>&1; then
            print_success "$candidate already installed via SDKMAN"
        else
            print_step "Installing latest $candidate..."
            sdk install "$candidate" </dev/null || rc=1
        fi
    done
    set -u
    return $rc
}

install_python() {
    command_exists uv || { print_error "uv missing - check the Brewfile step"; return 1; }
    print_step "Installing latest stable CPython via uv..."
    uv python install
}

install_claude_code() {
    if command_exists claude || [ -x "$HOME/.local/bin/claude" ]; then
        print_success "Claude Code already installed"
        return
    fi
    print_step "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
}

apply_macos_defaults() {
    $RUN_MACOS_DEFAULTS || { print_warn "Skipping macOS defaults (--no-macos)"; return; }
    bash "$REPO_DIR/macos.sh"
}

verify_installation() {
    print_step "Verifying installation..."
    local all_good=true

    for dir in "$HOME/.oh-my-zsh" \
               "$ZSH_CUSTOM/themes/powerlevel10k" \
               "$ZSH_CUSTOM/plugins/zsh-autosuggestions" \
               "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" \
               "$HOME/.nvm" "$HOME/.sdkman"; do
        [ -d "$dir" ] || { print_error "Missing: $dir"; all_good=false; }
    done

    for cmd in brew git gh uv autojump; do
        command_exists "$cmd" || { print_error "Missing command: $cmd"; all_good=false; }
    done

    # These live behind shell init, so check the files rather than $PATH.
    [ -s "$HOME/.nvm/nvm.sh" ] || { print_error "nvm not usable"; all_good=false; }
    [ -x "$HOME/.local/bin/claude" ] || command_exists claude || { print_error "Claude Code missing"; all_good=false; }

    echo
    print_step "Installed versions:"
    echo "  node:   $( . "$HOME/.nvm/nvm.sh" >/dev/null 2>&1 && node -v 2>/dev/null || echo 'n/a')"
    echo "  java:   $(set +u; . "$HOME/.sdkman/bin/sdkman-init.sh" >/dev/null 2>&1 && java -version 2>&1 | head -1 || echo 'n/a')"
    echo "  python: $(uv python list --only-installed 2>/dev/null | head -1 || echo 'n/a')"
    echo "  claude: $("$HOME/.local/bin/claude" --version 2>/dev/null || echo 'n/a')"
    echo

    if [ ${#FAILED_STEPS[@]} -gt 0 ]; then
        print_error "Steps that failed: ${FAILED_STEPS[*]}"
        all_good=false
    fi

    $all_good && print_success "All components installed successfully!" \
              || print_error "Some components need attention - see above."
}

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --no-macos) RUN_MACOS_DEFAULTS=false ;;
            *) print_error "Unknown option: $1"; exit 1 ;;
        esac
        shift
    done

    echo "Starting machine setup..."

    run_step "homebrew"     install_homebrew
    run_step "packages"     install_packages
    run_step "oh-my-zsh"    install_oh_my_zsh
    run_step "zsh-plugins"  install_zsh_plugins
    run_step "dotfiles"     link_dotfiles
    run_step "node"         install_nvm_node
    run_step "java"         install_sdkman_java
    run_step "python"       install_python
    run_step "claude-code"  install_claude_code
    run_step "macos"        apply_macos_defaults

    verify_installation

    echo
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Restart your terminal (or: exec zsh)"
    echo "2. Set the iTerm2 font to 'MesloLGS NF'"
    echo "3. gh auth login, then sign into Chrome / Slack / Google Drive"
    echo "4. Install manually: Antigravity, Antigravity IDE, OpenWhispr, ChatGPT Atlas"
    echo
    echo "Backups of any replaced dotfiles are at ~/.<name>.backup"
}

main "$@"
