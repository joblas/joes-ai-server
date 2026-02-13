# Troubleshooting Guide

## Common Issues

### Open WebUI shows "Model not found" or no models available

**Cause:** No models have been downloaded yet, or Ollama hasn't finished starting.

**Fix:**
```bash
# Check if Ollama is running
docker exec ollama ollama list

# If empty, pull a model
docker exec ollama ollama pull qwen3:4b

# If Ollama isn't responding, restart it
docker compose restart ollama
```

---

### "Connection refused" when accessing the URL

**Check 1:** Are containers running?
```bash
cd /opt/joes-ai-stack
docker compose ps
```

**Check 2:** Is the firewall allowing traffic?
```bash
sudo ufw status
# Should show 80/tcp and 443/tcp ALLOW
```

**Check 3:** Is DNS pointing to the right IP?
```bash
dig +short ai.yourclient.com
# Should return the VPS IP
```

---

### HTTPS certificate not working

**Cause:** DNS hasn't propagated yet, or port 80 is blocked.

**Fix:**
```bash
# Check Caddy logs
docker compose logs caddy

# Verify port 80 is open externally
curl -I http://ai.yourclient.com

# Force Caddy to retry certificates
docker compose restart caddy
```

Caddy needs port 80 open for the ACME challenge. Make sure no other service is using port 80.

---

### Slow responses from AI models

**Cause:** The VPS doesn't have enough RAM for the model, or the model is too large.

**Fix:**
- Use smaller models: `qwen3:4b` (2.6 GB) instead of larger ones
- Check available memory: `free -h`
- For 8GB VPS, stick to 4B–8B parameter models
- Consider quantized models: all Ollama models use Q4 quantization by default

---

### Container keeps restarting

```bash
# Check which container is failing
docker compose ps

# View its logs
docker compose logs <container_name> --tail 50

# Common fixes:
# - If ollama: usually disk space (models are large)
# - If open-webui: usually a bad WEBUI_SECRET_KEY in .env
# - If caddy: usually DNS not pointing to server yet
# - If watchtower: usually Docker API version mismatch
```

---

### Watchtower updated something and it broke

```bash
# Check what Watchtower did
docker logs watchtower --tail 20

# Roll back to a specific image version
docker compose down
# Edit docker-compose.yml to pin the image version, e.g.:
#   image: ghcr.io/open-webui/open-webui:v0.5.6
docker compose up -d
```

To prevent this, you can set Watchtower to monitor-only mode:
```yaml
environment:
  - WATCHTOWER_MONITOR_ONLY=true
```

---

### Out of disk space

```bash
# Check disk usage
df -h

# Clean up Docker (removes old images)
docker system prune -af

# Check model sizes
docker exec ollama ollama list

# Remove unused models
docker exec ollama ollama rm <model_name>
```

---

### Backup/Restore

**Manual backup:**
```bash
/opt/joes-ai-stack/scripts/backup.sh
```

**Restore from backup:**
```bash
# List available backups
ls -la /opt/joes-ai-backups/

# Restore (will prompt for confirmation)
/opt/joes-ai-stack/scripts/restore.sh 20250212_030000
```

---

## Quick Diagnostics Checklist

```bash
# Run all checks at once
echo "=== Docker ===" && docker compose ps
echo "=== Disk ===" && df -h /
echo "=== Memory ===" && free -h
echo "=== Ollama Models ===" && docker exec ollama ollama list
echo "=== Caddy ===" && docker compose logs caddy --tail 5
echo "=== Last Backup ===" && ls -lt /opt/joes-ai-backups/ | head -5
```

---

## Emergency: Full Reinstall

If everything is broken beyond repair:

```bash
cd /opt/joes-ai-stack
docker compose down -v   # WARNING: -v removes all data volumes
AI_DOMAIN=ai.client.com EMAIL=admin@client.com \
  curl -fsSL https://raw.githubusercontent.com/joblas/joes-ai-server/main/install-vps.sh | bash
```

This gives a fresh start. Models will need to be re-downloaded.
