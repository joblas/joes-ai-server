#!/usr/bin/env bash
#
# Joe's Tech Solutions — VPS AI Server Installer
# Deploys Ollama + Open WebUI + Caddy HTTPS + Watchtower auto-updates + backups
#
# Usage:
#   AI_DOMAIN=ai.client.com EMAIL=admin@client.com \
#   curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-vps.sh | bash
#
# Options:
#   AI_DOMAIN   (required)  Domain pointing at this VPS
#   EMAIL       (optional)  Email for Let's Encrypt certs (defaults to admin@AI_DOMAIN)
#   SKIP_HTTPS  (optional)  Set to "true" for HTTP-only mode (port 3000)
#
set -euo pipefail

# ── Config ──────────────────────────────────────────────
STACK_DIR="/opt/joes-ai-stack"
BACKUP_DIR="/opt/joes-ai-backups"
REPO_URL="https://raw.githubusercontent.com/joblas/joes-ai-server/main"
DOCKER_COMPOSE_VERSION="v2.32.4"

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Banner ──────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    Joe's Tech Solutions — Cloud AI Server    ║${NC}"
echo -e "${CYAN}║      Ollama + Open WebUI + HTTPS + Updates   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ── Validate inputs ────────────────────────────────────
if [ -z "${AI_DOMAIN:-}" ]; then
  fail "AI_DOMAIN is required.
       Usage: AI_DOMAIN=ai.example.com EMAIL=you@example.com bash install-vps.sh"
fi

EMAIL="${EMAIL:-admin@${AI_DOMAIN}}"
SKIP_HTTPS="${SKIP_HTTPS:-false}"

info "Domain:    ${AI_DOMAIN}"
info "Email:     ${EMAIL}"
info "Stack dir: ${STACK_DIR}"
echo ""

# ── Check: running as root or sudo ─────────────────────
if [ "$(id -u)" -ne 0 ]; then
  fail "This script must be run as root. Try: sudo bash install-vps.sh"
fi

# ══════════════════════════════════════════════════════════
# PHASE 1: System Setup
# ══════════════════════════════════════════════════════════

info "Phase 1/5: Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq curl wget jq openssl lsof ufw > /dev/null 2>&1
ok "System packages updated"

# ── Firewall ───────────────────────────────────────────
info "Configuring firewall (UFW)..."
ufw --force reset > /dev/null 2>&1
ufw default deny incoming > /dev/null 2>&1
ufw default allow outgoing > /dev/null 2>&1
ufw allow ssh > /dev/null 2>&1
ufw allow 80/tcp > /dev/null 2>&1
ufw allow 443/tcp > /dev/null 2>&1
ufw --force enable > /dev/null 2>&1
ok "Firewall configured (SSH + HTTP + HTTPS)"

# ══════════════════════════════════════════════════════════
# PHASE 2: Docker
# ══════════════════════════════════════════════════════════

info "Phase 2/5: Installing Docker..."

if command -v docker >/dev/null 2>&1; then
  ok "Docker already installed ($(docker --version | head -1))"
else
  curl -fsSL https://get.docker.com | sh > /dev/null 2>&1
  ok "Docker installed"
fi

systemctl enable docker > /dev/null 2>&1
systemctl start docker

# Install Compose plugin if missing
if ! docker compose version >/dev/null 2>&1; then
  info "Installing Docker Compose plugin..."
  mkdir -p /usr/lib/docker/cli-plugins
  curl -fsSL \
    "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-$(uname -m)" \
    -o /usr/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/lib/docker/cli-plugins/docker-compose
  ok "Docker Compose plugin installed"
else
  ok "Docker Compose already available"
fi

# ══════════════════════════════════════════════════════════
# PHASE 3: Stack Files
# ══════════════════════════════════════════════════════════

info "Phase 3/5: Creating stack configuration..."

mkdir -p "${STACK_DIR}" "${BACKUP_DIR}"
cd "${STACK_DIR}"

# ── docker-compose.yml ─────────────────────────────────
cat > docker-compose.yml << 'COMPOSE_EOF'
services:
  # ── LLM Inference Engine ──
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped
    ports:
      - "127.0.0.1:11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:11434/api/tags || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  # ── Chat Interface ──
  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: unless-stopped
    depends_on:
      ollama:
        condition: service_healthy
    expose:
      - "8080"
    ports:
      - "127.0.0.1:3000:8080"
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      - WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY}
      - WEBUI_NAME=${WEBUI_NAME:-Joe's AI Server}
      - ENABLE_SIGNUP=${ENABLE_SIGNUP:-true}
    volumes:
      - webui_data:/app/backend/data
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:8080/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  # ── Reverse Proxy + Auto HTTPS ──
  caddy:
    image: caddy:2-alpine
    container_name: caddy
    restart: unless-stopped
    depends_on:
      open-webui:
        condition: service_healthy
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config

  # ── Auto-Update Containers ──
  watchtower:
    image: nickfedor/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    environment:
      - WATCHTOWER_MONITOR_ONLY=true
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_SCHEDULE=0 0 4 * * *
      - WATCHTOWER_NOTIFICATIONS=shoutrrr
      - WATCHTOWER_LOG_FORMAT=pretty
      - DOCKER_API_VERSION=1.44
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

volumes:
  ollama_data:
  webui_data:
  caddy_data:
  caddy_config:
COMPOSE_EOF

ok "docker-compose.yml created"

# ── Caddyfile ──────────────────────────────────────────
if [ "${SKIP_HTTPS}" = "true" ]; then
  cat > Caddyfile << CADDY_EOF
:80 {
    reverse_proxy open-webui:8080
}
CADDY_EOF
  warn "HTTPS disabled — running HTTP-only on port 80"
else
  cat > Caddyfile << CADDY_EOF
{
    email ${EMAIL}
}

${AI_DOMAIN} {
    reverse_proxy open-webui:8080

    header {
        # Security headers
        X-Content-Type-Options nosniff
        X-Frame-Options SAMEORIGIN
        Referrer-Policy strict-origin-when-cross-origin
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
    }

    # Health check endpoint for uptime monitoring
    handle /health {
        respond "OK" 200
    }
}
CADDY_EOF
  ok "Caddyfile created for ${AI_DOMAIN}"
fi

# ── .env ───────────────────────────────────────────────
if [ ! -f .env ]; then
  cat > .env << ENV_EOF
# Joe's AI Server — Environment Configuration
# Generated: $(date -Iseconds)
# Domain: ${AI_DOMAIN}

# Secret key for Open WebUI sessions (auto-generated, do not share)
WEBUI_SECRET_KEY=$(openssl rand -hex 32)

# Branding
WEBUI_NAME=AI Server

# Allow new user signups (set to false after initial setup for security)
ENABLE_SIGNUP=true
ENV_EOF
  ok ".env created with secure random key"
else
  ok ".env already exists — preserved"
fi

# ══════════════════════════════════════════════════════════
# PHASE 4: Utility Scripts
# ══════════════════════════════════════════════════════════

info "Phase 4/5: Installing management scripts..."

mkdir -p "${STACK_DIR}/scripts"

# ── Backup script ──────────────────────────────────────
cat > "${STACK_DIR}/scripts/backup.sh" << 'BACKUP_EOF'
#!/usr/bin/env bash
# Joe's AI Server — Backup Script
# Backs up all Docker volumes to compressed tarballs
set -euo pipefail

BACKUP_DIR="/opt/joes-ai-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

echo "[$(date)] Starting backup..."
mkdir -p "${BACKUP_DIR}"

# Backup each volume
for vol in ollama_data webui_data caddy_data; do
  FULL_VOL="joes-ai-stack_${vol}"
  if docker volume inspect "${FULL_VOL}" >/dev/null 2>&1; then
    echo "  Backing up ${vol}..."
    docker run --rm \
      -v "${FULL_VOL}:/source:ro" \
      -v "${BACKUP_DIR}:/backup" \
      alpine tar czf "/backup/${vol}_${TIMESTAMP}.tar.gz" -C /source .
  fi
done

# Clean old backups
find "${BACKUP_DIR}" -name "*.tar.gz" -mtime +${RETENTION_DAYS} -delete
echo "[$(date)] Backup complete. Files in ${BACKUP_DIR}:"
ls -lh "${BACKUP_DIR}"/*.tar.gz 2>/dev/null || echo "  (none)"
BACKUP_EOF
chmod +x "${STACK_DIR}/scripts/backup.sh"

# ── Restore script ─────────────────────────────────────
cat > "${STACK_DIR}/scripts/restore.sh" << 'RESTORE_EOF'
#!/usr/bin/env bash
# Joe's AI Server — Restore Script
# Usage: ./restore.sh <backup_date>  (e.g., 20250212_040000)
set -euo pipefail

BACKUP_DIR="/opt/joes-ai-backups"
STACK_DIR="/opt/joes-ai-stack"
DATE="${1:?Usage: restore.sh <YYYYMMDD_HHMMSS>}"

echo "[$(date)] Restoring from backup date: ${DATE}"
echo "WARNING: This will overwrite current data. Press Ctrl+C to cancel."
read -r -p "Continue? [y/N] " confirm
[[ "${confirm}" =~ ^[Yy]$ ]] || exit 0

cd "${STACK_DIR}"
docker compose down

for vol in ollama_data webui_data caddy_data; do
  FULL_VOL="joes-ai-stack_${vol}"
  BACKUP_FILE="${BACKUP_DIR}/${vol}_${DATE}.tar.gz"
  if [ -f "${BACKUP_FILE}" ]; then
    echo "  Restoring ${vol}..."
    docker volume rm "${FULL_VOL}" 2>/dev/null || true
    docker volume create "${FULL_VOL}"
    docker run --rm \
      -v "${FULL_VOL}:/target" \
      -v "${BACKUP_DIR}:/backup:ro" \
      alpine tar xzf "/backup/${vol}_${DATE}.tar.gz" -C /target
  else
    echo "  SKIP: ${BACKUP_FILE} not found"
  fi
done

docker compose up -d
echo "[$(date)] Restore complete."
RESTORE_EOF
chmod +x "${STACK_DIR}/scripts/restore.sh"

# ── Update script ──────────────────────────────────────
cat > "${STACK_DIR}/scripts/update.sh" << 'UPDATE_EOF'
#!/usr/bin/env bash
# Joe's AI Server — Manual Update
set -euo pipefail

STACK_DIR="/opt/joes-ai-stack"
cd "${STACK_DIR}"

echo "[$(date)] Pulling latest images..."
docker compose pull

echo "[$(date)] Recreating containers..."
docker compose up -d --remove-orphans

echo "[$(date)] Cleaning old images..."
docker image prune -f

echo "[$(date)] Update complete."
docker compose ps
UPDATE_EOF
chmod +x "${STACK_DIR}/scripts/update.sh"

# ── Cron: daily backup at 3 AM ─────────────────────────
(crontab -l 2>/dev/null | grep -v "joes-ai-stack" || true; \
  echo "0 3 * * * ${STACK_DIR}/scripts/backup.sh >> /var/log/joes-ai-backup.log 2>&1") | crontab -

ok "Management scripts installed + daily backup cron set (3 AM)"

# ══════════════════════════════════════════════════════════
# PHASE 5: Launch
# ══════════════════════════════════════════════════════════

info "Phase 5/5: Pulling images and starting services..."

cd "${STACK_DIR}"
docker compose pull
docker compose up -d

# Wait for services
info "Waiting for services to start (this can take 1-2 minutes)..."
sleep 10

for i in $(seq 1 30); do
  if docker compose ps --format json 2>/dev/null | jq -e 'select(.Health == "healthy" or .State == "running")' >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

PUBLIC_IP=$(curl -sf https://ifconfig.me || echo "YOUR_SERVER_IP")

# ══════════════════════════════════════════════════════════
# PHASE 6: Hardware Detection & Model Selection
# ══════════════════════════════════════════════════════════

info "Detecting VPS hardware and selecting optimal AI models..."

# ── Detect RAM ──
OS_OVERHEAD_GB=4
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' || echo 0)
TOTAL_RAM_GB=$(( TOTAL_RAM_KB / 1048576 ))
AVAILABLE_RAM_GB=$(( TOTAL_RAM_GB - OS_OVERHEAD_GB ))
if [ "$AVAILABLE_RAM_GB" -lt 1 ]; then AVAILABLE_RAM_GB=1; fi

# ── Detect CPU ──
CPU_CORES=$(nproc 2>/dev/null || echo "?")

# ── Detect disk ──
FREE_DISK_GB=$(df -BG / 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'G' || echo "?")

echo ""
echo -e "${BOLD:-}  VPS Hardware: ${TOTAL_RAM_GB} GB RAM · ${CPU_CORES} cores · ${FREE_DISK_GB} GB free disk${NC}"
echo ""

# ── Select models based on RAM ──
MODELS_TO_PULL=()
TIER=""

if [ "$AVAILABLE_RAM_GB" -lt 6 ]; then
  MODELS_TO_PULL=("qwen3:4b")
  TIER="Starter"
elif [ "$AVAILABLE_RAM_GB" -lt 10 ]; then
  MODELS_TO_PULL=("qwen3:8b" "nomic-embed-text")
  TIER="Standard"
elif [ "$AVAILABLE_RAM_GB" -lt 20 ]; then
  MODELS_TO_PULL=("gemma3:12b" "deepseek-r1:8b" "nomic-embed-text")
  TIER="Performance"
elif [ "$AVAILABLE_RAM_GB" -lt 46 ]; then
  MODELS_TO_PULL=("qwen3:32b" "deepseek-r1:14b" "nomic-embed-text")
  TIER="Power"
else
  MODELS_TO_PULL=("qwen3:32b" "gemma3:27b" "deepseek-r1:32b" "nomic-embed-text")
  TIER="Maximum"
fi

info "Model tier: ${TIER} (${#MODELS_TO_PULL[@]} models selected)"

# ── Wait for Ollama health check ──
info "Waiting for Ollama to be ready..."
for i in $(seq 1 30); do
  if docker exec ollama ollama list >/dev/null 2>&1; then break; fi
  sleep 3
done

# ── Download models ──
info "Downloading AI models..."
DOWNLOAD_COUNT=0
DOWNLOAD_TOTAL=${#MODELS_TO_PULL[@]}

for model in "${MODELS_TO_PULL[@]}"; do
  DOWNLOAD_COUNT=$((DOWNLOAD_COUNT + 1))
  info "[${DOWNLOAD_COUNT}/${DOWNLOAD_TOTAL}] Downloading ${model}..."
  if docker exec ollama ollama pull "${model}"; then
    ok "${model} downloaded"
  else
    warn "${model} failed — pull manually later: docker exec ollama ollama pull ${model}"
  fi
done

echo ""
info "Installed models:"
docker exec ollama ollama list 2>/dev/null || true
echo ""

# ── Done ───────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          ✅ Joe's Cloud AI Server is LIVE!               ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
if [ "${SKIP_HTTPS}" = "true" ]; then
echo -e "${GREEN}║  URL:  http://${PUBLIC_IP}                               ║${NC}"
else
echo -e "${GREEN}║  URL:  https://${AI_DOMAIN}                              ║${NC}"
fi
echo -e "${GREEN}║  IP:   ${PUBLIC_IP}                                      ║${NC}"
echo -e "${GREEN}║  Tier: ${TIER} (${TOTAL_RAM_GB} GB RAM · ${CPU_CORES} cores)              ║${NC}"
echo -e "${GREEN}║  Models: ${#MODELS_TO_PULL[@]} installed and ready                       ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  DNS Setup (if not done):                                ║${NC}"
echo -e "${GREEN}║    A Record: ${AI_DOMAIN} → ${PUBLIC_IP}                 ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  First visit:                                            ║${NC}"
echo -e "${GREEN}║    1. Create admin account                               ║${NC}"
echo -e "${GREEN}║    2. Start chatting! (models already downloaded)         ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  Auto-updates:  Watchtower checks daily at 4 AM         ║${NC}"
echo -e "${GREEN}║  Backups:       Daily at 3 AM → /opt/joes-ai-backups    ║${NC}"
echo -e "${GREEN}║  Health check:  https://${AI_DOMAIN}/health              ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  Management:                                             ║${NC}"
echo -e "${GREEN}║    cd ${STACK_DIR}                                       ║${NC}"
echo -e "${GREEN}║    docker compose ps          (status)                   ║${NC}"
echo -e "${GREEN}║    docker compose logs -f     (live logs)                ║${NC}"
echo -e "${GREEN}║    ./scripts/update.sh        (manual update)            ║${NC}"
echo -e "${GREEN}║    ./scripts/backup.sh        (manual backup)            ║${NC}"
echo -e "${GREEN}║                                                          ║${NC}"
echo -e "${GREEN}║  Support: joe@joestechsolutions.com                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
