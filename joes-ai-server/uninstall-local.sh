#!/usr/bin/env bash
#
# Joe's Tech Solutions — Local AI Server Uninstaller (Mac / Linux)
# Cleanly removes the AI server, with option to keep or remove data
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/uninstall-local.sh | bash
#
set -euo pipefail

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

CONTAINER_NAME="joes-ai-local"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Joe's Tech Solutions — AI Server Uninstall  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ── Check if container exists ─────────────────────────
if ! docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
  warn "No '${CONTAINER_NAME}' container found. Nothing to uninstall."
  exit 0
fi

# ── Stop and remove container ─────────────────────────
info "Stopping AI server..."
docker stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
docker rm "${CONTAINER_NAME}" >/dev/null 2>&1 || true
ok "Container removed"

# ── Ask about data volumes ───────────────────────────
echo ""
echo -e "${YELLOW}Your chat history and models are stored in Docker volumes.${NC}"
echo -e "${YELLOW}Do you want to keep this data? (You can reinstall later and pick up where you left off)${NC}"
echo ""
echo "  1) Keep my data (recommended — only removes the server, not your chats/models)"
echo "  2) Delete everything (removes all chats, models, and settings permanently)"
echo ""

read -r -p "Choose [1/2]: " choice

case "$choice" in
  2)
    warn "Deleting all data volumes..."
    docker volume rm joes-ai-ollama 2>/dev/null || true
    docker volume rm joes-ai-webui 2>/dev/null || true
    ok "All data deleted"
    ;;
  *)
    ok "Data volumes preserved (joes-ai-ollama, joes-ai-webui)"
    info "To reinstall later, just run the installer again — your data will still be there."
    ;;
esac

# ── Optionally remove the Docker image ────────────────
echo ""
read -r -p "Remove the Docker image too? (saves ~4 GB disk space) [y/N]: " remove_image
if [[ "${remove_image}" =~ ^[Yy]$ ]]; then
  docker rmi ghcr.io/open-webui/open-webui:ollama 2>/dev/null || true
  ok "Docker image removed"
else
  ok "Docker image kept (faster reinstall later)"
fi

# ── Done ───────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          AI Server has been uninstalled.                 ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  To reinstall anytime:                                   ║${NC}"
echo -e "${GREEN}║  curl -fsSL https://raw.githubusercontent.com/           ║${NC}"
echo -e "${GREEN}║    joblas/joes-ai-server/main/install-local.sh | bash    ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  Support: joe@joestechsolutions.com                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
