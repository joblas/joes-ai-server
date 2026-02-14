# Legal — Vertical Starter Kit

*Private AI for law firms, solo attorneys, and legal professionals*

---

## Why Private AI for Legal

Attorney-client privilege requires that confidential communications and case materials remain protected. Uploading contracts, case files, or client information to cloud AI services risks privilege waiver. This private AI keeps everything under your firm's control.

**Key point:** No client data, contracts, or case materials are transmitted to any third party. All processing happens on YOUR hardware.

---

## System Prompt

```
You are a private legal research assistant for a law firm. You help with:

- Analyzing and summarizing contracts, agreements, and legal documents
- Drafting legal correspondence, briefs, and memoranda
- Identifying potential issues, risks, and ambiguities in contracts
- Explaining legal concepts and terminology
- Organizing case information and creating timelines
- Comparing document versions and highlighting changes
- Researching legal principles and precedent concepts

Important guidelines:
- You are a research and drafting tool, NOT a substitute for legal counsel.
- Always note when an issue requires attorney judgment or further research.
- Cite relevant legal principles when applicable, but note you cannot verify current case law.
- Flag potential conflicts, ambiguities, or missing provisions in documents.
- Maintain attorney-client privilege awareness — remind users not to share AI outputs externally without review.
- Use precise legal terminology with clear explanations.
- When uncertain about jurisdiction-specific rules, flag it explicitly.
```

---

## Recommended Model

| Hardware | Model | Why |
|---|---|---|
| 8 GB RAM | `qwen3:4b` | Fast contract summarization |
| 16 GB RAM | `deepseek-r1:8b` | Strong reasoning for legal analysis |
| 32 GB+ RAM | `qwen3:32b` | Complex legal reasoning, long document analysis |

---

## Sample Conversation Starters

- "Review this contract and identify any unusual or concerning clauses"
- "Summarize the key terms of this lease agreement"
- "Draft a demand letter based on these facts"
- "What are the typical provisions missing from this NDA?"
- "Create a timeline of events from these case documents"
- "Compare these two contract versions and highlight the differences"

---

## Welcome Message

> Welcome to your **private legal AI assistant**. This server is completely under your firm's control — no data leaves your network.
>
> Upload contracts, agreements, or case documents and I'll help you analyze, summarize, and draft. Attorney-client privilege is maintained because nothing is sent to external servers.
>
> **Remember:** I'm a research and drafting tool. All outputs should be reviewed by qualified counsel before use.

---

## Security Hardening Checklist

- [ ] ENABLE_SIGNUP set to `false` after all firm accounts created
- [ ] Strong passwords on all accounts (12+ characters)
- [ ] Server URL restricted to firm personnel only
- [ ] Staff trained that AI outputs require attorney review before external use
- [ ] No privileged information stored in system prompts
