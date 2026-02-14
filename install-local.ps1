#
# Joe's Tech Solutions — Local AI Server Installer (Windows)
# NATIVE install — no Docker required
# Auto-detects hardware and installs optimal AI models
#
# Usage (run in PowerShell as Administrator):
#   irm https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.ps1 | iex
#
# Options:
#   $env:WEBUI_PORT  = "3000"       Change the port
#   $env:PULL_MODEL  = "llama3.2"   Override auto-detected model
#   $env:SKIP_MODELS = "true"       Skip model downloads
#   $env:VERTICAL    = "healthcare" Create industry-specific AI assistant
#                                   Options: healthcare, legal, financial, realestate,
#                                   therapy, education, construction, creative, smallbusiness
#

$ErrorActionPreference = "Stop"

# ── Config ──────────────────────────────────────────────
$WebuiPort = if ($env:WEBUI_PORT) { $env:WEBUI_PORT } else { "3000" }
$OsOverheadGB = 4
$JoesAiDir = Join-Path $env:USERPROFILE ".joes-ai"
$VenvDir = Join-Path $JoesAiDir "venv"
$DataDir = Join-Path $JoesAiDir "data"
$LogDir = Join-Path $JoesAiDir "logs"

# ── Banner ──────────────────────────────────────────────
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "     Joe's Tech Solutions - Local AI Server        " -ForegroundColor Cyan
Write-Host "         Private ChatGPT Alternative               " -ForegroundColor Cyan
Write-Host "            (Native Install)                       " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# ═══════════════════════════════════════════════════════════
# STEP 1: PREREQUISITES
# ═══════════════════════════════════════════════════════════

Write-Host "[INFO]  Checking prerequisites..." -ForegroundColor Cyan

# ── Check for Python 3.11+ ──
$pythonCmd = $null
$pythonVersion = $null

# Try python3 first, then python
foreach ($cmd in @("python3", "python")) {
    try {
        $ver = & $cmd --version 2>&1
        if ($ver -match "Python (\d+)\.(\d+)") {
            $major = [int]$Matches[1]
            $minor = [int]$Matches[2]
            if ($major -eq 3 -and $minor -ge 11 -and $minor -lt 13) {
                $pythonCmd = $cmd
                $pythonVersion = "$major.$minor"
                break
            }
        }
    }
    catch { }
}

if (-not $pythonCmd) {
    Write-Host "[INFO]  Python 3.11+ not found. Installing Python 3.12 via winget..." -ForegroundColor Cyan
    try {
        winget install Python.Python.3.12 --accept-package-agreements --accept-source-agreements --silent
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        Start-Sleep -Seconds 3

        # Find the newly installed Python
        foreach ($cmd in @("python3", "python")) {
            try {
                $ver = & $cmd --version 2>&1
                if ($ver -match "Python (\d+)\.(\d+)") {
                    $major = [int]$Matches[1]
                    $minor = [int]$Matches[2]
                    if ($major -eq 3 -and $minor -ge 11) {
                        $pythonCmd = $cmd
                        $pythonVersion = "$major.$minor"
                        break
                    }
                }
            }
            catch { }
        }

        if (-not $pythonCmd) {
            Write-Host "[ERROR] Python installation succeeded but could not find it in PATH." -ForegroundColor Red
            Write-Host "        Please restart PowerShell and run the installer again." -ForegroundColor Red
            exit 1
        }
        Write-Host "[OK]    Python $pythonVersion installed" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Could not install Python automatically." -ForegroundColor Red
        Write-Host "        Please install Python 3.11 or 3.12 from https://python.org and try again." -ForegroundColor Red
        Write-Host "        Make sure to check 'Add Python to PATH' during installation." -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "[OK]    Python $pythonVersion found ($pythonCmd)" -ForegroundColor Green
}

# ═══════════════════════════════════════════════════════════
# STEP 2: HARDWARE DETECTION
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
            if ($gpu.Name -match "NVIDIA") { $script:GpuType = "nvidia" }
            elseif ($gpu.Name -match "AMD|Radeon") { $script:GpuType = "amd" }
            else { $script:GpuType = "integrated" }
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
# STEP 3: MODEL SELECTION ENGINE
# ═══════════════════════════════════════════════════════════

function Select-Models {
    $script:ModelsToPull = @()
    $script:ModelsDescription = @()
    $script:Tier = "Custom"

    if ($env:PULL_MODEL) {
        $script:ModelsToPull += $env:PULL_MODEL
        $script:ModelsDescription += "$($env:PULL_MODEL) (user selected)"
        $script:Tier = "Custom"
        return
    }

    if ($script:GpuType -eq "nvidia" -and $script:GpuVramGB -gt 0) {
        $computeRam = $script:GpuVramGB
        $ramSource = "GPU VRAM"
    }
    else {
        $computeRam = $script:AvailableRamGB
        $ramSource = "System RAM"
    }

    Write-Host "[INFO]  Selecting optimal models based on ${ramSource}: ${computeRam} GB available..." -ForegroundColor Cyan

    if ($computeRam -lt 6) {
        $script:ModelsToPull += "qwen3:4b"
        $script:ModelsDescription += "qwen3:4b     (2.6 GB) - Rivals 72B quality"
        $script:Tier = "Starter"
    }
    elseif ($computeRam -lt 10) {
        $script:ModelsToPull += "qwen3:8b"
        $script:ModelsToPull += "nomic-embed-text"
        $script:ModelsDescription += "qwen3:8b     (5.2 GB) - Sweet spot, 40+ tok/s"
        $script:ModelsDescription += "nomic-embed  (0.3 GB) - Document search (RAG)"
        $script:Tier = "Standard"
    }
    elseif ($computeRam -lt 20) {
        $script:ModelsToPull += "gemma3:12b"
        $script:ModelsToPull += "deepseek-r1:8b"
        $script:ModelsToPull += "nomic-embed-text"
        $script:ModelsDescription += "gemma3:12b     (8.1 GB) - Google multimodal"
        $script:ModelsDescription += "deepseek-r1:8b (4.9 GB) - Advanced coding + math"
        $script:ModelsDescription += "nomic-embed    (0.3 GB) - Document search (RAG)"
        $script:Tier = "Performance"
    }
    elseif ($computeRam -lt 46) {
        $script:ModelsToPull += "qwen3:32b"
        $script:ModelsToPull += "deepseek-r1:14b"
        $script:ModelsToPull += "nomic-embed-text"
        $script:ModelsDescription += "qwen3:32b       (20 GB) - Near-frontier quality"
        $script:ModelsDescription += "deepseek-r1:14b (9.0 GB) - Advanced reasoning"
        $script:ModelsDescription += "nomic-embed     (0.3 GB) - Document search (RAG)"
        $script:Tier = "Power"
    }
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

# ── Step 1: Detect hardware ────────────────────────────
Get-HardwareInfo

# ── Step 2: Select optimal models ──────────────────────
if ($env:SKIP_MODELS -ne "true") {
    Select-Models
}

# ── Step 3: Install Ollama ─────────────────────────────
Write-Host "[INFO]  Checking Ollama installation..." -ForegroundColor Cyan

$ollamaCmd = Get-Command ollama -ErrorAction SilentlyContinue
if ($ollamaCmd) {
    $ollamaVer = ollama --version 2>&1
    Write-Host "[OK]    Ollama already installed: $ollamaVer" -ForegroundColor Green
}
else {
    Write-Host "[INFO]  Installing Ollama..." -ForegroundColor Cyan
    try {
        # Download and run the Ollama installer silently
        $ollamaInstaller = Join-Path $env:TEMP "OllamaSetup.exe"
        Invoke-WebRequest -Uri "https://ollama.com/download/OllamaSetup.exe" -OutFile $ollamaInstaller -UseBasicParsing
        Start-Process -FilePath $ollamaInstaller -ArgumentList "/SILENT" -Wait
        Remove-Item $ollamaInstaller -Force -ErrorAction SilentlyContinue

        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        Start-Sleep -Seconds 3

        if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
            # Common Ollama install paths
            $ollamaPaths = @(
                "$env:LOCALAPPDATA\Programs\Ollama",
                "$env:ProgramFiles\Ollama",
                "$env:ProgramFiles (x86)\Ollama"
            )
            foreach ($p in $ollamaPaths) {
                if (Test-Path (Join-Path $p "ollama.exe")) {
                    $env:PATH += ";$p"
                    break
                }
            }
        }

        Write-Host "[OK]    Ollama installed" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Failed to install Ollama automatically." -ForegroundColor Red
        Write-Host "        Please install manually from https://ollama.com/download and re-run this script." -ForegroundColor Red
        exit 1
    }
}

# ── Step 4: Ensure Ollama is running ───────────────────
Write-Host "[INFO]  Ensuring Ollama is running..." -ForegroundColor Cyan
$ollamaRunning = $false
for ($i = 0; $i -lt 5; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:11434/api/tags" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) { $ollamaRunning = $true; break }
    }
    catch { }
    Start-Sleep -Seconds 2
}

if (-not $ollamaRunning) {
    Write-Host "[INFO]  Starting Ollama service..." -ForegroundColor Cyan
    Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 5

    for ($i = 0; $i -lt 15; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:11434/api/tags" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) { $ollamaRunning = $true; break }
        }
        catch { }
        Start-Sleep -Seconds 2
    }
}

if ($ollamaRunning) {
    Write-Host "[OK]    Ollama is running on port 11434" -ForegroundColor Green
}
else {
    Write-Host "[WARN]  Ollama may not be running yet. Continuing anyway..." -ForegroundColor Yellow
}

# ── Step 5: Download AI models ─────────────────────────
if ($env:SKIP_MODELS -ne "true" -and $script:ModelsToPull.Count -gt 0) {
    Write-Host ""
    Write-Host "[INFO]  Downloading AI models (this will take a few minutes per model)..." -ForegroundColor Cyan
    Write-Host ""

    $downloadCount = 0
    $downloadTotal = $script:ModelsToPull.Count

    foreach ($model in $script:ModelsToPull) {
        $downloadCount++
        Write-Host "[INFO]  [$downloadCount/$downloadTotal] Downloading $model..." -ForegroundColor Cyan
        ollama pull $model
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK]    $model downloaded successfully" -ForegroundColor Green
        }
        else {
            Write-Host "[WARN]  $model failed - you can pull it manually later: ollama pull $model" -ForegroundColor Yellow
        }
        Write-Host ""
    }
}

# ── Step 6: Create vertical assistant (if specified) ───
if ($env:VERTICAL) {
    $vertical = $env:VERTICAL.ToLower()
    $repoRaw = "https://raw.githubusercontent.com/joblas/joes-ai-server/main"
    $promptUrl = "$repoRaw/verticals/prompts/$vertical.txt"
    $baseModel = $script:ModelsToPull[0]

    $assistantNames = @{
        "healthcare"    = "Healthcare-Assistant"
        "legal"         = "Legal-Assistant"
        "financial"     = "Financial-Assistant"
        "realestate"    = "RealEstate-Assistant"
        "therapy"       = "Clinical-Assistant"
        "education"     = "Learning-Assistant"
        "construction"  = "Construction-Assistant"
        "creative"      = "Creative-Assistant"
        "smallbusiness" = "Business-Assistant"
    }

    $assistantName = if ($assistantNames.ContainsKey($vertical)) { $assistantNames[$vertical] } else { "$vertical-Assistant" }

    Write-Host "[INFO]  Creating $assistantName from $baseModel..." -ForegroundColor Cyan

    try {
        $systemPrompt = (Invoke-WebRequest -Uri $promptUrl -UseBasicParsing -ErrorAction Stop).Content.Trim()

        $modelfilePath = Join-Path $env:TEMP "joes-ai-modelfile.txt"
        "FROM $baseModel`nSYSTEM `"$systemPrompt`"" | Out-File -FilePath $modelfilePath -Encoding utf8
        ollama create $assistantName -f $modelfilePath
        Remove-Item $modelfilePath -Force -ErrorAction SilentlyContinue

        Write-Host "[OK]    $assistantName created successfully!" -ForegroundColor Green
        Write-Host "[INFO]  Your client will see '$assistantName' in their model dropdown." -ForegroundColor Cyan
    }
    catch {
        Write-Host "[WARN]  Could not create $assistantName - client can still use $baseModel directly" -ForegroundColor Yellow
    }
    Write-Host ""
}

# ── Step 7: Install Open WebUI ─────────────────────────
Write-Host "[INFO]  Setting up Open WebUI..." -ForegroundColor Cyan

# Create directories
New-Item -ItemType Directory -Path $JoesAiDir -Force | Out-Null
New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null

# Create Python virtual environment
if (-not (Test-Path (Join-Path $VenvDir "Scripts\python.exe"))) {
    Write-Host "[INFO]  Creating Python virtual environment..." -ForegroundColor Cyan
    & $pythonCmd -m venv $VenvDir
    Write-Host "[OK]    Virtual environment created at $VenvDir" -ForegroundColor Green
}

# Install Open WebUI in venv
$venvPip = Join-Path $VenvDir "Scripts\pip.exe"
$venvPython = Join-Path $VenvDir "Scripts\python.exe"

Write-Host "[INFO]  Installing Open WebUI (this may take 1-2 minutes)..." -ForegroundColor Cyan
& $venvPip install --upgrade pip 2>&1 | Out-Null
& $venvPip install open-webui 2>&1 | Select-Object -Last 5
Write-Host "[OK]    Open WebUI installed" -ForegroundColor Green

# ── Step 8: Create launch/stop scripts ─────────────────
$startScript = Join-Path $JoesAiDir "start-server.ps1"
$startContent = @"
# Joe's AI Server — Start Script
`$WebuiPort = if (`$env:WEBUI_PORT) { `$env:WEBUI_PORT } else { "$WebuiPort" }

Write-Host "Starting Joe's AI Server..."

# Ensure Ollama is running
`$ollamaRunning = `$false
try {
    `$r = Invoke-WebRequest -Uri "http://localhost:11434/api/tags" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
    if (`$r.StatusCode -eq 200) { `$ollamaRunning = `$true }
}
catch { }

if (-not `$ollamaRunning) {
    Write-Host "Starting Ollama..."
    Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 5
}

# Start Open WebUI
`$env:DATA_DIR = "$DataDir"
Write-Host "Starting Open WebUI on port `$WebuiPort..."
Write-Host "Open your browser: http://localhost:`$WebuiPort"
Write-Host "Press Ctrl+C to stop the server."
& "$VenvDir\Scripts\open-webui.exe" serve --port `$WebuiPort
"@
$startContent | Out-File -FilePath $startScript -Encoding utf8
Write-Host "[OK]    Start script created: $startScript" -ForegroundColor Green

$stopScript = Join-Path $JoesAiDir "stop-server.ps1"
$stopContent = @"
# Joe's AI Server — Stop Script
Write-Host "Stopping Joe's AI Server..."
Get-Process | Where-Object { `$_.ProcessName -match "open-webui" } | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Host "Open WebUI stopped."
Write-Host "Run ~/.joes-ai/start-server.ps1 to restart."
"@
$stopContent | Out-File -FilePath $stopScript -Encoding utf8
Write-Host "[OK]    Stop script created: $stopScript" -ForegroundColor Green

# ── Step 9: Set up auto-start via Task Scheduler ──────
Write-Host "[INFO]  Configuring auto-start (Windows Task Scheduler)..." -ForegroundColor Cyan

try {
    $taskName = "JoesAIServer"
    $openWebuiExe = Join-Path $VenvDir "Scripts\open-webui.exe"

    # Remove existing task if present
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

    $action = New-ScheduledTaskAction `
        -Execute $openWebuiExe `
        -Argument "serve --port $WebuiPort"

    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1)

    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Description "Joe's AI Server — Private ChatGPT (Open WebUI)" `
        -RunLevel Limited | Out-Null

    Write-Host "[OK]    Auto-start configured — Open WebUI will start on login" -ForegroundColor Green
}
catch {
    Write-Host "[WARN]  Could not set up auto-start. You can start manually: $startScript" -ForegroundColor Yellow
}

# ── Step 10: Start server now ──────────────────────────
Write-Host "[INFO]  Starting Open WebUI..." -ForegroundColor Cyan

$env:DATA_DIR = $DataDir
Start-Process -FilePath $openWebuiExe -ArgumentList "serve --port $WebuiPort" -WindowStyle Hidden -RedirectStandardError (Join-Path $LogDir "webui-stderr.log")

# Wait for it to be ready
$ready = $false
for ($i = 0; $i -lt 45; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$WebuiPort" -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) { $ready = $true; break }
    }
    catch { }
    Start-Sleep -Seconds 2
}

if (-not $ready) {
    Write-Host "[WARN]  Open WebUI is taking longer than expected to start." -ForegroundColor Yellow
    Write-Host "        Check logs: Get-Content $LogDir\webui-stderr.log" -ForegroundColor Yellow
    Write-Host "        Or start manually: $startScript" -ForegroundColor Yellow
}

# ── Show installed models ────────────────────────────
Write-Host ""
Write-Host "[INFO]  Installed models:" -ForegroundColor Cyan
ollama list 2>$null
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
Write-Host "    ollama list                 (list models)" -ForegroundColor Green
Write-Host "    ollama pull <model>         (download model)" -ForegroundColor Green
Write-Host "    ollama rm <model>           (remove model)" -ForegroundColor Green
Write-Host "    ~/.joes-ai/start-server.ps1 (start server)" -ForegroundColor Green
Write-Host "    ~/.joes-ai/stop-server.ps1  (stop server)" -ForegroundColor Green
Write-Host ""
Write-Host "  Auto-start: Server starts automatically on login" -ForegroundColor Green
Write-Host ""
Write-Host "  Support: joe@joestechsolutions.com" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""

# Auto-open browser
if ($ready) {
    Start-Process "http://localhost:$WebuiPort"
}
