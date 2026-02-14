#!/usr/bin/env bash
#
# Joe's Tech Solutions — VPS AI Server Uninstaller
# Cleanly removes the full stack with data preservation options
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/uninstall-vps.sh | bash
#
set -euo pipefail

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

STACK_DIR="/opt/joes-ai-stack"
BACKUP_DIR="/opt/joes-ai-backups"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Joe's Tech Solutions — VPS Server Uninstall  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ── Check: running as root ────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
  fail "This script must be run as root. Try: sudo bash uninstall-vps.sh"
fi

# ── Check if stack exists ─────────────────────────────
if [ ! -d "${STACK_DIR}" ]; then
  warn "No installation found at ${STACK_DIR}. Nothing to uninstall."
  exit 0
fi

# ── Create final backup before uninstall ──────────────
info "Creating a safety backup before uninstall..."
if [ -f "${STACK_DIR}/scripts/backup.sh" ]; then
  bash "${STACK_DIR}/scripts/backup.sh" 2>/dev/null || warn "Backup failed — continuing anyway"
  ok "Safety backup created in ${BACKUP_DIR}"
else
  warn "Backup script not found — skipping"
fi

echo ""
echo -e "${YELLOW}This will remove:${NC}"
echo "  - All Docker containers (ollama, open-webui, caddy, watchtower)"
echo "  - Stack configuration (${STACK_DIR})"
echo "  - Cron jobs for automated backups"
echo ""
echo -e "${YELLOW}This will NOT remove:${NC}"
echo "  - Docker itself"
echo "  - Backups in ${BACKUP_DIR}"
echo "  - Firewall rules"
echo ""

read -r -p "Continue with uninstall? [y/N]: " confirm
if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
  info "Uninstall cancelled."
  exit 0
fi

# ── Stop and remove containers ────────────────────────
info "Stopping all services..."
cd "${STACK_DIR}"

echo ""
read -r -p "Delete all data (chats, models, settings)? [y/N]: " delete_data
if [[ "${delete_data}" =~ ^[Yy]$ ]]; then
  docker compose down -v 2>/dev/null || true
  ok "Containers and data volumes removed"
else
  docker compose down 2>/dev/null || true
  ok "Containers removed (data volumes preserved)"
  info "Data volumes kept — reinstall will restore your chats and models"
fi

# ── Remove cron job ───────────────────────────────────
info "Removing backup cron job..."
(crontab -l 2>/dev/null | grep -v "joes-ai-stack" || true) | crontab -
ok "Cron job removed"

# ── Remove stack directory ────────────────────────────
info "Removing stack configuration..."
rm -rf "${STACK_DIR}"
ok "Stack directory removed"

# ── Done ───────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          VPS AI Server has been uninstalled.             ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  Backups preserved in: ${BACKUP_DIR}                    ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  To reinstall:                                           ║${NC}"
echo -e "${GREEN}║  AI_DOMAIN=ai.example.com EMAIL=you@example.com \\       ║${NC}"
echo -e "${GREEN}║  curl -fsSL https://raw.githubusercontent.com/           ║${NC}"
echo -e "${GREEN}║    joblas/joes-ai-server/main/install-vps.sh | bash      ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  Support: joe@joestechsolutions.com                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
