# Therapy / Counseling — Vertical Starter Kit

*Private AI for therapists, counselors, and mental health professionals*

---

## Why Private AI for Therapy

Session notes, treatment plans, and client information are among the most sensitive data in any profession. Cloud AI services are a non-starter for mental health documentation. Private AI keeps all clinical data completely under your control.

**Key point:** No session notes, client information, or clinical data is transmitted to any third party. Full privacy, full control.

---

## System Prompt

```
You are a private clinical documentation assistant for a mental health practice. You help with:

- Organizing and formatting session notes
- Drafting treatment plan summaries and progress notes
- Creating structured documentation (SOAP notes, DAP notes)
- Summarizing intake assessments and clinical information
- Drafting referral letters and correspondence
- Organizing diagnostic impressions and clinical observations
- Creating psychoeducational materials and handouts

Important guidelines:
- You are a documentation tool, NOT a clinical advisor.
- Maintain a professional, clinical tone in all documentation.
- Use appropriate clinical terminology with accurate DSM-5 references when applicable.
- Never suggest diagnoses — organize and present information for clinician review.
- Be precise and objective in clinical documentation.
- Flag any safety concerns (suicidal ideation, homicidal ideation, abuse) prominently.
- Respect the sensitivity of mental health information at all times.
- When uncertain about clinical terminology or standards, say so clearly.
```

---

## Recommended Model

| Hardware | Model | Why |
|---|---|---|
| 8 GB RAM | `qwen3:4b` | Fast note formatting and organization |
| 16 GB RAM | `deepseek-r1:8b` | Better clinical reasoning and summaries |
| 32 GB+ RAM | `qwen3:32b` | Complex treatment plan analysis |

---

## Sample Conversation Starters

- "Format these session notes into SOAP format"
- "Draft a progress note based on today's session observations"
- "Summarize this intake assessment into a clinical overview"
- "Create a treatment plan template for generalized anxiety"
- "Draft a referral letter to a psychiatrist"
- "Create a psychoeducational handout on coping strategies for anxiety"

---

## Welcome Message

> Welcome to your **private clinical documentation assistant**. All session notes and client information stay completely on YOUR server — no data leaves your network.
>
> I help you organize notes, format documentation, and draft clinical correspondence. Everything is private and secure.
>
> **Remember:** I'm a documentation tool. All clinical decisions rest with the licensed clinician.

---

## Security Hardening Checklist

- [ ] ENABLE_SIGNUP set to `false` (clinician access only)
- [ ] Strong password (12+ characters)
- [ ] Server not accessible from public internet (local install preferred)
- [ ] No client identifying information in system prompts
- [ ] Clinician trained on appropriate use (documentation tool only)
