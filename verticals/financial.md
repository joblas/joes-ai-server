# Financial / Accounting — Vertical Starter Kit

*Private AI for financial advisors, accountants, and bookkeepers*

---

## Why Private AI for Financial Services

Client financial data — tax returns, account statements, investment portfolios — is highly sensitive. Cloud AI services process data on external servers, creating compliance and confidentiality risks. This private AI keeps all financial data under your control.

**Key point:** No client financial data is transmitted to any third party. All processing stays on YOUR hardware.

---

## System Prompt

```
You are a private financial assistant for an accounting or financial advisory practice. You help with:

- Analyzing financial statements and reports
- Summarizing tax documents and identifying key figures
- Drafting client correspondence and financial summaries
- Explaining tax concepts and financial regulations in plain language
- Organizing financial data and creating comparisons
- Reviewing invoices, expense reports, and budgets
- Identifying discrepancies or unusual patterns in financial data

Important guidelines:
- You are a productivity tool, NOT a licensed financial advisor or tax preparer.
- Always note when an issue requires professional judgment or CPA review.
- Be precise with numbers — double-check calculations when possible.
- Flag potential compliance concerns or unusual transactions.
- Maintain client confidentiality awareness at all times.
- When uncertain about jurisdiction-specific tax rules, flag it explicitly.
- Never provide definitive tax advice — present information for professional review.
```

---

## Recommended Model

| Hardware | Model | Why |
|---|---|---|
| 8 GB RAM | `qwen3:4b` | Fast document summarization |
| 16 GB RAM | `deepseek-r1:8b` | Strong math and reasoning for financial analysis |
| 32 GB+ RAM | `qwen3:32b` | Complex financial modeling and analysis |

---

## Sample Conversation Starters

- "Summarize the key figures from this financial statement"
- "Compare this quarter's P&L to last quarter and highlight changes"
- "Draft a client letter explaining their tax situation"
- "Review this expense report and flag anything unusual"
- "What tax deductions might apply to a home-based business?"
- "Create a summary of this client's financial position for our review"

---

## Welcome Message

> Welcome to your **private financial AI assistant**. All client financial data stays on YOUR server — nothing is sent to external services.
>
> Upload financial statements, tax documents, or expense reports and I'll help you analyze, summarize, and draft communications.
>
> **Remember:** I'm a productivity tool. All financial advice and tax positions should be reviewed by a qualified professional.

---

## Security Hardening Checklist

- [ ] ENABLE_SIGNUP set to `false` after all staff accounts created
- [ ] Strong passwords on all accounts (12+ characters)
- [ ] Server access restricted to authorized staff only
- [ ] No client identifiers stored in system prompts
- [ ] Staff trained on appropriate use (analysis tool, not advisory)
