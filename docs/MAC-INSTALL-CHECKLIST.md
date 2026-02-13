# Mac Install — Complete Checklist

**Native Install (No Docker Required)**
*For: Apple Silicon Macs (M1/M2/M3/M4) with 8 GB+ RAM*

---

## Before You Start

| Requirement | How to Check | Minimum |
|-------------|-------------|---------|
| Mac Model | Apple menu → About This Mac | Apple Silicon (M1 or later) |
| macOS Version | Apple menu → About This Mac | macOS 12 (Monterey) or later |
| RAM | Apple menu → About This Mac → Memory | 8 GB minimum |
| Free Disk Space | Apple menu → About This Mac → Storage | 20 GB+ (50 GB+ ideal) |
| Internet | Open any webpage | Required for initial install |

---

## Installation Steps

### Step 1: Open Terminal

- Press **Command + Space** to open Spotlight
- Type **Terminal** and hit Enter
- A black/white text window will open

### Step 2: Run the Installer

Copy and paste this entire command into Terminal, then hit **Enter**:

```bash
curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.sh | bash
```

### Step 3: Wait (~5-10 minutes)

The installer will automatically:

| Step | What Happens | Time |
|------|-------------|------|
| 1 | Install Homebrew (if needed) | ~1 min |
| 2 | Install Python 3 (if needed) | ~1 min |
| 3 | Detect your hardware | ~5 sec |
| 4 | Install Ollama (AI engine) | ~1 min |
| 5 | Download AI model(s) | ~2-5 min |
| 6 | Install Open WebUI (chat interface) | ~1-2 min |
| 7 | Configure auto-start | ~5 sec |

You'll see progress messages throughout. **Don't close Terminal until you see the green success banner.**

### Step 4: Verify — Green Banner

When the install finishes, you should see:

```
╔══════════════════════════════════════════════════════════╗
║            ✅ Joe's Local AI Server is LIVE!             ║
╚══════════════════════════════════════════════════════════╝
```

### Step 5: Open Your AI Server

Open **Safari** or **Chrome** and go to:

**http://localhost:3000**

### Step 6: Create Your Admin Account

- Click **Sign Up**
- Enter your name, email, and a strong password
- This first account becomes the **admin**

### Step 7: Select Your AI Model

- Click the model dropdown at the top of the chat
- Select the model that was installed (e.g., `qwen3:4b`)

### Step 8: Test It!

Type a message like: *"Tell me a fun fact about space"*

You should get a response within a few seconds. If the response appears — **you're done!**

---

## Verification Checklist

| Check | Expected | Status |
|-------|----------|--------|
| Terminal shows green success banner | ✅ | ☐ |
| http://localhost:3000 loads in browser | Login/signup page appears | ☐ |
| Admin account created | Can log in | ☐ |
| Model selected from dropdown | e.g., qwen3:4b | ☐ |
| AI responds to a test message | Gets a text response | ☐ |
| Server survives a reboot* | Restart Mac, check localhost:3000 | ☐ |

*The server auto-starts on login. After restarting your Mac, wait ~30 seconds, then check http://localhost:3000.

---

## Quick Reference Card

| Action | How |
|--------|-----|
| **Access AI** | Open http://localhost:3000 in any browser |
| **Start server** (if stopped) | Open Terminal → `~/.joes-ai/start-server.sh` |
| **Stop server** | Open Terminal → `~/.joes-ai/stop-server.sh` |
| **List models** | Open Terminal → `ollama list` |
| **Download new model** | Open Terminal → `ollama pull qwen3:8b` |
| **Remove a model** | Open Terminal → `ollama rm qwen3:4b` |
| **View logs** | Open Terminal → `cat ~/.joes-ai/logs/webui-stderr.log` |
| **Update Ollama** | Open Terminal → `brew upgrade ollama` |
| **Update Open WebUI** | Open Terminal → `source ~/.joes-ai/venv/bin/activate && pip install --upgrade open-webui` |

---

## Troubleshooting

### "This site can't be reached" at localhost:3000

1. Open Terminal
2. Run: `~/.joes-ai/start-server.sh`
3. Wait 30 seconds, then refresh the browser

### AI doesn't respond

1. Make sure a model is selected in the dropdown
2. Open Terminal and run: `ollama list` — you should see your model listed
3. If no models shown: `ollama pull qwen3:4b`

### Everything broke

Full reinstall (takes ~5 minutes):
```bash
curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/uninstall-local.sh | bash
curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.sh | bash
```

### Need help?

Email **joe@joestechsolutions.com** with:
- Your Mac model (e.g., M1, 8 GB)
- What step failed
- Copy/paste of Terminal output

---

*Joe's Tech Solutions LLC — joe@joestechsolutions.com*
*This checklist replaces the previous Docker-based install guide.*
