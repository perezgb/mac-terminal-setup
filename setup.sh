#!/bin/bash

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}==>${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Backup existing configurations
backup_configs() {
    print_step "Creating backups of existing configurations..."
    
    # Backup zshrc if it exists
    if [ -f ~/.zshrc ]; then
        cp ~/.zshrc ~/.zshrc.backup
        print_success "Backed up ~/.zshrc"
    fi
    
    # Backup p10k config if it exists
    if [ -f ~/.p10k.zsh ]; then
        cp ~/.p10k.zsh ~/.p10k.zsh.backup
        print_success "Backed up ~/.p10k.zsh"
    fi
}

# Install Homebrew if not already installed
install_homebrew() {
    if ! command_exists brew; then
        print_step "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        print_success "Homebrew installed"
    else
        print_success "Homebrew already installed"
    fi
}

# Install iTerm2
install_iterm() {
    print_step "Installing iTerm2..."
    brew install --cask iterm2
    print_success "iTerm2 installed"
}

# Install Oh My Zsh
install_oh_my_zsh() {
    if [ ! -d ~/.oh-my-zsh ]; then
        print_step "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        print_success "Oh My Zsh installed"
    else
        print_success "Oh My Zsh already installed"
    fi
}

# Install Powerlevel10k
install_powerlevel10k() {
    print_step "Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
    sed -i '' 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
    print_success "Powerlevel10k installed"
}

# Install plugins
install_plugins() {
    print_step "Installing plugins..."
    
    # zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    
    # zsh-syntax-highlighting
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    
    # autojump
    brew install autojump
    
    # Update plugins in .zshrc
    sed -i '' 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting autojump)/' ~/.zshrc
    
    print_success "Plugins installed"
}

# Verify installation
verify_installation() {
    print_step "Verifying installation..."
    
    # Check each component
    local all_good=true
    
    if ! command_exists brew; then
        print_error "Homebrew is not installed correctly"
        all_good=false
    fi
    
    if [ ! -d ~/.oh-my-zsh ]; then
        print_error "Oh My Zsh is not installed correctly"
        all_good=false
    fi
    
    if [ ! -d ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k ]; then
        print_error "Powerlevel10k is not installed correctly"
        all_good=false
    fi
    
    # Check plugins
    if [ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions ] || \
       [ ! -d ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting ] || \
       ! command_exists autojump; then
        print_error "Some plugins are not installed correctly"
        all_good=false
    fi
    
    if $all_good; then
        print_success "All components installed successfully!"
    else
        print_error "Some components may not have installed correctly. Please check the error messages above."
    fi
}

# Main installation
main() {
    echo "Starting terminal environment setup..."
    
    # Create backups
    backup_configs
    
    # Install components
    install_homebrew
    install_iterm
    install_oh_my_zsh
    install_powerlevel10k
    install_plugins
    
    # Verify installation
    verify_installation
    
    # Final instructions
    echo
    print_success "Installation complete!"
    echo
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Restart your terminal or run: source ~/.zshrc"
    echo "2. Run 'p10k configure' to set up your Powerlevel10k theme"
    echo
    echo "If you encounter any issues, you can restore your backup files:"
    echo "cp ~/.zshrc.backup ~/.zshrc"
    echo "cp ~/.p10k.zsh.backup ~/.p10k.zsh"
}

# Run the script
main