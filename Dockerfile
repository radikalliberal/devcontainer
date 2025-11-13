# DevContainer Dockerfile
# Based on Arch Linux for latest packages
FROM archlinux:latest

# Set environment variables
ENV USER=dev
ENV HOME=/home/$USER
ENV INSTALL_FOLDER=$HOME/.local/share
ENV BIN_FOLDER=$HOME/.local/bin
ENV PATH="$BIN_FOLDER:$HOME/.cargo/bin:/usr/local/go/bin:$HOME/go/bin:$HOME/.local/bin:$PATH"
ENV GOPATH=$HOME/go
ENV CARGO_HOME=$HOME/.cargo
ENV RUSTUP_HOME=$HOME/.rustup
ENV DEBIAN_FRONTEND=noninteractive

# Install base packages
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        base-devel \
        unzip \
        git \
        python \
        python-pip \
        tmux \
        zsh \
        curl \
        wget \
        openssh \
        sudo \
        fd \
        cowsay \
        neovim \
        cmake \
        go \
        nodejs \
        npm \
        rustup \
        luarocks \
        docker \
        docker-compose \
        ripgrep \
        lazygit \
        fastfetch \
        chezmoi \
        && \
    pacman -Scc --noconfirm

# Create non-root user
RUN useradd -m -s /bin/zsh $USER && \
    echo "$USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir -p $INSTALL_FOLDER $BIN_FOLDER && \
    chown -R $USER:$USER $HOME

# Switch to user
USER $USER
WORKDIR $HOME

# Install bin package manager
RUN if ! command -v bin &>/dev/null; then \
        wget https://github.com/marcosnils/bin/releases/download/v0.23.1/bin_0.23.1_linux_amd64 && \
        chmod +x bin_0.23.1_linux_amd64 && \
        ./bin_0.23.1_linux_amd64 install https://github.com/marcosnils/bin && \
        rm bin_0.23.1_linux_amd64; \
    fi

# Install additional tools via bin
RUN bin install https://github.com/junegunn/fzf && \
    bin install https://github.com/mrjackwills/oxker

# Install uv (Python package manager)
RUN if ! command -v uv &>/dev/null; then \
        curl -LsSf https://astral.sh/uv/install.sh | sh; \
    fi

# Install Rust toolchain via rustup
RUN rustup default stable && \
    rustup component add clippy rustfmt rust-analyzer

# Configure npm for user-local global installs
# This allows npm install -g to work without sudo
RUN mkdir -p "$HOME/.local" && \
    npm config set prefix "$HOME/.local" && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && \
    echo 'NPM prefix configured to: ' && npm config get prefix

# Install global npm packages (pre-install mcp-hub for immediate use)
RUN npm install -g mcp-hub@latest

# Verify installations
RUN go version && \
    node --version && \
    npm --version && \
    rustc --version && \
    cargo --version && \
    mcp-hub --version

# Install atuin (shell history)
RUN bash <(curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh)

# Install oh-my-zsh (will be configured at runtime)
RUN rm -rf ~/.oh-my-zsh && \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --keep-zshrc

# Install luarocks package
RUN luarocks install luaposix --local

# Install GitHub CLI
RUN if ! command -v gh &>/dev/null; then \
        sudo pacman -S --noconfirm github-cli; \
    fi

# Create entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sudo chmod +x /usr/local/bin/entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]