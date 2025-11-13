#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS]${NC} $*"
}

# Function to check if GitHub CLI is authenticated
check_gh_auth() {
    if gh auth status >/dev/null 2>&1; then
        log_success "GitHub CLI is already authenticated"
        return 0
    else
        log_warn "GitHub CLI authentication required"
        return 1
    fi
}

# Function to authenticate with GitHub
authenticate_github() {
    log_info "Starting GitHub authentication..."
    log_info "A browser window will open for device authentication"
    log_info "Complete the authentication in your browser"

    if gh auth login --git-protocol ssh --hostname github.com --web; then
        log_success "GitHub authentication successful"
        return 0
    else
        log_error "GitHub authentication failed"
        return 1
    fi
}

# Function to get SSH public key content
get_public_key_content() {
    local key_file=$1
    if [ -f "${key_file}" ]; then
        # Extract just the key part (second field)
        awk '{print $2}' "${key_file}" 2>/dev/null
    fi
}

# Function to check if key is registered on GitHub
is_key_on_github() {
    local key_path=$1
    # Test SSH connectivity to GitHub using this specific key
    local output
    output=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes -i "${key_path}" -T git@github.com 2>&1)
    local exit_code=$?

    # GitHub returns exit code 1 even on successful auth (because no shell access)
    # Check for success message in output
    if echo "${output}" | grep -q "successfully authenticated"; then
        return 0
    fi

    # Log the actual error for debugging
    log_warn "SSH test output: ${output}"
    return 1
}

# Function to setup SSH key
setup_ssh_key() {
    log_info "Checking SSH key setup..."

    # Check if SSH keys are mounted from host
    if [ ! -d "${HOME}/.ssh" ] || [ -z "$(ls -A ${HOME}/.ssh/*.pub 2>/dev/null)" ]; then
        log_error "No SSH keys found from host machine"
        log_error "Please ensure your ~/.ssh directory is mounted and contains SSH keys"
        log_error "Run: make shell (with SSH keys in ~/.ssh)"
        return 1
    fi

    log_info "Found SSH keys from host machine"

    # Look for SSH keys (prefer ed25519, then rsa)
    local host_key=""
    for key_type in id_ed25519 id_rsa id_ecdsa; do
        if [ -f "${HOME}/.ssh/${key_type}" ] && [ -f "${HOME}/.ssh/${key_type}.pub" ]; then
            host_key="${HOME}/.ssh/${key_type}"
            break
        fi
    done

    if [ -z "${host_key}" ]; then
        log_error "No usable SSH key pairs found in ~/.ssh"
        log_error "Expected to find one of: id_ed25519, id_rsa, or id_ecdsa"
        return 1
    fi

    log_info "Found host SSH key: ${host_key##*/}"

    # Skip GitHub test if SKIP_GITHUB_CHECK is set
    if [ "${SKIP_GITHUB_CHECK:-false}" != "true" ]; then
        log_info "Testing if key works with GitHub..."

        # Check if this key is registered on GitHub by testing SSH connectivity
        if ! is_key_on_github "${host_key}"; then
            log_error "Host SSH key found but NOT registered on GitHub"
            log_error "Please add this key to GitHub: https://github.com/settings/keys"
            log_error ""
            log_error "Your public key:"
            cat "${host_key}.pub"
            log_error ""
            log_warn "To skip this check, set SKIP_GITHUB_CHECK=true"
            return 1
        fi

        log_success "Host SSH key is already registered on GitHub!"
    else
        log_warn "Skipping GitHub SSH key verification (SKIP_GITHUB_CHECK=true)"
    fi

    # Since .ssh is read-only, copy the key to a writable location
    local ssh_writable_dir="${HOME}/.ssh-container"
    mkdir -p "${ssh_writable_dir}"
    chmod 700 "${ssh_writable_dir}"

    # Copy the private key
    cp "${host_key}" "${ssh_writable_dir}/"
    cp "${host_key}.pub" "${ssh_writable_dir}/"
    chmod 600 "${ssh_writable_dir}/$(basename ${host_key})"
    chmod 644 "${ssh_writable_dir}/$(basename ${host_key}).pub"

    local writable_key="${ssh_writable_dir}/$(basename ${host_key})"

    # Start SSH agent and add the key
    eval "$(ssh-agent -s)" >/dev/null
    if ssh-add "${writable_key}" 2>/dev/null; then
        log_success "Host SSH key added to agent"
    else
        log_warn "Could not add key to agent (may require passphrase)"
        # Still continue, git will try to use the key directly
    fi

    # Create SSH config to use this key
    cat >"${ssh_writable_dir}/config" <<EOF
Host github.com
    IdentityFile ${writable_key}
    User git

Host *
    IdentityFile ${writable_key}
EOF
    chmod 600 "${ssh_writable_dir}/config"
    export GIT_SSH_COMMAND="ssh -F ${ssh_writable_dir}/config"

    log_success "SSH configuration complete"
    return 0
}

# Function to setup dotfiles with chezmoi
setup_dotfiles() {
    local dotfiles_repo="git@github.com:radikalliberal/dotfiles.git"

    log_info "Setting up dotfiles with chezmoi..."

    # Remove any existing chezmoi config to start fresh
    rm -rf ~/.local/share/chezmoi ~/.config/chezmoi

    # Initialize and apply dotfiles
    if chezmoi init --apply "${dotfiles_repo}"; then
        log_success "Dotfiles applied successfully"
        return 0
    else
        log_error "Failed to apply dotfiles"
        return 1
    fi
}

# Function to setup git config
setup_git_config() {
    log_info "Setting up git configuration..."

    # Set git user name
    git config --global user.name "Jan Schlüter"

    # Set email based on environment (work vs personal)
    if ping -q -c 1 -W 1 br-documentserver &>/dev/null; then
        git config --global user.email "jan.schlueter@dermalog.com"
        log_info "Configured for work environment"
    else
        git config --global user.email "radikalliber@gmail.com"
        log_info "Configured for personal environment"
    fi
}

# Main setup function
main() {
    log_info "Starting DevContainer initialization..."
    log_info "Project: ${PROJECT_NAME:-default}"

    # Setup SSH key first (doesn't require gh auth)
    if ! setup_ssh_key; then
        log_error "Failed to setup SSH key"
        exit 1
    fi

    # Check and setup GitHub authentication (needed for gh ssh-key add if creating new key)
    if ! check_gh_auth; then
        log_warn "GitHub CLI not authenticated - will authenticate if needed for key management"
    fi

    # Setup dotfiles
    if ! setup_dotfiles; then
        log_error "Failed to setup dotfiles"
        exit 1
    fi

    # Setup git config
    setup_git_config

    log_success "DevContainer initialization complete!"
    log_info "Starting zsh shell..."

    # Export GitHub token for scripts that expect it
    export GITHUB_TOKEN="$(gh auth token 2>/dev/null || true)"

    # Start the shell
    exec /bin/zsh
}

# Run main function
main "$@"
