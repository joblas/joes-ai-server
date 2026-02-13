#!/usr/bin/env bash
#
# Joe's Tech Solutions — Local AI Server Installer (Mac / Linux)
# Auto-detects hardware and installs optimal AI models
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.sh | bash
#
# Options (environment variables):
#   WEBUI_PORT=3000        Port for Open WebUI (default: 3000)
#   PULL_MODEL=llama3.2    Override auto-detected model (skip hardware detection)
#   SKIP_MODELS=true       Skip all model downloads (just install the server)
#
set -euo pipefail

# ── Config ──────────────────────────────────────────────
WEBUI_PORT="${WEBUI_PORT:-3000}"
CONTAINER_NAME="joes-ai-local"
IMAGE="ghcr.io/open-webui/open-webui:ollama"
OS_OVERHEAD_GB=4  # Reserve for OS + Docker + apps

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
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ═══════════════════════════════════════════════════════════
# HARDWARE DETECTION
# ═══════════════════════════════════════════════════════════

detect_hardware() {
  info "Scanning hardware..."

  # ── Detect RAM ──
  TOTAL_RAM_GB=0
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    TOTAL_RAM_BYTES=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    TOTAL_RAM_GB=$(( TOTAL_RAM_BYTES / 1073741824 ))
  else
    # Linux
    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0)
    TOTAL_RAM_GB=$(( TOTAL_RAM_KB / 1048576 ))
  fi

  AVAILABLE_RAM_GB=$(( TOTAL_RAM_GB - OS_OVERHEAD_GB ))
  if [ "$AVAILABLE_RAM_GB" -lt 1 ]; then AVAILABLE_RAM_GB=1; fi

  # ── Detect CPU cores ──
  if [[ "$OSTYPE" == "darwin"* ]]; then
    CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo "?")
    # Check for Apple Silicon
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
    # Check for NVIDIA GPU
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

  # ── Detect disk space ──
  if [[ "$OSTYPE" == "darwin"* ]]; then
    FREE_DISK_GB=$(df -g / 2>/dev/null | tail -1 | awk '{print $4}' || echo "?")
  else
    FREE_DISK_GB=$(df -BG / 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'G' || echo "?")
  fi

  # ── Print hardware report ──
  echo ""
  echo -e "${BOLD}  ┌─────────────────────────────────────────┐${NC}"
  echo -e "${BOLD}  │         HARDWARE DETECTED                │${NC}"
  echo -e "${BOLD}  ├─────────────────────────────────────────┤${NC}"
  echo -e "${BOLD}  │${NC}  RAM:        ${GREEN}${TOTAL_RAM_GB} GB total${NC} (${AVAILABLE_RAM_GB} GB available for AI)"
  echo -e "${BOLD}  │${NC}  CPU Cores:  ${GREEN}${CPU_CORES}${NC}"
  echo -e "${BOLD}  │${NC}  GPU:        ${GREEN}${GPU_NAME}${NC}"
  if [ "${GPU_TYPE}" = "nvidia" ] && [ "${GPU_VRAM_GB}" -gt 0 ]; then
  echo -e "${BOLD}  │${NC}  VRAM:       ${GREEN}${GPU_VRAM_GB} GB${NC}"
  fi
  echo -e "${BOLD}  │${NC}  Free Disk:  ${GREEN}${FREE_DISK_GB} GB${NC}"
  echo -e "${BOLD}  └─────────────────────────────────────────┘${NC}"
  echo ""
}

# ═══════════════════════════════════════════════════════════
# MODEL SELECTION ENGINE
# ═══════════════════════════════════════════════════════════
#
# Model sizes (approximate download / RAM when loaded):
#   llama3.2:1b       ~1.3 GB   — Fast, basic tasks
#   llama3.2          ~2.0 GB   — Good all-rounder (3B)
#   phi3:mini         ~2.3 GB   — Microsoft, strong reasoning for size
#   gemma2:2b         ~1.6 GB   — Google, efficient
#   mistral           ~4.1 GB   — Fast, great instruction following
#   llama3.1:8b       ~4.7 GB   — Meta's workhorse, high quality
#   deepseek-r1:8b    ~4.9 GB   — Excellent reasoning + coding
#   qwen2.5:14b       ~9.0 GB   — Alibaba, strong multilingual
#   llama3.1:70b      ~40  GB   — Flagship quality (needs serious hardware)
#   nomic-embed-text  ~0.3 GB   — Embedding model for RAG/document search
#

select_models() {
  MODELS_TO_PULL=()
  MODELS_DESCRIPTION=()

  # If user manually specified a model, use that
  if [ -n "${PULL_MODEL:-}" ]; then
    MODELS_TO_PULL+=("${PULL_MODEL}")
    MODELS_DESCRIPTION+=("${PULL_MODEL} (user selected)")
    return
  fi

  # Use GPU VRAM as primary if NVIDIA, otherwise use system RAM
  if [ "${GPU_TYPE}" = "nvidia" ] && [ "${GPU_VRAM_GB:-0}" -gt 0 ]; then
    COMPUTE_RAM=${GPU_VRAM_GB}
    RAM_SOURCE="GPU VRAM"
  else
    COMPUTE_RAM=${AVAILABLE_RAM_GB}
    RAM_SOURCE="System RAM"
  fi

  info "Selecting optimal models based on ${RAM_SOURCE}: ${COMPUTE_RAM} GB available..."

  # ── Tier 1: Minimal (< 6 GB available) ──
  if [ "${COMPUTE_RAM}" -lt 6 ]; then
    MODELS_TO_PULL+=("llama3.2:1b")
    MODELS_DESCRIPTION+=("llama3.2:1b  (1.3 GB) — Lightweight chat, fits your ${COMPUTE_RAM}GB available")
    TIER="Starter"

  # ── Tier 2: Light (6–9 GB available) ──
  elif [ "${COMPUTE_RAM}" -lt 10 ]; then
    MODELS_TO_PULL+=("llama3.2" "nomic-embed-text")
    MODELS_DESCRIPTION+=("llama3.2     (2.0 GB) — Solid all-rounder chat model")
    MODELS_DESCRIPTION+=("nomic-embed  (0.3 GB) — Enables document search (RAG)")
    TIER="Standard"

  # ── Tier 3: Capable (10–19 GB available) ──
  elif [ "${COMPUTE_RAM}" -lt 20 ]; then
    MODELS_TO_PULL+=("llama3.1:8b" "nomic-embed-text")
    MODELS_DESCRIPTION+=("llama3.1:8b  (4.7 GB) — High quality chat + reasoning")
    MODELS_DESCRIPTION+=("nomic-embed  (0.3 GB) — Enables document search (RAG)")
    TIER="Performance"

  # ── Tier 4: Strong (20–45 GB available) ──
  elif [ "${COMPUTE_RAM}" -lt 46 ]; then
    MODELS_TO_PULL+=("llama3.1:8b" "deepseek-r1:8b" "nomic-embed-text")
    MODELS_DESCRIPTION+=("llama3.1:8b    (4.7 GB) — High quality general chat")
    MODELS_DESCRIPTION+=("deepseek-r1:8b (4.9 GB) — Advanced reasoning + coding")
    MODELS_DESCRIPTION+=("nomic-embed    (0.3 GB) — Enables document search (RAG)")
    TIER="Power"

  # ── Tier 5: Beast (46+ GB available) ──
  else
    MODELS_TO_PULL+=("qwen2.5:14b" "llama3.1:8b" "deepseek-r1:8b" "nomic-embed-text")
    MODELS_DESCRIPTION+=("qwen2.5:14b    (9.0 GB) — Flagship quality, multilingual")
    MODELS_DESCRIPTION+=("llama3.1:8b    (4.7 GB) — Fast general chat")
    MODELS_DESCRIPTION+=("deepseek-r1:8b (4.9 GB) — Advanced reasoning + coding")
    MODELS_DESCRIPTION+=("nomic-embed    (0.3 GB) — Enables document search (RAG)")
    TIER="Maximum"
  fi

  # ── Print selection ──
  echo ""
  echo -e "${BOLD}  ┌─────────────────────────────────────────────────────┐${NC}"
  echo -e "${BOLD}  │  AI MODEL PLAN — ${TIER} Tier                         ${NC}"
  echo -e "${BOLD}  ├─────────────────────────────────────────────────────┤${NC}"
  for desc in "${MODELS_DESCRIPTION[@]}"; do
  echo -e "${BOLD}  │${NC}  ✦ ${desc}"
  done
  echo -e "${BOLD}  └─────────────────────────────────────────────────────┘${NC}"
  echo ""

  # ── Disk space warning ──
  if [ "${FREE_DISK_GB}" != "?" ]; then
    TOTAL_MODEL_GB=0
    for model in "${MODELS_TO_PULL[@]}"; do
      case "$model" in
        llama3.2:1b)       TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 2));;
        llama3.2)          TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 3));;
        phi3:mini)         TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 3));;
        mistral)           TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 5));;
        llama3.1:8b)       TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 5));;
        deepseek-r1:8b)    TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 5));;
        qwen2.5:14b)       TOTAL_MODEL_GB=$((TOTAL_MODEL_GB + 10));;
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
# MAIN INSTALLATION
# ═══════════════════════════════════════════════════════════

# ── Step 1: Check Docker ───────────────────────────────
info "Checking Docker installation..."

if ! command -v docker >/dev/null 2>&1; then
  fail "Docker is not installed. Please install Docker Desktop first:
       https://docs.docker.com/get-docker/
       Then run this script again."
fi

if ! docker info >/dev/null 2>&1; then
  fail "Docker daemon is not running.
       • macOS: Launch Docker Desktop and wait for it to say 'Running'
       • Linux: Run 'sudo systemctl start docker'
       Then run this script again."
fi

ok "Docker is installed and running"

# ── Step 2: Detect hardware ────────────────────────────
detect_hardware

# ── Step 3: Select optimal models ──────────────────────
if [ "${SKIP_MODELS:-false}" != "true" ]; then
  select_models
fi

# ── Step 4: Check port availability ────────────────────
if lsof -i ":${WEBUI_PORT}" >/dev/null 2>&1 || ss -tlnp 2>/dev/null | grep -q ":${WEBUI_PORT} "; then
  warn "Port ${WEBUI_PORT} appears to be in use."
  warn "Set WEBUI_PORT=<number> to use a different port, or stop the conflicting service."
fi

# ── Step 5: Pull image ─────────────────────────────────
info "Pulling latest Open WebUI + Ollama image (this may take a few minutes first time)..."
docker pull "${IMAGE}"
ok "Image pulled successfully"

# ── Step 6: Stop existing container if present ─────────
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  info "Existing '${CONTAINER_NAME}' container found. Updating..."
  docker stop "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  docker rm "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  ok "Old container removed (data volumes preserved)"
fi

# ── Step 7: Start container ────────────────────────────
info "Starting AI server on port ${WEBUI_PORT}..."
docker run -d \
  -p "${WEBUI_PORT}:8080" \
  -v joes-ai-ollama:/root/.ollama \
  -v joes-ai-webui:/app/backend/data \
  --name "${CONTAINER_NAME}" \
  --restart unless-stopped \
  "${IMAGE}"

ok "Container started"

# ── Step 8: Wait for Ollama to be ready ────────────────
info "Waiting for Ollama to initialize..."
for i in $(seq 1 30); do
  if docker exec "${CONTAINER_NAME}" ollama list >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# ── Step 9: Download models ────────────────────────────
if [ "${SKIP_MODELS:-false}" != "true" ] && [ ${#MODELS_TO_PULL[@]} -gt 0 ]; then
  echo ""
  info "Downloading AI models (this will take a few minutes per model)..."
  echo ""

  DOWNLOAD_COUNT=0
  DOWNLOAD_TOTAL=${#MODELS_TO_PULL[@]}

  for model in "${MODELS_TO_PULL[@]}"; do
    DOWNLOAD_COUNT=$((DOWNLOAD_COUNT + 1))
    info "[${DOWNLOAD_COUNT}/${DOWNLOAD_TOTAL}] Downloading ${model}..."
    if docker exec "${CONTAINER_NAME}" ollama pull "${model}"; then
      ok "${model} downloaded successfully"
    else
      warn "${model} failed to download — you can pull it manually from the UI"
    fi
    echo ""
  done
fi

# ── Step 10: Wait for WebUI to be ready ────────────────
info "Waiting for Open WebUI to start..."
for i in $(seq 1 30); do
  if curl -sf "http://localhost:${WEBUI_PORT}" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# ── Step 11: List what's installed ─────────────────────
echo ""
info "Installed models:"
docker exec "${CONTAINER_NAME}" ollama list 2>/dev/null || true
echo ""

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
echo -e "${GREEN}║    docker logs ${CONTAINER_NAME}     (view logs)          ║${NC}"
echo -e "${GREEN}║    docker restart ${CONTAINER_NAME}  (restart)            ║${NC}"
echo -e "${GREEN}║    docker stop ${CONTAINER_NAME}     (stop server)        ║${NC}"
echo -e "${GREEN}║    docker exec ${CONTAINER_NAME} ollama pull <model>      ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  Support: joe@joestechsolutions.com                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
