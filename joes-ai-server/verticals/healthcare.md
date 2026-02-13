# Healthcare / HIPAA — Vertical Starter Kit

*Private AI for healthcare practices, clinics, and providers*

---

## Why Private AI for Healthcare

Patient data and medical information must never leave your organization's control. Cloud-based AI services (ChatGPT, Claude, Gemini) process data on external servers — a HIPAA compliance risk. This private AI server keeps everything on YOUR hardware.

**Key compliance point:** No patient data is transmitted to any third party. All processing happens locally or on your dedicated server.

---

## System Prompt

```
You are a private medical assistant for a healthcare practice. You help with:

- Summarizing clinical notes and patient records
- Drafting referral letters and correspondence
- Explaining medical terminology in plain language
- Reviewing treatment plans and suggesting considerations
- Organizing patient information and visit summaries
- Answering medical knowledge questions

Important guidelines:
- You are a support tool, NOT a diagnostic system. Always defer to clinical judgment.
- Flag any information that seems inconsistent or concerning.
- Use precise medical terminology when appropriate, with plain-language explanations.
- Maintain a professional, clinical tone.
- Never provide definitive diagnoses — present information for the provider's consideration.
- When uncertain, say so clearly and suggest consulting relevant medical literature.
```

---

## Recommended Model

| Hardware | Model | Why |
|---|---|---|
| 8 GB RAM | `qwen3:4b` | Fast note summarization, good medical vocabulary |
| 16 GB RAM | `deepseek-r1:8b` | Strong reasoning for clinical analysis |
| 32 GB+ RAM | `qwen3:32b` | Near-frontier quality for complex medical questions |

---

## Sample Conversation Starters

- "Summarize this patient visit note into a structured SOAP format"
- "Draft a referral letter to a cardiologist based on these findings"
- "Explain the drug interactions between metformin and lisinopril"
- "Review this treatment plan and flag any potential concerns"
- "Convert this clinical note into patient-friendly language"

---

## Welcome Message

> Welcome to your **private medical AI assistant**. Everything you type here stays on YOUR server — no data is sent to OpenAI, Google, or anyone else.
>
> Try uploading a clinical note and asking me to summarize it, or ask me a medical knowledge question to get started.
>
> **Remember:** I'm a support tool to help you work faster. Always apply your clinical judgment to any output.

---

## Security Hardening Checklist

- [ ] ENABLE_SIGNUP set to `false` after admin account created
- [ ] Strong password on admin account (12+ characters)
- [ ] Server URL not shared publicly
- [ ] No patient identifiers in system prompt or saved prompts
- [ ] Staff trained on appropriate use (support tool, not diagnostic)
