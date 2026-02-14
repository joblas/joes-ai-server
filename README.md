# 🛡️ Joe's AI Server

**Private, Self-Hosted AI Chat — Deployed in Minutes**

By [Joe's Tech Solutions LLC](https://joestechsolutions.com)

---

## What This Is

A turnkey deployment toolkit for installing a private AI chat server (Ollama + Open WebUI) on either a local computer or a cloud VPS. One command. Full privacy. No API fees.

### Two Products, One Repo

| Product | Target | What They Get |
|---|---|---|
| **Joe's Local AI** | Individuals, home offices | Private ChatGPT alternative on their own computer |
| **Joe's Cloud AI** | Small businesses, teams | Hosted AI server with HTTPS, custom domain, auto-updates |

---

## Quick Start

### 🖥️ Local Install

**No Docker required!** The installer handles all dependencies automatically.

**Mac / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.sh | bash
```

**Windows (PowerShell as Administrator):**
```powershell
irm https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.ps1 | iex
```

Then open **http://localhost:3000** and create your admin account.

**What gets installed natively:**
- **Homebrew** (Mac) or **winget** (Windows) for package management
- **Ollama** — AI model engine (runs directly on your hardware)
- **Open WebUI** — Chat interface (Python pip package in a virtual environment)
- **Auto-start** — Server launches on login (launchd on Mac, Task Scheduler on Windows, systemd on Linux)

### ☁️ VPS Install (Hostinger / Any Ubuntu VPS)

**Prerequisites:** Fresh Ubuntu 22.04+ VPS with a domain pointed at it.

```bash
AI_DOMAIN=ai.yourclient.com \
EMAIL=admin@yourclient.com \
curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-vps.sh | bash
```

Then visit **https://ai.yourclient.com** once DNS propagates.

---

## What's Included

### Core Stack
- **[Ollama](https://ollama.com)** — Run LLMs locally (Qwen3, Gemma3, DeepSeek-R1, etc.)
- **[Open WebUI](https://docs.openwebui.com)** — Beautiful ChatGPT-style interface with RAG, multi-user, model management

### VPS Extras
- **[Caddy](https://caddyserver.com)** — Automatic HTTPS with Let's Encrypt
- **[Watchtower](https://github.com/containrrr/watchtower)** — Container update monitoring (monitor-only by default, manual approval)
- **Health check endpoint** — Simple uptime monitoring
- **Automated backups** — Daily volume snapshots with 7-day retention

---

## Architecture

```
┌─────────────────────────────────────────────┐
│              Client Browser                  │
│         https://ai.client.com                │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│              Caddy (443/80)                  │
│         Auto HTTPS + Reverse Proxy           │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│           Open WebUI (:8080)                 │
│    Chat UI · RAG · User Management           │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│            Ollama (:11434)                   │
│     LLM Inference · Model Management         │
└─────────────────────────────────────────────┘
         ▲                          ▲
    Watchtower                 Health Check
   (auto-updates)            (uptime monitor)
```

---

## Hardware Requirements

| Tier | RAM | Storage | Good For |
|---|---|---|---|
| Starter | 8 GB | 20 GB | Qwen3 4B — rivals 72B quality |
| Standard | 16 GB | 50 GB | Qwen3 8B, Gemma3 12B — excellent all-rounders |
| Power | 32 GB+ | 100 GB+ | Qwen3 32B, DeepSeek-R1 32B — near-frontier quality |

For VPS: Hostinger KVM 2 (8 GB RAM, $12/mo) is the sweet spot for small business use.

---

## Management Commands

### Local (Mac / Linux)

```bash
# Start/stop server
~/.joes-ai/start-server.sh
~/.joes-ai/stop-server.sh

# Pull a new model
ollama pull qwen3:4b

# List downloaded models
ollama list

# Remove a model
ollama rm <model_name>

# Update Open WebUI
source ~/.joes-ai/venv/bin/activate && pip install --upgrade open-webui

# Update Ollama (Mac)
brew upgrade ollama

# Check logs
cat ~/.joes-ai/logs/webui-stderr.log
```

### Local (Windows)

```powershell
# Start/stop server
~\.joes-ai\start-server.ps1
~\.joes-ai\stop-server.ps1

# Pull a new model
ollama pull qwen3:4b

# List downloaded models
ollama list
```

### VPS (Cloud)

```bash
# Check status
cd /opt/joes-ai-stack && docker compose ps

# View logs
docker compose logs -f open-webui

# Update everything
docker compose pull && docker compose up -d

# Pull a new model
docker exec ollama ollama pull qwen3:4b

# List downloaded models
docker exec ollama ollama list

# Restart stack
docker compose restart

# Full backup
/opt/joes-ai-stack/scripts/backup.sh
```

---

## File Structure

```
joes-ai-server/
├── install-local.sh          # One-liner for Mac / Linux
├── install-local.ps1         # One-liner for Windows (PowerShell)
├── install-vps.sh            # One-liner for VPS deployment
├── uninstall-local.sh        # Clean uninstall for Mac / Linux
├── uninstall-local.ps1       # Clean uninstall for Windows
├── uninstall-vps.sh          # Clean uninstall for VPS
├── configs/
│   ├── docker-compose.local.yml  # Legacy Docker config (local installs are now native)
│   └── .env.example          # Environment variable template
├── docs/
│   ├── CLIENT_GUIDE.md       # End-user documentation
│   ├── CLIENT_INTAKE.md      # Client intake checklist
│   ├── PRICING.md            # Service pricing + verticals
│   └── TROUBLESHOOTING.md    # Common issues and fixes
├── verticals/                # Industry-specific starter kits
│   ├── healthcare.md         # HIPAA-aware medical AI assistant
│   ├── legal.md              # Attorney privilege-safe legal AI
│   ├── financial.md          # Financial data privacy AI
│   ├── realestate.md         # Real estate listings + comps AI
│   ├── therapy.md            # Clinical documentation AI
│   ├── education.md          # FERPA-safe student learning AI
│   ├── construction.md       # Bid/spec/estimate AI for trades
│   ├── creative.md           # IP-safe creative writing AI
│   └── smallbusiness.md      # General team productivity AI
└── README.md
```

---

## Support

This is a service product of **Joe's Tech Solutions LLC**.

- 📧 Email: joe@joestechsolutions.com
- 🌐 Website: https://joestechsolutions.com

---

## License

Scripts and configurations are MIT licensed. Ollama, Open WebUI, Caddy, and Watchtower each have their own licenses.
