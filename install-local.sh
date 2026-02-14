#!/usr/bin/env bash
#
# Joe's Tech Solutions — Local AI Server Installer (Mac / Linux)
# NATIVE install — no Docker required
# Auto-detects hardware and installs optimal AI models
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.sh | bash
#
# Options (environment variables):
#   WEBUI_PORT=3000        Port for Open WebUI (default: 3000)
#   PULL_MODEL=llama3.2    Override auto-detected model (skip hardware detection)
#   SKIP_MODELS=true       Skip all model downloads (just install the server)
#   VERTICAL=healthcare    Create industry-specific AI assistant
#                          Options: healthcare, legal, financial, realestate,
#                          therapy, education, construction, creative, smallbusiness
#
set -euo pipefail

# ── Config ──────────────────────────────────────────────
WEBUI_PORT="${WEBUI_PORT:-3000}"
OS_OVERHEAD_GB=4  # Reserve for OS + apps

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Banner ──────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     Joe's Tech Solutions — Local AI Server   ║${NC}"
echo -e "${CYAN}║         Private ChatGPT Alternative          ║${NC}"
echo -e "${CYAN}║            (Native Install)                  ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════
# STEP 1: PREREQUISITES
# ═══════════════════════════════════════════════════════════

install_prerequisites() {
  info "Checking prerequisites..."

  # ── macOS: Install Homebrew if missing ──
  if [[ "$OSTYPE" == "darwin"* ]]; then
    if ! command -v brew >/dev/null 2>&1; then
      info "Installing Homebrew (macOS package manager)..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

      # Add Homebrew to PATH for Apple Silicon
      if [[ "$(uname -m)" == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        SHELL_PROFILE="${HOME}/.zprofile"
        if ! grep -q 'brew shellenv' "${SHELL_PROFILE}" 2>/dev/null; then
          echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "${SHELL_PROFILE}"
          info "Added Homebrew to ${SHELL_PROFILE}"
        fi
      fi
      ok "Homebrew installed"
    else
      ok "Homebrew already installed"
    fi
  fi

  # ── Check for curl ──
  if ! command -v curl >/dev/null 2>&1; then
    fail "curl is not installed. Please install it and try again."
  fi

  # ── Check for Python 3.11 or 3.12 (Open WebUI requires >=3.11, <3.13) ──
  PYTHON_CMD=""

  # Search for compatible Python (3.11 or 3.12 ONLY — 3.13+ is too new for Open WebUI)
  for cmd in python3.12 python3.11; do
    if command -v "$cmd" >/dev/null 2>&1; then
      PYTHON_CMD="$cmd"
      break
    fi
  done

  # Also check bare python3 in case it's 3.11 or 3.12
  if [ -z "${PYTHON_CMD}" ] && command -v python3 >/dev/null 2>&1; then
    PY_MINOR=$(python3 -c "import sys; print(sys.version_info.minor)" 2>/dev/null || echo "0")
    if [ "$PY_MINOR" -ge 11 ] && [ "$PY_MINOR" -le 12 ]; then
      PYTHON_CMD="python3"
    fi
  fi

  if [ -z "${PYTHON_CMD}" ]; then
    info "Python 3.11 or 3.12 required (Open WebUI doesn't support 3.13+). Installing Python 3.11..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      brew install python@3.11
      # Homebrew Python paths
      if [ -x "/opt/homebrew/bin/python3.11" ]; then
        PYTHON_CMD="/opt/homebrew/bin/python3.11"
      elif [ -x "/usr/local/bin/python3.11" ]; then
        PYTHON_CMD="/usr/local/bin/python3.11"
      else
        PYTHON_CMD="python3.11"
      fi
    else
      sudo apt-get update && sudo apt-get install -y python3.11 python3.11-venv python3.11-pip 2>/dev/null \
        || sudo apt-get install -y python3 python3-pip python3-venv
      PYTHON_CMD="python3.11"
      if ! command -v python3.11 >/dev/null 2>&1; then
        PYTHON_CMD="python3"
      fi
    fi
    ok "Python installed: $(${PYTHON_CMD} --version)"
  else
    ok "Python found: $(${PYTHON_CMD} --version) (${PYTHON_CMD})"
  fi
}

# ═══════════════════════════════════════════════════════════
# STEP 2: HARDWARE DETECTION
# ═══════════════════════════════════════════════════════════

detect_hardware() {
  info "Scanning hardware..."

  TOTAL_RAM_GB=0
  if [[ "$OSTYPE" == "darwin"* ]]; then
    TOTAL_RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    TOTAL_RAM_GB=$(( TOTAL_RAM_BYTES / 1073741824 ))
  else
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0)
    TOTAL_RAM_GB=$(( TOTAL_RAM_KB / 1048576 ))
  fi

  AVAILABLE_RAM_GB=$(( TOTAL_RAM_GB - OS_OVERHEAD_GB ))
  if [ "$AVAILABLE_RAM_GB" -lt 1 ]; then AVAILABLE_RAM_GB=1; fi

  if [[ "$OSTYPE" == "darwin"* ]]; then
    CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo "?")
    CPU_ARCH=$(uname -m)
    if [[ "$CPU_ARCH" == "arm64" ]]; then
      GPU_TYPE="apple_silicon"
      GPU_NAME="Apple Silicon ($(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'M-series'))"
    else
      GPU_TYPE="none"
      GPU_NAME="Intel Mac (CPU only)"
    fi
  else
    CPU_CORES=$(nproc 2>/dev/null || echo "?")
    if command -v nvidia-smi >/dev/null 2>&1; then
      GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "NVIDIA GPU")
      GPU_VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "0")
      GPU_VRAM_GB=$(( GPU_VRAM_MB / 1024 ))
      GPU_TYPE="nvidia"
    else
      GPU_TYPE="none"
      GPU_NAME="None detected (CPU only)"
      GPU_VRAM_GB=0
    fi
  fi

  if [[ "$OSTYPE" == "darwin"* ]]; then
    FREE_DISK_GB=$(df -g / 2>/dev/null | tail -1 | awk '{print $4}' || echo "?")
  else
    FREE_DISK_GB=$(df -BG / 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'G' || echo "?")
  fi

  echo ""
  echo -e "${BOLD}  ┌─────────────────────────────────────────┐${NC}"
  echo -e "${BOLD}  │         HARDWARE DETECTED                │${NC}"
  echo -e "${BOLD}  ├─────────────────────────────────────────┤${NC}"
  echo -e "${BOLD}  │${NC}  RAM:        ${GREEN}${TOTAL_RAM_GB} GB total${NC} (${AVAILABLE_RAM_GB} GB available for AI)"
  echo -e "${BOLD}  │${NC}  CPU Cores:  ${GREEN}${CPU_CORES}${NC}"
  echo -e "${BOLD}  │${NC}  GPU:        ${GREEN}${GPU_NAME}${NC}"
  if [ "${GPU_TYPE}" = "nvidia" ] && [ "${GPU_VRAM_GB:-0}" -gt 0 ]; then
  echo -e "${BOLD}  │${NC}  VRAM:       ${GREEN}${GPU_VRAM_GB} GB${NC}"
  fi
  echo -e "${BOLD}  │${NC}  Free Disk:  ${GREEN}${FREE_DISK_GB} GB${NC}"
  echo -e "${BOLD}  └─────────────────────────────────────────┘${NC}"
  echo ""
}

# ═══════════════════════════════════════════════════════════
# STEP 3: MODEL SELECTION ENGINE
# ═══════════════════════════════════════════════════════════

select_models() {
  MODELS_TO_PULL=()
  MODELS_DESCRIPTION=()

  if [ -n "${PULL_MODEL:-}" ]; then
    MODELS_TO_PULL+=("${PULL_MODEL}")
    MODELS_DESCRIPTION+=("${PULL_MODEL} (user selected)")
    return
  fi

  if [ "${GPU_TYPE}" = "nvidia" ] && [ "${GPU_VRAM_GB:-0}" -gt 0 ]; then
    COMPUTE_RAM=${GPU_VRAM_GB}
    RAM_SOURCE="GPU VRAM"
  else
    COMPUTE_RAM=${AVAILABLE_RAM_GB}
    RAM_SOURCE="System RAM"
  fi

  info "Selecting optimal models based on ${RAM_SOURCE}: ${COMPUTE_RAM} GB available..."

  if [ "${COMPUTE_RAM}" -lt 6 ]; then
    MODELS_TO_PULL+=("qwen3:4b")
    MODELS_DESCRIPTION+=("qwen3:4b     (2.6 GB) — Rivals 72B quality, fits your ${COMPUTE_RAM}GB available")
    TIER="Starter"
  elif [ "${COMPUTE_RAM}" -lt 10 ]; then
    MODELS_TO_PULL+=("qwen3:8b" "nomic-embed-text")
    MODELS_DESCRIPTION+=("qwen3:8b     (5.2 GB) — Sweet spot performance, 40+ tok/s")
    MODELS_DESCRIPTION+=("nomic-embed  (0.3 GB) — Enables document search (RAG)")
    TIER="Standard"
  elif [ "${COMPUTE_RAM}" -lt 20 ]; then
    MODELS_TO_PULL+=("gemma3:12b" "deepseek-r1:8b" "nomic-embed-text")
    MODELS_DESCRIPTION+=("gemma3:12b     (8.1 GB) — Google multimodal, strong reasoning")
    MODELS_DESCRIPTION+=("deepseek-r1:8b (4.9 GB) — Advanced coding + math")
    MODELS_DESCRIPTION+=("nomic-embed    (0.3 GB) — Enables document search (RAG)")
    TIER="Performance"
  elif [ "${COMPUTE_RAM}" -lt 46 ]; then
    MODELS_TO_PULL+=("qwen3:32b" "deepseek-r1:14b" "nomic-embed-text")
    MODELS_DESCRIPTION+=("qwen3:32b       (20 GB) — Near-frontier quality locally")
    MODELS_DESCRIPTION+=("deepseek-r1:14b (9.0 GB) — Advanced reasoning + coding")
    MODELS_DESCRIPTION+=("nomic-embed     (0.3 GB) — Enables document search (RAG)")
    TIER="Power"
  else
    MODELS_TO_PULL+=("qwen3:32b" "gemma3:27b" "deepseek-r1:32b" "nomic-embed-text")
    MODELS_DESCRIPTION+=("qwen3:32b       (20 GB) — Flagship quality, rivals GPT-4")
    MODELS_DESCRIPTION+=("gemma3:27b      (17 GB) — Google flagship, multimodal")
    MODELS_DESCRIPTION+=("deepseek-r1:32b (20 GB) — Top-tier reasoning + coding")
    MODELS_DESCRIPTION+=("nomic-embed     (0.3 GB) — Enables document search (RAG)")
    TIER="Maximum"
  fi

  echo ""
  echo -e "${BOLD}  ┌─────────────────────────────────────────────────────┐${NC}"
  echo -e "${BOLD}  │  AI MODEL PLAN — ${TIER} Tier                         ${NC}"
  echo -e "${BOLD}  ├─────────────────────────────────────────────────────┤${NC}"
  for desc in "${MODELS_DESCRIPTION[@]}"; do
  echo -e "${BOLD}  │${NC}  ✦ ${desc}"
  done
  echo -e "${BOLD}  └─────────────────────────────────────────────────────┘${NC}"
  echo ""

  if [ "${FREE_DISK_GB}" != "?" ]; then
    TOTAL_MODEL_GB=0
    for model in "${MODELS_TO_PULL[@]}"; do
      case "$model" in
        qwen3:4b)          TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 3));;
        qwen3:8b)          TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 6));;
        gemma3:12b)        TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 9));;
        deepseek-r1:8b)    TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 5));;
        deepseek-r1:14b)   TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 10));;
        deepseek-r1:32b)   TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 21));;
        qwen3:32b)         TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 21));;
        gemma3:27b)        TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 18));;
        nomic-embed-text)  TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 1));;
        *)                 TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 5));;
      esac
    done
    if [ "${FREE_DISK_GB}" -lt "${TOTAL_MODEL_GB}" ] 2>/dev/null; then
      warn "Models need ~${TOTAL_MODEL_GB} GB but only ${FREE_DISK_GB} GB free disk space."
      warn "Some models may fail to download. Free up disk space if needed."
    fi
  fi
}

# ═══════════════════════════════════════════════════════════
# STEP 4: INSTALL OLLAMA (NATIVE)
# ═══════════════════════════════════════════════════════════

install_ollama() {
  info "Checking Ollama installation..."

  if command -v ollama >/dev/null 2>&1; then
    ok "Ollama already installed: $(ollama --version 2>/dev/null || echo 'installed')"
  else
    info "Installing Ollama..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      brew install ollama
    else
      curl -fsSL https://ollama.com/install.sh | sh
    fi
    ok "Ollama installed"
  fi

  info "Starting Ollama service..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew services start ollama 2>/dev/null || true
  else
    sudo systemctl enable ollama 2>/dev/null || true
    sudo systemctl start ollama 2>/dev/null || true
  fi

  info "Waiting for Ollama to start..."
  for i in $(seq 1 30); do
    if curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
      break
    fi
    if [ "$i" -eq 30 ]; then
      fail "Ollama did not start within 60 seconds. Try running 'ollama serve' manually."
    fi
    sleep 2
  done
  ok "Ollama is running on port 11434"
}

# ═══════════════════════════════════════════════════════════
# STEP 5: DOWNLOAD AI MODELS
# ═══════════════════════════════════════════════════════════

download_models() {
  if [ "${SKIP_MODELS:-false}" != "true" ] && [ ${#MODELS_TO_PULL[@]} -gt 0 ]; then
    echo ""
    info "Downloading AI models (this will take a few minutes per model)..."
    echo ""

    DOWNLOAD_COUNT=0
    DOWNLOAD_TOTAL=${#MODELS_TO_PULL[@]}

    for model in "${MODELS_TO_PULL[@]}"; do
      DOWNLOAD_COUNT=$((DOWNLOAD_COUNT + 1))
      info "[${DOWNLOAD_COUNT}/${DOWNLOAD_TOTAL}] Downloading ${model}..."
      if ollama pull "${model}"; then
        ok "${model} downloaded successfully"
      else
        warn "${model} failed to download — you can pull it manually later: ollama pull ${model}"
      fi
      echo ""
    done
  fi
}

# ═══════════════════════════════════════════════════════════
# STEP 6: CREATE VERTICAL ASSISTANT (if specified)
# ═══════════════════════════════════════════════════════════

create_vertical() {
  if [ -n "${VERTICAL:-}" ]; then
    REPO_RAW="https://raw.githubusercontent.com/joblas/joes-ai-server/main"
    PROMPT_URL="${REPO_RAW}/verticals/prompts/${VERTICAL}.txt"
    BASE_MODEL="${MODELS_TO_PULL[0]}"

    case "${VERTICAL}" in
      healthcare)    ASSISTANT_NAME="Healthcare-Assistant" ;;
      legal)         ASSISTANT_NAME="Legal-Assistant" ;;
      financial)     ASSISTANT_NAME="Financial-Assistant" ;;
      realestate)    ASSISTANT_NAME="RealEstate-Assistant" ;;
      therapy)       ASSISTANT_NAME="Clinical-Assistant" ;;
      education)     ASSISTANT_NAME="Learning-Assistant" ;;
      construction)  ASSISTANT_NAME="Construction-Assistant" ;;
      creative)      ASSISTANT_NAME="Creative-Assistant" ;;
      smallbusiness) ASSISTANT_NAME="Business-Assistant" ;;
      *)             ASSISTANT_NAME="${VERTICAL}-Assistant" ;;
    esac

    info "Creating ${ASSISTANT_NAME} from ${BASE_MODEL}..."
    SYSTEM_PROMPT=$(curl -fsSL "${PROMPT_URL}" 2>/dev/null || echo "")

    if [ -n "${SYSTEM_PROMPT}" ]; then
      MODELFILE_PATH="/tmp/joes-ai-modelfile-$$"
      cat > "${MODELFILE_PATH}" << MODELFILE_EOF
FROM ${BASE_MODEL}
SYSTEM "${SYSTEM_PROMPT}"
MODELFILE_EOF

      if ollama create "${ASSISTANT_NAME}" -f "${MODELFILE_PATH}"; then
        ok "${ASSISTANT_NAME} created successfully!"
        info "Your client will see '${ASSISTANT_NAME}' in their model dropdown."
      else
        warn "Failed to create ${ASSISTANT_NAME} — client can still use ${BASE_MODEL} directly"
      fi
      rm -f "${MODELFILE_PATH}"
    else
      warn "Could not download prompt for vertical '${VERTICAL}'"
      warn "Valid options: healthcare, legal, financial, realestate, therapy, education, construction, creative, smallbusiness"
    fi
    echo ""
  fi
}

# ═══════════════════════════════════════════════════════════
# STEP 7: INSTALL OPEN WEBUI (NATIVE)
# ═══════════════════════════════════════════════════════════

install_open_webui() {
  info "Setting up Open WebUI..."

  VENV_DIR="${HOME}/.joes-ai/venv"
  DATA_DIR="${HOME}/.joes-ai/data"

  mkdir -p "${HOME}/.joes-ai"
  mkdir -p "${DATA_DIR}"

  if [ ! -d "${VENV_DIR}" ]; then
    info "Creating Python virtual environment with ${PYTHON_CMD}..."
    "${PYTHON_CMD}" -m venv "${VENV_DIR}"
    ok "Virtual environment created at ${VENV_DIR}"
  fi

  source "${VENV_DIR}/bin/activate"
  info "Installing Open WebUI (this may take 1-2 minutes)..."
  pip install --upgrade pip >/dev/null 2>&1
  pip install open-webui 2>&1 | tail -5
  ok "Open WebUI installed"
  deactivate
}

# ═══════════════════════════════════════════════════════════
# STEP 8: CREATE LAUNCH SCRIPT & AUTO-START
# ═══════════════════════════════════════════════════════════

setup_autostart() {
  LAUNCH_SCRIPT="${HOME}/.joes-ai/start-server.sh"
  VENV_DIR="${HOME}/.joes-ai/venv"
  DATA_DIR="${HOME}/.joes-ai/data"

  cat > "${LAUNCH_SCRIPT}" << LAUNCH_EOF
#!/usr/bin/env bash
WEBUI_PORT=\${WEBUI_PORT:-${WEBUI_PORT}}
echo "Starting Joe's AI Server..."
if ! curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
  echo "Starting Ollama..."
  if [[ "\$OSTYPE" == "darwin"* ]]; then
    brew services start ollama 2>/dev/null || ollama serve &
  else
    sudo systemctl start ollama 2>/dev/null || ollama serve &
  fi
  sleep 3
fi
source "${VENV_DIR}/bin/activate"
export DATA_DIR="${DATA_DIR}"
echo "Starting Open WebUI on port \${WEBUI_PORT}..."
echo "Open your browser: http://localhost:\${WEBUI_PORT}"
echo "Press Ctrl+C to stop the server."
open-webui serve --port \${WEBUI_PORT}
LAUNCH_EOF
  chmod +x "${LAUNCH_SCRIPT}"
  ok "Launch script created: ${LAUNCH_SCRIPT}"

  STOP_SCRIPT="${HOME}/.joes-ai/stop-server.sh"
  cat > "${STOP_SCRIPT}" << STOP_EOF
#!/usr/bin/env bash
echo "Stopping Joe's AI Server..."
pkill -f "open-webui" 2>/dev/null || true
echo "Open WebUI stopped."
echo "Run ~/.joes-ai/start-server.sh to restart."
STOP_EOF
  chmod +x "${STOP_SCRIPT}"
  ok "Stop script created: ${STOP_SCRIPT}"

  # ── macOS: Create Login Item via launchd ──
  if [[ "$OSTYPE" == "darwin"* ]]; then
    PLIST_DIR="${HOME}/Library/LaunchAgents"
    PLIST_FILE="${PLIST_DIR}/com.joestechsolutions.ai-server.plist"
    LOG_DIR="${HOME}/.joes-ai/logs"
    mkdir -p "${PLIST_DIR}" "${LOG_DIR}"

    cat > "${PLIST_FILE}" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.joestechsolutions.ai-server</string>
    <key>ProgramArguments</key>
    <array>
        <string>${VENV_DIR}/bin/open-webui</string>
        <string>serve</string>
        <string>--port</string>
        <string>${WEBUI_PORT}</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>DATA_DIR</key>
        <string>${DATA_DIR}</string>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/webui-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/webui-stderr.log</string>
</dict>
</plist>
PLIST_EOF

    launchctl unload "${PLIST_FILE}" 2>/dev/null || true
    launchctl load "${PLIST_FILE}"
    ok "Auto-start configured — Open WebUI will start on login"

  # ── Linux: Create systemd user service ──
  else
    SERVICE_DIR="${HOME}/.config/systemd/user"
    mkdir -p "${SERVICE_DIR}"

    cat > "${SERVICE_DIR}/joes-ai-webui.service" << SERVICE_EOF
[Unit]
Description=Joe's AI Server — Open WebUI
After=network.target ollama.service

[Service]
Type=simple
ExecStart=${VENV_DIR}/bin/open-webui serve --port ${WEBUI_PORT}
Environment=DATA_DIR=${DATA_DIR}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
SERVICE_EOF

    systemctl --user daemon-reload
    systemctl --user enable joes-ai-webui.service
    systemctl --user start joes-ai-webui.service
    ok "Auto-start configured — Open WebUI runs as a systemd user service"
  fi
}

# ═══════════════════════════════════════════════════════════
# STEP 9: WAIT FOR WEBUI & VERIFY
# ═══════════════════════════════════════════════════════════

verify_installation() {
  info "Waiting for Open WebUI to start..."
  for i in $(seq 1 45); do
    if curl -sf "http://localhost:${WEBUI_PORT}" >/dev/null 2>&1; then
      break
    fi
    if [ "$i" -eq 45 ]; then
      warn "Open WebUI is taking longer than expected to start."
      warn "Check logs: cat ~/.joes-ai/logs/webui-stderr.log"
      warn "Or start manually: ~/.joes-ai/start-server.sh"
    fi
    sleep 2
  done

  echo ""
  info "Installed models:"
  ollama list 2>/dev/null || true
  echo ""
}

# ═══════════════════════════════════════════════════════════
# MAIN — RUN ALL STEPS
# ═══════════════════════════════════════════════════════════

install_prerequisites
detect_hardware

if [ "${SKIP_MODELS:-false}" != "true" ]; then
  select_models
fi

install_ollama
download_models
create_vertical
install_open_webui
setup_autostart
verify_installation

# ── Done ───────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            ✅ Joe's Local AI Server is LIVE!             ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  Open your browser:  http://localhost:${WEBUI_PORT}                ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  Hardware:  ${TOTAL_RAM_GB} GB RAM · ${CPU_CORES} cores · ${GPU_TYPE} GPU         ${NC}"
echo -e "${GREEN}║  Tier:      ${TIER:-Custom}                                        ${NC}"
echo -e "${GREEN}║  Models:    ${#MODELS_TO_PULL[@]} installed and ready                       ${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  First visit: Create your admin account, then chat!      ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  Commands:                                               ║${NC}"
echo -e "${GREEN}║    ~/.joes-ai/start-server.sh    (start server)          ║${NC}"
echo -e "${GREEN}║    ~/.joes-ai/stop-server.sh     (stop server)           ║${NC}"
echo -e "${GREEN}║    ollama list                   (list models)           ║${NC}"
echo -e "${GREEN}║    ollama pull <model>           (download model)        ║${NC}"
echo -e "${GREEN}║    ollama rm <model>             (remove model)          ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  Auto-start: Server starts automatically on login ✓      ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  Support: joe@joestechsolutions.com                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
