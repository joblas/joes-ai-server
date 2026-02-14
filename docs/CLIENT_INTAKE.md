# Client Intake Checklist

*Use this before every new AI server deployment*

---

## 1. Client Information

- [ ] **Client name:**
- [ ] **Business name:**
- [ ] **Email:**
- [ ] **Phone:**
- [ ] **Website (if any):**

---

## 2. Use Case / Vertical

What will they primarily use the AI for?

- [ ] Healthcare / Medical (HIPAA considerations)
- [ ] Legal (attorney-client privilege)
- [ ] Financial / Accounting (client data sensitivity)
- [ ] Real Estate (listings, comps, client comms)
- [ ] Therapy / Counseling (session notes, treatment plans)
- [ ] Education / Tutoring (student privacy, FERPA)
- [ ] Construction / Trades (bids, specs, estimates)
- [ ] Creative / Content (writing, marketing, IP protection)
- [ ] Small Business / General (email, content, team productivity)
- [ ] Other: _________________________________

**Compliance vertical?** (Healthcare, Legal, Financial, Therapy = +$100)
- [ ] Yes → Apply compliance hardening checklist
- [ ] No → Standard setup

---

## 3. Deployment Type

- [ ] **Local** (on their computer) — Tier 1: $199
- [ ] **Cloud VPS** (hosted server) — Tier 2: $499 + $29/mo
- [ ] **Managed + Automation** — Tier 3: $999 + $79/mo

---

## 4. Hardware (Local Install)

- [ ] **Operating system:** Mac / Windows / Linux
- [ ] **RAM:** _____ GB
- [ ] **Free disk space:** _____ GB
- [ ] **Processor:** Apple Silicon (M1/M2/M3/M4) / Intel / AMD
- [ ] **GPU (if Linux/Windows):** NVIDIA model + VRAM / AMD / None
- [ ] **Python 3.11+ installed?** Yes / No (installer handles this automatically)

**Predicted tier:**
| RAM | Tier | Primary Model |
|---|---|---|
| 8 GB | Starter | qwen3:4b (2.6 GB) |
| 16 GB | Standard/Performance | qwen3:8b or gemma3:12b |
| 32 GB | Power | qwen3:32b |
| 64 GB+ | Maximum | Full model stack |

---

## 5. Cloud Server Details (Tier 2 & 3)

- [ ] **Domain for AI server:** (e.g., ai.theircompany.com)
- [ ] **Domain registrar:** (e.g., GoDaddy, Namecheap, Cloudflare)
- [ ] **DNS access confirmed?** Yes / No
- [ ] **VPS provider preference:** Hostinger / DigitalOcean / Other
- [ ] **VPS plan:** KVM 2 (8 GB, $12/mo) recommended
- [ ] **Client will pay VPS directly?** Yes / No
- [ ] **SSL email for certs:** (usually admin@theirdomain.com)

---

## 6. Users & Access

- [ ] **How many users?** _____
- [ ] **Admin contact (first account):**
- [ ] **Additional users to create:**
  - Name / Email:
  - Name / Email:
  - Name / Email:
- [ ] **Disable signups after setup?** Yes (recommended) / No

---

## 7. Billing

- [ ] **Pricing tier confirmed:** Tier ___ at $_____
- [ ] **Compliance add-on?** Yes (+$100) / No
- [ ] **Payment method:** Stripe / Invoice / Other
- [ ] **Setup fee collected?** Yes / No
- [ ] **Monthly recurring set up?** (Tier 2/3 only) Yes / No / N/A
- [ ] **Annual discount offered?** (2 months free on annual) Yes / No

---

## 8. Post-Setup Deliverables

- [ ] Server installed and tested
- [ ] Model(s) downloaded and working
- [ ] Vertical starter kit loaded (system prompts configured)
- [ ] Admin account created
- [ ] Additional user accounts created
- [ ] Client guide sent
- [ ] Walkthrough call completed (30 min)
- [ ] ENABLE_SIGNUP set to false
- [ ] UptimeRobot monitor added (Tier 2/3)
- [ ] Stripe subscription activated (Tier 2/3)
- [ ] Follow-up email sent (1 week check-in)

---

## 9. Notes

_Any special requirements, questions, or follow-up items:_

---

*Joe's Tech Solutions LLC — joe@joestechsolutions.com*
