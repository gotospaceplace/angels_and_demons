#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/gotospaceplace/angels_and_demons.git"
INSTALL_DIR="/opt/angels-and-demons"
COMPOSE_FILE="infra/docker/docker-compose.yml"

echo "=== Angels and Demons — Server Deploy ==="

# Install Docker if missing
if ! command -v docker &>/dev/null; then
    echo "[1/4] Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
else
    echo "[1/4] Docker already installed"
fi

# Clone or pull repo
if [ -d "$INSTALL_DIR" ]; then
    echo "[2/4] Updating repo..."
    cd "$INSTALL_DIR"
    git pull --ff-only
else
    echo "[2/4] Cloning repo..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Open firewall port
echo "[3/4] Opening UDP port 27050..."
if command -v ufw &>/dev/null; then
    ufw allow 27050/udp || true
elif command -v firewall-cmd &>/dev/null; then
    firewall-cmd --permanent --add-port=27050/udp || true
    firewall-cmd --reload || true
fi

# Build and start
echo "[4/4] Building and starting server..."
docker compose -f "$COMPOSE_FILE" up -d --build

echo ""
echo "=== Server running ==="
echo "Port: 27050/udp"
echo "Logs: docker compose -f $COMPOSE_FILE logs -f"
echo "Stop: docker compose -f $COMPOSE_FILE down"
echo "Update: git pull && docker compose -f $COMPOSE_FILE up -d --build"
