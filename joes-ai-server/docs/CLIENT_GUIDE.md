# Your Private AI Server — Quick Start Guide

**Powered by Joe's Tech Solutions LLC**

---

## Welcome!

You now have your own private AI chat server. It works just like ChatGPT, but your conversations stay on YOUR computer — nothing is sent to OpenAI, Google, or anyone else.

---

## Getting Started

### 1. Open Your AI Server

Open your browser and go to: **http://localhost:3000**

Your AI server starts automatically when you log into your computer. If it's not running, open Terminal and type:
```bash
~/.joes-ai/start-server.sh
```

### 2. Create Your Account

The first person to sign up becomes the **admin**. Choose a strong password — this is the key to your AI server.

### 3. Start Chatting!

Select your AI model from the dropdown at the top (e.g., `qwen3:4b`), then type your question. That's it!

---

## Tips & Tricks

**Upload Documents:** Click the 📎 icon to upload PDFs, text files, or images. The AI will read and answer questions about them.

**Multiple Conversations:** Use the sidebar to create new chats and keep topics organized.

**Add More Users:** As admin, go to Admin Panel → Users to manage who has access.

**Switch Models:** Different models have different strengths. Try a few to see which you prefer.

---

## Managing Your Server

### Start & Stop

Your server runs automatically in the background. If you need to control it:

```bash
# Start the server
~/.joes-ai/start-server.sh

# Stop the server
~/.joes-ai/stop-server.sh
```

### Download Additional Models

Want to try a bigger or different AI model? Open Terminal and type:

```bash
# See what's installed
ollama list

# Download a new model
ollama pull qwen3:8b

# Remove a model you don't use (saves disk space)
ollama rm qwen3:4b
```

| Model | Size | Best For |
|---|---|---|
| `qwen3:4b` | ~2.6 GB | Rivals 72B quality, great for 8 GB machines |
| `qwen3:8b` | ~5.2 GB | Sweet spot performance, 40+ tokens/sec |
| `gemma3:12b` | ~8.1 GB | Google multimodal, strong reasoning |
| `deepseek-r1:8b` | ~4.9 GB | Advanced reasoning and coding |
| `qwen3:32b` | ~20 GB | Near-frontier quality, rivals GPT-4 (needs 32 GB+ RAM) |

**Recommendation:** Start with `qwen3:4b` — it's fast, fits on most hardware, and rivals much larger models.

---

## Frequently Asked Questions

**Q: Is my data private?**
Yes. Everything runs on your computer. No data is sent to any third party.

**Q: Can I use this offline?**
Yes! Once models are downloaded, everything works without internet.

**Q: Does it start automatically?**
Yes. The server starts when you log into your computer. No need to do anything.

**Q: How do I update?**
For Ollama updates:
```bash
brew upgrade ollama
```
For Open WebUI updates:
```bash
source ~/.joes-ai/venv/bin/activate
pip install --upgrade open-webui
```

**Q: Something isn't working. Who do I contact?**
Email **joe@joestechsolutions.com** — I'll get back to you within 24 hours.

---

## Important Security Notes

1. **Change ENABLE_SIGNUP to false** after all your users have created accounts (ask Joe to do this)
2. **Use strong passwords** for all accounts
3. **Don't share your server URL** publicly unless you want strangers signing up

---

## Quick Reference

| Action | Command |
|--------|---------|
| Start server | `~/.joes-ai/start-server.sh` |
| Stop server | `~/.joes-ai/stop-server.sh` |
| List models | `ollama list` |
| Download model | `ollama pull <model_name>` |
| Remove model | `ollama rm <model_name>` |
| Test a model | `ollama run qwen3:4b "hello"` |
| View logs | `cat ~/.joes-ai/logs/webui-stderr.log` |

---

*This server is managed by Joe's Tech Solutions LLC.*
*Support: joe@joestechsolutions.com*
