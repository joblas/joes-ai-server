# Joe's AI Server — Service Pricing Reference

*Internal document for Joe's Tech Solutions LLC*
*Updated: Feb 2026*

---

## Market Research

| Competitor | What They Sell | Pricing |
|---|---|---|
| **Elest.io** | Managed Ollama/Open WebUI hosting | $26-$180+/mo (compute based) |
| **AWS Marketplace AMIs** | Pre-configured EC2 images | $0.10-0.50/hr + EC2 costs |
| **Iternal / AirgapAI** | Enterprise self-hosted AI | $10K+ setup, enterprise contracts |
| **ai-human.co** | Turnkey AI consulting | Custom pricing, $5K-50K projects |
| **Local IT shops** | Ad-hoc Docker setup | $100-500/hr consulting |

**Key insight:** Massive gap between free DIY and enterprise. Our sweet spot: done-for-you private AI for small businesses and professionals who need data privacy.

---

## Client Verticals

Each client gets a **vertical-specific package** with tailored system prompts, model recommendations, and use-case examples. Verticals justify premium pricing because you're solving an **industry-specific problem**, not just installing software.

| Vertical | Why They Need PRIVATE AI | Pain Point | Best Model | Premium |
|---|---|---|---|---|
| **Healthcare / HIPAA** | Patient data can never hit OpenAI | "I can't use ChatGPT for patient info" | DeepSeek-R1 (reasoning) | +$100 setup |
| **Legal** | Attorney-client privilege | "I need to analyze contracts privately" | Qwen3 (long context) | +$100 setup |
| **Financial / Accounting** | Client financials, tax data | "I handle sensitive data" | DeepSeek-R1 (reasoning) | +$100 setup |
| **Real Estate** | Client info, comps, MLS data | "AI for listings without leaking info" | Qwen3 (general) | Standard |
| **Therapy / Counseling** | Session notes, patient privacy | "Absolutely no cloud AI for notes" | DeepSeek-R1 | +$100 setup |
| **Education / FERPA** | Student privacy, no data harvesting | "AI for students, privately" | Qwen3 (general) | Standard |
| **Construction / Trades** | Competitive bid info | "Help with bids and specs privately" | Qwen3 (general) | Standard |
| **Creative / Content** | IP protection, no training | "Don't want my work training AI" | Qwen3 (creative) | Standard |
| **Small Business** | Cost savings, team access | "ChatGPT for the whole team" | Qwen3 (general) | Standard |

**Vertical starter kits include:** Pre-built system prompts, industry-specific welcome message, model recommendation, sample conversation starters, and compliance notes where applicable.

---

## Pricing Tiers

### Tier 1: Local AI Setup — $199 one-time

**Target:** Individual, home office, freelancer
**Website price:** $150 (intro/promo) → normalize to $199

**Includes:**
- Docker + Ollama + Open WebUI installed on their computer
- Hardware detection + optimal model auto-selected
- Vertical starter kit (system prompts for their use case)
- 30-minute walkthrough call
- Client guide PDF
- 30 days email support

**Your time:** ~30-45 min (mostly automated)
**Margin:** Very high — script-driven

---

### Tier 2: Cloud AI Server — $499 setup + $29/mo management

**Target:** Small business, team of 2-10

**Includes:**
- Hostinger VPS provisioning (client pays VPS ~$12/mo separately)
- Full stack: Ollama + Open WebUI + HTTPS + custom domain
- Watchtower monitoring (Joe approves updates)
- Daily automated backups with 7-day retention
- 2 models pre-loaded (optimal for their hardware)
- Vertical starter kit with custom system prompts
- Admin + user account setup
- Client guide
- Monthly health check
- Email support
- UptimeRobot monitoring (Joe gets alerted on downtime)

**Your time:** ~1 hour setup (automated), ~15 min/mo maintenance
**Margin:** $29/mo is nearly passive

---

### Tier 3: Managed AI + Automation — $999 setup + $79/mo

**Target:** Business wanting AI workflows, not just chat

**Includes everything in Tier 2, plus:**
- n8n workflow automation server
- 3 custom AI workflows (email summarizer, document Q&A, social content)
- RAG setup with their business documents
- SearXNG private web search integration
- Vertical-specific workflow templates
- Quarterly strategy call
- Priority support (same-day response)

**Your time:** ~3-4 hours setup, ~30 min/mo
**Margin:** Highest — workflows are reusable templates

---

### Vertical Premium Add-on — +$100 setup (compliance verticals)

For Healthcare, Legal, Financial, and Therapy clients:
- Compliance-oriented system prompts (HIPAA awareness, privilege protection, etc.)
- Data handling documentation
- Security configuration hardening (disable signup, strong auth)
- Compliance checklist walkthrough

---

## Upsell Opportunities

| Upsell | Price | Notes |
|---|---|---|
| Additional model setup | $49/model | Takes 5 min, pure margin |
| Custom AI workflow | $199/workflow | Reusable n8n templates |
| User training (group) | $99/hr | Record it, sell recording |
| User training (1-on-1) | $149/hr | Higher touch |
| Emergency support | $149/incident | After-hours, urgent |
| Custom branding | $99 | WEBUI_NAME + logo |
| Annual plan discount | 2 months free | Incentivize commitment |

---

## Cost Basis

| Item | Cost | Notes |
|---|---|---|
| Hostinger VPS KVM 2 | ~$12/mo | 8 GB RAM, client pays directly |
| Domain (if needed) | ~$12/yr | Usually client already has one |
| UptimeRobot (free tier) | $0 | 50 monitors free |
| Your time (Tier 2) | ~15 min/mo | Mostly monitoring |
| GitHub hosting | Free | Public repo |

---

## Revenue Projections at Scale

| Scenario | Monthly Recurring | Your Time/mo | Effective Rate |
|---|---|---|---|
| 10 Tier 2 clients | $290/mo | ~2.5 hrs | **$116/hr** |
| 5 Tier 3 clients | $395/mo | ~2.5 hrs | **$158/hr** |
| 10 Tier 2 + 5 Tier 3 | $685/mo | ~5 hrs | **$137/hr** |
| 20 Tier 2 + 10 Tier 3 | $1,370/mo | ~10 hrs | **$137/hr** |

**Target: 20 Tier 2 + 10 Tier 3 = $1,370/mo recurring + one-time setup fees**

Setup fees alone (30 clients): $199-999 each = **$10K-20K one-time**

---

## Website Sync Notes

**Current website:** joestechsolutions.com shows Private AI Setup at $150
**Action needed:** Update Stripe pricing to match tier structure:
- Tier 1: $199 one-time (or keep $150 as intro price)
- Tier 2: $499 setup + $29/mo subscription
- Tier 3: $999 setup + $79/mo subscription

**Landing pages needed:**
- `/ai-server` — Main product page with all tiers
- `/ai-server/healthcare` — HIPAA-compliant AI for practices
- `/ai-server/legal` — Private AI for law firms
- `/ai-server/business` — Team AI for small businesses
