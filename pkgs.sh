#!/bin/bash

# Enhanced Kali Linux Development Environment Setup Script
# Author: Enhanced by Claude
# Version: 2.0
# Description: Automated installation of development tools, languages, and cloud SDKs

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="/tmp/kali-dev-setup-$(date +%Y%m%d_%H%M%S).log"
readonly TEMP_DIR="/tmp/kali-dev-setup-$$"
readonly MIN_DISK_SPACE_GB=5

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $*${NC}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $*${NC}" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $*${NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*${NC}" | tee -a "$LOG_FILE" >&2
}

# Utility functions
cleanup() {
    log "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR" 2>/dev/null || true
}

trap cleanup EXIT

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root. Please run as a regular user with sudo privileges."
        exit 1
    fi
}

check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        log "This script requires sudo privileges. Please enter your password when prompted."
        sudo -v
    fi
}

check_disk_space() {
    local available_gb
    available_gb=$(df / | awk 'NR==2 {printf "%.0f", $4/1024/1024}')
    if [[ $available_gb -lt $MIN_DISK_SPACE_GB ]]; then
        log_error "Insufficient disk space. Available: ${available_gb}GB, Required: ${MIN_DISK_SPACE_GB}GB"
        exit 1
    fi
    log "Disk space check passed. Available: ${available_gb}GB"
}

check_internet() {
    if ! ping -c 1 google.com &> /dev/null; then
        log_error "Internet connection required. Please check your network connection."
        exit 1
    fi
    log "Internet connectivity confirmed."
}

is_installed() {
    command -v "$1" >/dev/null 2>&1
}

safe_download() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry=0
    
    while [[ $retry -lt $max_retries ]]; do
        if wget --timeout=30 --tries=3 -O "$output" "$url" 2>>"$LOG_FILE"; then
            return 0
        fi
        ((retry++))
        log_warn "Download failed (attempt $retry/$max_retries). Retrying..."
        sleep 2
    done
    
    log_error "Failed to download $url after $max_retries attempts"
    return 1
}

install_package() {
    local package="$1"
    local description="${2:-$package}"
    
    if is_installed "$package"; then
        log "$description is already installed. Skipping."
        return 0
    fi
    
    log "Installing $description..."
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$package" &>>"$LOG_FILE"; then
        log_success "$description installed successfully"
        return 0
    else
        log_error "Failed to install $description"
        return 1
    fi
}

# Installation categories
INSTALL_BASIC=true
INSTALL_IDES=true
INSTALL_CONTAINERS=true
INSTALL_CLOUD=true
INSTALL_DATABASES=true
INSTALL_LANGUAGES=true

show_menu() {
    echo
    echo "===================================================="
    echo "  Kali Linux Development Environment Setup v2.0"
    echo "===================================================="
    echo "Select installation categories:"
    echo "1) System Updates & Essential Tools [$INSTALL_BASIC]"
    echo "2) IDEs & Editors (Cursor, Zed, Warp) [$INSTALL_IDES]"
    echo "3) Containers (Docker, Kubernetes) [$INSTALL_CONTAINERS]"
    echo "4) Cloud SDKs (AWS, Azure, GCP) [$INSTALL_CLOUD]"
    echo "5) Databases (MongoDB) [$INSTALL_DATABASES]"
    echo "6) Programming Languages [$INSTALL_LANGUAGES]"
    echo "7) Start Installation"
    echo "8) Exit"
    echo
    echo "Current log file: $LOG_FILE"
}

toggle_option() {
    case $1 in
        1) INSTALL_BASIC=$([[ $INSTALL_BASIC == true ]] && echo false || echo true) ;;
        2) INSTALL_IDES=$([[ $INSTALL_IDES == true ]] && echo false || echo true) ;;
        3) INSTALL_CONTAINERS=$([[ $INSTALL_CONTAINERS == true ]] && echo false || echo true) ;;
        4) INSTALL_CLOUD=$([[ $INSTALL_CLOUD == true ]] && echo false || echo true) ;;
        5) INSTALL_DATABASES=$([[ $INSTALL_DATABASES == true ]] && echo false || echo true) ;;
        6) INSTALL_LANGUAGES=$([[ $INSTALL_LANGUAGES == true ]] && echo false || echo true) ;;
    esac
}

# Installation functions
install_system_basics() {
    [[ $INSTALL_BASIC != true ]] && return 0
    
    log "=== SYSTEM UPDATES & ESSENTIAL TOOLS ==="
    
    log "Updating package repositories..."
    sudo apt-get update -y &>>"$LOG_FILE" || {
        log_error "Failed to update package repositories"
        return 1
    }
    
    log "Upgrading system packages..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y &>>"$LOG_FILE" || {
        log_warn "System upgrade completed with some warnings"
    }
    
    local essential_packages=(
        curl wget gnupg software-properties-common apt-transport-https
        ca-certificates lsb-release unzip build-essential git vim htop tree
        jq zip p7zip-full net-tools dnsutils
    )
    
    for package in "${essential_packages[@]}"; do
        install_package "$package"
    done
    
    log_success "System basics installation completed"
}

install_ides() {
    [[ $INSTALL_IDES != true ]] && return 0
    
    log "=== IDEs & EDITORS ==="
    
    mkdir -p "$TEMP_DIR"
    
    # Cursor IDE
    if ! is_installed cursor; then
        log "Installing Cursor IDE..."
        local cursor_deb="$TEMP_DIR/cursor.deb"
        if safe_download "https://downloader.cursor.sh/linux/appImage/x64" "$cursor_deb"; then
            if sudo dpkg -i "$cursor_deb" &>>"$LOG_FILE" || sudo apt-get -f install -y &>>"$LOG_FILE"; then
                log_success "Cursor IDE installed successfully"
            else
                log_error "Failed to install Cursor IDE"
            fi
        fi
    fi
    
    # VS Code (more reliable alternative)
    if ! is_installed code; then
        log "Installing Visual Studio Code..."
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/ &>>"$LOG_FILE"
        echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
        sudo apt-get update &>>"$LOG_FILE"
        install_package "code" "Visual Studio Code"
        rm -f packages.microsoft.gpg
    fi
    
    # Chromium Browser
    install_package "chromium" "Chromium Browser"
    
    log_success "IDEs & Editors installation completed"
}

install_containers() {
    [[ $INSTALL_CONTAINERS != true ]] && return 0
    
    log "=== CONTAINERIZATION ==="
    
    # Docker
    if ! is_installed docker; then
        log "Installing Docker..."
        
        # Remove old versions
        sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
        
        # Install Docker using official convenience script (more reliable)
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh &>>"$LOG_FILE"
        rm get-docker.sh
        
        # Add user to docker group
        sudo usermod -aG docker "$USER"
        log_success "Docker installed. Please log out and back in to use Docker without sudo."
    fi
    
    # Docker Compose (standalone)
    if ! is_installed docker-compose; then
        log "Installing Docker Compose..."
        local compose_version
        compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
        sudo curl -L "https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        log_success "Docker Compose installed"
    fi
    
    # kubectl
    if ! is_installed kubectl; then
        log "Installing kubectl..."
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
        echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl kubectl.sha256
        log_success "kubectl installed"
    fi
    
    # minikube
    if ! is_installed minikube; then
        log "Installing minikube..."
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
        rm minikube-linux-amd64
        log_success "minikube installed"
    fi
    
    log_success "Containerization tools installation completed"
}

install_cloud_sdks() {
    [[ $INSTALL_CLOUD != true ]] && return 0
    
    log "=== CLOUD SDKs ==="
    
    # AWS CLI v2
    if ! is_installed aws; then
        log "Installing AWS CLI v2..."
        local aws_zip="$TEMP_DIR/awscliv2.zip"
        if safe_download "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" "$aws_zip"; then
            cd "$TEMP_DIR"
            unzip -q "$aws_zip"
            sudo ./aws/install &>>"$LOG_FILE"
            log_success "AWS CLI v2 installed"
        fi
    fi
    
    # Azure CLI
    if ! is_installed az; then
        log "Installing Azure CLI..."
        curl -sL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
        sudo apt-get update &>>"$LOG_FILE"
        install_package "azure-cli" "Azure CLI"
    fi
    
    # Google Cloud SDK
    if ! is_installed gcloud; then
        log "Installing Google Cloud SDK..."
        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
        curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
        sudo apt-get update &>>"$LOG_FILE"
        install_package "google-cloud-cli" "Google Cloud SDK"
    fi
    
    log_success "Cloud SDKs installation completed"
}

install_databases() {
    [[ $INSTALL_DATABASES != true ]] && return 0
    
    log "=== DATABASES ==="
    
    # MongoDB
    if ! is_installed mongod; then
        log "Installing MongoDB Community Edition..."
        curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg --dearmor -o /etc/apt/keyrings/mongodb-server-7.0.gpg
        echo "deb [ arch=amd64,arm64 signed-by=/etc/apt/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
        sudo apt-get update &>>"$LOG_FILE"
        install_package "mongodb-org" "MongoDB"
        
        # Enable and start MongoDB
        sudo systemctl enable mongod &>>"$LOG_FILE"
        sudo systemctl start mongod &>>"$LOG_FILE"
        log_success "MongoDB installed and started"
    fi
    
    # PostgreSQL
    install_package "postgresql postgresql-contrib" "PostgreSQL"
    
    # Redis
    install_package "redis-server" "Redis"
    
    log_success "Databases installation completed"
}

install_programming_languages() {
    [[ $INSTALL_LANGUAGES != true ]] && return 0
    
    log "=== PROGRAMMING LANGUAGES ==="
    
    # Python 3 and pip
    install_package "python3 python3-pip python3-venv" "Python 3 and pip"
    
    # Node.js (via NodeSource)
    if ! is_installed node; then
        log "Installing Node.js LTS..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - &>>"$LOG_FILE"
        install_package "nodejs" "Node.js"
        
        # Install useful global packages
        sudo npm install -g npm@latest &>>"$LOG_FILE"
        sudo npm install -g yarn pnpm typescript @angular/cli @vue/cli create-react-app &>>"$LOG_FILE"
    fi
    
    # Java
    install_package "openjdk-17-jdk maven gradle" "OpenJDK 17, Maven, and Gradle"
    
    # PHP
    install_package "php php-cli php-fpm php-common php-mysql php-zip php-gd php-mbstring php-curl php-xml php-bcmath" "PHP and extensions"
    
    # Install Composer
    if ! is_installed composer; then
        log "Installing Composer..."
        cd "$TEMP_DIR"
        php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
        php composer-setup.php --install-dir=/usr/local/bin --filename=composer &>>"$LOG_FILE"
        rm composer-setup.php
        log_success "Composer installed"
    fi
    
    # Ruby
    install_package "ruby ruby-dev" "Ruby"
    if ! gem list bundler -i &>/dev/null; then
        sudo gem install bundler &>>"$LOG_FILE"
        log_success "Bundler installed"
    fi
    
    # Go
    install_package "golang-go" "Go"
    
    # Rust via rustup
    if ! is_installed rustc; then
        log "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y &>>"$LOG_FILE"
        source "$HOME/.cargo/env"
        log_success "Rust installed. Add 'source \$HOME/.cargo/env' to your shell profile."
    fi
    
    # .NET
    if ! is_installed dotnet; then
        log "Installing .NET..."
        wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
        sudo dpkg -i packages-microsoft-prod.deb &>>"$LOG_FILE"
        rm packages-microsoft-prod.deb
        sudo apt-get update &>>"$LOG_FILE"
        install_package "dotnet-sdk-8.0" ".NET SDK"
    fi
    
    log_success "Programming languages installation completed"
}

# Interactive menu
interactive_setup() {
    while true; do
        show_menu
        read -p "Enter your choice (1-8): " choice
        
        case $choice in
            [1-6]) toggle_option "$choice" ;;
            7) break ;;
            8) 
                log "Setup cancelled by user"
                exit 0
                ;;
            *) 
                echo "Invalid option. Please try again."
                sleep 1
                ;;
        esac
    done
}

# Main execution
main() {
    # Pre-flight checks
    check_root
    check_sudo
    check_internet
    check_disk_space
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Show banner
    echo "===================================================="
    echo "  Kali Linux Development Environment Setup v2.0"
    echo "===================================================="
    echo "Log file: $LOG_FILE"
    echo
    
    # Check if running in interactive mode
    if [[ "${1:-}" != "--auto" ]]; then
        interactive_setup
    fi
    
    # Start installation
    local start_time=$(date +%s)
    log "Starting installation process..."
    
    # Install components
    install_system_basics
    install_ides
    install_containers  
    install_cloud_sdks
    install_databases
    install_programming_languages
    
    # Completion summary
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo
    echo "===================================================="
    log_success "Installation completed in $duration seconds!"
    echo "===================================================="
    echo
    echo "📋 Summary:"
    echo "• Log file: $LOG_FILE"
    echo "• For Docker to work without sudo, please log out and back in"
    echo "• For Rust environment, add 'source \$HOME/.cargo/env' to your shell profile"
    echo
    echo "🚀 Quick verification commands:"
    echo "• docker --version"
    echo "• kubectl version --client"
    echo "• aws --version"
    echo "• node --version"
    echo "• python3 --version"
    echo
    
    read -p "Press Enter to continue..."
}

# Handle command line arguments
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Usage: $SCRIPT_NAME [--auto] [--help]"
    echo "  --auto    Run with default settings (no interactive menu)"
    echo "  --help    Show this help message"
    exit 0
fi

# Run main function
main "$@"
