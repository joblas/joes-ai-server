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

# Wrap everything in main() so the entire script is read into memory before
# executing. This prevents `curl | bash` from breaking when child processes
# (like brew) consume stdin.
main() {
set -euo pipefail

# ── Config ──────────────────────────────────────────────
WEBUI_PORT="${WEBUI_PORT:-3000}"
OS_OVERHEAD_GB=4  # Reserve for OS + apps
OPENWEBUI_VERSION="0.8.1"

# ── Install log capture ────────────────────────────────
LOG_DIR="${HOME}/.joes-ai/logs"
mkdir -p "${LOG_DIR}"
LOG="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "${LOG}") 2>&1

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Box line helper (auto-padded to 56 chars) ──────────
BOX_WIDTH=56
box_line() {
  local content="$1"
  printf "${GREEN}║${NC}  %-${BOX_WIDTH}s${GREEN}║${NC}\n" "$content"
}
box_line_green() {
  local content="$1"
  printf "${GREEN}║  %-${BOX_WIDTH}s║${NC}\n" "$content"
}

# ── Banner ──────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     Joe's Tech Solutions — Local AI Server               ║${NC}"
echo -e "${CYAN}║         Private ChatGPT Alternative                      ║${NC}"
echo -e "${CYAN}║            (Native Install)                              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════
# STEP 1: PREREQUISITES
# ═══════════════════════════════════════════════════════════

install_prerequisites() {
  info "Step 1/9: Checking prerequisites..."

  # ── macOS: Install Homebrew if missing ──
  if [[ "$OSTYPE" == "darwin"* ]]; then
    if ! command -v brew >/dev/null 2>&1; then
      info "Installing Homebrew (macOS package manager)..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/null

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

  # ── Check for Python 3.11+ (needed for Open WebUI) ──
  PYTHON_CMD=""

  # Check if any existing python3 is 3.11+
  if command -v python3 >/dev/null 2>&1; then
    PY_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || echo "0.0")
    PY_MAJOR=$(echo "$PY_VERSION" | cut -d. -f1)
    PY_MINOR=$(echo "$PY_VERSION" | cut -d. -f2)
    if [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -ge 11 ] && [ "$PY_MINOR" -lt 13 ]; then
      PYTHON_CMD="python3"
      ok "Python ${PY_VERSION} found (compatible)"
    fi
  fi

  # Check for python3.11 specifically
  if [ -z "$PYTHON_CMD" ] && command -v python3.11 >/dev/null 2>&1; then
    PYTHON_CMD="python3.11"
    ok "Python 3.11 found"
  fi

  # Check for python3.12 specifically
  if [ -z "$PYTHON_CMD" ] && command -v python3.12 >/dev/null 2>&1; then
    PYTHON_CMD="python3.12"
    ok "Python 3.12 found"
  fi

  # Not found — install Python 3.11
  if [ -z "$PYTHON_CMD" ]; then
    info "Installing Python 3.11 (required by Open WebUI)..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      brew install python@3.11 < /dev/null
      # python3.11 is now available via Homebrew
      if command -v python3.11 >/dev/null 2>&1; then
        PYTHON_CMD="python3.11"
      elif command -v /opt/homebrew/bin/python3.11 >/dev/null 2>&1; then
        PYTHON_CMD="/opt/homebrew/bin/python3.11"
      else
        # Homebrew may install it as python3
        PYTHON_CMD="python3"
      fi
      ok "Python installed: $($PYTHON_CMD --version 2>&1)"
    else
      sudo apt-get update < /dev/null && sudo apt-get install -y python3 python3-pip python3-venv < /dev/null
      PYTHON_CMD="python3"
      ok "Python installed: $($PYTHON_CMD --version 2>&1)"
    fi
  fi

  # Verify the Python we found can actually create venvs
  if ! $PYTHON_CMD -m venv --help >/dev/null 2>&1; then
    warn "Python venv module not available. Installing..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      : # Homebrew Python includes venv
    else
      sudo apt-get install -y python3-venv < /dev/null
    fi
  fi
}

# ═══════════════════════════════════════════════════════════
# STEP 2: HARDWARE DETECTION
# ═══════════════════════════════════════════════════════════

detect_hardware() {
  info "Step 2/9: Scanning hardware..."

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
  info "Step 3/9: Selecting optimal AI models..."

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
    MODELS_TO_PULL+=("llama3.2:3b" "gemma3:4b" "nomic-embed-text")
    MODELS_DESCRIPTION+=("llama3.2:3b  (2.0 GB) — Fast text chat, ideal for 8 GB machines")
    MODELS_DESCRIPTION+=("gemma3:4b    (3.3 GB) — Vision model, reads images & documents")
    MODELS_DESCRIPTION+=("nomic-embed  (0.3 GB) — Enables document search (RAG)")
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
        llama3.2:3b)       TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 2));;
        gemma3:4b)         TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 4));;
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
  info "Step 4/9: Checking Ollama installation..."

  if command -v ollama >/dev/null 2>&1; then
    ok "Ollama already installed: $(ollama --version 2>/dev/null || echo 'installed')"
  else
    info "Installing Ollama..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
      brew install ollama < /dev/null
    else
      curl -fsSL https://ollama.com/install.sh | sh
    fi
    ok "Ollama installed"
  fi

  info "Starting Ollama service..."
  if [[ "$OSTYPE" == "darwin"* ]]; then
    brew services start ollama < /dev/null 2>/dev/null || true
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
    info "Step 5/9: Downloading AI models (this will take a few minutes per model)..."
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
    info "Step 6/9: Creating industry-specific AI assistant..."
    REPO_RAW="https://raw.githubusercontent.com/joblas/joes-ai-server/main"
    PROMPT_URL="${REPO_RAW}/verticals/prompts/${VERTICAL}.txt"
    BASE_MODEL="${MODELS_TO_PULL[0]}"

    case "${VERTICAL}" in
      healthcare)    ASSISTANT_NAME="healthcare-assistant" ;;
      legal)         ASSISTANT_NAME="legal-assistant" ;;
      financial)     ASSISTANT_NAME="financial-assistant" ;;
      realestate)    ASSISTANT_NAME="realestate-assistant" ;;
      therapy)       ASSISTANT_NAME="clinical-assistant" ;;
      education)     ASSISTANT_NAME="learning-assistant" ;;
      construction)  ASSISTANT_NAME="construction-assistant" ;;
      creative)      ASSISTANT_NAME="creative-assistant" ;;
      smallbusiness) ASSISTANT_NAME="business-assistant" ;;
      *)             ASSISTANT_NAME="${VERTICAL}-assistant" ;;
    esac

    info "Creating ${ASSISTANT_NAME} from ${BASE_MODEL}..."
    SYSTEM_PROMPT=$(curl -fsSL "${PROMPT_URL}" 2>/dev/null || echo "")

    if [ -n "${SYSTEM_PROMPT}" ]; then
      PROMPT_FILE="/tmp/joes-ai-prompt-$$"
      printf '%s' "${SYSTEM_PROMPT}" > "${PROMPT_FILE}"

      MODELFILE_PATH="/tmp/joes-ai-modelfile-$$"
      printf 'FROM %s\nSYSTEM """\n' "${BASE_MODEL}" > "${MODELFILE_PATH}"
      cat "${PROMPT_FILE}" >> "${MODELFILE_PATH}"
      printf '\n"""\n' >> "${MODELFILE_PATH}"

      if ollama create "${ASSISTANT_NAME}" -f "${MODELFILE_PATH}"; then
        ok "${ASSISTANT_NAME} created successfully!"
        info "Your client will see '${ASSISTANT_NAME}' in their model dropdown."
      else
        warn "Failed to create ${ASSISTANT_NAME} — client can still use ${BASE_MODEL} directly"
      fi
      rm -f "${MODELFILE_PATH}" "${PROMPT_FILE}"
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
  info "Step 7/9: Setting up Open WebUI..."

  VENV_DIR="${HOME}/.joes-ai/venv"
  DATA_DIR="${HOME}/.joes-ai/data"

  mkdir -p "${HOME}/.joes-ai"
  mkdir -p "${DATA_DIR}"

  if [ ! -d "${VENV_DIR}" ]; then
    info "Creating Python virtual environment..."
    $PYTHON_CMD -m venv "${VENV_DIR}"
    ok "Virtual environment created at ${VENV_DIR}"
  fi

  source "${VENV_DIR}/bin/activate"

  # Check if correct version is already installed (skip on re-run)
  CURRENT_OWUI_VERSION=$(pip show open-webui 2>/dev/null | grep "^Version:" | awk '{print $2}' || echo "")
  if [ "${CURRENT_OWUI_VERSION}" = "${OPENWEBUI_VERSION}" ]; then
    ok "Open WebUI ${OPENWEBUI_VERSION} already installed — skipping"
  else
    if [ -n "${CURRENT_OWUI_VERSION}" ]; then
      info "Upgrading Open WebUI from ${CURRENT_OWUI_VERSION} to ${OPENWEBUI_VERSION}..."
    else
      info "Installing Open WebUI ${OPENWEBUI_VERSION} (this may take 1-2 minutes)..."
    fi
    pip install --upgrade pip >/dev/null 2>&1
    pip install "open-webui==${OPENWEBUI_VERSION}" 2>&1 | tail -5
    ok "Open WebUI ${OPENWEBUI_VERSION} installed"
  fi

  deactivate
}

# ═══════════════════════════════════════════════════════════
# STEP 8: CREATE MANAGEMENT SCRIPTS
# ═══════════════════════════════════════════════════════════

create_scripts() {
  info "Step 8/9: Creating management scripts..."

  LAUNCH_SCRIPT="${HOME}/.joes-ai/start-server.sh"
  VENV_DIR="${HOME}/.joes-ai/venv"
  DATA_DIR="${HOME}/.joes-ai/data"

  # Don't overwrite existing scripts (preserves customer customizations)
  if [ ! -f "${LAUNCH_SCRIPT}" ]; then
    cat > "${LAUNCH_SCRIPT}" << LAUNCH_EOF
#!/usr/bin/env bash
WEBUI_PORT=\${WEBUI_PORT:-${WEBUI_PORT}}

# Prevent duplicate processes
if pgrep -f "open-webui serve" >/dev/null 2>&1; then
  echo "Joe's AI Server is already running."
  echo "Open your browser: http://localhost:\${WEBUI_PORT}"
  exit 0
fi

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
  else
    ok "Launch script already exists — preserved: ${LAUNCH_SCRIPT}"
  fi

  STOP_SCRIPT="${HOME}/.joes-ai/stop-server.sh"
  if [ ! -f "${STOP_SCRIPT}" ]; then
    cat > "${STOP_SCRIPT}" << STOP_EOF
#!/usr/bin/env bash
echo "Stopping Joe's AI Server..."
pkill -f "open-webui" 2>/dev/null || true
echo "Open WebUI stopped."
echo "Run ~/.joes-ai/start-server.sh to restart."
STOP_EOF
    chmod +x "${STOP_SCRIPT}"
    ok "Stop script created: ${STOP_SCRIPT}"
  else
    ok "Stop script already exists — preserved: ${STOP_SCRIPT}"
  fi

  # ── Auto-update script (always overwrite — not user-customizable) ──
  UPDATE_SCRIPT="${HOME}/.joes-ai/update.sh"
  cat > "${UPDATE_SCRIPT}" << 'UPDATE_EOF'
#!/usr/bin/env bash
#
# Joe's AI Server — Auto-Updater
# Safely updates Open WebUI and Ollama, then restarts the server.
# Runs weekly via launchd/systemd, or manually: ~/.joes-ai/update.sh
#
set -uo pipefail

LOG_DIR="${HOME}/.joes-ai/logs"
mkdir -p "${LOG_DIR}"
LOG="${LOG_DIR}/update-$(date +%Y%m%d-%H%M%S).log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG}"; }

log "=== Joe's AI Server — Update Check ==="

VENV_DIR="${HOME}/.joes-ai/venv"
UPDATED=false

# ── Update Open WebUI ──
if [ -d "${VENV_DIR}" ]; then
  source "${VENV_DIR}/bin/activate"
  OLD_VER=$(pip show open-webui 2>/dev/null | grep "^Version:" | awk '{print $2}' || echo "unknown")
  log "Current Open WebUI version: ${OLD_VER}"

  pip install --upgrade open-webui >> "${LOG}" 2>&1 || log "WARN: pip upgrade failed"
  NEW_VER=$(pip show open-webui 2>/dev/null | grep "^Version:" | awk '{print $2}' || echo "unknown")

  if [ "${OLD_VER}" != "${NEW_VER}" ]; then
    log "Open WebUI updated: ${OLD_VER} → ${NEW_VER}"
    UPDATED=true
  else
    log "Open WebUI already up to date (${OLD_VER})"
  fi
  deactivate
else
  log "WARN: Virtual environment not found at ${VENV_DIR}"
fi

# ── Update Ollama ──
if command -v brew >/dev/null 2>&1; then
  OLD_OLLAMA=$(ollama --version 2>/dev/null || echo "unknown")
  brew upgrade ollama >> "${LOG}" 2>&1 || log "Ollama already up to date (brew)"
  NEW_OLLAMA=$(ollama --version 2>/dev/null || echo "unknown")
  if [ "${OLD_OLLAMA}" != "${NEW_OLLAMA}" ]; then
    log "Ollama updated: ${OLD_OLLAMA} → ${NEW_OLLAMA}"
    UPDATED=true
  else
    log "Ollama already up to date"
  fi
elif command -v ollama >/dev/null 2>&1; then
  curl -fsSL https://ollama.com/install.sh | sh >> "${LOG}" 2>&1 || log "WARN: Ollama update failed"
  UPDATED=true
fi

# ── Restart server if anything was updated ──
if [ "${UPDATED}" = "true" ]; then
  log "Restarting Open WebUI..."
  pkill -f "open-webui" 2>/dev/null || true
  sleep 2
  # launchd/systemd KeepAlive will auto-restart, but give it a nudge
  if [[ "$OSTYPE" == "darwin"* ]]; then
    PLIST="${HOME}/Library/LaunchAgents/com.joestechsolutions.ai-server.plist"
    if [ -f "${PLIST}" ]; then
      launchctl unload "${PLIST}" 2>/dev/null || true
      launchctl load "${PLIST}" 2>/dev/null || true
    fi
  else
    systemctl --user restart joes-ai-webui.service 2>/dev/null || true
  fi
  log "Server restarted after update"
fi

log "=== Update check complete ==="

# Clean up old update logs (keep last 10)
ls -1t "${LOG_DIR}"/update-*.log 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
UPDATE_EOF
  chmod +x "${UPDATE_SCRIPT}"
  ok "Update script created: ${UPDATE_SCRIPT}"

  # ── Schedule weekly auto-update ──
  if [[ "$OSTYPE" == "darwin"* ]]; then
    UPDATE_PLIST="${HOME}/Library/LaunchAgents/com.joestechsolutions.ai-update.plist"
    cat > "${UPDATE_PLIST}" << UPDATE_PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.joestechsolutions.ai-update</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${HOME}/.joes-ai/update.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>3</integer>
        <key>Hour</key>
        <integer>4</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>${HOME}/.joes-ai/logs/update-launchd.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.joes-ai/logs/update-launchd.log</string>
</dict>
</plist>
UPDATE_PLIST_EOF
    launchctl unload "${UPDATE_PLIST}" 2>/dev/null || true
    launchctl load "${UPDATE_PLIST}"
    ok "Weekly auto-update scheduled (Wednesdays at 4 AM)"
  else
    UPDATE_TIMER_DIR="${HOME}/.config/systemd/user"
    mkdir -p "${UPDATE_TIMER_DIR}"

    cat > "${UPDATE_TIMER_DIR}/joes-ai-update.service" << UPDATE_SVC_EOF
[Unit]
Description=Joe's AI Server — Weekly Update

[Service]
Type=oneshot
ExecStart=/bin/bash ${HOME}/.joes-ai/update.sh
UPDATE_SVC_EOF

    cat > "${UPDATE_TIMER_DIR}/joes-ai-update.timer" << UPDATE_TIMER_EOF
[Unit]
Description=Joe's AI Server — Weekly Update Timer

[Timer]
OnCalendar=Wed *-*-* 04:00:00
Persistent=true

[Install]
WantedBy=timers.target
UPDATE_TIMER_EOF

    systemctl --user daemon-reload
    systemctl --user enable joes-ai-update.timer
    systemctl --user start joes-ai-update.timer
    ok "Weekly auto-update scheduled (Wednesdays at 4 AM)"
  fi
}

# ═══════════════════════════════════════════════════════════
# STEP 9: START SERVER & VERIFY (first boot)
# ═══════════════════════════════════════════════════════════

start_and_verify() {
  info "Step 9/9: Starting Open WebUI for the first time..."
  info "(First launch takes 2-4 minutes — initializing database and loading assets)"
  echo ""

  VENV_DIR="${HOME}/.joes-ai/venv"
  DATA_DIR="${HOME}/.joes-ai/data"
  mkdir -p "${LOG_DIR}"

  # Kill any existing Open WebUI processes
  pkill -f "open-webui" 2>/dev/null || true
  sleep 1

  # Start Open WebUI directly in background
  DATA_DIR="${DATA_DIR}" nohup "${VENV_DIR}/bin/open-webui" serve --port "${WEBUI_PORT}" \
    > "${LOG_DIR}/webui-stdout.log" 2> "${LOG_DIR}/webui-stderr.log" &
  WEBUI_PID=$!

  # Wait for Open WebUI with progress indicator (up to 5 minutes)
  MAX_WAIT=100  # 100 × 3 seconds = 5 minutes
  WEBUI_STARTED=false
  for i in $(seq 1 $MAX_WAIT); do
    if curl -sf "http://localhost:${WEBUI_PORT}" >/dev/null 2>&1; then
      WEBUI_STARTED=true
      break
    fi

    # Check if process is still alive
    if ! kill -0 "$WEBUI_PID" 2>/dev/null; then
      echo ""
      warn "Open WebUI process exited unexpectedly."
      warn "Check logs: cat ~/.joes-ai/logs/webui-stderr.log"
      warn "Try starting manually: ~/.joes-ai/start-server.sh"
      break
    fi

    # Progress indicator every 3 seconds
    ELAPSED=$((i * 3))
    if [ $((i % 10)) -eq 0 ]; then
      info "Still starting... (${ELAPSED}s elapsed — this is normal on first run)"
    else
      printf "."
    fi
    sleep 3
  done
  echo ""

  if [ "$WEBUI_STARTED" = "true" ]; then
    ok "Open WebUI is running at http://localhost:${WEBUI_PORT}"
  else
    warn "Open WebUI is still starting up — it may need another minute."
    warn "Check: curl -sf http://localhost:${WEBUI_PORT} && echo 'Ready!'"
    warn "Logs:  cat ~/.joes-ai/logs/webui-stderr.log"
  fi

  # ── Configure auto-start for future logins ──
  info "Configuring auto-start for future logins..."

  if [[ "$OSTYPE" == "darwin"* ]]; then
    PLIST_DIR="${HOME}/Library/LaunchAgents"
    PLIST_FILE="${PLIST_DIR}/com.joestechsolutions.ai-server.plist"
    mkdir -p "${PLIST_DIR}"

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
    ok "Auto-start configured — Open WebUI will start automatically on login"

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
    ok "Auto-start configured — Open WebUI will start automatically on login"
  fi

  echo ""
  info "Installed models:"
  ollama list 2>/dev/null || true
  echo ""

  MODEL_COUNT=$(ollama list 2>/dev/null | tail -n +2 | wc -l | tr -d ' ' || echo "0")
}

# ═══════════════════════════════════════════════════════════
# PRELOAD VERTICAL ASSISTANTS INTO OLLAMA
# ═══════════════════════════════════════════════════════════

preload_verticals() {
  info "Loading industry-specific AI assistants..."
  echo ""

  REPO_RAW="https://raw.githubusercontent.com/joblas/joes-ai-server/main"
  BASE_MODEL="${MODELS_TO_PULL[0]}"

  LOADED=0
  FAILED=0

  for vertical in healthcare legal financial realestate therapy education construction creative smallbusiness; do
    # Map vertical key to Ollama model name (no spaces allowed) and display name
    case "$vertical" in
      healthcare)    OLLAMA_NAME="healthcare-assistant";    DISPLAY_NAME="Healthcare Assistant" ;;
      legal)         OLLAMA_NAME="legal-assistant";         DISPLAY_NAME="Legal Assistant" ;;
      financial)     OLLAMA_NAME="financial-assistant";     DISPLAY_NAME="Financial Assistant" ;;
      realestate)    OLLAMA_NAME="realestate-assistant";    DISPLAY_NAME="Real Estate Assistant" ;;
      therapy)       OLLAMA_NAME="clinical-assistant";      DISPLAY_NAME="Clinical Assistant" ;;
      education)     OLLAMA_NAME="learning-assistant";      DISPLAY_NAME="Learning Assistant" ;;
      construction)  OLLAMA_NAME="construction-assistant";  DISPLAY_NAME="Construction Assistant" ;;
      creative)      OLLAMA_NAME="creative-assistant";      DISPLAY_NAME="Creative Assistant" ;;
      smallbusiness) OLLAMA_NAME="business-assistant";      DISPLAY_NAME="Business Assistant" ;;
      *)             OLLAMA_NAME="${vertical}-assistant";    DISPLAY_NAME="${vertical}" ;;
    esac
    PROMPT_URL="${REPO_RAW}/verticals/prompts/${vertical}.txt"

    # Download the system prompt
    SYSTEM_PROMPT=$(curl -fsSL "${PROMPT_URL}" 2>/dev/null || echo "")
    if [ -z "${SYSTEM_PROMPT}" ]; then
      warn "  Could not download prompt for ${vertical} — skipping"
      FAILED=$((FAILED + 1))
      continue
    fi

    # Write system prompt to a temp file (avoids escaping issues with special chars)
    PROMPT_FILE="/tmp/joes-ai-prompt-${vertical}-$$"
    printf '%s' "${SYSTEM_PROMPT}" > "${PROMPT_FILE}"

    # Create Ollama modelfile — read SYSTEM from file to avoid quoting issues
    MODELFILE_PATH="/tmp/joes-ai-${vertical}-$$"
    printf 'FROM %s\nSYSTEM """\n' "${BASE_MODEL}" > "${MODELFILE_PATH}"
    cat "${PROMPT_FILE}" >> "${MODELFILE_PATH}"
    printf '\n"""\n' >> "${MODELFILE_PATH}"

    if ollama create "${OLLAMA_NAME}" -f "${MODELFILE_PATH}" 2>&1; then
      ok "  ${DISPLAY_NAME} (${OLLAMA_NAME})"
      LOADED=$((LOADED + 1))
    else
      warn "  Failed to create ${DISPLAY_NAME} (${OLLAMA_NAME})"
      FAILED=$((FAILED + 1))
    fi
    rm -f "${MODELFILE_PATH}" "${PROMPT_FILE}"
  done

  echo ""
  if [ "${LOADED}" -gt 0 ]; then
    ok "${LOADED} industry assistants loaded — they'll appear in the model dropdown"
  fi
  if [ "${FAILED}" -gt 0 ]; then
    warn "${FAILED} assistants failed to load (can be added later)"
  fi
}

# ═══════════════════════════════════════════════════════════
# CONFIGURE OPEN WEBUI (model descriptions via temp admin)
# ═══════════════════════════════════════════════════════════

configure_webui() {
  info "Configuring model descriptions..."

  WEBUI_URL="http://localhost:${WEBUI_PORT}"

  # Create a temporary admin account to access the API
  # (first signup = admin; we'll delete it after so customer creates their own)
  TEMP_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 16 || true)
  SIGNUP_RESPONSE=$(curl -sf -X POST "${WEBUI_URL}/api/v1/auths/signup" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"Setup\",\"email\":\"setup@install.local\",\"password\":\"${TEMP_PASS}\"}" 2>/dev/null || echo "")

  if [ -z "${SIGNUP_RESPONSE}" ]; then
    warn "Could not configure descriptions — customer will see models without descriptions"
    return
  fi

  # Extract JWT + user ID (bash 3.2 compatible)
  JWT=$(echo "${SIGNUP_RESPONSE}" | "$PYTHON_CMD" -c "import sys,json; print(json.loads(sys.stdin.read()).get('token',''))" 2>/dev/null || echo "")
  TEMP_USER_ID=$(echo "${SIGNUP_RESPONSE}" | "$PYTHON_CMD" -c "import sys,json; print(json.loads(sys.stdin.read()).get('id',''))" 2>/dev/null || echo "")

  if [ -z "${JWT}" ]; then
    warn "Could not authenticate — descriptions skipped"
    return
  fi

  # Set descriptions + suggestion prompts for each vertical assistant
  # Uses a Python helper to build clean JSON (avoids escaping nightmares in bash)
  MODEL_CONFIG_SCRIPT=$(cat << 'PYCONFIG'
import json, sys
configs = {
  "healthcare-assistant": {
    "name": "Healthcare Assistant",
    "desc": "HIPAA-aware assistant for clinical notes, treatment plans, patient communication, and medical research.",
    "prompts": [
      {"title": ["Draft a", "patient summary"], "content": "Write a professional patient summary for a 45-year-old presenting with..."},
      {"title": ["Explain this", "diagnosis simply"], "content": "Explain the following diagnosis in plain language a patient can understand:"},
      {"title": ["Create a", "treatment plan"], "content": "Help me create a treatment plan outline for a patient with..."},
      {"title": ["Write a", "referral letter"], "content": "Draft a referral letter to a specialist for a patient who..."}
    ]
  },
  "legal-assistant": {
    "name": "Legal Assistant",
    "desc": "Legal research, contract review, case analysis, and compliance guidance. Not a substitute for licensed counsel.",
    "prompts": [
      {"title": ["Review this", "contract clause"], "content": "Review the following contract clause and identify any risks or issues:"},
      {"title": ["Summarize this", "legal concept"], "content": "Explain the following legal concept in plain language for a client:"},
      {"title": ["Draft a", "demand letter"], "content": "Help me draft a professional demand letter regarding..."},
      {"title": ["Research", "case precedent"], "content": "What are the key legal precedents related to..."}
    ]
  },
  "financial-assistant": {
    "name": "Financial Assistant",
    "desc": "Financial analysis, budgeting, tax planning, and investment research. Not personalized financial advice.",
    "prompts": [
      {"title": ["Create a", "budget template"], "content": "Help me create a monthly budget template for a small business with revenue of..."},
      {"title": ["Explain this", "financial term"], "content": "Explain the following financial concept in simple terms:"},
      {"title": ["Analyze", "cash flow"], "content": "Help me analyze the cash flow for a business with these numbers:"},
      {"title": ["Tax planning", "strategies"], "content": "What tax deduction strategies should a small business consider for..."}
    ]
  },
  "realestate-assistant": {
    "name": "Real Estate Assistant",
    "desc": "Property listings, market analysis, client communications, and transaction support for agents and brokers.",
    "prompts": [
      {"title": ["Write a", "property listing"], "content": "Write a compelling MLS listing description for a 3-bed/2-bath home with..."},
      {"title": ["Draft a", "client email"], "content": "Write a professional email to a buyer who just had their offer rejected on..."},
      {"title": ["Market analysis", "summary"], "content": "Summarize the key market trends I should share with a seller in a neighborhood where..."},
      {"title": ["Prepare", "showing notes"], "content": "Help me prepare talking points for showing a property that features..."}
    ]
  },
  "clinical-assistant": {
    "name": "Clinical Assistant",
    "desc": "Session notes, treatment planning, psychoeducation materials, and clinical documentation support.",
    "prompts": [
      {"title": ["Write", "session notes"], "content": "Help me write SOAP-format session notes for a client who discussed..."},
      {"title": ["Create a", "psychoeducation handout"], "content": "Create a client-friendly handout explaining the basics of..."},
      {"title": ["Treatment plan", "goals"], "content": "Help me write measurable treatment plan goals for a client presenting with..."},
      {"title": ["Draft a", "progress summary"], "content": "Write a progress summary for an insurance review for a client who has been in treatment for..."}
    ]
  },
  "learning-assistant": {
    "name": "Learning Assistant",
    "desc": "Lesson planning, curriculum design, student assessments, and educational content creation.",
    "prompts": [
      {"title": ["Create a", "lesson plan"], "content": "Create a 45-minute lesson plan for teaching the concept of..."},
      {"title": ["Write", "assessment questions"], "content": "Write 10 varied assessment questions (multiple choice, short answer, essay) for..."},
      {"title": ["Differentiate", "instruction"], "content": "How can I differentiate this lesson for students at different reading levels:"},
      {"title": ["Parent", "communication"], "content": "Draft a professional email to parents about upcoming..."}
    ]
  },
  "construction-assistant": {
    "name": "Construction Assistant",
    "desc": "Project estimates, safety compliance, scheduling, RFI responses, and construction documentation.",
    "prompts": [
      {"title": ["Draft an", "RFI response"], "content": "Help me draft a response to this Request for Information (RFI):"},
      {"title": ["Create a", "safety checklist"], "content": "Create a job site safety checklist for a project involving..."},
      {"title": ["Write a", "project scope"], "content": "Help me write a scope of work for a residential renovation that includes..."},
      {"title": ["Estimate", "materials"], "content": "Help me create a rough materials estimate for..."}
    ]
  },
  "creative-assistant": {
    "name": "Creative Assistant",
    "desc": "Writing, editing, brainstorming, marketing copy, social media content, and creative direction.",
    "prompts": [
      {"title": ["Write a", "blog post outline"], "content": "Create a blog post outline about the topic of..."},
      {"title": ["Social media", "content ideas"], "content": "Give me 5 engaging social media post ideas for a business that..."},
      {"title": ["Edit this", "for clarity"], "content": "Edit the following text for clarity, tone, and impact:"},
      {"title": ["Write", "email copy"], "content": "Write a compelling email newsletter promoting..."}
    ]
  },
  "business-assistant": {
    "name": "Business Assistant",
    "desc": "Business planning, marketing strategy, operations, customer service templates, and growth tactics.",
    "prompts": [
      {"title": ["Write a", "business plan section"], "content": "Help me write the executive summary for a business that..."},
      {"title": ["Customer", "response template"], "content": "Write a professional response to a customer who is unhappy about..."},
      {"title": ["Marketing", "strategy ideas"], "content": "Suggest 5 low-cost marketing strategies for a local business that..."},
      {"title": ["Improve my", "operations"], "content": "How can I streamline operations for a small business that currently..."}
    ]
  }
}
model_id = sys.argv[1]
if model_id in configs:
    c = configs[model_id]
    payload = {
        "id": model_id,
        "name": c["name"],
        "meta": {"description": c["desc"], "suggestion_prompts": c["prompts"]},
        "base_model_id": model_id,
        "params": {}
    }
    print(json.dumps(payload))
PYCONFIG
  )

  for vertical in healthcare legal financial realestate therapy education construction creative smallbusiness; do
    case "$vertical" in
      healthcare)    MODEL_ID="healthcare-assistant" ;;
      legal)         MODEL_ID="legal-assistant" ;;
      financial)     MODEL_ID="financial-assistant" ;;
      realestate)    MODEL_ID="realestate-assistant" ;;
      therapy)       MODEL_ID="clinical-assistant" ;;
      education)     MODEL_ID="learning-assistant" ;;
      construction)  MODEL_ID="construction-assistant" ;;
      creative)      MODEL_ID="creative-assistant" ;;
      smallbusiness) MODEL_ID="business-assistant" ;;
    esac

    PAYLOAD=$(echo "${MODEL_CONFIG_SCRIPT}" | "$PYTHON_CMD" - "${MODEL_ID}" 2>/dev/null || echo "")
    if [ -n "${PAYLOAD}" ]; then
      curl -sf -X POST "${WEBUI_URL}/api/v1/models/add" \
        -H "Authorization: Bearer ${JWT}" \
        -H "Content-Type: application/json" \
        -d "${PAYLOAD}" >/dev/null 2>&1 || true
    fi
  done

  # Set descriptions + prompts for base models
  curl -sf -X POST "${WEBUI_URL}/api/v1/models/add" \
    -H "Authorization: Bearer ${JWT}" \
    -H "Content-Type: application/json" \
    -d '{"id":"llama3.2:3b","name":"Llama 3.2","meta":{"description":"Fast general-purpose chat. Best for quick questions and everyday tasks.","suggestion_prompts":[{"title":["Help me","write something"],"content":"Help me write a professional email about..."},{"title":["Explain","a concept"],"content":"Explain the following concept in simple terms:"},{"title":["Brainstorm","ideas for"],"content":"Give me 5 creative ideas for..."},{"title":["Summarize","this text"],"content":"Summarize the following text in 3 bullet points:"}]},"base_model_id":"llama3.2:3b","params":{}}' >/dev/null 2>&1 || true

  curl -sf -X POST "${WEBUI_URL}/api/v1/models/add" \
    -H "Authorization: Bearer ${JWT}" \
    -H "Content-Type: application/json" \
    -d '{"id":"gemma3:4b","name":"Gemma 3 Vision","meta":{"description":"Upload images, screenshots, or documents and ask questions about them.","suggestion_prompts":[{"title":["Read this","image"],"content":"What does this image show? Describe everything you see."},{"title":["Extract text","from photo"],"content":"Extract and list all the text you can see in this image."},{"title":["Analyze this","document"],"content":"Read this document and summarize the key points."},{"title":["What is","in this photo?"],"content":"Describe what you see and answer any questions I have about it."}]},"base_model_id":"gemma3:4b","params":{}}' >/dev/null 2>&1 || true

  ok "Model descriptions and prompt suggestions configured"

  # ── Configure RAG / Document settings ──────────────────
  info "Configuring RAG (document search) settings..."
  RAG_RESPONSE=$(curl -sf -X POST "${WEBUI_URL}/api/v1/retrieval/config/update" \
    -H "Authorization: Bearer ${JWT}" \
    -H "Content-Type: application/json" \
    -d '{
      "chunk": {"chunk_size": 1500, "chunk_overlap": 200},
      "top_k": 5,
      "file": {"max_size": 104857600, "max_count": 10}
    }' 2>/dev/null || echo "")
  if [ -n "${RAG_RESPONSE}" ]; then
    ok "RAG settings configured (chunk_size=1500, top_k=5)"
  else
    warn "RAG settings could not be applied — configure manually in Admin > Documents"
  fi

  # ── Configure embedding model (Ollama + nomic-embed-text) ──
  info "Configuring embedding model..."
  EMBED_RESPONSE=$(curl -sf -X POST "${WEBUI_URL}/api/v1/retrieval/embedding/update" \
    -H "Authorization: Bearer ${JWT}" \
    -H "Content-Type: application/json" \
    -d '{
      "embedding_engine": "ollama",
      "embedding_model": "nomic-embed-text",
      "ollama_config": {"url": "http://localhost:11434"}
    }' 2>/dev/null || echo "")
  if [ -n "${EMBED_RESPONSE}" ]; then
    ok "Embedding model set to nomic-embed-text (Ollama)"
  else
    warn "Embedding model could not be set — configure manually in Admin > Documents"
  fi

  # ── Configure Web Search (DuckDuckGo — no API key needed) ──
  info "Enabling web search..."
  WEBSEARCH_RESPONSE=$(curl -sf -X POST "${WEBUI_URL}/api/v1/retrieval/config/update" \
    -H "Authorization: Bearer ${JWT}" \
    -H "Content-Type: application/json" \
    -d '{
      "web": {
        "search": {
          "enabled": true,
          "engine": "duckduckgo",
          "result_count": 5
        }
      }
    }' 2>/dev/null || echo "")
  if [ -n "${WEBSEARCH_RESPONSE}" ]; then
    ok "Web search enabled (DuckDuckGo, 5 results)"
  else
    warn "Web search could not be enabled — configure manually in Admin > Web Search"
  fi

  # ── Configure Task generation settings ──
  info "Configuring task generation..."
  TASKS_RESPONSE=$(curl -sf -X POST "${WEBUI_URL}/api/v1/tasks/config/update" \
    -H "Authorization: Bearer ${JWT}" \
    -H "Content-Type: application/json" \
    -d '{
      "ENABLE_TITLE_GENERATION": true,
      "ENABLE_TAGS_GENERATION": true,
      "ENABLE_SEARCH_QUERY_GENERATION": true,
      "ENABLE_RETRIEVAL_QUERY_GENERATION": true
    }' 2>/dev/null || echo "")
  if [ -n "${TASKS_RESPONSE}" ]; then
    ok "Title, tags, and query generation enabled"
  else
    warn "Task generation settings could not be applied — configure manually in Admin > Interface"
  fi

  # ── Set default model (first chat model in the list) ──
  info "Setting default model..."
  DEFAULT_MODEL="${MODELS_TO_PULL[0]}"
  DEFAULT_MODEL_RESPONSE=$(curl -sf -X POST "${WEBUI_URL}/api/v1/configs/update" \
    -H "Authorization: Bearer ${JWT}" \
    -H "Content-Type: application/json" \
    -d "{\"ui\":{\"default_models\":\"${DEFAULT_MODEL}\"}}" 2>/dev/null || echo "")
  if [ -n "${DEFAULT_MODEL_RESPONSE}" ]; then
    ok "Default model set to ${DEFAULT_MODEL}"
  else
    warn "Default model could not be set — customer can pick from the dropdown"
  fi

  # Delete the temp admin account so customer creates their own on first visit
  if [ -n "${TEMP_USER_ID}" ]; then
    curl -sf -X DELETE "${WEBUI_URL}/api/v1/users/${TEMP_USER_ID}" \
      -H "Authorization: Bearer ${JWT}" >/dev/null 2>&1 || true
    ok "Temporary setup account removed — customer will create their own"
  fi
}

# ═══════════════════════════════════════════════════════════
# GENERATE LOCAL WELCOME PAGE
# ═══════════════════════════════════════════════════════════

generate_welcome_page() {
  local WELCOME_FILE="${HOME}/.joes-ai/welcome.html"
  local INSTALL_DATE
  INSTALL_DATE="$(date '+%B %d, %Y at %I:%M %p')"

  # Build model table rows from MODELS_TO_PULL
  local MODEL_ROWS=""
  for model in "${MODELS_TO_PULL[@]}"; do
    case "$model" in
      llama3.2:3b)       MODEL_ROWS="${MODEL_ROWS}<tr><td><code>llama3.2:3b</code></td><td>~2.0 GB</td><td>Fast text chat, great for 8 GB machines</td></tr>" ;;
      gemma3:4b)         MODEL_ROWS="${MODEL_ROWS}<tr><td><code>gemma3:4b</code></td><td>~3.3 GB</td><td>Vision model — reads images and documents</td></tr>" ;;
      qwen3:8b)          MODEL_ROWS="${MODEL_ROWS}<tr><td><code>qwen3:8b</code></td><td>~5.2 GB</td><td>Sweet spot performance, 40+ tokens/sec</td></tr>" ;;
      gemma3:12b)        MODEL_ROWS="${MODEL_ROWS}<tr><td><code>gemma3:12b</code></td><td>~8.1 GB</td><td>Google multimodal, strong reasoning</td></tr>" ;;
      deepseek-r1:8b)    MODEL_ROWS="${MODEL_ROWS}<tr><td><code>deepseek-r1:8b</code></td><td>~4.9 GB</td><td>Advanced reasoning and coding</td></tr>" ;;
      deepseek-r1:14b)   MODEL_ROWS="${MODEL_ROWS}<tr><td><code>deepseek-r1:14b</code></td><td>~9.0 GB</td><td>Advanced reasoning + coding</td></tr>" ;;
      deepseek-r1:32b)   MODEL_ROWS="${MODEL_ROWS}<tr><td><code>deepseek-r1:32b</code></td><td>~20 GB</td><td>Top-tier reasoning + coding</td></tr>" ;;
      qwen3:32b)         MODEL_ROWS="${MODEL_ROWS}<tr><td><code>qwen3:32b</code></td><td>~20 GB</td><td>Near-frontier quality, rivals GPT-4</td></tr>" ;;
      gemma3:27b)        MODEL_ROWS="${MODEL_ROWS}<tr><td><code>gemma3:27b</code></td><td>~17 GB</td><td>Google flagship, multimodal</td></tr>" ;;
      nomic-embed-text)  MODEL_ROWS="${MODEL_ROWS}<tr><td><code>nomic-embed-text</code></td><td>~0.3 GB</td><td>Enables document search (RAG)</td></tr>" ;;
      *)                 MODEL_ROWS="${MODEL_ROWS}<tr><td><code>${model}</code></td><td>-</td><td>User-selected model</td></tr>" ;;
    esac
  done

  cat > "${WELCOME_FILE}" << 'WELCOME_HTML_TOP'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Your Private AI Server - Joe's Tech Solutions</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: #f5f7fa; color: #1a2332; line-height: 1.6;
  }
  .header {
    background: linear-gradient(135deg, #0f2847 0%, #1a4b8c 50%, #2563a8 100%);
    color: white; padding: 48px 24px; text-align: center;
  }
  .header h1 { font-size: 2.2em; font-weight: 700; margin-bottom: 8px; }
  .header p { font-size: 1.1em; opacity: 0.9; }
  .header .brand { font-size: 0.85em; opacity: 0.7; margin-top: 12px; letter-spacing: 1px; text-transform: uppercase; }
  .container { max-width: 820px; margin: 0 auto; padding: 0 24px 48px; }
  .card {
    background: white; border-radius: 12px; padding: 32px;
    margin-top: 28px; box-shadow: 0 2px 12px rgba(0,0,0,0.06);
    border: 1px solid #e2e8f0;
  }
  .card h2 {
    font-size: 1.35em; color: #0f2847; margin-bottom: 16px;
    padding-bottom: 10px; border-bottom: 2px solid #e2e8f0;
  }
  .summary-grid {
    display: grid; grid-template-columns: 1fr 1fr;
    gap: 12px 24px;
  }
  .summary-item { display: flex; flex-direction: column; }
  .summary-label { font-size: 0.8em; text-transform: uppercase; color: #64748b; letter-spacing: 0.5px; font-weight: 600; }
  .summary-value { font-size: 1.05em; font-weight: 600; color: #1a2332; }
  .steps {
    display: flex; justify-content: space-between; gap: 16px;
    margin-top: 8px;
  }
  .step {
    flex: 1; text-align: center; padding: 20px 12px;
    background: #f0f5ff; border-radius: 10px;
  }
  .step-num {
    display: inline-block; width: 36px; height: 36px; line-height: 36px;
    background: #1a4b8c; color: white; border-radius: 50%;
    font-weight: 700; font-size: 1.1em; margin-bottom: 10px;
  }
  .step-title { font-weight: 600; font-size: 0.95em; margin-bottom: 4px; }
  .step-desc { font-size: 0.82em; color: #64748b; }
  table { width: 100%; border-collapse: collapse; margin-top: 8px; }
  th { background: #f0f5ff; text-align: left; padding: 10px 12px; font-size: 0.85em; color: #1a4b8c; border-bottom: 2px solid #d4e0f0; }
  td { padding: 10px 12px; border-bottom: 1px solid #e2e8f0; font-size: 0.92em; }
  tr:last-child td { border-bottom: none; }
  code {
    background: #f0f5ff; padding: 2px 8px; border-radius: 4px;
    font-family: "SF Mono", "Fira Code", Menlo, monospace;
    font-size: 0.88em; color: #1a4b8c;
  }
  .cmd-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 8px; }
  .cmd-item {
    background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px;
    padding: 12px 14px;
  }
  .cmd-label { font-size: 0.78em; text-transform: uppercase; color: #64748b; font-weight: 600; margin-bottom: 4px; }
  .cmd-code { font-family: "SF Mono", Menlo, monospace; font-size: 0.88em; color: #1a2332; }
  .troubleshooting-item { padding: 12px 0; border-bottom: 1px solid #f0f0f0; }
  .troubleshooting-item:last-child { border-bottom: none; }
  .troubleshooting-item strong { color: #0f2847; }
  .troubleshooting-item p { margin-top: 4px; font-size: 0.92em; color: #475569; }
  .footer {
    text-align: center; padding: 32px 24px; color: #94a3b8;
    font-size: 0.85em; border-top: 1px solid #e2e8f0; margin-top: 40px;
  }
  .footer a { color: #1a4b8c; text-decoration: none; }
  .footer a:hover { text-decoration: underline; }
  @media (max-width: 600px) {
    .summary-grid { grid-template-columns: 1fr; }
    .steps { flex-direction: column; }
    .cmd-grid { grid-template-columns: 1fr; }
  }
</style>
</head>
<body>
<div class="header">
  <h1>Your Private AI Server</h1>
  <p>Everything runs locally &mdash; your data never leaves this computer.</p>
  <div class="brand">Joe's Tech Solutions LLC</div>
</div>
<div class="container">
WELCOME_HTML_TOP

  # ── System Summary card (dynamic values) ──
  cat >> "${WELCOME_FILE}" << WELCOME_HTML_SUMMARY
  <div class="card">
    <h2>System Summary</h2>
    <div class="summary-grid">
      <div class="summary-item">
        <span class="summary-label">Total RAM</span>
        <span class="summary-value">${TOTAL_RAM_GB} GB</span>
      </div>
      <div class="summary-item">
        <span class="summary-label">Performance Tier</span>
        <span class="summary-value">${TIER:-Custom}</span>
      </div>
      <div class="summary-item">
        <span class="summary-label">CPU Cores</span>
        <span class="summary-value">${CPU_CORES}</span>
      </div>
      <div class="summary-item">
        <span class="summary-label">GPU</span>
        <span class="summary-value">${GPU_NAME}</span>
      </div>
      <div class="summary-item">
        <span class="summary-label">Web UI Port</span>
        <span class="summary-value">${WEBUI_PORT}</span>
      </div>
      <div class="summary-item">
        <span class="summary-label">Models Installed</span>
        <span class="summary-value">${MODEL_COUNT}</span>
      </div>
    </div>
  </div>
WELCOME_HTML_SUMMARY

  # ── Getting Started card ──
  cat >> "${WELCOME_FILE}" << WELCOME_HTML_STARTED
  <div class="card">
    <h2>Getting Started</h2>
    <div class="steps">
      <div class="step">
        <div class="step-num">1</div>
        <div class="step-title">Open Browser</div>
        <div class="step-desc">Go to <strong>http://localhost:${WEBUI_PORT}</strong></div>
      </div>
      <div class="step">
        <div class="step-num">2</div>
        <div class="step-title">Create Account</div>
        <div class="step-desc">First signup becomes the admin</div>
      </div>
      <div class="step">
        <div class="step-num">3</div>
        <div class="step-title">Start Chatting</div>
        <div class="step-desc">Pick an assistant from the dropdown and ask anything</div>
      </div>
    </div>
  </div>
WELCOME_HTML_STARTED

  # ── Model Recommendations card (dynamic rows) ──
  cat >> "${WELCOME_FILE}" << WELCOME_HTML_MODELS
  <div class="card">
    <h2>Your Installed Models</h2>
    <table>
      <thead><tr><th>Model</th><th>Size</th><th>Best For</th></tr></thead>
      <tbody>
        ${MODEL_ROWS}
      </tbody>
    </table>
  </div>
WELCOME_HTML_MODELS

  # ── Quick Reference card ──
  cat >> "${WELCOME_FILE}" << 'WELCOME_HTML_CMDS'
  <div class="card">
    <h2>Quick Reference</h2>
    <div class="cmd-grid">
      <div class="cmd-item">
        <div class="cmd-label">Start Server</div>
        <div class="cmd-code">~/.joes-ai/start-server.sh</div>
      </div>
      <div class="cmd-item">
        <div class="cmd-label">Stop Server</div>
        <div class="cmd-code">~/.joes-ai/stop-server.sh</div>
      </div>
      <div class="cmd-item">
        <div class="cmd-label">List Models</div>
        <div class="cmd-code">ollama list</div>
      </div>
      <div class="cmd-item">
        <div class="cmd-label">Download Model</div>
        <div class="cmd-code">ollama pull &lt;model&gt;</div>
      </div>
      <div class="cmd-item">
        <div class="cmd-label">Remove Model</div>
        <div class="cmd-code">ollama rm &lt;model&gt;</div>
      </div>
      <div class="cmd-item">
        <div class="cmd-label">Update Everything</div>
        <div class="cmd-code">~/.joes-ai/update.sh</div>
      </div>
    </div>
  </div>
WELCOME_HTML_CMDS

  # ── Troubleshooting card ──
  cat >> "${WELCOME_FILE}" << 'WELCOME_HTML_TROUBLE'
  <div class="card">
    <h2>Troubleshooting</h2>
    <div class="troubleshooting-item">
      <strong>Can't connect to the server?</strong>
      <p>Open Terminal and run: <code>~/.joes-ai/start-server.sh</code><br>
      Make sure Ollama is also running: <code>brew services start ollama</code></p>
    </div>
    <div class="troubleshooting-item">
      <strong>AI doesn't respond or is very slow?</strong>
      <p>Check that a model is selected in the dropdown. Try a smaller model if responses are slow.
      Restart the server if needed: <code>~/.joes-ai/stop-server.sh && ~/.joes-ai/start-server.sh</code></p>
    </div>
    <div class="troubleshooting-item">
      <strong>Need to reinstall?</strong>
      <p>You can safely re-run the installer at any time &mdash; it won't delete your chats or settings:<br>
      <code>curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.sh | bash</code></p>
    </div>
    <div class="troubleshooting-item">
      <strong>Still stuck?</strong>
      <p>Email <a href="mailto:joe@joestechsolutions.com">joe@joestechsolutions.com</a> with a description
      of the issue. Attach the install log from <code>~/.joes-ai/logs/</code> if available.</p>
    </div>
  </div>
WELCOME_HTML_TROUBLE

  # ── Footer (dynamic install date) ──
  cat >> "${WELCOME_FILE}" << WELCOME_HTML_FOOTER
</div>
<div class="footer">
  <p>Installed on ${INSTALL_DATE}</p>
  <p style="margin-top: 6px;">Support: <a href="mailto:joe@joestechsolutions.com">joe@joestechsolutions.com</a></p>
  <p style="margin-top: 6px; opacity: 0.7;">Joe's Tech Solutions LLC &mdash; Private AI for Everyone</p>
</div>
</body>
</html>
WELCOME_HTML_FOOTER

  ok "Welcome page generated: ${WELCOME_FILE}"
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
install_open_webui
create_scripts
start_and_verify

# Load vertical assistants (only if WebUI started and models are available)
if [ "${WEBUI_STARTED}" = "true" ] && [ ${#MODELS_TO_PULL[@]} -gt 0 ]; then
  if [ -n "${VERTICAL:-}" ]; then
    # Single vertical specified via env var — load just that one (legacy support)
    create_vertical
  else
    # Default: preload all 9 industry assistants
    preload_verticals
  fi
fi

# Refresh model count (includes verticals now)
MODEL_COUNT=$(ollama list 2>/dev/null | tail -n +2 | wc -l | tr -d ' ' || echo "0")

# Configure Open WebUI (model descriptions via temp admin)
if [ "${WEBUI_STARTED}" = "true" ]; then
  configure_webui
fi

generate_welcome_page

# ── Conditional Banner ────────────────────────────────────
echo ""
if [ "${WEBUI_STARTED}" = "true" ]; then
  echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
  box_line_green "$(printf '%-4s%s' '' '✅ Joes Local AI Server is LIVE!')"
  echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
  box_line_green ""
  box_line_green "$(printf 'Open your browser:  http://localhost:%s' "${WEBUI_PORT}")"
  box_line_green ""
  box_line_green "$(printf 'Hardware:  %s GB RAM / %s cores / %s' "${TOTAL_RAM_GB}" "${CPU_CORES}" "${GPU_TYPE}")"
  box_line_green "$(printf 'Tier:      %s' "${TIER:-Custom}")"
  box_line_green "$(printf 'Models:    %s installed and ready' "${MODEL_COUNT}")"
  box_line_green ""
  box_line_green "First visit: Create your admin account, then chat!"
  box_line_green ""
  box_line_green "Commands:"
  box_line_green "  ~/.joes-ai/start-server.sh    (start server)"
  box_line_green "  ~/.joes-ai/stop-server.sh     (stop server)"
  box_line_green "  ollama list                   (list models)"
  box_line_green "  ollama pull <model>           (download model)"
  box_line_green "  ollama rm <model>             (remove model)"
  box_line_green ""
  box_line_green "Auto-start: Server starts automatically on login"
  box_line_green "Auto-update: Checks for updates weekly (Wed 4 AM)"
  box_line_green ""
  box_line_green "Support: joe@joestechsolutions.com"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
else
  echo -e "${YELLOW}╔══════════════════════════════════════════════════════════╗${NC}"
  printf "${YELLOW}║${NC}  %-56s${YELLOW}║${NC}\n" "Installation Complete — Server Not Verified"
  echo -e "${YELLOW}╠══════════════════════════════════════════════════════════╣${NC}"
  printf "${YELLOW}║${NC}  %-56s${YELLOW}║${NC}\n" ""
  printf "${YELLOW}║${NC}  %-56s${YELLOW}║${NC}\n" "Everything was installed, but Open WebUI did not"
  printf "${YELLOW}║${NC}  %-56s${YELLOW}║${NC}\n" "respond on port ${WEBUI_PORT} within the timeout."
  printf "${YELLOW}║${NC}  %-56s${YELLOW}║${NC}\n" ""
  printf "${YELLOW}║${NC}  %-56s${YELLOW}║${NC}\n" "Try these steps:"
  printf "${YELLOW}║${NC}  %-56s${YELLOW}║${NC}\n" "  1. Wait a minute, then open http://localhost:${WEBUI_PORT}"
  printf "${YELLOW}║${NC}  %-56s${YELLOW}║${NC}\n" "  2. Check logs: cat ~/.joes-ai/logs/webui-stderr.log"
  printf "${YELLOW}║${NC}  %-56s${YELLOW}║${NC}\n" "  3. Restart: ~/.joes-ai/start-server.sh"
  printf "${YELLOW}║${NC}  %-56s${YELLOW}║${NC}\n" "  4. Email joe@joestechsolutions.com with the log"
  printf "${YELLOW}║${NC}  %-56s${YELLOW}║${NC}\n" ""
  printf "${YELLOW}║${NC}  %-56s${YELLOW}║${NC}\n" "Install log: ${LOG}"
  echo -e "${YELLOW}╚══════════════════════════════════════════════════════════╝${NC}"
fi
echo ""

# Auto-open welcome page on success (macOS)
if [ "${WEBUI_STARTED}" = "true" ] && [[ "$OSTYPE" == "darwin"* ]]; then
  open "${HOME}/.joes-ai/welcome.html" 2>/dev/null || true
fi

info "Install log saved to: ${LOG}"

} # end main()

# Run main — this ensures the entire script is parsed before execution
main "$@"
