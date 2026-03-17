# Webinar Demo Restructure Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure `demo/demo-commands.sh` and create a presenter runbook to match the approved 5-act webinar demo structure.

**Architecture:** The existing 9-chapter script is reorganized into 5 acts. The CLI script now only contains commands that are actually executed on-screen (Act 3 HVP + Act 4 denied access + Act 1 cleanup helpers). Everything else is shown in the Akeyless UI, Vault UI, or Azure portal — the script comments describe what to show in each UI.

**Tech Stack:** Bash, Akeyless CLI, Vault CLI, Markdown

**Spec:** `docs/superpowers/specs/2026-03-17-webinar-demo-restructure-design.md`

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `demo/demo-commands.sh` | Modify | Restructure into 5-act webinar flow |
| `demo/presenter-runbook.md` | Create | Day-of checklist + act-by-act UI navigation guide |

---

### Task 1: Restructure `demo/demo-commands.sh` into 5-act webinar flow

**Files:**
- Modify: `demo/demo-commands.sh`

The script should be the on-screen CLI companion for the webinar. Acts that are UI-only get a comment block describing what to show — no runnable commands. Acts with CLI steps get the exact commands.

- [ ] **Step 1: Replace the ENV VAR block at the top**

Replace the existing commented-out env var block with one that matches the webinar's variables (remove AWS/Azure USC vars not used in the webinar, add webinar-specific ones):

```bash
#!/usr/bin/env bash
# Webinar demo CLI companion — 5-act structure
# Only run sections that are marked as CLI steps.
# UI-only acts are documented here as comments for reference.
#
# SOURCE this file or copy-paste sections into your terminal.
# Do NOT run as a single script.

# ─────────────────────────────────────────────────────────────────────────────
# ENV — set these before the webinar (run once in your on-screen terminal)
# ─────────────────────────────────────────────────────────────────────────────
export VAULT_ADDR_BACKEND='http://127.0.0.1:8200'
export VAULT_ADDR_PAYMENTS='http://127.0.0.1:8202'
export LOCAL_VAULT_TOKEN='root'
export AKEYLESS_GW='https://192.168.1.82:8000'
export AKEYLESS_PROFILE='demo'
export USC_BACKEND='MVG-demo/vault-usc-backend'
export USC_PAYMENTS='MVG-demo/vault-usc-payments'
export ROTATED_AZURE_APP='MVG-demo/azure-app-rotated-secret'
export DB_ROTATED='MVG-demo/db-rotated-password'
export DENIED_ACCESS_ID='p-xzdtj47phxl5am'
export DENIED_ACCESS_KEY='KLFVvXCsGgJ1RKQYxpyimVZT14kEkkAQhZSOVe1zQo8='
```

- [ ] **Step 2: Write Act 1 — Multi-Cluster Governance (UI-only, with cleanup helpers)**

```bash
# ─────────────────────────────────────────────────────────────────────────────
# ACT 1: Multi-Cluster Governance (~4 min) — VAULT UI + AKEYLESS UI
# ─────────────────────────────────────────────────────────────────────────────
#
# SHOW IN AKEYLESS UI:
#   • Targets → demo-vault-target-backend (port 8200) and demo-vault-target-payments (port 8202)
#   • Universal Secrets Connectors → demo-vault-usc-backend and demo-vault-usc-payments
#   • Browse secrets already synced from the e2e setup
#
# LIVE SYNC DEMO — Vault → Akeyless:
#   • In Vault UI (http://localhost:8200/ui): create secret/myapp/created-from-vault
#   • Switch to Akeyless UI: show it appears under demo-vault-usc-backend
#
# LIVE SYNC DEMO — Akeyless → Vault:
#   • In Akeyless UI: create secret/myapp/created-from-akeyless under demo-vault-usc-backend
#   • Switch to Vault UI (http://localhost:8200/ui): show it synced to Vault
#
# MESSAGE: One control plane. Multiple isolated clusters. Any secrets manager. Bidirectional.

# Helper: clean up the live-created sync secrets before the webinar
# Run this in the pre-demo checklist (not during the live demo)
_act1_cleanup() {
  export VAULT_TOKEN="$LOCAL_VAULT_TOKEN"
  export VAULT_ADDR="$VAULT_ADDR_BACKEND"
  vault kv delete secret/myapp/created-from-vault 2>/dev/null || true
  vault kv delete secret/myapp/created-from-akeyless 2>/dev/null || true
  # Also delete from Akeyless if they exist from a prior run
  akeyless delete-item \
    --name "${USC_BACKEND}/secret/myapp/created-from-vault" \
    --profile "$AKEYLESS_PROFILE" 2>/dev/null || true
  akeyless delete-item \
    --name "${USC_BACKEND}/secret/myapp/created-from-akeyless" \
    --profile "$AKEYLESS_PROFILE" 2>/dev/null || true
  echo "Act 1 sync paths cleaned up."
}
```

- [ ] **Step 3: Write Act 2 — Rotation + Sync (UI-only comments)**

```bash
# ─────────────────────────────────────────────────────────────────────────────
# ACT 2: Rotation + Sync (~6 min) — AKEYLESS UI + AZURE PORTAL + VAULT UI
# ─────────────────────────────────────────────────────────────────────────────
#
# AZURE APP REGISTRATION ROTATION (~3 min):
#   • In Akeyless UI: Rotated Secrets → MVG-demo/azure-app-rotated-secret → Rotate Now
#   • Switch to Azure portal tab (pre-opened):
#       Key Vault akl-mvg-demo-kv → Secrets → demo-app-client-secret
#       Show updated secret value and timestamp confirming fresh rotation
#   • MESSAGE: Akeyless rotated the credential, synced it to Key Vault.
#              The app reads only from Key Vault — it never touches the rotation.
#
# DATABASE ROTATION (~3 min):
#   • In Akeyless UI: Rotated Secrets → MVG-demo/db-rotated-password → Rotate Now
#   • Switch to Vault UI (http://localhost:8200/ui):
#       secret/myapp/db-password — show the updated password value
#   • MESSAGE: Rotation synced to HashiCorp Vault via USC. The app reads from Vault — unchanged.
#
# MESSAGE: Akeyless owns the rotation lifecycle. Downstream consumers receive
#          updated secrets automatically — whether that's Key Vault, Vault, or any other target.
```

- [ ] **Step 4: Write Act 3 — HVP: Zero Disruption (CLI)**

```bash
# ─────────────────────────────────────────────────────────────────────────────
# ACT 3: HVP — Zero Disruption (~2 min) — TERMINAL
# ─────────────────────────────────────────────────────────────────────────────

export VAULT_ADDR='https://hvp.akeyless.io'
# ~/.vault-token is already set to <Access Id>..<Access Key> format

# Standard vault CLI — unchanged. Akeyless is now the backend.
vault kv get secret/myapp/db-password
vault kv get secret/myapp/api-key

# MESSAGE: Same commands. Same workflow. Zero changes required.
#          Teams using vault CLI don't need to know Akeyless exists.
```

- [ ] **Step 5: Write Act 4 — RBAC Governance (UI + CLI)**

```bash
# ─────────────────────────────────────────────────────────────────────────────
# ACT 4: RBAC Governance (~2 min) — AKEYLESS UI + TERMINAL
# ─────────────────────────────────────────────────────────────────────────────
#
# SHOW IN AKEYLESS UI:
#   • Access Roles → demo-readonly-role (read access to both USCs)
#   • Access Roles → demo-denied-role (explicitly blocked)
#   • MESSAGE: One RBAC policy governs access across every connected secrets manager.

# CLI: Trigger a denied access attempt to show enforcement in real time
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
# Expected: permission denied

# MESSAGE: One deny policy. Both clusters. Any connected secrets manager.
```

- [ ] **Step 6: Write Act 5 — Audit Trail (UI-only comment)**

```bash
# ─────────────────────────────────────────────────────────────────────────────
# ACT 5: Audit Trail (~1 min) — AKEYLESS UI
# ─────────────────────────────────────────────────────────────────────────────
#
# SHOW IN AKEYLESS UI:
#   • Logs tab → filter by current session timeframe (start of demo to now)
#   • Point out:
#       - Rotation events: Azure App Reg rotation, MySQL rotation
#       - Denied access attempt from Act 4
#   • NOTE: Verify during dry run whether sync events appear as distinct log entries.
#           If they do, highlight them. If not, focus on rotation + denied access.
#
# MESSAGE: Full visibility across every cluster, from one place.
#          Every rotation, every access, every denial — in one audit log.
```

- [ ] **Step 7: Verify the file is valid bash**

```bash
bash -n demo/demo-commands.sh
```
Expected: no output (no syntax errors).

---

### Task 2: Create `demo/presenter-runbook.md`

**Files:**
- Create: `demo/presenter-runbook.md`

This is the day-of guide. It has two sections: pre-demo checklist and act-by-act narration cues.

- [ ] **Step 1: Write the pre-demo checklist**

```markdown
# Presenter Runbook — Webinar Demo

## Pre-Demo Checklist (run ~30 min before going live)

### Infrastructure
- [ ] Start both Vault dev instances: `bash demo/setup-vault-dev.sh`
- [ ] Verify backend Vault: `VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root vault kv list secret/myapp`
- [ ] Verify payments Vault: `VAULT_ADDR=http://127.0.0.1:8202 VAULT_TOKEN=root vault kv list secret/payments`
- [ ] Verify Akeyless Gateway pods: `kubectl get pods -n akeyless`

### Akeyless configuration
- [ ] Verify USCs are visible in Akeyless UI: demo-vault-usc-backend, demo-vault-usc-payments
- [ ] Verify rotated secrets exist: MVG-demo/azure-app-rotated-secret, MVG-demo/db-rotated-password
- [ ] Verify MySQL sync is active on MVG-demo/db-rotated-password (wired to demo-vault-usc-backend)
- [ ] Verify RBAC roles: demo-readonly-role, demo-denied-role

### Act 1 — clean up sync demo paths
Run in terminal:
source demo/demo-commands.sh
_act1_cleanup

### HVP token
- [ ] `cat ~/.vault-token` — confirm it contains `<Access Id>..<Access Key>` (not expired)
- [ ] `VAULT_ADDR=https://hvp.akeyless.io vault kv get secret/myapp/db-password` — confirm it works

### Shell environment
- [ ] Source the demo script in the on-screen terminal: `source demo/demo-commands.sh`
- [ ] Confirm `$DENIED_ACCESS_ID` and `$DENIED_ACCESS_KEY` are set

### Browser tabs (pre-open and navigate before going live)
- [ ] Akeyless console — logged in, at home/dashboard
- [ ] Vault UI backend — http://localhost:8200/ui — logged in, at secret/ path
- [ ] Vault UI payments — http://localhost:8202/ui — logged in, at secret/ path
- [ ] Azure portal — Key Vault `akl-mvg-demo-kv` → Secrets → `demo-app-client-secret`

### Dry-run audit log
- [ ] Trigger a test rotation (either secret) and a denied access attempt
- [ ] Open Logs tab — confirm events appear and you know which filter to use
- [ ] Note the demo start time so you can filter to it during Act 5
```

- [ ] **Step 2: Write act-by-act narration cues**

```markdown
---

## Act-by-Act Guide (15 min live demo)

### Act 1 — Multi-Cluster Governance (~4 min)
**Open:** Akeyless UI

1. Show Targets — "Two isolated Vault clusters. Different teams, different networks."
2. Show USCs — "Akeyless bridges them both. One control plane."
3. Show existing secrets synced from e2e setup — "Already governed."
4. **Vault UI → create** `secret/myapp/created-from-vault` → switch to Akeyless UI — "Vault-to-Akeyless, bidirectional."
5. **Akeyless UI → create** `secret/myapp/created-from-akeyless` → switch to Vault UI — "Akeyless-to-Vault."

**Transition:** "Now let's see the rotation engine."

---

### Act 2 — Rotation + Sync (~6 min)
**Open:** Akeyless UI

**Azure (~3 min):**
1. Rotated Secrets → MVG-demo/azure-app-rotated-secret → Rotate Now
2. Switch to Azure portal tab → akl-mvg-demo-kv → Secrets → demo-app-client-secret — show new timestamp
3. "The app reads from Key Vault. It never touches the rotation."

**Database (~3 min):**
1. Rotated Secrets → MVG-demo/db-rotated-password → Rotate Now
2. Switch to Vault UI → secret/myapp/db-password — show updated value
3. "Rotated credential, synced to Vault. App reads from Vault — unchanged."

**Transition:** "Same vault CLI they've always used — let me show you."

---

### Act 3 — HVP: Zero Disruption (~2 min)
**Open:** Terminal

```bash
export VAULT_ADDR='https://hvp.akeyless.io'
vault kv get secret/myapp/db-password
vault kv get secret/myapp/api-key
```
"Same commands. Different backend. Zero workflow changes."

**Transition:** "Who controls what gets accessed? Let's look at RBAC."

---

### Act 4 — RBAC Governance (~2 min)
**Open:** Akeyless UI

1. Access Roles → demo-readonly-role — "Read access, both clusters."
2. Access Roles → demo-denied-role — "Explicitly blocked."
3. Switch to terminal — run the denied access command
4. "One deny. Both clusters. Every connected secrets manager."

**Transition:** "Every action we just took — it's all recorded."

---

### Act 5 — Audit Trail (~1 min)
**Open:** Akeyless UI → Logs tab

1. Filter to demo start time
2. Show rotation events (Azure, MySQL)
3. Show denied access attempt
4. "Full visibility across every cluster. One log. Nothing missing."
```

- [ ] **Step 3: Verify the markdown renders correctly**

Open `demo/presenter-runbook.md` in a markdown previewer and confirm headings, checkboxes, and code blocks render as expected.

---

## Notes

- This is a demo script restructure, not application code — there are no unit tests to write. Correctness is verified by a full dry-run against the live environment.
- The `_act1_cleanup` function is a helper for the pre-demo checklist only and is never called during the live demo.
- All times are targets for rehearsal. Practice each act separately before the full run-through.
