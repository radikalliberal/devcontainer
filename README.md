# DevContainer

A portable, Docker-based development environment that works across any Linux machine. Built on Arch Linux with all your favorite development tools pre-installed.

## 🚀 Features

- **Portable**: Works on any Linux machine with Docker
- **Stateless**: No configuration persists between sessions
- **Multi-Project**: Run isolated containers for different projects
- **Docker-in-Docker**: Full Docker capabilities inside the container
- **Latest Tools**: Always up-to-date packages via Arch Linux
- **One-Command Setup**: `curl | bash` bootstrap script
- **GitHub Integration**: Automatic SSH key setup and authentication

## 🛠️ Included Tools

- **Editors**: Neovim (latest), tmux, zsh + oh-my-zsh
- **Languages**: Python (uv), Go, Node.js (nvm), Rust, C/C++
- **Tools**: Git, GitHub CLI, lazygit, ripgrep, fzf, fastfetch
- **DevOps**: Docker, docker-compose, CMake
- **Utilities**: atuin (shell history), oxker, fd, luarocks

## 📋 Prerequisites

- Linux machine with Docker installed
- Internet connection for initial setup
- GitHub account for authentication

### Install Docker

**Ubuntu/Debian:**

```bash
sudo apt update
sudo apt install docker.io
sudo systemctl start docker
sudo usermod -aG docker $USER
```

**Arch Linux:**

```bash
sudo pacman -S docker
sudo systemctl start docker
sudo usermod -aG docker $USER
```

**Fedora:**

```bash
sudo dnf install docker
sudo systemctl start docker
sudo usermod -aG docker $USER
```

## 🚀 Quick Start

### Option 1: One-Command Setup (Recommended)

```bash
# Replace <short-url> with your short URL (see Short URL Setup below)
curl -fsSL <short-url> | bash
```

### Option 2: Manual Setup

```bash
# Clone this repository
git clone https://github.com/radikalliberal/devcontainer.git
cd devcontainer

# Build and run
make build
make run
```

## 📖 Usage

### SSH Key Forwarding

The container can use your existing SSH keys from the host machine:

```bash
# Ensure your SSH agent is running on the host
eval $(ssh-agent)
ssh-add ~/.ssh/id_ed25519  # or your key name

# Run the container (keys will be automatically forwarded)
make run
```

The container will:

1. Mount your `~/.ssh` directory (read-only)
2. Forward the SSH agent socket
3. Use your existing keys for Git operations

**Note**: If no SSH keys are found, the container will generate new ones and register them with GitHub.

### Basic Commands

```bash
# Start container for default project
make run

# Start container for specific project
make run-myproject

# Get shell access directly
make shell

# View logs
make logs

# Stop containers
make stop

# Clean up everything
make clean
```

### Project Isolation

Run multiple projects simultaneously with different names:

```bash
# Terminal 1: Work on project A
make run-projectA

# Terminal 2: Work on project B
make run-projectB

# Each gets its own container: devcontainer-projectA, devcontainer-projectB
```

### Bootstrap Script Options

```bash
# Run with custom project name
bash <(curl -fsSL https://is.gd/RHw93q) --project myproject

# Show help
bash <(curl -fsSL https://is.gd/RHw93q) --help
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Any Linux Machine                                          │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  curl short.url/devcontainer.sh | bash                 │ │
│  └───────────────────┬───────────────────────────────────┘ │
│                      ↓                                      │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ 1. Checks Docker installed                            │ │
│  │ 2. Downloads Dockerfile from GitHub                   │ │
│  │ 3. Builds Arch-based image (cached after first build) │ │
│  │  └───────────────────┬────────────────────────────────┘ │
│                          ↓                                  │
│  ┌───────────────────────────────────────────────────────┐ │
│  │ Container Entrypoint:                                 │ │
│  │ - Prompts for GitHub auth (gh auth login)             │ │
│  │ - Sets up SSH key                                     │ │
│  │ - Clones & applies dotfiles via chezmoi               │ │
│  │ - Drops into zsh shell                                │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Key Design Decisions

- **Base Image**: `archlinux:latest` for rolling releases and latest packages
- **No Persistence**: Fresh authentication each session, only `~/dev` mounted
- **Privileged Mode**: Required for Docker-in-Docker functionality
- **User Isolation**: Non-root user `dev` with sudo access
- **Volume Mounts**:
  - `~/dev` → `/home/dev/dev` (your code)
  - `/var/run/docker.sock` (Docker socket for DinD)

## 🔧 Configuration

### Environment Variables

- `PROJECT_NAME`: Container and SSH key naming (default: `default`)
- `HOME`: Container home directory (`/home/dev`)

### Customization

Edit these files to customize your environment:

- `Dockerfile`: Add/remove packages or tools
- `entrypoint.sh`: Modify initialization logic
- `docker-compose.yml`: Change mounts, environment, or networking

## 🐛 Troubleshooting

### Common Issues

**"Docker not found"**

```bash
# Install Docker
sudo apt install docker.io  # Ubuntu/Debian
sudo pacman -S docker       # Arch
sudo dnf install docker     # Fedora

# Start service
sudo systemctl start docker

# Add user to docker group
sudo usermod -aG docker $USER
# Logout and login again, or run: newgrp docker
```

**"Permission denied" on ~/dev**

```bash
# Ensure ~/dev exists and is writable
mkdir -p ~/dev
ls -la ~/dev
```

**GitHub authentication fails**

- Ensure you have a GitHub account
- Complete the device authentication in your browser
- Check internet connection

**Container exits immediately**

```bash
# Check logs
make logs

# Try shell access
make shell
```

**Build fails**

```bash
# Clean and rebuild
make clean
make build

# Update base image
make update
```

### Debug Mode

```bash
# Run with verbose logging
PROJECT_NAME=debug make run

# Check container status
make status

# View system info
make info
```

## 📁 Project Structure

```
devcontainer/
├── Dockerfile              # Arch Linux base image with all tools
├── docker-compose.yml      # Container orchestration
├── entrypoint.sh          # Initialization script (auth + dotfiles)
├── devcontainer.sh        # Bootstrap script for curl | bash
├── Makefile               # Helper commands
└── README.md              # This file
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Happy coding! 🎉**

For issues or questions, please open an issue on GitHub.

