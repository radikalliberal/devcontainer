#!/bin/bash
set -euo pipefail

# DevContainer Bootstrap Script
# Usage: curl -fsSL <short-url> | bash [-s -- <project-name>]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS]${NC} $*" >&2
}

# Function to check if Docker is installed and running
check_docker() {
    if ! command -v docker &>/dev/null; then
        log_error "Docker is not installed. Please install Docker first:"
        log_error "  - Ubuntu/Debian: sudo apt install docker.io"
        log_error "  - Arch: sudo pacman -S docker"
        log_error "  - Fedora: sudo dnf install docker"
        log_error "Then start the service: sudo systemctl start docker"
        log_error "And add your user to docker group: sudo usermod -aG docker \$USER"
        exit 1
    fi

    if ! docker info &>/dev/null; then
        log_error "Docker daemon is not running. Please start it:"
        log_error "  sudo systemctl start docker"
        exit 1
    fi

    log_success "Docker is installed and running"
}

# Function to check if ~/dev directory exists
check_dev_directory() {
    if [ ! -d "${HOME}/dev" ]; then
        log_warn "$HOME/dev directory does not exist. Creating it..."
        mkdir -p "${HOME}/dev"
        log_success "Created $HOME/dev directory"
    else
        log_info "$HOME/dev directory exists"
    fi
}

# Function to download devcontainer project
download_devcontainer() {
    local url="https://github.com/radikalliberal/devcontainer.git"
    local temp_dir="/tmp/devcontainer-setup"

    log_info "Cloning devcontainer project..."

    # Clean up any existing temp directory
    rm -rf "$temp_dir"

    # Clone repository
    if git clone "$url" "$temp_dir"; then
        log_success "Cloned devcontainer project"
        echo "$temp_dir"
    else
        log_error "Failed to clone devcontainer project"
        exit 1
    fi
}

# Function to build and run container
setup_container() {
    local project_name="${1:-default}"
    local devcontainer_dir="$2"

    log_info "Setting up container for project: $project_name"

    # Change to devcontainer directory
    cd "$devcontainer_dir"

    # Set project name environment variable
    export PROJECT_NAME="$project_name"

    # Build the image (if not exists)
    log_info "Building Docker image (this may take a few minutes on first run)..."
    if ! docker-compose build; then
        log_error "Failed to build Docker image"
        exit 1
    fi

    # Start the container interactively
    log_info "Starting container..."
    log_success "Launching interactive session..."
    
    # Run docker-compose with proper stdin/stdout/stderr
    # When piped from curl, we need to reconnect to the terminal
    if [ -t 0 ]; then
        # stdin is a terminal, use it directly
        docker-compose run --rm --service-ports devcontainer
    else
        # stdin is not a terminal (piped from curl), reconnect to controlling terminal
        docker-compose run --rm --service-ports devcontainer </dev/tty
    fi
    local exit_code=$?
    
    log_info "Container session ended"
    return $exit_code
}

# Function to cleanup
cleanup() {
    local temp_dir="$1"
    log_info "Cleaning up temporary files..."
    rm -rf "$temp_dir"
}

# Main function
main() {
    local project_name="default"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
        --project | -p)
            project_name="$2"
            shift 2
            ;;
        --help | -h)
            echo "DevContainer Bootstrap Script"
            echo ""
            echo "Usage:"
            echo "  curl -fsSL <url> | bash [-s -- <options>]"
            echo ""
            echo "Options:"
            echo "  --project, -p <name>    Project name (default: default)"
            echo "  --help, -h             Show this help"
            echo ""
            echo "Examples:"
            echo "  curl -fsSL <url> | bash"
            echo "  curl -fsSL <url> | bash -s -- --project myproject"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
        esac
    done

    log_info "DevContainer Bootstrap Starting..."
    log_info "Project: $project_name"

    # Check prerequisites
    check_docker
    check_dev_directory

    # Download devcontainer project
    local devcontainer_dir
    devcontainer_dir=$(download_devcontainer)

    # Setup and launch container
    setup_container "$project_name" "$devcontainer_dir"
    
    # Cleanup after container exits
    cleanup "$devcontainer_dir"
    
    log_success "DevContainer setup complete!"
}

# Run main function with all arguments
main "$@"

