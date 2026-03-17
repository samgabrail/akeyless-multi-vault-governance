# Webinar Demo Restructure — Design Spec
**Date:** 2026-03-17
**Format:** 30-minute session — 15 min slides + 15 min live demo
**Venue:** Live webinar (also published to YouTube)
**Audience:** Platform engineers / DevOps (technical; familiar with Vault, not necessarily Akeyless)

---

## Goal

Restructure the existing 9-chapter demo into a focused 15-minute live demo that proves one core thesis:

> **Akeyless gives you governance over multiple isolated HashiCorp Vault clusters and any cloud secrets manager — without disrupting existing workflows.**

Every demo act is a proof point for that thesis.

> **Note on timing:** The 15-minute allocation has zero slack. Each act must be practiced to fit its time box. Navigation between UI sections and tab-switching is not budgeted separately — presenters must treat transitions as part of each act's time.

---

## Demo Structure (15 minutes live)

### Act 1 — Multi-Cluster Governance (~4 min)
**Tools:** Akeyless UI + Vault UI tabs

Open in Akeyless UI. Show the two pre-configured Vault targets:
- `demo-vault-target-backend` (port 8200) — backend cluster
- `demo-vault-target-payments` (port 8202) — payments cluster

Show the USCs bridging them and the existing synced secrets already populated from the e2e script. Then demonstrate bidirectional sync live:
1. In Vault UI (`http://localhost:8200/ui`), create `secret/myapp/created-from-vault` → switch to Akeyless UI and show it appears under `MVG-demo/vault-usc-backend`
2. In Akeyless UI, create `secret/myapp/created-from-akeyless` → switch to Vault UI and show it synced to Vault

All Vault interactions use the Vault UI — no CLI in this act.

> **Sync interval:** Verify during dry run that sync is near-instant (≤10 seconds) in both directions. Confirm in the Akeyless console USC settings before the webinar.

**Message:** One control plane. Multiple isolated clusters. Any secrets manager. Bidirectional.

---

### Act 2 — Rotation + Sync (~6 min)
**Tools:** Akeyless UI (primary) + Azure portal tab pre-opened to App Registrations → `demo-akeyless-mvg-target` → Certificates & Secrets

**Azure App Registration (~3 min):**
- Trigger rotation of `MVG-demo/azure-app-rotated-secret` in Akeyless UI
- Switch to pre-opened Azure portal tab showing `akl-mvg-demo-kv` (Azure Key Vault) → Secrets → `demo-app-client-secret` — show the updated secret value and timestamp confirming it's freshly rotated
- This is where the application consumes it — the app reads from Key Vault, never touches the rotation directly

> **Pre-demo:** Azure portal must be pre-navigated to `akl-mvg-demo-kv` → Secrets → `demo-app-client-secret`. Do not navigate live.

**Database rotation (~3 min):**
- Trigger MySQL rotation on `MVG-demo/db-rotated-password` in Akeyless UI
- Switch to Vault UI and show the updated password at `secret/myapp/db-password` — this is where the app reads it, proving the rotation synced end-to-end

> **MySQL sync pre-condition:** `MVG-demo/db-rotated-password` must have a sync rule wired to `MVG-demo/vault-usc-backend`. Verify this is active before the webinar.

**Message:** Akeyless owns the rotation lifecycle. Downstream consumers (Vault, Key Vault, apps) receive updated secrets automatically.

---

### Act 3 — HVP: Zero Disruption (~2 min)
**Tool:** Terminal (CLI only section)

Run native Vault CLI against HashiCorp Vault Provider endpoint:
```bash
export VAULT_ADDR=https://hvp.akeyless.io
vault kv get secret/myapp/db-password
```

No config changes. No wrapper scripts. The same command that worked before Akeyless still works.

**Message:** Existing Vault workflows require zero changes. Teams don't need to know Akeyless exists.

---

### Act 4 — RBAC Governance (~2 min)
**Tool:** Akeyless UI

Show access roles scoped across both clusters:
- `demo-readonly-role` — read access to both USCs
- `demo-denied-role` — explicitly blocked

Trigger a denied access attempt using the denied auth token. This is required (not optional) because Act 5's audit log references this event. Execute via CLI (exact command with credentials is in `demo/demo-commands.sh` Chapter 4):
```bash
TOKEN=$(akeyless auth --access-id p-xzdtj47phxl5am --access-key "$DENIED_KEY" --profile demo | jq -r .token)
akeyless usc get --usc-name MVG-demo/vault-usc-backend --secret-id secret/payments/stripe-key \
  --token "$TOKEN" --gateway-url https://192.168.1.82:8000
```
Expected output: permission denied error. `$DENIED_KEY` must be set in the pre-demo checklist from the stored credentials.

**Message:** Centralized access control across every cluster from one place.

---

### Act 5 — Audit Trail (~1 min)
**Tool:** Akeyless UI → Logs tab

Open the Logs tab. Filter by the current session's timeframe (start of demo to now). Show:
- Rotation events (Azure App Reg rotation, MySQL rotation)
- Denied access attempt from Act 4

> **Sync events in audit:** Verify during dry run whether Akeyless logs USC sync operations as distinct audit events. If sync operations do not appear as separate log entries, remove "sync events" from the narration and focus on rotation + denied access only.

> **Pre-demo:** Run a test rotation and denied access attempt in a separate session beforehand to confirm the log is working and to identify the correct event type names. Note the demo start time and filter to that window to avoid noise from test runs.

**Message:** Full visibility across every cluster, from one place. Every action is accounted for.

---

## What's Cut from the Original Demo

The original demo had 9 chapters. The following are intentionally excluded to stay within 15 minutes:

| Chapter | Content | Disposition |
|---------|---------|-------------|
| Chapter 1 | Vault Setup | Pre-configured — not shown |
| Chapter 2 | Gateway Setup | Pre-configured — not shown |
| Chapter 3 | Akeyless Setup | Pre-configured — not shown |
| Chapter 4 | RBAC Setup detail | Covered briefly in Act 4 only |
| Chapter 5 | USC/target creation | Shown as already-configured in Act 1 |
| Chapter 6 | Secret sync setup | Subsumed by Act 1 bidirectional sync demo |
| Chapter 7a | SaaS Vault target read | Subsumed by Act 1 |
| Chapter 7b | RBAC token demo detail | Subsumed by Act 4 |
| Chapters 8–9 | Additional integrations | Out of scope for this webinar |

---

## Pre-Demo Requirements

All infrastructure and secrets are created ahead of time using the end-to-end setup script (`demo/demo-commands.sh` or equivalent e2e script). Nothing is created live during the demo except for the bidirectional sync demonstration in Act 1.

Run the e2e script before the webinar and verify the following are in place:

**Infrastructure:**
- Both Vault dev instances running (ports 8200, 8202) and seeded with secrets
- Akeyless Gateway running on `proxmox-k3s` (`akeyless` namespace, Helm release `akeyless-gw`)
- Gateway reachable at `https://192.168.1.82:8000`

**Akeyless configuration (all pre-created by e2e script):**
- USCs: `MVG-demo/vault-usc-backend`, `MVG-demo/vault-usc-payments`
- Vault targets: `demo-vault-target-backend`, `demo-vault-target-payments`
- Rotated secret: `MVG-demo/azure-app-rotated-secret` (Azure App Reg rotation)
- Rotated secret: `MVG-demo/db-rotated-password` (MySQL rotation, sync wired to `MVG-demo/vault-usc-backend`)
- RBAC roles: `demo-readonly-role`, `demo-denied-role`
- Auth methods: `demo-readonly-auth`, `demo-denied-auth` (Access ID: `p-xzdtj47phxl5am`)

**Act 1 sync paths — delete before the webinar** so the live creation is visually fresh:
- `secret/myapp/created-from-vault` (in both Vault and Akeyless)
- `secret/myapp/created-from-akeyless` (in both Vault and Akeyless)

**HVP:**
- `~/.vault-token` set to `<Access Id>..<Access Key>` using `demo-readonly-auth` credentials
- Verify: `VAULT_ADDR=https://hvp.akeyless.io vault kv get secret/myapp/db-password` returns a value

**Shell (for Act 4 denied access):**
- Export `DENIED_KEY` in the terminal before the webinar for the denied access command

**Browser tabs pre-opened:**
- Akeyless console (logged in)
- Vault UI — backend cluster (`http://localhost:8200/ui`, logged in, browsed to `secret/`)
- Vault UI — payments cluster (`http://localhost:8202/ui`, logged in, browsed to `secret/`)
- Azure portal → Key Vault `akl-mvg-demo-kv` → Secrets → `demo-app-client-secret`

---

## Key Files

| File | Purpose |
|------|---------|
| `demo/demo-commands.sh` | Chapter-by-chapter CLI commands |
| `demo/setup-vault-dev.sh` | Vault dev instance setup |
| `demo/akeyless-setup.sh` | Akeyless targets, USCs, RBAC setup |
| `demo/azure-app-rotation-workflow.excalidraw` / `.svg` | Azure rotation diagram (for slides) |
| `demo/db-rotation-workflow.excalidraw` / `.svg` | DB rotation diagram (for slides) |

---