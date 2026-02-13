# Joe's AI Server

**Private, Self-Hosted AI Chat — Deployed in Minutes**

By [Joe's Tech Solutions LLC](https://joestechsolutions.com)

---

## What This Is

A turnkey deployment toolkit for installing a private AI chat server (Ollama + Open WebUI) on either a local computer or a cloud VPS. One command. Full privacy. No API fees.

### Two Products, One Repo

| Product | Target | What They Get |
|---|---|---|
| **Joe's Local AI** | Individuals, home offices | Private ChatGPT alternative on their own computer (native install, no Docker) |
| **Joe's Cloud AI** | Small businesses, teams | Hosted AI server with HTTPS, custom domain, auto-updates |

---

## Quick Start

### Local Install (Mac / Linux) — Native, No Docker

**Prerequisites:** macOS 12+ (Apple Silicon recommended) or Ubuntu 20.04+. That's it — the script installs everything else.

**Mac / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.sh | bash
```

**Windows (PowerShell as Administrator):**
```powershell
irm https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.ps1 | iex
```

Then open **http://localhost:3000** and create your admin account.

**What the installer does automatically:**
1. Installs Homebrew (Mac) if missing
2. Installs Python 3 if missing
3. Detects your hardware (RAM, CPU, GPU)
4. Installs Ollama natively (direct Metal GPU acceleration on Apple Silicon)
5. Selects and downloads optimal AI models for your hardware
6. Installs Open WebUI in a clean Python virtual environment
7. Configures auto-start on login (launchd on Mac, systemd on Linux)
8. Creates start/stop helper scripts

### Cloud Install (Hostinger / Any Ubuntu VPS)

**Prerequisites:** Fresh Ubuntu 22.04+ VPS with a domain pointed at it.

```bash
AI_DOMAIN=ai.yourclient.com \
EMAIL=admin@yourclient.com \
curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-vps.sh | bash
```

Then visit **https://ai.yourclient.com** once DNS propagates.

---

## What's Included

### Local Install Stack (Native)
- **[Ollama](https://ollama.com)** — Run LLMs natively with Metal GPU acceleration (Apple Silicon)
- **[Open WebUI](https://docs.openwebui.com)** — Beautiful ChatGPT-style interface with RAG, multi-user, model management
- **Auto-start** — Server launches automatically on login
- **Start/Stop scripts** — Simple `~/.joes-ai/start-server.sh` and `stop-server.sh`

### VPS Stack (Docker)
- **[Ollama](https://ollama.com)** — Run LLMs on cloud GPU/CPU
- **[Open WebUI](https://docs.openwebui.com)** — Full-featured chat interface
- **[Caddy](https://caddyserver.com)** — Automatic HTTPS with Let's Encrypt
- **[Watchtower](https://github.com/containrrr/watchtower)** — Container update monitoring (monitor-only by default)
- **Health check endpoint** — Simple uptime monitoring
- **Automated backups** — Daily volume snapshots with 7-day retention

---

## Architecture

### Local Install
```
┌─────────────────────────────────────────────┐
│              Client Browser                  │
│         http://localhost:3000                │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│         Open WebUI (:3000)                   │
│    Chat UI · RAG · User Management           │
│    (Python venv @ ~/.joes-ai/venv)           │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│          Ollama (:11434)                     │
│   LLM Inference · Metal GPU Acceleration     │
│   (Native install via Homebrew)              │
└─────────────────────────────────────────────┘
```

### VPS Install
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

| Tier | RAM | Storage | Models | Good For |
|---|---|---|---|---|
| Starter | 8 GB | 20 GB | Qwen3 4B | Rivals 72B quality — great for most tasks |
| Standard | 16 GB | 50 GB | Qwen3 8B + embeddings | Sweet spot performance, 40+ tok/s |
| Power | 32 GB+ | 100 GB+ | Qwen3 32B, DeepSeek-R1 | Near-frontier quality locally |

**Apple Silicon advantage:** Unified memory means the GPU has direct access to all your RAM — no separate VRAM needed. An M1 with 8 GB outperforms most NVIDIA setups at the same RAM level for inference.

For VPS: Hostinger KVM 2 (8 GB RAM, $12/mo) is the sweet spot for small business use.

---

## Management Commands

### Local Install

```bash
# Start/stop the server
~/.joes-ai/start-server.sh
~/.joes-ai/stop-server.sh

# List downloaded models
ollama list

# Download a new model
ollama pull qwen3:8b

# Remove a model (saves disk space)
ollama rm qwen3:4b

# Test a model directly in terminal
ollama run qwen3:4b "Explain quantum computing in one paragraph"

# Check Ollama status
curl http://localhost:11434/api/tags

# View Open WebUI logs
cat ~/.joes-ai/logs/webui-stderr.log

# Restart Ollama service (macOS)
brew services restart ollama

# Restart Ollama service (Linux)
sudo systemctl restart ollama
```

### VPS Install

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

## Industry Verticals

Each install can include an industry-specific AI assistant with tailored system prompts:

```bash
# Install with a vertical
VERTICAL=healthcare curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.sh | bash
```

| Vertical | Use Case |
|---|---|
| `healthcare` | HIPAA-aware medical AI assistant |
| `legal` | Attorney privilege-safe legal AI |
| `financial` | Financial data privacy AI |
| `realestate` | Real estate listings + comps AI |
| `therapy` | Clinical documentation AI |
| `education` | FERPA-safe student learning AI |
| `construction` | Bid/spec/estimate AI for trades |
| `creative` | IP-safe creative writing AI |
| `smallbusiness` | General team productivity AI |

---

## File Structure

```
joes-ai-server/
├── install-local.sh          # Native installer for Mac / Linux (no Docker)
├── install-local.ps1         # Native installer for Windows (PowerShell)
├── install-vps.sh            # Docker-based VPS deployment
├── uninstall-local.sh        # Clean uninstall for Mac / Linux
├── uninstall-local.ps1       # Clean uninstall for Windows
├── uninstall-vps.sh          # Clean uninstall for VPS
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

### Local Install Creates These Files

```
~/.joes-ai/
├── venv/                     # Python virtual environment (Open WebUI)
├── data/                     # Open WebUI data (chats, settings, uploads)
├── logs/                     # Server logs
│   ├── webui-stdout.log
│   └── webui-stderr.log
├── start-server.sh           # Start the AI server
└── stop-server.sh            # Stop the AI server

~/Library/LaunchAgents/
└── com.joestechsolutions.ai-server.plist  # macOS auto-start config
```

---

## Uninstall

### Local

```bash
curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/uninstall-local.sh | bash
```

The uninstaller gives you options to:
- Keep or delete your chat history
- Keep or remove downloaded AI models
- Keep or completely remove Ollama

### VPS

```bash
curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/uninstall-vps.sh | bash
```

---

## Support

This is a service product of **Joe's Tech Solutions LLC**.

- Email: joe@joestechsolutions.com
- Website: https://joestechsolutions.com

---

## License

Scripts and configurations are MIT licensed. Ollama, Open WebUI, Caddy, and Watchtower each have their own licenses.
