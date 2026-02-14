# Troubleshooting Guide

## Local Install (Mac / Linux / Windows)

### Open WebUI shows "Model not found" or no models available

**Cause:** No models have been downloaded yet, or Ollama hasn't finished starting.

**Fix:**
```bash
# Check if Ollama is running
ollama list

# If empty, pull a model
ollama pull qwen3:4b

# If Ollama isn't responding, restart it
# Mac:
brew services restart ollama
# Linux:
sudo systemctl restart ollama
# Windows (PowerShell):
# Stop and restart from system tray, or: ollama serve
```

---

### "Can't connect to localhost:3000"

**Check 1:** Is Open WebUI running?
```bash
# Mac / Linux:
~/.joes-ai/start-server.sh

# Windows (PowerShell):
~\.joes-ai\start-server.ps1
```

**Check 2:** Is port 3000 already in use?
```bash
# Mac / Linux:
lsof -i :3000

# Windows (PowerShell):
netstat -ano | findstr :3000
```

If another app is using port 3000, reinstall with a different port:
```bash
WEBUI_PORT=3001 curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.sh | bash
```

---

### Slow responses from AI models

**Cause:** The model is too large for the available RAM.

**Fix:**
- Use smaller models: `qwen3:4b` (2.6 GB) instead of larger ones
- Check available memory: `free -h` (Linux) or Activity Monitor (Mac)
- For 8 GB machines, stick to 4B parameter models
- Close memory-heavy apps (Chrome tabs, etc.)

---

### "Ollama not running" or models not responding

```bash
# Mac — restart Ollama:
brew services restart ollama

# Linux — restart Ollama:
sudo systemctl restart ollama

# Any platform — start Ollama manually:
ollama serve
```

---

### Open WebUI won't start / errors on launch

```bash
# Check logs (Mac / Linux):
cat ~/.joes-ai/logs/webui-stderr.log

# Check logs (Windows PowerShell):
Get-Content ~\.joes-ai\logs\webui-stderr.log

# Common fix — reinstall Open WebUI:
# Mac / Linux:
source ~/.joes-ai/venv/bin/activate
pip install --upgrade open-webui
deactivate

# Windows (PowerShell):
& ~\.joes-ai\venv\Scripts\pip.exe install --upgrade open-webui
```

---

### Server won't auto-start on login

**Mac:**
```bash
launchctl load ~/Library/LaunchAgents/com.joestechsolutions.ai-server.plist
```

**Linux:**
```bash
systemctl --user enable joes-ai-webui.service
systemctl --user start joes-ai-webui.service
```

**Windows:**
Check Task Scheduler for "JoesAIServer" task. If missing, re-run the installer.

---

### Model download failed or corrupted

```bash
# Remove and re-download a model
ollama rm qwen3:4b
ollama pull qwen3:4b
```

---

### Client forgot password

Reset via the admin panel in Open WebUI: Admin Panel > Users > Reset password.

---

### Update Open WebUI

```bash
# Mac / Linux:
source ~/.joes-ai/venv/bin/activate
pip install --upgrade open-webui
deactivate

# Windows (PowerShell):
& ~\.joes-ai\venv\Scripts\pip.exe install --upgrade open-webui
```

### Update Ollama

```bash
# Mac:
brew upgrade ollama

# Linux:
curl -fsSL https://ollama.com/install.sh | sh

# Windows:
# Download latest from https://ollama.com/download or run installer again
```

---

## VPS Install (Cloud)

### "Connection refused" when accessing the URL

**Check 1:** Are containers running?
```bash
cd /opt/joes-ai-stack
docker compose ps
```

**Check 2:** Is the firewall allowing traffic?
```bash
sudo ufw status
# Should show 80/tcp and 443/tcp ALLOW
```

**Check 3:** Is DNS pointing to the right IP?
```bash
dig +short ai.yourclient.com
# Should return the VPS IP
```

---

### HTTPS certificate not working

**Cause:** DNS hasn't propagated yet, or port 80 is blocked.

**Fix:**
```bash
# Check Caddy logs
docker compose logs caddy

# Verify port 80 is open externally
curl -I http://ai.yourclient.com

# Force Caddy to retry certificates
docker compose restart caddy
```

Caddy needs port 80 open for the ACME challenge. Make sure no other service is using port 80.

---

### Container keeps restarting

```bash
# Check which container is failing
docker compose ps

# View its logs
docker compose logs <container_name> --tail 50

# Common fixes:
# - If ollama: usually disk space (models are large)
# - If open-webui: usually a bad WEBUI_SECRET_KEY in .env
# - If caddy: usually DNS not pointing to server yet
# - If watchtower: usually Docker API version mismatch
```

---

### Watchtower updated something and it broke

```bash
# Check what Watchtower did
docker logs watchtower --tail 20

# Roll back to a specific image version
docker compose down
# Edit docker-compose.yml to pin the image version, e.g.:
#   image: ghcr.io/open-webui/open-webui:v0.5.6
docker compose up -d
```

---

### Out of disk space (VPS)

```bash
# Check disk usage
df -h

# Clean up Docker (removes old images)
docker system prune -af

# Check model sizes
docker exec ollama ollama list

# Remove unused models
docker exec ollama ollama rm <model_name>
```

---

### Backup/Restore (VPS)

**Manual backup:**
```bash
/opt/joes-ai-stack/scripts/backup.sh
```

**Restore from backup:**
```bash
# List available backups
ls -la /opt/joes-ai-backups/

# Restore (will prompt for confirmation)
/opt/joes-ai-stack/scripts/restore.sh 20250212_030000
```

---

## Quick Diagnostics

### Local (Mac / Linux)
```bash
echo "=== Ollama ===" && ollama list
echo "=== Server ===" && curl -sf http://localhost:3000 >/dev/null && echo "Running" || echo "Not running"
echo "=== Disk ===" && df -h /
echo "=== Memory ===" && free -h 2>/dev/null || vm_stat 2>/dev/null
echo "=== Logs ===" && tail -5 ~/.joes-ai/logs/webui-stderr.log 2>/dev/null
```

### VPS
```bash
echo "=== Docker ===" && docker compose ps
echo "=== Disk ===" && df -h /
echo "=== Memory ===" && free -h
echo "=== Ollama Models ===" && docker exec ollama ollama list
echo "=== Caddy ===" && docker compose logs caddy --tail 5
echo "=== Last Backup ===" && ls -lt /opt/joes-ai-backups/ | head -5
```

---

## Emergency: Full Reinstall

### Local (Mac / Linux)
```bash
# Uninstall first
curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/uninstall-local.sh | bash
# Choose options to delete data if desired

# Then re-run installer
curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.sh | bash
```

### Local (Windows PowerShell)
```powershell
# Uninstall first
irm https://raw.githubusercontent.com/joblas/joes-ai-server/main/uninstall-local.ps1 | iex

# Then re-run installer
irm https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.ps1 | iex
```

### VPS
```bash
cd /opt/joes-ai-stack
docker compose down -v   # WARNING: -v removes all data volumes
AI_DOMAIN=ai.client.com EMAIL=admin@client.com \
  curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-vps.sh | bash
```

This gives a fresh start. Models will need to be re-downloaded.
