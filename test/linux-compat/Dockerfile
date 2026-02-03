FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies and required packages
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    coreutils \
    git \
    sed \
    gawk \
    findutils \
    grep \
    curl \
    util-linux \
    lsb-release \
    ca-certificates \
    locales \
    unzip \
    libsecret-tools \
    gnome-keyring \
    dbus-x11 \
    && rm -rf /var/lib/apt/lists/*

# Generate en_US.UTF-8 locale to avoid locale warnings
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Install bash 5.3+ (required for ${...; } command substitution syntax)
# Ubuntu 22.04 ships with bash 5.1.16, but rayvn requires 5.2+
RUN cd /tmp && \
    wget https://ftp.gnu.org/gnu/bash/bash-5.3.tar.gz && \
    tar -xzf bash-5.3.tar.gz && \
    cd bash-5.3 && \
    ./configure --prefix=/usr/local && \
    make && \
    make install && \
    cd / && \
    rm -rf /tmp/bash-5.3* && \
    # Make the new bash the default
    ln -sf /usr/local/bin/bash /bin/bash

# Install Bitwarden CLI (required for wardn tests)
# Dynamically fetch and install the latest CLI release
RUN cd /tmp && \
    # Get all releases and filter for CLI releases only
    wget -qO- https://api.github.com/repos/bitwarden/clients/releases > releases.json && \
    # Extract the first (latest) CLI version tag (e.g., "cli-v2024.12.0")
    TAG=$(grep '"tag_name"' releases.json | grep 'cli-v' | head -1 | sed 's/.*"tag_name": "\(cli-v[^"]*\)".*/\1/') && \
    # Extract version number (e.g., "2024.12.0")
    VERSION=$(echo "$TAG" | sed 's/cli-v//') && \
    # Construct download URL
    DOWNLOAD_URL="https://github.com/bitwarden/clients/releases/download/${TAG}/bw-linux-${VERSION}.zip" && \
    # Download and install
    wget "$DOWNLOAD_URL" && \
    unzip "bw-linux-${VERSION}.zip" && \
    chmod +x bw && \
    mv bw /usr/local/bin/ && \
    cd / && \
    rm -rf /tmp/bw-linux-*.zip /tmp/releases.json

# Set bash as the default shell
SHELL ["/usr/local/bin/bash", "-c"]

# Create a non-root user for running tests
RUN useradd -m -s /bin/bash testuser

# Prepare Nix store directory for single-user install
RUN mkdir -m 0755 /nix && chown testuser:testuser /nix

# Copy test runner script into the image (must be done before switching to testuser)
COPY test-runner.sh /usr/local/bin/test-runner.sh
RUN chmod 755 /usr/local/bin/test-runner.sh

# Set working directory
WORKDIR /workspace

# Switch to non-root user
USER testuser

# Configure git for testuser (required by test-create)
RUN git config --global user.name "Test User" && \
    git config --global user.email "testuser@example.com"

# Install Nix in single-user mode (as testuser)
RUN curl -L https://nixos.org/nix/install | bash -s -- --no-daemon && \
    mkdir -p /home/testuser/.config/nix && \
    echo 'experimental-features = nix-command flakes' > /home/testuser/.config/nix/nix.conf

ENV PATH="/home/testuser/.nix-profile/bin:${PATH}"

# Default command
CMD ["/bin/bash"]
