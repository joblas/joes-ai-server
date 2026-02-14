#!/usr/bin/env bash
#
# Joe's Tech Solutions — Local AI Server Uninstaller (Mac / Linux)
# Cleanly removes the native AI server, with option to keep or remove data
#
# Usage (interactive — run directly):
#   bash uninstall-local.sh
#
# Usage (pipe mode — safe defaults, no prompts):
#   curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/uninstall-local.sh | bash
#
# Flags (pass after -- in pipe mode, e.g. `| bash -s -- --remove-all`):
#   --keep-data       Keep chat history & settings (default in pipe mode)
#   --remove-all      Delete everything including chat data
#   --keep-ollama     Keep Ollama installed (default in pipe mode)
#   --remove-ollama   Remove Ollama and all downloaded models
#

main() {
set -euo pipefail

# ── Parse CLI flags ───────────────────────────────────
FLAG_DATA=""       # "", "keep", or "remove"
FLAG_OLLAMA=""     # "", "keep", or "remove"

for arg in "$@"; do
  case "$arg" in
    --keep-data)      FLAG_DATA="keep" ;;
    --remove-all)     FLAG_DATA="remove" ;;
    --keep-ollama)    FLAG_OLLAMA="keep" ;;
    --remove-ollama)  FLAG_OLLAMA="remove" ;;
  esac
done

# ── Detect pipe mode ─────────────────────────────────
# Even inside main(), stdin may still be the pipe (not a terminal).
# We can be interactive if /dev/tty is available (i.e. a real user terminal).
INTERACTIVE=false
if [ -t 0 ]; then
  INTERACTIVE=true
elif [ -c /dev/tty ] 2>/dev/null; then
  # Piped via curl|bash but terminal exists — we can prompt via /dev/tty
  INTERACTIVE=true
fi

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }

JOES_AI_DIR="${HOME}/.joes-ai"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     Joe's Tech Solutions — AI Server Uninstall           ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ── Check if anything is installed ──────────────────────
HAS_INSTALL=false

if [ -d "${JOES_AI_DIR}" ]; then
  HAS_INSTALL=true
fi

if command -v ollama >/dev/null 2>&1; then
  HAS_INSTALL=true
fi

if [ "$HAS_INSTALL" = "false" ]; then
  warn "No Joe's AI Server installation found. Nothing to uninstall."
  exit 0
fi

if [ "$INTERACTIVE" = "false" ]; then
  info "Pipe mode detected — using safe defaults (keep data, keep Ollama)"
  info "Use flags to override: --remove-all, --remove-ollama"
  echo ""
fi

# ── Step 1: Stop running services ───────────────────────
info "Stopping AI server processes..."

# Stop Open WebUI
pkill -f "open-webui" 2>/dev/null || true

# Stop auto-start services and auto-update
if [[ "$OSTYPE" == "darwin"* ]]; then
  PLIST_FILE="${HOME}/Library/LaunchAgents/com.joestechsolutions.ai-server.plist"
  UPDATE_PLIST="${HOME}/Library/LaunchAgents/com.joestechsolutions.ai-update.plist"
  if [ -f "${PLIST_FILE}" ]; then
    launchctl unload "${PLIST_FILE}" 2>/dev/null || true
    ok "macOS LaunchAgent unloaded"
  fi
  if [ -f "${UPDATE_PLIST}" ]; then
    launchctl unload "${UPDATE_PLIST}" 2>/dev/null || true
    ok "macOS auto-update unloaded"
  fi
else
  if systemctl --user is-active joes-ai-webui.service >/dev/null 2>&1; then
    systemctl --user stop joes-ai-webui.service 2>/dev/null || true
    systemctl --user disable joes-ai-webui.service 2>/dev/null || true
    ok "systemd service stopped and disabled"
  fi
fi

ok "Server processes stopped"

# ── Step 2: Handle chat data ─────────────────────────────
# Determine action: flag > interactive prompt > safe default
DATA_ACTION="${FLAG_DATA}"

if [ -z "${DATA_ACTION}" ]; then
  if [ "$INTERACTIVE" = "true" ]; then
    echo ""
    echo -e "${YELLOW}Your chat history and settings are stored in ~/.joes-ai/data/${NC}"
    echo -e "${YELLOW}Do you want to keep this data?${NC}"
    echo ""
    echo "  1) Keep my data (recommended — only removes the server, not your chats)"
    echo "  2) Delete everything (removes all chats, settings permanently)"
    echo ""
    read -r -p "Choose [1/2]: " choice < /dev/tty
    case "$choice" in
      2) DATA_ACTION="remove" ;;
      *) DATA_ACTION="keep" ;;
    esac
  else
    # Pipe mode default: keep data
    DATA_ACTION="keep"
  fi
fi

case "$DATA_ACTION" in
  remove)
    warn "Deleting all Joe's AI data..."
    rm -rf "${JOES_AI_DIR}"
    ok "All data deleted (${JOES_AI_DIR} removed)"
    ;;
  *)
    # Remove everything except data directory
    if [ -d "${JOES_AI_DIR}" ]; then
      rm -rf "${JOES_AI_DIR}/venv" 2>/dev/null || true
      rm -rf "${JOES_AI_DIR}/logs" 2>/dev/null || true
      rm -f "${JOES_AI_DIR}/start-server.sh" 2>/dev/null || true
      rm -f "${JOES_AI_DIR}/stop-server.sh" 2>/dev/null || true
      rm -f "${JOES_AI_DIR}/update.sh" 2>/dev/null || true
      rm -f "${JOES_AI_DIR}/welcome.html" 2>/dev/null || true
      ok "Server files removed. Chat data preserved in ${JOES_AI_DIR}/data/"
      info "To reinstall later, just run the installer again — your data will still be there."
    fi
    ;;
esac

# ── Step 3: Remove auto-start & auto-update configuration ──
if [[ "$OSTYPE" == "darwin"* ]]; then
  PLIST_FILE="${HOME}/Library/LaunchAgents/com.joestechsolutions.ai-server.plist"
  UPDATE_PLIST="${HOME}/Library/LaunchAgents/com.joestechsolutions.ai-update.plist"
  if [ -f "${PLIST_FILE}" ]; then
    rm -f "${PLIST_FILE}"
    ok "macOS auto-start removed"
  fi
  if [ -f "${UPDATE_PLIST}" ]; then
    rm -f "${UPDATE_PLIST}"
    ok "macOS auto-update removed"
  fi
else
  SERVICE_FILE="${HOME}/.config/systemd/user/joes-ai-webui.service"
  UPDATE_SVC="${HOME}/.config/systemd/user/joes-ai-update.service"
  UPDATE_TIMER="${HOME}/.config/systemd/user/joes-ai-update.timer"
  if [ -f "${SERVICE_FILE}" ]; then
    rm -f "${SERVICE_FILE}"
  fi
  if [ -f "${UPDATE_TIMER}" ]; then
    systemctl --user stop joes-ai-update.timer 2>/dev/null || true
    systemctl --user disable joes-ai-update.timer 2>/dev/null || true
    rm -f "${UPDATE_TIMER}"
    rm -f "${UPDATE_SVC}"
  fi
  systemctl --user daemon-reload 2>/dev/null || true
  ok "Linux auto-start and auto-update removed"
fi

# ── Step 4: Handle Ollama ────────────────────────────────
OLLAMA_ACTION="${FLAG_OLLAMA}"

if [ -z "${OLLAMA_ACTION}" ]; then
  if [ "$INTERACTIVE" = "true" ]; then
    echo ""
    echo -e "${YELLOW}Ollama (the AI engine) can be kept for other uses, or removed entirely.${NC}"
    echo ""
    echo "  1) Keep Ollama installed (recommended if you use AI models elsewhere)"
    echo "  2) Remove Ollama and keep downloaded models"
    echo "  3) Remove Ollama AND all downloaded models (frees the most disk space)"
    echo ""
    read -r -p "Choose [1/2/3]: " ollama_choice < /dev/tty
    case "$ollama_choice" in
      2) OLLAMA_ACTION="remove-keep-models" ;;
      3) OLLAMA_ACTION="remove" ;;
      *) OLLAMA_ACTION="keep" ;;
    esac
  else
    # Pipe mode default: keep Ollama
    OLLAMA_ACTION="keep"
  fi
fi

case "$OLLAMA_ACTION" in
  remove-keep-models)
    info "Removing Ollama (keeping models in ~/.ollama)..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      brew services stop ollama 2>/dev/null || true
      brew uninstall ollama 2>/dev/null || true
    else
      sudo systemctl stop ollama 2>/dev/null || true
      sudo systemctl disable ollama 2>/dev/null || true
      sudo rm -f /usr/local/bin/ollama 2>/dev/null || true
      sudo rm -f /etc/systemd/system/ollama.service 2>/dev/null || true
      sudo systemctl daemon-reload 2>/dev/null || true
    fi
    ok "Ollama removed (models preserved in ~/.ollama)"
    ;;
  remove)
    info "Removing Ollama and all models..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      brew services stop ollama 2>/dev/null || true
      brew uninstall ollama 2>/dev/null || true
    else
      sudo systemctl stop ollama 2>/dev/null || true
      sudo systemctl disable ollama 2>/dev/null || true
      sudo rm -f /usr/local/bin/ollama 2>/dev/null || true
      sudo rm -f /etc/systemd/system/ollama.service 2>/dev/null || true
      sudo systemctl daemon-reload 2>/dev/null || true
    fi
    rm -rf "${HOME}/.ollama" 2>/dev/null || true
    ok "Ollama and all models removed"
    ;;
  *)
    ok "Ollama kept installed"
    ;;
esac

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

} # end main()

# Run main — ensures entire script is parsed before execution (pipe-safe)
main "$@"
