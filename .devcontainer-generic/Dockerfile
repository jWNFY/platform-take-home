FROM mcr.microsoft.com/devcontainers/go:1.23

# Install Docker and other dependencies
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    protobuf-compiler \
    postgresql-client \
    python3-pip \ 
    python3-venv \
    pipx \
    sudo \
    git \
    ca-certificates \
    curl \
    gnupg \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo \
      "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get -y install --no-install-recommends \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/ \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* \
    && echo "vscode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/vscode

# Add vscode user to docker group
RUN usermod -aG docker vscode

# Create docker-init script
RUN echo '#!/bin/sh\n\
sudo service docker start\n\
sudo chmod 666 /var/run/docker.sock\n\
exec "$@"' > /usr/local/bin/docker-init.sh \
    && chmod +x /usr/local/bin/docker-init.sh

USER vscode

# Set up PATH
ENV PATH="${PATH}:/home/vscode/.local/bin:/home/vscode/go/bin"
RUN echo "export PATH=\"\$PATH:/home/vscode/.local/bin:/home/vscode/go/bin\"" >> /home/vscode/.bashrc && \
    echo "export PATH=\"\$PATH:/home/vscode/.local/bin:/home/vscode/go/bin\"" >> /home/vscode/.profile

# Install pre-commit
RUN pipx install pre-commit