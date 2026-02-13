# Troubleshooting Guide — Native Install

*For local Mac / Linux installations (no Docker required)*

---

## 1. System Requirements & Initial Setup

| Check | Expected | Fix |
|-------|----------|-----|
| Mac Model | Apple Silicon (M1/M2/M3/M4) | Intel Macs work but performance is significantly lower. Apple Silicon gets native Metal GPU acceleration. |
| RAM | At least 8 GB | With < 8 GB, only `qwen3:4b` will run. 16 GB+ recommended for best experience. |
| Free Disk Space | > 20 GB (ideally > 50 GB) | Models range from 2.6 GB to 20+ GB. Delete large, unneeded files if low. |
| macOS Version | macOS 12 (Monterey) or later | Ollama requires Monterey+. Check: Apple menu → About This Mac. |

---

## 2. Installation Issues

### Homebrew fails to install

**Symptoms:** "Command not found: brew" after install attempt.

**Fix (Apple Silicon Macs):**
```bash
# Homebrew installs to /opt/homebrew on Apple Silicon
# Add it to your PATH manually:
eval "$(/opt/homebrew/bin/brew shellenv)"

# Then add to your shell profile permanently:
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
source ~/.zprofile
```

**Fix (Intel Macs):**
```bash
# Homebrew installs to /usr/local on Intel
export PATH="/usr/local/bin:$PATH"
```

---

### Ollama fails to install

**Symptoms:** `brew install ollama` fails or `ollama` command not found after install.

**Fix:**
```bash
# Try reinstalling
brew reinstall ollama

# Or install directly from the website
# Download from https://ollama.com/download/mac
# Drag Ollama to Applications, then run it
```

---

### Python / Open WebUI install fails

**Symptoms:** `pip install open-webui` fails with errors.

**Common fixes:**
```bash
# Ensure you have Python 3.11+
python3 --version

# If not installed:
brew install python@3.11

# If pip fails with permission errors, the installer uses a virtual environment
# at ~/.joes-ai/venv — try reinstalling:
rm -rf ~/.joes-ai/venv
python3 -m venv ~/.joes-ai/venv
source ~/.joes-ai/venv/bin/activate
pip install --upgrade pip
pip install open-webui
```

---

### Script hangs or fails to download

**Symptoms:** Output stops after running the curl command.

**Fix:**
- Check internet connection
- Try downloading the script manually:
```bash
curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.sh -o install.sh
bash install.sh
```

---

## 3. Post-Installation Issues

### Cannot access http://localhost:3000

**Symptoms:** "This site can't be reached" or "Connection refused"

**Check 1 — Is Ollama running?**
```bash
curl http://localhost:11434/api/tags
# Should return JSON with model list
```

If not running:
```bash
# macOS
brew services start ollama
# Or manually:
ollama serve
```

**Check 2 — Is Open WebUI running?**
```bash
# Check if the process is running
ps aux | grep open-webui

# If not running, start manually:
~/.joes-ai/start-server.sh

# Or start directly:
source ~/.joes-ai/venv/bin/activate
open-webui serve --port 3000
```

**Check 3 — Is something else using port 3000?**
```bash
lsof -i :3000
# If another app is using it, either stop that app or:
WEBUI_PORT=8080 ~/.joes-ai/start-server.sh
```

---

### AI is unresponsive (interface loads but model doesn't respond)

1. **Check model is selected:** Ensure a model is selected from the dropdown (e.g., `qwen3:4b`)
2. **Check Ollama is running:**
   ```bash
   ollama list
   # Should show your downloaded models
   ```
3. **Check model is actually loaded:**
   ```bash
   ollama run qwen3:4b "hello"
   # Should get a response. If not, the model may be corrupted.
   ```
4. **Re-download the model if corrupted:**
   ```bash
   ollama rm qwen3:4b
   ollama pull qwen3:4b
   ```

---

### Model download fails or times out

**Symptoms:** `ollama pull` hangs or errors out.

**Fix:**
```bash
# Check internet connection
curl -I https://ollama.com

# Retry the download (it will resume where it left off)
ollama pull qwen3:4b

# If the model is corrupted from a partial download:
ollama rm qwen3:4b
ollama pull qwen3:4b
```

---

### Open WebUI won't auto-start after reboot

**Symptoms:** Need to manually start the server after every restart.

**Check the launchd agent (macOS):**
```bash
# Verify the plist exists
ls ~/Library/LaunchAgents/com.joestechsolutions.ai-server.plist

# Reload it
launchctl unload ~/Library/LaunchAgents/com.joestechsolutions.ai-server.plist
launchctl load ~/Library/LaunchAgents/com.joestechsolutions.ai-server.plist

# Check if it's loaded
launchctl list | grep joestechsolutions
```

**Check the systemd service (Linux):**
```bash
systemctl --user status joes-ai-webui.service
systemctl --user enable joes-ai-webui.service
systemctl --user start joes-ai-webui.service
```

**Manual workaround:** If auto-start won't cooperate, just run:
```bash
~/.joes-ai/start-server.sh
```

---

### Slow performance / Out of memory

**Symptoms:** Model responds very slowly or system becomes unresponsive.

**Fixes:**
- **Use a smaller model:** Switch from `qwen3:8b` → `qwen3:4b` (uses ~2.6 GB instead of ~5.2 GB)
- **Close other apps:** AI models need RAM. Close Chrome tabs, other heavy apps.
- **Check system resources:**
  ```bash
  # macOS: Open Activity Monitor → Memory tab
  # Look for memory pressure (green = good, yellow = caution, red = problem)

  # Linux:
  free -h
  ```
- **For 8 GB Macs:** Stick to `qwen3:4b` only. Don't try to run larger models.

---

### Ollama data location

Models and data are stored in:

| Platform | Location |
|----------|----------|
| macOS | `~/.ollama/` |
| Linux | `~/.ollama/` (user) or `/usr/share/ollama/.ollama/` (system) |

Open WebUI data (chats, settings) is stored in:
- `~/.joes-ai/data/`

---

## 4. Quick Diagnostics Checklist

Run these commands to get a full picture:

```bash
echo "=== Ollama Status ==="
curl -sf http://localhost:11434/api/tags && echo "Ollama: RUNNING" || echo "Ollama: NOT RUNNING"

echo ""
echo "=== Installed Models ==="
ollama list 2>/dev/null || echo "Cannot connect to Ollama"

echo ""
echo "=== Open WebUI Status ==="
curl -sf http://localhost:3000 >/dev/null && echo "WebUI: RUNNING on port 3000" || echo "WebUI: NOT RUNNING"

echo ""
echo "=== Disk Space ==="
df -h / | tail -1

echo ""
echo "=== Memory ==="
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "Total RAM: $(( $(sysctl -n hw.memsize) / 1073741824 )) GB"
else
  free -h
fi

echo ""
echo "=== Auto-start Status ==="
if [[ "$OSTYPE" == "darwin"* ]]; then
  launchctl list 2>/dev/null | grep joestechsolutions && echo "Auto-start: ENABLED" || echo "Auto-start: NOT CONFIGURED"
else
  systemctl --user is-active joes-ai-webui.service 2>/dev/null || echo "Auto-start: NOT CONFIGURED"
fi

echo ""
echo "=== Logs (last 10 lines) ==="
tail -10 ~/.joes-ai/logs/webui-stderr.log 2>/dev/null || echo "No log file found"
```

---

## 5. Emergency: Full Reinstall

If everything is broken beyond repair:

```bash
# Step 1: Uninstall everything
curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/uninstall-local.sh | bash
# Choose option 2 (delete everything) and option 3 (remove Ollama)

# Step 2: Fresh install
curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.sh | bash
```

This gives a completely fresh start. Models will need to be re-downloaded.

---

## 6. Migrating from Docker Install

If you previously had the Docker-based version and are switching to native:

```bash
# Step 1: Stop and remove Docker containers
docker stop joes-ai-local 2>/dev/null || true
docker rm joes-ai-local 2>/dev/null || true

# Step 2: Optionally remove Docker volumes (your old chats)
docker volume rm joes-ai-ollama joes-ai-webui 2>/dev/null || true

# Step 3: Optionally remove Docker Desktop entirely
# Drag Docker from Applications to Trash, or:
# Docker Desktop → Troubleshoot → Uninstall

# Step 4: Run the native installer
curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.sh | bash
```

**Note:** Chat history from the Docker version cannot be automatically migrated to the native version. You start fresh.

---

## Support

If all troubleshooting steps fail, collect the following:

1. **Mac model** (e.g., M1, 8 GB)
2. **The exact step where it failed**
3. **Terminal output** (copy and paste the full text)
4. **Diagnostics output** (run the Quick Diagnostics Checklist above)

Email this to **joe@joestechsolutions.com** for help.
