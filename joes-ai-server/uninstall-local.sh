#!/usr/bin/env bash
#
# Joe's Tech Solutions — Local AI Server Uninstaller (Mac / Linux)
# Cleanly removes the native AI server, with option to keep or remove data
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

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Joe's Tech Solutions — AI Server Uninstall  ║${NC}"
echo -e "${CYAN}║              (Native Install)                 ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════
# STEP 1: STOP SERVICES
# ═══════════════════════════════════════════════════════════

info "Stopping AI server services..."

# ── Stop Open WebUI ──
pkill -f "open-webui" 2>/dev/null || true

# ── Unload launchd agent (macOS) ──
PLIST_FILE="${HOME}/Library/LaunchAgents/com.joestechsolutions.ai-server.plist"
if [ -f "${PLIST_FILE}" ]; then
  launchctl unload "${PLIST_FILE}" 2>/dev/null || true
  rm -f "${PLIST_FILE}"
  ok "macOS auto-start removed"
fi

# ── Disable systemd service (Linux) ──
if systemctl --user is-enabled joes-ai-webui.service 2>/dev/null; then
  systemctl --user stop joes-ai-webui.service 2>/dev/null || true
  systemctl --user disable joes-ai-webui.service 2>/dev/null || true
  rm -f "${HOME}/.config/systemd/user/joes-ai-webui.service"
  systemctl --user daemon-reload 2>/dev/null || true
  ok "Linux systemd service removed"
fi

ok "Services stopped"

# ═══════════════════════════════════════════════════════════
# STEP 2: REMOVE OPEN WEBUI
# ═══════════════════════════════════════════════════════════

info "Removing Open WebUI..."

# ── Remove virtual environment and app data ──
if [ -d "${HOME}/.joes-ai" ]; then
  echo ""
  echo -e "${YELLOW}Your chat history and settings are stored in ~/.joes-ai/data/${NC}"
  echo -e "${YELLOW}Do you want to keep this data?${NC}"
  echo ""
  echo "  1) Keep my data (recommended — only removes the server, not your chats)"
  echo "  2) Delete everything (removes all chats, settings, and logs permanently)"
  echo ""

  read -r -p "Choose [1/2]: " choice

  case "$choice" in
    2)
      warn "Deleting all Open WebUI data..."
      rm -rf "${HOME}/.joes-ai"
      ok "All Open WebUI data deleted"
      ;;
    *)
      # Remove venv and scripts but keep data
      rm -rf "${HOME}/.joes-ai/venv"
      rm -f "${HOME}/.joes-ai/start-server.sh"
      rm -f "${HOME}/.joes-ai/stop-server.sh"
      rm -rf "${HOME}/.joes-ai/logs"
      ok "Open WebUI removed (chat data preserved in ~/.joes-ai/data/)"
      info "To reinstall later, just run the installer again — your data will still be there."
      ;;
  esac
else
  warn "No ~/.joes-ai directory found. Open WebUI may not have been installed."
fi

# ═══════════════════════════════════════════════════════════
# STEP 3: HANDLE OLLAMA & MODELS
# ═══════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}What would you like to do with Ollama and your AI models?${NC}"
echo ""
echo "  1) Keep Ollama and all models (recommended — instant reinstall later)"
echo "  2) Remove models only (keeps Ollama installed, saves disk space)"
echo "  3) Remove everything (uninstalls Ollama + all models completely)"
echo ""

read -r -p "Choose [1/2/3]: " ollama_choice

case "$ollama_choice" in
  2)
    info "Removing all downloaded models..."
    if command -v ollama >/dev/null 2>&1; then
      # List and remove each model
      MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' || true)
      if [ -n "${MODELS}" ]; then
        for model in ${MODELS}; do
          ollama rm "${model}" 2>/dev/null || true
          ok "Removed model: ${model}"
        done
      else
        info "No models found to remove."
      fi
    fi
    ok "All models removed. Ollama is still installed."
    ;;
  3)
    info "Uninstalling Ollama completely..."

    # Stop Ollama service
    if [[ "$OSTYPE" == "darwin"* ]]; then
      brew services stop ollama 2>/dev/null || true
      brew uninstall ollama 2>/dev/null || true
    else
      sudo systemctl stop ollama 2>/dev/null || true
      sudo systemctl disable ollama 2>/dev/null || true
      sudo rm -f /usr/local/bin/ollama
      sudo rm -rf /usr/share/ollama
      sudo userdel ollama 2>/dev/null || true
      sudo groupdel ollama 2>/dev/null || true
    fi

    # Remove Ollama data directory
    rm -rf "${HOME}/.ollama"
    ok "Ollama and all models completely removed"
    ;;
  *)
    ok "Ollama and models preserved"
    ;;
esac

# ═══════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════

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
