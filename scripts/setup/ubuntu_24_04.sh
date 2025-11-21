#!/usr/bin/env bash
#
# ubuntu24_04.sh
#
# Install Docker Engine and Docker Compose plugin on Ubuntu 24.04 LTS (noble)
# using the official Docker APT repository.
#

set -euo pipefail

echo "[INFO] Checking for root privileges..."
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] This script must be run as root. Try:"
    echo "  sudo $0"
    exit 1
fi

echo "[INFO] Updating package index..."
apt-get update -y

echo "[INFO] Installing prerequisites (ca-certificates, curl, gnupg)..."
apt-get install -y ca-certificates curl gnupg

echo "[INFO] Setting up Docker GPG keyring..."
install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg

echo "[INFO] Adding Docker APT repository..."
. /etc/os-release

ARCH="$(dpkg --print-architecture)"
DOCKER_LIST_FILE="/etc/apt/sources.list.d/docker.list"

cat > "$DOCKER_LIST_FILE" <<EOF
deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable
EOF

echo "[INFO] Docker APT source written to ${DOCKER_LIST_FILE}:"
cat "$DOCKER_LIST_FILE"

echo "[INFO] Updating package index with Docker repository..."
apt-get update -y

echo "[INFO] Installing Docker Engine, CLI, containerd, Buildx and Compose plugin..."
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

echo "[INFO] Enabling and starting Docker service..."
systemctl enable docker
systemctl restart docker

echo "[INFO] Verifying Docker installation with hello-world image..."
if docker run --rm hello-world > /dev/null 2>&1; then
    echo "[SUCCESS] Docker is installed and working correctly."
else
    echo "[WARNING] Docker installed, but 'docker run hello-world' did not complete successfully."
    echo "          Check 'docker run hello-world' output manually for more details."
fi

echo
echo "[INFO] Docker Compose plugin is installed. Use:"
echo "  docker compose up"
echo "instead of the legacy 'docker-compose' command."
echo
echo "[DONE] Ubuntu 24.04 Docker setup complete."
