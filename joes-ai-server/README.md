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

**Prerequisites:** [Docker Desktop](https://docs.docker.com/get-docker/) installed and running.

**Mac / Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.sh | bash
```

**Windows (PowerShell as Administrator):**
```powershell
irm https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-local.ps1 | iex
```

Then open **http://localhost:3000** and create your admin account.

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
- **[Ollama](https://ollama.com)** — Run LLMs locally (Llama 3.2, Mistral, Phi-3, DeepSeek, etc.)
- **[Open WebUI](https://docs.openwebui.com)** — Beautiful ChatGPT-style interface with RAG, multi-user, model management

### VPS Extras
- **[Caddy](https://caddyserver.com)** — Automatic HTTPS with Let's Encrypt
- **[Watchtower](https://github.com/nickfedor/watchtower)** — Auto-updates all containers (monitor-only mode by default)
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
| Minimum | 8 GB | 20 GB | Small models (Phi-3, Gemma 2B) |
| Recommended | 16 GB | 50 GB | Medium models (Llama 3.2 8B, Mistral 7B) |
| Power User | 32 GB+ | 100 GB+ | Large models (Llama 3.1 70B quantized) |

For VPS: Hostinger KVM 2 (8 GB RAM, $12/mo) is the sweet spot for small business use.

---

## Management Commands

```bash
# Check status
cd /opt/joes-ai-stack && docker compose ps

# View logs
docker compose logs -f open-webui

# Update everything
docker compose pull && docker compose up -d

# Pull a new model
docker exec ollama ollama pull llama3.2

# List downloaded models
docker exec ollama ollama list

# Restart stack
docker compose restart

# Full backup (VPS)
/opt/joes-ai-stack/scripts/backup.sh
```

---

## File Structure

```
joes-ai-server/
├── install-local.sh          # One-liner for Mac / Linux
├── install-local.ps1         # One-liner for Windows (PowerShell)
├── install-vps.sh            # One-liner for VPS deployment
├── configs/
│   ├── docker-compose.yml    # Full stack (Ollama + WebUI + Caddy + Watchtower)
│   ├── docker-compose.local.yml  # Simplified local-only stack
│   ├── Caddyfile.template    # HTTPS reverse proxy config
│   └── .env.example          # Environment variable template
├── scripts/
│   ├── backup.sh             # Automated backup script
│   ├── restore.sh            # Restore from backup
│   ├── health-check.sh       # Uptime monitoring endpoint
│   └── update.sh             # Manual update trigger
├── docs/
│   ├── CLIENT_GUIDE.md       # End-user documentation
│   ├── PRICING.md            # Service pricing reference
│   └── TROUBLESHOOTING.md    # Common issues and fixes
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
