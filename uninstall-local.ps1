#
# Joe's Tech Solutions — Local AI Server Uninstaller (Windows)
# Cleanly removes the native AI server, with option to keep or remove data
#
# Usage (run in PowerShell as Administrator):
#   irm https://raw.githubusercontent.com/joblas/joes-ai-server/main/uninstall-local.ps1 | iex
#

$ErrorActionPreference = "Stop"
$JoesAiDir = Join-Path $env:USERPROFILE ".joes-ai"
$TaskName = "JoesAIServer"

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Joe's Tech Solutions - AI Server Uninstall      " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# ── Check if anything is installed ──────────────────────
$hasInstall = $false

if (Test-Path $JoesAiDir) { $hasInstall = $true }
if (Get-Command ollama -ErrorAction SilentlyContinue) { $hasInstall = $true }
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) { $hasInstall = $true }

if (-not $hasInstall) {
    Write-Host "[WARN]  No Joe's AI Server installation found. Nothing to uninstall." -ForegroundColor Yellow
    exit 0
}

# ── Step 1: Stop running services ───────────────────────
Write-Host "[INFO]  Stopping AI server processes..." -ForegroundColor Cyan

# Stop Open WebUI processes
Get-Process | Where-Object { $_.ProcessName -match "open-webui" } | Stop-Process -Force -ErrorAction SilentlyContinue

# Remove scheduled task
try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "[OK]    Auto-start task removed from Task Scheduler" -ForegroundColor Green
}
catch {
    # Task may not exist
}

Write-Host "[OK]    Server processes stopped" -ForegroundColor Green

# ── Step 2: Ask about chat data ─────────────────────────
Write-Host ""
Write-Host "Your chat history and settings are stored in ~/.joes-ai/data/" -ForegroundColor Yellow
Write-Host "Do you want to keep this data?" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1) Keep my data (recommended — only removes the server, not your chats)" -ForegroundColor White
Write-Host "  2) Delete everything (removes all chats, settings permanently)" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Choose [1/2]"

if ($choice -eq "2") {
    Write-Host "[WARN]  Deleting all Joe's AI data..." -ForegroundColor Yellow
    Remove-Item -Path $JoesAiDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[OK]    All data deleted ($JoesAiDir removed)" -ForegroundColor Green
}
else {
    # Remove everything except data directory
    if (Test-Path $JoesAiDir) {
        $venvDir = Join-Path $JoesAiDir "venv"
        $logDir = Join-Path $JoesAiDir "logs"
        $startScript = Join-Path $JoesAiDir "start-server.ps1"
        $stopScript = Join-Path $JoesAiDir "stop-server.ps1"

        if (Test-Path $venvDir) { Remove-Item -Path $venvDir -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $logDir) { Remove-Item -Path $logDir -Recurse -Force -ErrorAction SilentlyContinue }
        if (Test-Path $startScript) { Remove-Item -Path $startScript -Force -ErrorAction SilentlyContinue }
        if (Test-Path $stopScript) { Remove-Item -Path $stopScript -Force -ErrorAction SilentlyContinue }

        Write-Host "[OK]    Server files removed. Chat data preserved in $JoesAiDir\data\" -ForegroundColor Green
        Write-Host "[INFO]  To reinstall later, just run the installer again — your data will still be there." -ForegroundColor Cyan
    }
}

# ── Step 3: Optionally remove Ollama ────────────────────
Write-Host ""
Write-Host "Ollama (the AI engine) can be kept for other uses, or removed entirely." -ForegroundColor Yellow
Write-Host ""
Write-Host "  1) Keep Ollama installed (recommended)" -ForegroundColor White
Write-Host "  2) Remove Ollama and keep downloaded models" -ForegroundColor White
Write-Host "  3) Remove Ollama AND all downloaded models (frees the most disk space)" -ForegroundColor White
Write-Host ""

$ollamaChoice = Read-Host "Choose [1/2/3]"

switch ($ollamaChoice) {
    "2" {
        Write-Host "[INFO]  Removing Ollama (keeping models)..." -ForegroundColor Cyan
        # Stop Ollama service
        Get-Process | Where-Object { $_.ProcessName -match "ollama" } | Stop-Process -Force -ErrorAction SilentlyContinue
        # Uninstall via winget if available
        try {
            winget uninstall Ollama.Ollama --silent 2>$null | Out-Null
        }
        catch {
            Write-Host "[WARN]  Could not auto-uninstall Ollama. Uninstall manually from Settings > Apps." -ForegroundColor Yellow
        }
        Write-Host "[OK]    Ollama removed (models preserved in $env:USERPROFILE\.ollama)" -ForegroundColor Green
    }
    "3" {
        Write-Host "[INFO]  Removing Ollama and all models..." -ForegroundColor Cyan
        # Stop Ollama service
        Get-Process | Where-Object { $_.ProcessName -match "ollama" } | Stop-Process -Force -ErrorAction SilentlyContinue
        # Uninstall via winget if available
        try {
            winget uninstall Ollama.Ollama --silent 2>$null | Out-Null
        }
        catch {
            Write-Host "[WARN]  Could not auto-uninstall Ollama. Uninstall manually from Settings > Apps." -ForegroundColor Yellow
        }
        # Remove models
        $ollamaDir = Join-Path $env:USERPROFILE ".ollama"
        if (Test-Path $ollamaDir) {
            Remove-Item -Path $ollamaDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Host "[OK]    Ollama and all models removed" -ForegroundColor Green
    }
    default {
        Write-Host "[OK]    Ollama kept installed" -ForegroundColor Green
    }
}

# ── Done ───────────────────────────────────────────────
Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "  AI Server has been uninstalled.                  " -ForegroundColor Green
Write-Host ""
Write-Host "  To reinstall anytime:" -ForegroundColor Green
Write-Host "  irm https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.ps1 | iex" -ForegroundColor Green
Write-Host ""
Write-Host "  Support: joe@joestechsolutions.com               " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
