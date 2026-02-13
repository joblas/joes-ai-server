#
# Joe's Tech Solutions — Local AI Server Installer (Windows)
# Auto-detects hardware and installs optimal AI models
#
# Usage (run in PowerShell):
#   irm https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.ps1 | iex
#
# Options:
#   $env:WEBUI_PORT  = "3000"       Change the port
#   $env:PULL_MODEL  = "llama3.2"   Override auto-detected model
#   $env:SKIP_MODELS = "true"       Skip model downloads
#

$ErrorActionPreference = "Stop"

# ── Config ──────────────────────────────────────────────
$WebuiPort = if ($env:WEBUI_PORT) { $env:WEBUI_PORT } else { "3000" }
$ContainerName = "joes-ai-local"
$Image = "ghcr.io/open-webui/open-webui:ollama"
$OsOverheadGB = 4

# ── Banner ──────────────────────────────────────────────
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "     Joe's Tech Solutions - Local AI Server        " -ForegroundColor Cyan
Write-Host "         Private ChatGPT Alternative               " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# ═══════════════════════════════════════════════════════════
# HARDWARE DETECTION
# ═══════════════════════════════════════════════════════════

function Get-HardwareInfo {
    Write-Host "[INFO]  Scanning hardware..." -ForegroundColor Cyan

    # ── RAM ──
    $computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem
    $script:TotalRamGB = [math]::Floor($computerInfo.TotalPhysicalMemory / 1GB)
    $script:AvailableRamGB = $script:TotalRamGB - $OsOverheadGB
    if ($script:AvailableRamGB -lt 1) { $script:AvailableRamGB = 1 }

    # ── CPU ──
    $cpu = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $script:CpuCores = $cpu.NumberOfLogicalProcessors
    $script:CpuName = $cpu.Name.Trim()

    # ── GPU (NVIDIA check) ──
    $script:GpuType = "none"
    $script:GpuName = "None detected (CPU only)"
    $script:GpuVramGB = 0

    try {
        $nvidiaSmi = nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>$null
        if ($LASTEXITCODE -eq 0 -and $nvidiaSmi) {
            $parts = $nvidiaSmi.Split(',')
            $script:GpuName = $parts[0].Trim()
            $script:GpuVramGB = [math]::Floor([int]$parts[1].Trim() / 1024)
            $script:GpuType = "nvidia"
        }
    }
    catch { }

    # If no NVIDIA, check for any GPU
    if ($script:GpuType -eq "none") {
        $gpu = Get-CimInstance -ClassName Win32_VideoController | Where-Object { $_.AdapterRAM -gt 0 } | Select-Object -First 1
        if ($gpu) {
            $script:GpuName = $gpu.Name
            $adapterRam = $gpu.AdapterRAM
            if ($adapterRam -gt 0) {
                $script:GpuVramGB = [math]::Floor($adapterRam / 1GB)
            }
            if ($gpu.Name -match "NVIDIA") {
                $script:GpuType = "nvidia"
            }
            elseif ($gpu.Name -match "AMD|Radeon") {
                $script:GpuType = "amd"
            }
            else {
                $script:GpuType = "integrated"
            }
        }
    }

    # ── Disk ──
    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'"
    $script:FreeDiskGB = [math]::Floor($disk.FreeSpace / 1GB)

    # ── Print hardware report ──
    Write-Host ""
    Write-Host "  +-----------------------------------------+" -ForegroundColor White
    Write-Host "  |         HARDWARE DETECTED                |" -ForegroundColor White
    Write-Host "  +-----------------------------------------+" -ForegroundColor White
    Write-Host "  |  RAM:       $($script:TotalRamGB) GB total ($($script:AvailableRamGB) GB available for AI)" -ForegroundColor Green
    Write-Host "  |  CPU:       $($script:CpuName)" -ForegroundColor Green
    Write-Host "  |  Cores:     $($script:CpuCores)" -ForegroundColor Green
    Write-Host "  |  GPU:       $($script:GpuName)" -ForegroundColor Green
    if ($script:GpuType -eq "nvidia" -and $script:GpuVramGB -gt 0) {
        Write-Host "  |  VRAM:      $($script:GpuVramGB) GB" -ForegroundColor Green
    }
    Write-Host "  |  Free Disk: $($script:FreeDiskGB) GB" -ForegroundColor Green
    Write-Host "  +-----------------------------------------+" -ForegroundColor White
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════
# MODEL SELECTION ENGINE
# ═══════════════════════════════════════════════════════════

function Select-Models {
    $script:ModelsToPull = @()
    $script:ModelsDescription = @()
    $script:Tier = "Custom"

    # If user manually specified a model, use that
    if ($env:PULL_MODEL) {
        $script:ModelsToPull += $env:PULL_MODEL
        $script:ModelsDescription += "$($env:PULL_MODEL) (user selected)"
        $script:Tier = "Custom"
        return
    }

    # Use GPU VRAM as primary if NVIDIA, otherwise system RAM
    if ($script:GpuType -eq "nvidia" -and $script:GpuVramGB -gt 0) {
        $computeRam = $script:GpuVramGB
        $ramSource = "GPU VRAM"
    }
    else {
        $computeRam = $script:AvailableRamGB
        $ramSource = "System RAM"
    }

    Write-Host "[INFO]  Selecting optimal models based on ${ramSource}: ${computeRam} GB available..." -ForegroundColor Cyan

    # ── Tier 1: Minimal (< 6 GB) ──
    if ($computeRam -lt 6) {
        $script:ModelsToPull += "qwen3:4b"
        $script:ModelsDescription += "qwen3:4b     (2.6 GB) - Rivals 72B quality"
        $script:Tier = "Starter"
    }
    # ── Tier 2: Light (6-9 GB) ──
    elseif ($computeRam -lt 10) {
        $script:ModelsToPull += "qwen3:8b"
        $script:ModelsToPull += "nomic-embed-text"
        $script:ModelsDescription += "qwen3:8b     (5.2 GB) - Sweet spot, 40+ tok/s"
        $script:ModelsDescription += "nomic-embed  (0.3 GB) - Document search (RAG)"
        $script:Tier = "Standard"
    }
    # ── Tier 3: Capable (10-19 GB) ──
    elseif ($computeRam -lt 20) {
        $script:ModelsToPull += "gemma3:12b"
        $script:ModelsToPull += "deepseek-r1:8b"
        $script:ModelsToPull += "nomic-embed-text"
        $script:ModelsDescription += "gemma3:12b     (8.1 GB) - Google multimodal"
        $script:ModelsDescription += "deepseek-r1:8b (4.9 GB) - Advanced coding + math"
        $script:ModelsDescription += "nomic-embed    (0.3 GB) - Document search (RAG)"
        $script:Tier = "Performance"
    }
    # ── Tier 4: Strong (20-45 GB) ──
    elseif ($computeRam -lt 46) {
        $script:ModelsToPull += "qwen3:32b"
        $script:ModelsToPull += "deepseek-r1:14b"
        $script:ModelsToPull += "nomic-embed-text"
        $script:ModelsDescription += "qwen3:32b       (20 GB) - Near-frontier quality"
        $script:ModelsDescription += "deepseek-r1:14b (9.0 GB) - Advanced reasoning"
        $script:ModelsDescription += "nomic-embed     (0.3 GB) - Document search (RAG)"
        $script:Tier = "Power"
    }
    # ── Tier 5: Beast (46+ GB) ──
    else {
        $script:ModelsToPull += "qwen3:32b"
        $script:ModelsToPull += "gemma3:27b"
        $script:ModelsToPull += "deepseek-r1:32b"
        $script:ModelsToPull += "nomic-embed-text"
        $script:ModelsDescription += "qwen3:32b       (20 GB) - Flagship, rivals GPT-4"
        $script:ModelsDescription += "gemma3:27b      (17 GB) - Google flagship"
        $script:ModelsDescription += "deepseek-r1:32b (20 GB) - Top-tier reasoning"
        $script:ModelsDescription += "nomic-embed     (0.3 GB) - Document search (RAG)"
        $script:Tier = "Maximum"
    }

    # ── Print selection ──
    Write-Host ""
    Write-Host "  +-----------------------------------------------------+" -ForegroundColor White
    Write-Host "  |  AI MODEL PLAN - $($script:Tier) Tier" -ForegroundColor White
    Write-Host "  +-----------------------------------------------------+" -ForegroundColor White
    foreach ($desc in $script:ModelsDescription) {
        Write-Host "  |  * $desc" -ForegroundColor Green
    }
    Write-Host "  +-----------------------------------------------------+" -ForegroundColor White
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════
# MAIN INSTALLATION
# ═══════════════════════════════════════════════════════════

# ── Step 1: Check Docker ───────────────────────────────
Write-Host "[INFO]  Checking Docker installation..." -ForegroundColor Cyan

try {
    $dockerVersion = docker version --format '{{.Server.Version}}' 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Docker not responding" }
    Write-Host "[OK]    Docker is running (v$dockerVersion)" -ForegroundColor Green
}
catch {
    $dockerPath = Get-Command docker -ErrorAction SilentlyContinue
    if ($dockerPath) {
        Write-Host "[ERROR] Docker is installed but not running." -ForegroundColor Red
        Write-Host "        Please launch Docker Desktop and wait for it to say 'Running'." -ForegroundColor Red
    }
    else {
        Write-Host "[ERROR] Docker Desktop is not installed." -ForegroundColor Red
        Write-Host "        Download it from: https://docs.docker.com/get-docker/" -ForegroundColor Red
    }
    Write-Host "        Then run this script again." -ForegroundColor Red
    exit 1
}

# ── Step 2: Detect hardware ────────────────────────────
Get-HardwareInfo

# ── Step 3: Select optimal models ──────────────────────
if ($env:SKIP_MODELS -ne "true") {
    Select-Models
}

# ── Step 4: Pull image ─────────────────────────────────
Write-Host "[INFO]  Pulling latest Open WebUI + Ollama image..." -ForegroundColor Cyan
Write-Host "        (This may take a few minutes on first run)" -ForegroundColor Cyan
docker pull $Image
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to pull image. Check your internet connection." -ForegroundColor Red
    exit 1
}
Write-Host "[OK]    Image pulled successfully" -ForegroundColor Green

# ── Step 5: Stop existing container if present ─────────
$existing = docker ps -a --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $ContainerName }
if ($existing) {
    Write-Host "[INFO]  Existing '$ContainerName' container found. Updating..." -ForegroundColor Cyan
    docker stop $ContainerName 2>$null | Out-Null
    docker rm $ContainerName 2>$null | Out-Null
    Write-Host "[OK]    Old container removed (data volumes preserved)" -ForegroundColor Green
}

# ── Step 6: Start container ────────────────────────────
Write-Host "[INFO]  Starting AI server on port $WebuiPort..." -ForegroundColor Cyan
docker run -d `
    -p "${WebuiPort}:8080" `
    -v joes-ai-ollama:/root/.ollama `
    -v joes-ai-webui:/app/backend/data `
    --name $ContainerName `
    --restart unless-stopped `
    $Image

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to start container." -ForegroundColor Red
    Write-Host "        Check if port $WebuiPort is already in use." -ForegroundColor Red
    exit 1
}
Write-Host "[OK]    Container started" -ForegroundColor Green

# ── Step 7: Wait for Ollama to be ready ────────────────
Write-Host "[INFO]  Waiting for Ollama to initialize..." -ForegroundColor Cyan
Start-Sleep -Seconds 8

for ($i = 0; $i -lt 20; $i++) {
    try {
        docker exec $ContainerName ollama list 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { break }
    }
    catch { }
    Start-Sleep -Seconds 3
}

# ── Step 8: Download models ────────────────────────────
if ($env:SKIP_MODELS -ne "true" -and $script:ModelsToPull.Count -gt 0) {
    Write-Host ""
    Write-Host "[INFO]  Downloading AI models (this will take a few minutes per model)..." -ForegroundColor Cyan
    Write-Host ""

    $downloadCount = 0
    $downloadTotal = $script:ModelsToPull.Count

    foreach ($model in $script:ModelsToPull) {
        $downloadCount++
        Write-Host "[INFO]  [$downloadCount/$downloadTotal] Downloading $model..." -ForegroundColor Cyan
        docker exec $ContainerName ollama pull $model
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK]    $model downloaded successfully" -ForegroundColor Green
        }
        else {
            Write-Host "[WARN]  $model failed - you can pull it manually from the UI" -ForegroundColor Yellow
        }
        Write-Host ""
    }
}

# ── Step 9: Wait for WebUI ─────────────────────────────
Write-Host "[INFO]  Waiting for Open WebUI to start..." -ForegroundColor Cyan
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$WebuiPort" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) { $ready = $true; break }
    }
    catch { }
    Start-Sleep -Seconds 2
}

# ── Step 10: Show installed models ─────────────────────
Write-Host ""
Write-Host "[INFO]  Installed models:" -ForegroundColor Cyan
docker exec $ContainerName ollama list 2>$null
Write-Host ""

# ── Done ───────────────────────────────────────────────
Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "     Joe's Local AI Server is LIVE!                " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  URL:       http://localhost:$WebuiPort" -ForegroundColor Green
Write-Host "  Hardware:  $($script:TotalRamGB) GB RAM | $($script:CpuCores) cores | $($script:GpuType) GPU" -ForegroundColor Green
Write-Host "  Tier:      $($script:Tier)" -ForegroundColor Green
Write-Host "  Models:    $($script:ModelsToPull.Count) installed and ready" -ForegroundColor Green
Write-Host ""
Write-Host "  First visit: Create your admin account, then chat!" -ForegroundColor Green
Write-Host ""
Write-Host "  Commands (PowerShell):" -ForegroundColor Green
Write-Host "    docker logs $ContainerName     (view logs)" -ForegroundColor Green
Write-Host "    docker restart $ContainerName  (restart)" -ForegroundColor Green
Write-Host "    docker stop $ContainerName     (stop server)" -ForegroundColor Green
Write-Host "    docker exec $ContainerName ollama pull <model>" -ForegroundColor Green
Write-Host ""
Write-Host "  Support: joe@joestechsolutions.com" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""

# Auto-open browser
if ($ready) {
    Start-Process "http://localhost:$WebuiPort"
}
