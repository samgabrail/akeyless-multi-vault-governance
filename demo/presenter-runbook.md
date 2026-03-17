# Presenter Runbook — Webinar Demo

**Format:** 30 min total — 15 min slides + 15 min live demo (5 acts)

---

## Pre-Demo Checklist (run ~30 min before going live)

### Infrastructure
- [ ] Start both Vault dev instances: `bash demo/setup-vault-dev.sh`
- [ ] Verify backend Vault: `VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault kv list secret/myapp`
- [ ] Verify payments Vault: `VAULT_ADDR=http://127.0.0.1:8202 VAULT_TOKEN=root vault kv list secret/payments`
- [ ] Verify Akeyless Gateway pods: `kubectl get pods -n akeyless`

### Akeyless configuration
- [ ] Verify USCs visible in Akeyless UI: `MVG-demo/vault-usc-backend`, `MVG-demo/vault-usc-payments`
- [ ] Verify rotated secrets exist: `MVG-demo/azure-app-rotated-secret`, `MVG-demo/db-rotated-password`
- [ ] Verify MySQL sync is active on `MVG-demo/db-rotated-password` (wired to `MVG-demo/vault-usc-backend`)
- [ ] Verify RBAC roles: `demo-readonly-role`, `demo-denied-role`

### Act 1 — clean up sync demo paths
Run in terminal (not on screen):
```bash
source demo/demo-commands.sh
_act1_cleanup
```

### HVP token
- [ ] `cat ~/.vault-token` — confirm it contains `<Access Id>..<Access Key>` (not expired)
- [ ] `VAULT_ADDR=https://hvp.akeyless.io vault kv get secret/myapp/db-password` — confirm it returns a value

### Shell environment
- [ ] Source the demo script in the **on-screen terminal**: `source demo/demo-commands.sh`
- [ ] Confirm env vars are set: `echo $DENIED_ACCESS_ID $USC_BACKEND`

### Browser tabs (pre-open and navigate before going live)
- [ ] Akeyless console — logged in, at home/dashboard
- [ ] Vault UI backend — `http://localhost:8200/ui` — logged in, browsed to `secret/`
- [ ] Vault UI payments — `http://localhost:8202/ui` — logged in, browsed to `secret/`
- [ ] Azure portal — Key Vault `akl-mvg-demo-kv` → Secrets → `demo-app-client-secret`

### Dry-run audit log
- [ ] Trigger a test rotation (either rotated secret) and a denied access attempt (Act 4 CLI command)
- [ ] Open Logs tab — confirm events appear and you know how to filter by timeframe
- [ ] Note the demo start time — use it to filter out test-run noise during Act 5

---

## Act-by-Act Guide (15 min live demo)

### Act 1 — Multi-Cluster Governance (~4 min)
**Open:** Akeyless UI

1. Show **Targets** — *"Two isolated Vault clusters. Different teams, different networks."*
2. Show **Universal Secrets Connectors** — *"Akeyless bridges them both. One control plane."*
3. Browse existing synced secrets — *"Already governed from day one."*
4. **Vault UI → create** `secret/myapp/created-from-vault` → switch to Akeyless UI → show it appears under `MVG-demo/vault-usc-backend`
   - *"Created in Vault. Visible in Akeyless instantly."*
5. **Akeyless UI → create** `secret/myapp/created-from-akeyless` under `MVG-demo/vault-usc-backend` → switch to Vault UI → show it synced
   - *"Created in Akeyless. Lands in Vault automatically."*

**Message:** *One control plane. Multiple isolated clusters. Any secrets manager. Bidirectional.*

**Transition:** *"Now let's see the rotation engine."*

---

### Act 2 — Rotation + Sync (~6 min)
**Open:** Akeyless UI

#### Azure App Registration (~3 min)
1. Rotated Secrets → `MVG-demo/azure-app-rotated-secret` → **Rotate Now**
2. Switch to pre-opened Azure portal tab → `akl-mvg-demo-kv` → Secrets → `demo-app-client-secret` — show updated value and new timestamp
3. *"The app reads from Key Vault. It never touches the rotation. Akeyless handles it."*

#### Database rotation (~3 min)
1. Rotated Secrets → `MVG-demo/db-rotated-password` → **Rotate Now**
2. Switch to Vault UI → `secret/myapp/db-password` — show the updated password value
3. *"Rotated credential, synced to Vault. The app reads from Vault — unchanged."*

**Message:** *Akeyless owns the rotation lifecycle. Downstream consumers — Key Vault, Vault, or anything else — receive updated secrets automatically.*

**Transition:** *"Same vault CLI they've always used — let me show you."*

---

### Act 3 — HVP: Zero Disruption (~2 min)
**Open:** Terminal

```bash
export VAULT_ADDR='https://hvp.akeyless.io'
vault kv get secret/myapp/db-password
vault kv get secret/myapp/api-key
```

*"Same commands. Same workflow. Zero changes. Teams using the vault CLI don't need to know Akeyless exists."*

**Transition:** *"Who controls what gets accessed? Let's look at RBAC."*

---

### Act 4 — RBAC Governance (~2 min)
**Open:** Akeyless UI

1. Access Roles → `demo-readonly-role` — *"Read access, both clusters."*
2. Access Roles → `demo-denied-role` — *"Explicitly blocked."*
3. Switch to terminal — run the denied access command (already in shell history / `demo-commands.sh` Act 4 section):
   ```bash
   DENIED_TOKEN=$(akeyless auth \
     --access-id "$DENIED_ACCESS_ID" \
     --access-key "$DENIED_ACCESS_KEY" \
     --access-type access_key --json 2>/dev/null \
     | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")

   akeyless usc get \
     --usc-name "$USC_BACKEND" \
     --secret-id "secret/myapp/db-password" \
     --gateway-url "$AKEYLESS_GW" \
     --token "$DENIED_TOKEN"
   ```
   Expected output: permission denied error
4. *"One deny policy. Both clusters. Every connected secrets manager."*

**Transition:** *"Every action we just took — it's all recorded."*

---

### Act 5 — Audit Trail (~1 min)
**Open:** Akeyless UI → Logs tab

1. Filter to demo start time
2. Show rotation events (Azure App Reg, MySQL/DB)
3. Show the denied access attempt from Act 4

*"Full visibility across every cluster. One log. Every rotation, every access, every denial — nothing missing."*

---