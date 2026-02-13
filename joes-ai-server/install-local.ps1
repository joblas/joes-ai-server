#
# Joe's Tech Solutions — Local AI Server Installer (Windows)
# Installs Ollama + Open WebUI on a Windows machine via Docker Desktop
#
# Usage (run in PowerShell as Administrator):
#   irm https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.ps1 | iex
#
# Or download and run:
#   .\install-local.ps1
#
# Options:
#   $env:WEBUI_PORT = "3000"         Change the port
#   $env:PULL_MODEL = "llama3.2"     Auto-download a model after install
#

$ErrorActionPreference = "Stop"

# ── Config ──────────────────────────────────────────────
$WebuiPort = if ($env:WEBUI_PORT) { $env:WEBUI_PORT } else { "3000" }
$ContainerName = "joes-ai-local"
$Image = "ghcr.io/open-webui/open-webui:ollama"

# ── Helpers ─────────────────────────────────────────────
function Write-Info  { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Fail  { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }

# ── Banner ──────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Joe's Tech Solutions — Local AI Server   ║" -ForegroundColor Cyan
Write-Host "║       Private ChatGPT Alternative            ║" -ForegroundColor Cyan
Write-Host "║              Windows Edition                 ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── Step 1: Check Docker ───────────────────────────────
Write-Info "Checking Docker installation..."

$dockerPath = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerPath) {
    Write-Fail @"
Docker is not installed.

Please install Docker Desktop for Windows:
  https://docs.docker.com/desktop/install/windows-install/

After installing:
  1. Restart your computer
  2. Launch Docker Desktop
  3. Wait for it to say 'Running' (green icon in system tray)
  4. Run this script again
"@
}

# Check if daemon is running
try {
    $null = docker info 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Docker not running" }
    Write-Ok "Docker is installed and running"
}
catch {
    Write-Fail @"
Docker Desktop is installed but not running.

Please:
  1. Launch Docker Desktop from the Start menu
  2. Wait for the whale icon in the system tray to stop animating
  3. Run this script again
"@
}

# ── Step 2: Check WSL2 (common Windows issue) ──────────
Write-Info "Checking WSL2 status..."
$wslStatus = wsl --status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warn "WSL2 may not be properly configured. If Docker has issues, run:"
    Write-Warn "  wsl --install"
    Write-Warn "  (then restart your computer)"
}
else {
    Write-Ok "WSL2 is available"
}

# ── Step 3: Pull image ─────────────────────────────────
Write-Info "Pulling latest Open WebUI + Ollama image (this may take a few minutes first time)..."
docker pull $Image
if ($LASTEXITCODE -ne 0) { Write-Fail "Failed to pull image. Check your internet connection." }
Write-Ok "Image pulled successfully"

# ── Step 4: Stop existing container if present ─────────
$existing = docker ps -a --format '{{.Names}}' | Where-Object { $_ -eq $ContainerName }
if ($existing) {
    Write-Info "Existing '$ContainerName' container found. Updating..."
    docker stop $ContainerName 2>$null | Out-Null
    docker rm $ContainerName 2>$null | Out-Null
    Write-Ok "Old container removed (data volumes preserved)"
}

# ── Step 5: Start container ────────────────────────────
Write-Info "Starting AI server on port $WebuiPort..."
docker run -d `
    -p "${WebuiPort}:8080" `
    -v joes-ai-ollama:/root/.ollama `
    -v joes-ai-webui:/app/backend/data `
    --name $ContainerName `
    --restart unless-stopped `
    $Image

if ($LASTEXITCODE -ne 0) { Write-Fail "Failed to start container." }
Write-Ok "Container started"

# ── Step 6: Auto-pull model if requested ───────────────
if ($env:PULL_MODEL) {
    Write-Info "Downloading model '$($env:PULL_MODEL)' (this can take several minutes)..."
    Start-Sleep -Seconds 8
    docker exec $ContainerName ollama pull $env:PULL_MODEL
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "Model '$($env:PULL_MODEL)' downloaded"
    }
    else {
        Write-Warn "Model pull failed — you can pull it manually from the UI"
    }
}

# ── Step 7: Wait for WebUI to be ready ─────────────────
Write-Info "Waiting for Open WebUI to start..."
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$WebuiPort" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) { $ready = $true; break }
    }
    catch { }
    Start-Sleep -Seconds 2
}

# ── Step 8: Open browser ──────────────────────────────
$url = "http://localhost:$WebuiPort"
if ($ready) {
    Write-Info "Opening browser..."
    Start-Process $url
}

# ── Done ───────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          ✅ Joe's Local AI Server is LIVE!           ║" -ForegroundColor Green
Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Green
Write-Host "║                                                      ║" -ForegroundColor Green
Write-Host "║  Open your browser:  $url              ║" -ForegroundColor Green
Write-Host "║                                                      ║" -ForegroundColor Green
Write-Host "║  First visit:                                        ║" -ForegroundColor Green
Write-Host "║    1. Create your admin account                      ║" -ForegroundColor Green
Write-Host "║    2. Go to Settings → Models → Pull a model         ║" -ForegroundColor Green
Write-Host "║       (try: llama3.2, mistral, or phi3)              ║" -ForegroundColor Green
Write-Host "║    3. Start chatting!                                 ║" -ForegroundColor Green
Write-Host "║                                                      ║" -ForegroundColor Green
Write-Host "║  Commands (run in PowerShell):                       ║" -ForegroundColor Green
Write-Host "║    docker logs $ContainerName          (view logs)   ║" -ForegroundColor Green
Write-Host "║    docker restart $ContainerName       (restart)     ║" -ForegroundColor Green
Write-Host "║    docker stop $ContainerName          (stop)        ║" -ForegroundColor Green
Write-Host "║                                                      ║" -ForegroundColor Green
Write-Host "║  Support: joe@joestechsolutions.com                  ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
