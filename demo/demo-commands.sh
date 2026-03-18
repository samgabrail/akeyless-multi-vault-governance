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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/demo/.akeyless-demo.env" 2>/dev/null \
  || source "${SCRIPT_DIR}/.akeyless-demo.env" 2>/dev/null \
  || { echo "ERROR: .akeyless-demo.env not found. Run akeyless-setup.sh first."; }
export VAULT_ADDR_BACKEND='http://127.0.0.1:8200'
export VAULT_ADDR_PAYMENTS='http://127.0.0.1:8202'
export LOCAL_VAULT_TOKEN='root'


# ─────────────────────────────────────────────────────────────────────────────
# ACT 1: Multi-Cluster Governance (~4 min) — VAULT UI + AKEYLESS UI
# ─────────────────────────────────────────────────────────────────────────────
#
# SHOW IN AKEYLESS UI:
#   • Targets → demo-vault-target-backend (port 8200) and demo-vault-target-payments (port 8202)
#   • Universal Secrets Connectors → MVG-demo/vault-usc-backend and MVG-demo/vault-usc-payments
#   • Browse secrets already synced from the e2e setup
#
# LIVE SYNC DEMO — Vault → Akeyless:
#   • In Vault UI (http://localhost:8200/ui): create secret/myapp/created-from-vault
#   • Switch to Akeyless UI: show it appears under MVG-demo/vault-usc-backend
#
# LIVE SYNC DEMO — Akeyless → Vault:
#   • In Akeyless UI: create secret/myapp/created-from-akeyless under MVG-demo/vault-usc-backend
#   • Switch to Vault UI (http://localhost:8200/ui): show it synced to Vault
#
# MESSAGE: One control plane. Multiple isolated clusters. Any secrets manager. Bidirectional.

# Helper: clean up the live-created sync secrets before the webinar.
# Run this as part of the pre-demo checklist (NOT during the live demo).
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


# ─────────────────────────────────────────────────────────────────────────────
# ACT 4: RBAC Governance (~2 min) — AKEYLESS UI + TERMINAL
# ─────────────────────────────────────────────────────────────────────────────
#
# SHOW IN AKEYLESS UI:
#   • Access Roles → demo-readonly-role (read access to both USCs)
#   • Access Roles → demo-denied-role (explicitly blocked)
#   • MESSAGE: One RBAC policy governs access across every connected secrets manager.

# CLI: Trigger a denied access attempt to show enforcement in real time
DENIED_TOKEN=$(akeyless auth --access-id "$DENIED_ACCESS_ID" --access-key "$DENIED_ACCESS_KEY" --access-type access_key --json 2>/dev/null  | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")

akeyless usc get \
  --usc-name "MVG-demo/vault-usc-backend" \
  --secret-id "secret/myapp/db-password" \
  --gateway-url "https://192.168.1.82:8000" \
  --token "$DENIED_TOKEN"
# Expected: permission denied

# MESSAGE: One deny policy. Both clusters. Any connected secrets manager.


# ─────────────────────────────────────────────────────────────────────────────
# ACT 5: Audit Trail (~1 min) — AKEYLESS UI
# ─────────────────────────────────────────────────────────────────────────────
#
# SHOW IN AKEYLESS UI:
#   • Logs tab → filter by current session timeframe (start of demo to now)
#   • Point out:
#       - Rotation events: Azure App Reg rotation, MySQL/DB rotation
#       - Denied access attempt from Act 4
#   • NOTE: Verify during dry run whether sync events appear as distinct log entries.
#           If they do, highlight them. If not, focus on rotation + denied access.
#
# MESSAGE: Full visibility across every cluster, from one place.
#          Every rotation, every access, every denial — in one audit log.
