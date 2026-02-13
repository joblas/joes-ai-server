#!/usr/bin/env bash
#
# Joe's Tech Solutions — Local AI Server Installer
# Installs Ollama + Open WebUI on a local machine via Docker
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/joestechsolutions/joes-ai-server/main/install-local.sh | bash
#
# Options (environment variables):
#   WEBUI_PORT=3000        Port for Open WebUI (default: 3000)
#   PULL_MODEL=llama3.2    Auto-download a model after install (default: none)
#
set -euo pipefail

# ── Config ──────────────────────────────────────────────
WEBUI_PORT="${WEBUI_PORT:-3000}"
CONTAINER_NAME="joes-ai-local"
IMAGE="ghcr.io/open-webui/open-webui:ollama"

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Banner ──────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     Joe's Tech Solutions — Local AI Server   ║${NC}"
echo -e "${CYAN}║         Private ChatGPT Alternative          ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ── Step 1: Check Docker ───────────────────────────────
info "Checking Docker installation..."

if ! command -v docker >/dev/null 2>&1; then
  fail "Docker is not installed. Please install Docker Desktop first:
       https://docs.docker.com/get-docker/
       Then run this script again."
fi

if ! docker info >/dev/null 2>&1; then
  fail "Docker daemon is not running.
       • macOS/Windows: Launch Docker Desktop and wait for it to say 'Running'
       • Linux: Run 'sudo systemctl start docker'
       Then run this script again."
fi

ok "Docker is installed and running"

# ── Step 2: Check port availability ────────────────────
if lsof -i ":${WEBUI_PORT}" >/dev/null 2>&1 || ss -tlnp 2>/dev/null | grep -q ":${WEBUI_PORT} " ; then
  warn "Port ${WEBUI_PORT} appears to be in use."
  warn "Set WEBUI_PORT=<number> to use a different port, or stop the conflicting service."
fi

# ── Step 3: Pull image ─────────────────────────────────
info "Pulling latest Open WebUI + Ollama image (this may take a few minutes first time)..."
docker pull "${IMAGE}"
ok "Image pulled successfully"

# ── Step 4: Stop existing container if present ─────────
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  info "Existing '${CONTAINER_NAME}' container found. Updating..."
  docker stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  docker rm "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  ok "Old container removed (data volumes preserved)"
fi

# ── Step 5: Start container ────────────────────────────
info "Starting AI server on port ${WEBUI_PORT}..."
docker run -d \
  -p "${WEBUI_PORT}:8080" \
  -v joes-ai-ollama:/root/.ollama \
  -v joes-ai-webui:/app/backend/data \
  --name "${CONTAINER_NAME}" \
  --restart unless-stopped \
  "${IMAGE}"

ok "Container started"

# ── Step 6: Auto-pull model if requested ───────────────
if [ -n "${PULL_MODEL:-}" ]; then
  info "Downloading model '${PULL_MODEL}' (this can take several minutes)..."
  # Wait for Ollama to be ready inside the container
  sleep 5
  docker exec "${CONTAINER_NAME}" ollama pull "${PULL_MODEL}" || warn "Model pull failed — you can pull it manually from the UI"
  ok "Model '${PULL_MODEL}' downloaded"
fi

# ── Step 7: Wait for WebUI to be ready ─────────────────
info "Waiting for Open WebUI to start..."
for i in $(seq 1 30); do
  if curl -sf "http://localhost:${WEBUI_PORT}" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# ── Done ───────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          ✅ Joe's Local AI Server is LIVE!           ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  Open your browser:  http://localhost:${WEBUI_PORT}            ║${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  First visit:                                        ║${NC}"
echo -e "${GREEN}║    1. Create your admin account                      ║${NC}"
echo -e "${GREEN}║    2. Go to Settings → Models → Pull a model         ║${NC}"
echo -e "${GREEN}║       (try: llama3.2, mistral, or phi3)              ║${NC}"
echo -e "${GREEN}║    3. Start chatting!                                 ║${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  Commands:                                           ║${NC}"
echo -e "${GREEN}║    docker logs ${CONTAINER_NAME}    (view logs)       ║${NC}"
echo -e "${GREEN}║    docker restart ${CONTAINER_NAME} (restart)         ║${NC}"
echo -e "${GREEN}║    docker stop ${CONTAINER_NAME}    (stop server)     ║${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  Support: joe@joestechsolutions.com                  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
