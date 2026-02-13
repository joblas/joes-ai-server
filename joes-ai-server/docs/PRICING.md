# Joe's AI Server — Service Pricing Reference

*Internal document for Joe's Tech Solutions LLC*

---

## Market Research (Feb 2025)

| Competitor | What They Sell | Pricing |
|---|---|---|
| **Elest.io** | Managed Ollama/Open WebUI hosting | $26–$180+/mo (compute based) |
| **AWS Marketplace AMIs** | Pre-configured EC2 images | $0.10–0.50/hr + EC2 costs |
| **Iternal / AirgapAI** | Enterprise self-hosted AI | $10K+ setup, enterprise contracts |
| **ai-human.co** | Turnkey AI consulting | Custom pricing, $5K–50K projects |
| **Local IT shops** | Ad-hoc Docker setup | $100–500/hr consulting |

**Key insight:** There's a massive gap between free DIY (hard) and enterprise solutions (expensive). Your sweet spot is the small business / individual who wants it done right without the enterprise price tag.

---

## Suggested Pricing Tiers

### Tier 1: Local AI Setup — $199 one-time

**Target:** Individual, home office, freelancer

**Includes:**
- Docker + Ollama + Open WebUI installed on their computer
- First model downloaded and tested
- 30-minute walkthrough call
- Client guide PDF
- 30 days email support

**Your time:** ~30–45 min (mostly automated)
**Margin:** Very high — this is script-driven

---

### Tier 2: Cloud AI Server — $499 setup + $29/mo management

**Target:** Small business, team of 2–10

**Includes:**
- Hostinger VPS provisioning (client pays VPS ~$12/mo separately)
- Full stack deployment with HTTPS + custom domain
- Watchtower auto-updates
- Daily automated backups
- 2 models pre-loaded
- Admin + user account setup
- Client guide
- Monthly health check
- Email support

**Your time:** ~1 hour setup (automated), ~15 min/mo maintenance
**Margin:** $29/mo is nearly passive — Watchtower handles updates, backups are cron'd

---

### Tier 3: Managed AI + Automation — $999 setup + $79/mo

**Target:** Business wanting AI workflows, not just chat

**Includes everything in Tier 2, plus:**
- n8n workflow automation server
- 3 custom AI workflows (email summarizer, document Q&A, social content)
- RAG setup with their business documents
- SearXNG private web search integration
- Quarterly strategy call
- Priority support (same-day response)

**Your time:** ~3–4 hours setup, ~30 min/mo
**Margin:** This is where the real value is — the n8n workflows are reusable templates

---

## Upsell Opportunities

- **Additional model setup:** $49 per model
- **Custom AI workflow:** $199 per workflow
- **User training session:** $99/hr (group), $149/hr (1-on-1)
- **Emergency support:** $149/incident
- **Annual plan discount:** 2 months free on yearly commitment

---

## Cost Basis

| Item | Cost | Notes |
|---|---|---|
| Hostinger VPS KVM 2 | ~$12/mo | 8 GB RAM, client pays directly |
| Domain (if needed) | ~$12/yr | Usually client already has one |
| Your time (Tier 2) | ~15 min/mo | Mostly monitoring |
| GitHub hosting | Free | Public repo |

**Effective hourly rate at scale:**
- 10 Tier 2 clients = $290/mo recurring for ~2.5 hrs/mo = **$116/hr passive**
- 5 Tier 3 clients = $395/mo recurring for ~2.5 hrs/mo = **$158/hr passive**
