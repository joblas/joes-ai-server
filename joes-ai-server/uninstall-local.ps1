#
# Joe's Tech Solutions — Local AI Server Uninstaller (Windows)
#
# Usage (run in PowerShell):
#   irm https://raw.githubusercontent.com/joblas/joes-ai-server/main/uninstall-local.ps1 | iex
#

$ErrorActionPreference = "Stop"
$ContainerName = "joes-ai-local"

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "   Joe's Tech Solutions - AI Server Uninstall      " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# ── Check if container exists ─────────────────────────
$existing = docker ps -a --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $ContainerName }
if (-not $existing) {
    Write-Host "[WARN]  No '$ContainerName' container found. Nothing to uninstall." -ForegroundColor Yellow
    exit 0
}

# ── Stop and remove container ─────────────────────────
Write-Host "[INFO]  Stopping AI server..." -ForegroundColor Cyan
docker stop $ContainerName 2>$null | Out-Null
docker rm $ContainerName 2>$null | Out-Null
Write-Host "[OK]    Container removed" -ForegroundColor Green

# ── Ask about data volumes ───────────────────────────
Write-Host ""
Write-Host "Your chat history and models are stored in Docker volumes." -ForegroundColor Yellow
Write-Host "Do you want to keep this data?" -ForegroundColor Yellow
Write-Host ""
Write-Host "  1) Keep my data (recommended)" -ForegroundColor White
Write-Host "  2) Delete everything permanently" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Choose [1/2]"

if ($choice -eq "2") {
    Write-Host "[WARN]  Deleting all data volumes..." -ForegroundColor Yellow
    docker volume rm joes-ai-ollama 2>$null | Out-Null
    docker volume rm joes-ai-webui 2>$null | Out-Null
    Write-Host "[OK]    All data deleted" -ForegroundColor Green
}
else {
    Write-Host "[OK]    Data volumes preserved" -ForegroundColor Green
    Write-Host "[INFO]  To reinstall later, your data will still be there." -ForegroundColor Cyan
}

# ── Optionally remove Docker image ────────────────────
Write-Host ""
$removeImage = Read-Host "Remove the Docker image too? (saves ~4 GB) [y/N]"
if ($removeImage -match "^[Yy]$") {
    docker rmi ghcr.io/open-webui/open-webui:ollama 2>$null | Out-Null
    Write-Host "[OK]    Docker image removed" -ForegroundColor Green
}
else {
    Write-Host "[OK]    Docker image kept (faster reinstall)" -ForegroundColor Green
}

# ── Done ───────────────────────────────────────────────
Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "  AI Server has been uninstalled.                  " -ForegroundColor Green
Write-Host "  Support: joe@joestechsolutions.com               " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host ""
