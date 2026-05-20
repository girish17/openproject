# Azure VM Deployment Guide for Yojana

> **Audience**: Coding agents and DevOps engineers performing production deployments.
> **Strategy**: Blue-green zero-downtime deployment with instant rollback capability.
> **Last updated**: 2026-05-18

---

## Architecture Overview

```
                         Blue (current)                 Green (incoming)
                         ┌──────────────┐              ┌──────────────────┐
Internet ──► Caddy ──────►  yojana      │   8080:80    │  yojana-green    │  8081:80
(HTTPS)       (reverse    │  container   │              │  container       │
yojana.        proxy)     │  (pgdata in  │              │  pgdata via      │
girishm.info              │  writable    │              │  host bind mount │
                          │  layer)      │              │  /opt/yojana/    │
                          └──────────────┘              │  pgdata          │
                                                        └──────────────────┘

Caddy configuration: /etc/caddy/Caddyfile
yojana.girishm.info { reverse_proxy localhost:8080 }
```

### Key Principles

1. **Zero downtime** — Caddy reloads are sub-second, sessions are not disrupted
2. **Instant rollback** — old container is renamed, never deleted until fully validated
3. **Data safety** — pg_dump backup before any changes; old container's pgdata untouched
4. **Host bind mount** — `/opt/yojana/pgdata` for green container; once confirmed, future deployments reuse it

---

## Environment Reference

| Attribute | Value |
|---|---|
| **Azure subscription** | `00000000-0000-0000-0000-000000000000` |
| **Resource group** | `AZUREQUANTUM` |
| **VM name** | `element` |
| **Public IP** | `127.0.0.1` |
| **Domain** | `yojana.girishm.info` |
| **Docker Hub image** | `girish17/yojana:dev-azure` (also `:latest`) |
| **Image type** | `all-in-one` (PostgreSQL + Apache + Rails bundled) |
| **Platform** | `linux/amd64` (x86_64) |
| **Container ports** | Blue: `8080:80`, Green: `8081:80` |
| **Caddyfile path** | `/etc/caddy/Caddyfile` |
| **pgdata (host)** | `/opt/yojana/pgdata` |
| **pgdata (container)** | `/var/openproject/pgdata` |
| **Build host** | ARM64 Mac (Apple Silicon) — requires Docker Buildx + QEMU |

### Build Script

`bin/build-docker-azure` generates the tag as `{git-branch}-azure` (e.g., `dev-azure`). To push both `latest` and the branch tag:

```bash
docker buildx build --push \
  --platform linux/amd64 \
  -t girish17/yojana:latest \
  -t girish17/yojana:dev-azure \
  --target all-in-one \
  -f docker/prod/Dockerfile .
```

---

## Deployment Procedure (Blue-Green)

All remote commands use `az vm run-command invoke`. The local shell variable `RG` captures the repetition:

```bash
RG="--subscription 00000000-0000-0000-0000-000000000000 --resource-group AZUREQUANTUM --name element --command-id RunShellScript"
```

### Phase 1 — Preparation (live container unaffected)

| Step | Command | Why |
|------|---------|-----|
| **1a – Backup** | `az vm run-command invoke $RG --scripts "docker exec yojana bash -c 'su - postgres -c \\"pg_dump -U openproject openproject > /tmp/yojana-pre-upgrade.sql\\"'"` | Consistent snapshot before any change |
| **1b – Copy dump to host** | `az vm run-command invoke $RG --scripts "docker cp yojana:/tmp/yojana-pre-upgrade.sql /tmp/"` | Dump survives container removal |
| **1c – Pull new image** | `az vm run-command invoke $RG --scripts "docker pull girish17/yojana:dev-azure"` | Image ready on VM before green starts |

> **Safety**: Old container `yojana` still serves traffic on port 8080 throughout Phase 1.

### Phase 2 — Deploy Green Container

| Step | Command | Why |
|------|---------|-----|
| **2a – Extract pgdata** | `az vm run-command invoke $RG --scripts "docker cp yojana:/var/openproject/pgdata /tmp/pgdata && sudo mkdir -p /opt/yojana/pgdata && sudo cp -a /tmp/pgdata/* /opt/yojana/pgdata/ && sudo chown -R 999:999 /opt/yojana/pgdata"` | Copy existing data to host bind mount |
| **2b – Start green** | `az vm run-command invoke $RG --scripts "docker run -d --name yojana-green -p 8081:80 -v /opt/yojana/pgdata:/var/openproject/pgdata -e SECRET_KEY_BASE=\$(openssl rand -hex 64) girish17/yojana:dev-azure"` | Green on 8081, same pgdata via bind mount |
| **2c – Wait for Postgres init** | `az vm run-command invoke $RG --scripts "sleep 90"` | Entrypoint initializes Postgres cluster |
| **2d – Run migrations** | `az vm run-command invoke $RG --scripts "docker exec yojana-green rake db:migrate"` | Apply any new schema changes |
| **2e – Verify green health** | `az vm run-command invoke $RG --scripts "curl -s -o /dev/null -w '%{http_code}' http://localhost:8081"` | Expect `200` |

> **Safety**: Old container still serves on 8080. If green fails (step 2b–2e), stop here and roll back (see below) — no traffic impact.

### Phase 3 — Swap Traffic (Zero Downtime)

| Step | Command | Why |
|------|---------|-----|
| **3a – Update Caddyfile** | `az vm run-command invoke $RG --scripts "sudo sed -i 's/localhost:8080/localhost:8081/' /etc/caddy/Caddyfile"` | Point Caddy at green |
| **3b – Graceful reload Caddy** | `az vm run-command invoke $RG --scripts "sudo systemctl reload caddy"` | Zero-downtime reload (sub-second) |
| **3c – Rename old to blue** | `az vm run-command invoke $RG --scripts "docker rename yojana yojana-blue"` | Preserve old container for rollback |
| **3d – Rename green to primary** | `az vm run-command invoke $RG --scripts "docker rename yojana-green yojana"` | New container becomes the primary |
| **3e – Stop blue** | `az vm run-command invoke $RG --scripts "docker stop yojana-blue"` | Frees port 8080 |

> **Note**: Step 3a and 3b can be combined into a single command; they are separated above for clarity.

---

## Rollback Procedures

### Rollback During Phase 1 (before green starts)

**Situation**: New image pull failed or corrupted.
**Action**: Stop here. Production unaffected. Fix the image locally, rebuild, push, retry.

### Rollback During Phase 2 (green deployed, but not serving traffic)

**Situation**: Green container fails to start, or migrations fail.
**Action**: Tear down green. Blue (old container) still serves on 8080.

```bash
# Full rollback command (Phase 2)
az vm run-command invoke $RG --scripts \
  "docker stop yojana-green && docker rm yojana-green"
```

**Post-rollback**: Fix the image locally, rebuild, push, retry from Phase 2a.

### Rollback After Phase 3 (traffic swapped, green has bugs)

**Situation**: Users report errors, AI features broken, performance regression.

```bash
# Full rollback command (Phase 3) — zero downtime
az vm run-command invoke $RG --scripts \
  "sudo sed -i 's/localhost:8081/localhost:8080/' /etc/caddy/Caddyfile && sudo systemctl reload caddy && docker start yojana-blue"
```

**What this does**:
1. Swaps Caddy back to `localhost:8080` (the old container)
2. Gracefully reloads Caddy (sub-second)
3. Starts the `yojana-blue` container (cold-start ~10 seconds; Postgres cluster already exists, so fast)

**Total effective downtime**: ~10 seconds (until blue's Postgres is ready), but Caddy instantly routes to `localhost:8080` — the app becomes available as soon as Docker starts the process. During this window, Caddy returns `502 Bad Gateway` briefly, then back to normal.

### Rollback Timeline Matrix

| Rollback triggered at | Blue container state | Green container state | User impact | Time to restore |
|---|---|---|---|---|
| Phase 1 | Running (8080) | Doesn't exist | None | 0s |
| Phase 2 | Running (8080) | Stopped/removed | None | 0s |
| Phase 3 (immediate) | Stopped (named yojana-blue) | Running (8080) | ~10s 502 | ~10s |
| Phase 3 (days later) | Stopped (named yojana-blue) | Running (8080) | ~10s 502 | ~10s |

### Cleanup After Successful Deployment

After a confidence period (recommended: 1–3 days of successful operation):

```bash
az vm run-command invoke $RG --scripts \
  "docker rm yojana-blue && sudo rm -rf /tmp/yojana-pre-upgrade.sql /tmp/pgdata-backup"
```

---

## Data Safety & Integrity

### What protects your data

| Protection | Implementation |
|---|---|
| **pg_dump backup** | Full SQL dump created before any container changes (Phase 1a) |
| **Old container preserved** | Renamed to `yojana-blue` — its pgdata remains intact in its writable layer at `/var/openproject/pgdata` |
| **Copy-on-read for bind mount** | Green container reads a *copy* of pgdata — never writes to the original |
| **Postgres UID** | `chown 999:999` ensures container can read the bind mount (Postgres internal UID) |
| **Migration rollback** | If `rake db:migrate` fails, green is discarded and blue continues with original schema + data |

### Recovery from pg_dump backup (catastrophic scenario)

If both containers are lost:

```bash
# Start a fresh container with an empty bind mount
az vm run-command invoke $RG --scripts \
  "docker run -d --name yojana-recovery -p 8080:80 -v /opt/yojana/pgdata:/var/openproject/pgdata -e SECRET_KEY_BASE=\$(openssl rand -hex 64) girish17/yojana:dev-azure"

# Copy dump into container
az vm run-command invoke $RG --scripts \
  "docker cp /tmp/yojana-pre-upgrade.sql yojana-recovery:/tmp/"

# Restore
az vm run-command invoke $RG --scripts \
  "docker exec yojana-recovery bash -c 'su - postgres -c \\"psql -U openproject -f /tmp/yojana-pre-upgrade.sql\\"'"
```

---

## Troubleshooting

### Container won't start

```bash
az vm run-command invoke $RG --scripts "docker logs yojana-green --tail 50"
```

Common issues:
- **Port conflict** (`bind: address already in use`): Another process on 8081. Stop it or pick a different green port.
- **Permission denied** on `/opt/yojana/pgdata`: Verify `sudo chown -R 999:999 /opt/yojana/pgdata`.
- **Postgres password auth failed**: The pgdata is from a previous image version with a different `pg_hba.conf`. Run the password fix inside green: `docker exec yojana-green bash -c "su - postgres -c \\"psql -c \\\\\\"ALTER USER openproject WITH PASSWORD 'openproject';\\\\\\"\\""`

### Migrations fail

```bash
az vm run-command invoke $RG --scripts "docker exec yojana-green rake db:migrate:status"
```

If a migration is stuck or failed, roll back green and investigate the migration code before retrying.

### Caddy reload fails

```bash
az vm run-command invoke $RG --scripts "sudo systemctl status caddy && sudo journalctl -u caddy --tail 30"
```

If Caddy fails to reload, the old config is still active — no traffic loss. Fix the Caddyfile syntax and retry.

### Azure CLI authentication fails

```bash
az login
```

Ensure you have the `AzureQuantum` resource group contributor role.

### Azure VM unresponsive or `az vm run-command` times out

**Symptoms**: Command hangs for 60+ seconds, returns `(ProvisioningState: Failed)`, "Unable to connect to the VM", or a generic HTTP gateway error.

**Root causes**:
- VM is stopped/deallocated (most common)
- VM is under high CPU/memory pressure (run-command agent can't respond)
- Azure Linux Agent (`walinuxagent`) is not running or crashed inside the VM
- Temporary Azure networking issue
- Command itself is a long-running operation (e.g., `docker pull` on slow internet, `docker exec` on a busy container)

**Diagnostic steps**:

```bash
# 1 — Quick availability check (uses Azure control plane, not the VM agent)
az vm get-instance-view --subscription 00000000-0000-0000-0000-000000000000 --resource-group AZUREQUANTUM --name element --query "statuses[?code=='PowerState/running'].displayStatus"
```
Expected: `"VM running"`. If "VM deallocated" or "VM stopped", start the VM:
```bash
az vm start --subscription 00000000-0000-0000-0000-000000000000 --resource-group AZUREQUANTUM --name element
```
Wait 2–3 minutes for boot + agent startup, then retry.

```bash
# 2 — Check the run-command agent status (heartbeat from within the VM)
az vm run-command invoke $RG --scripts "echo OK"
```
If this succeeds but docker commands hang, the problem is Docker, not the VM agent.

```bash
# 3 — If docker commands hang specifically, check for a hung process
az vm run-command invoke $RG --scripts "docker ps 2>&1 || (systemctl status docker --no-pager 2>&1 | tail -10)"
```

**Recovery actions**:

| Issue | Action |
|---|---|
| VM is stopped/deallocated | `az vm start ...` and wait 3 min |
| Azure Agent not responding | Restart the agent: `az vm run-command invoke $RG --scripts "sudo systemctl restart walinuxagent"` (may fail if agent is truly dead — try next row) |
| Agent completely unresponsive | Restart the VM from Azure control plane: `az vm restart --subscription ... --resource-group AZUREQUANTUM --name element` |
| Docker daemon hung | `az vm run-command invoke $RG --scripts "sudo systemctl restart docker"` |
| Command takes > 90 seconds | Set a longer timeout on `az vm run-command invoke`: add `--timeout 300` (seconds) to the command |

**Preventing timeouts on long operations**:

Some Phase 2 steps (like `docker pull`, `sleep 90`, `docker exec ... rake db:migrate`) can exceed the default Azure run-command timeout (~90 seconds). For these, use the `--timeout` flag:

```bash
# Long-running commands need an explicit timeout
az vm run-command invoke $RG --timeout 300 \
  --scripts "docker pull girish17/yojana:dev-azure"
```

The `sleep 90` in Phase 2c is intentionally a separate short command to avoid timeout issues. If combining steps, always set `--timeout` appropriately.

**Alternative: direct SSH access** (fallback if run-command is persistently broken):

```bash
# If you have SSH key access configured
ssh adminuser@127.0.0.1

# If you have Azure AD-based SSH
az ssh vm --ip 127.0.0.1 --subscription 00000000-0000-0000-0000-000000000000
```

`az ssh vm` uses Azure AD authentication and does not depend on the `walinuxagent` — it can work when `az vm run-command` does not.

---

## Quick Reference

### One-shot build and push (from local ARM Mac)

```bash
docker buildx build --push \
  --platform linux/amd64 \
  -t girish17/yojana:latest \
  -t girish17/yojana:dev-azure \
  --target all-in-one \
  -f docker/prod/Dockerfile .
```

### Azure shell alias

```bash
RG="--subscription 00000000-0000-0000-0000-000000000000 --resource-group AZUREQUANTUM --name element --command-id RunShellScript"
```

Check what's running:
```bash
az vm run-command invoke $RG --scripts "docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"
```

View logs:
```bash
az vm run-command invoke $RG --scripts "docker logs yojana --tail 30"
```

Exec into the running container:
```bash
az vm run-command invoke $RG --scripts "docker exec yojana bash -c 'cat /etc/os-release | head -3'"
```

### Future deployment (when bind mount already exists)

Once the bind mount at `/opt/yojana/pgdata` is established from a successful green deployment, future deployments skip Phase 2a (no need to extract pgdata again — the bind mount is the source of truth). The flow becomes:

1. Phase 1: Backup + pull
2. Phase 2: Start green with existing `/opt/yojana/pgdata` + migrate
3. Phase 3: Swap Caddy + rename

---

## Pre-deployment Checklist

- [ ] Local changes committed and pushed to GitHub
- [ ] Docker image built and pushed to Docker Hub (both `latest` and `dev-azure`)
- [ ] `az login` successful
- [ ] Caddyfile on VM known and readable (`/etc/caddy/Caddyfile`)
- [ ] Enough disk space on VM (`df -h` via run-command)
- [ ] Backup pg_dump download tested (can reach VM through Azure CLI)
- [ ] Migration SQL reviewed (no destructive column drops or irreversible changes)

## Post-deployment Verification

- [ ] `curl -s -o /dev/null -w '%{http_code}' http://localhost:8081` returns `200`
- [ ] Domain resolves: `curl -s -o /dev/null -w '%{http_code}' https://yojana.girishm.info` returns `200`
- [ ] Login works: `admin` / `changeme!`
- [ ] Existing projects and work packages visible
- [ ] AI features functional: chat drawer opens, inline AI suggestions render
- [ ] Agent page loads: `/ai/agents`
- [ ] Old container renamed to `yojana-blue`, stopped
- [ ] Rollback procedure documented and tested mentally
