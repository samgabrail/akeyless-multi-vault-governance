#!/usr/bin/env bash
# Live demo commands — run section by section during the screencast.
# Source this file or copy-paste chapters into your terminal.
# Do NOT run this as a single script — it is designed to be executed chapter by chapter.

# ─────────────────────────────────────────────────────────────────────────────
# ENV VAR SETUP — set these before starting the demo
# ─────────────────────────────────────────────────────────────────────────────
# export VAULT_ADDR='http://127.0.0.1:8200'    # backend vault (active default)
# export VAULT_ADDR_BACKEND='http://127.0.0.1:8200'
# export VAULT_ADDR_PAYMENTS='http://127.0.0.1:8201'
# export VAULT_TOKEN='root'
# export USC_BACKEND='demo-vault-usc-backend'
# export USC_PAYMENTS='demo-vault-usc-payments'


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 1: Two isolated Vault instances — no Akeyless yet
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 1: Two separate Vault clusters, zero shared governance ---"

# Backend team's Vault (port 8200)
export VAULT_ADDR="${VAULT_ADDR_BACKEND:-http://127.0.0.1:8200}"
vault kv list secret/myapp
vault kv get secret/myapp/db-password
vault kv get secret/myapp/api-key

# Payments team's Vault (port 8201) — completely separate cluster
export VAULT_ADDR="${VAULT_ADDR_PAYMENTS:-http://127.0.0.1:8201}"
vault kv list secret/payments
vault kv get secret/payments/stripe-key
vault kv get secret/payments/db-url

# Reset to backend vault for subsequent chapters
export VAULT_ADDR="${VAULT_ADDR_BACKEND:-http://127.0.0.1:8200}"


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 2: Gateway already running on K8s — show pods
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 2: Akeyless Gateway running on K8s ---"

# One Gateway bridges both Vault instances to the Akeyless control plane
kubectl get pods -n akeyless
kubectl get svc -n akeyless


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 3: Read secrets from BOTH Vaults via Akeyless USC
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 3: Both Vaults governed from one Akeyless control plane ---"

# Backend team's Vault — via USC
akeyless usc list --usc-name "$USC_BACKEND"
akeyless usc get --usc-name "$USC_BACKEND" --secret-id "myapp/db-password"

# Payments team's Vault — via USC
akeyless usc list --usc-name "$USC_PAYMENTS"
akeyless usc get --usc-name "$USC_PAYMENTS" --secret-id "payments/stripe-key"

# Key point: same CLI, same RBAC, same audit trail — two separate Vault clusters.


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 4a: Two-way sync — Akeyless → Vault (backend)
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 4a: Create via Akeyless USC → appears in backend Vault ---"

# Write a new secret through Akeyless — it physically lands in backend Vault
akeyless usc create \
  --usc-name "$USC_BACKEND" \
  --secret-name "myapp/created-from-akeyless" \
  --value "value=hello-from-akeyless"

# Verify it exists natively in backend Vault
export VAULT_ADDR="${VAULT_ADDR_BACKEND:-http://127.0.0.1:8200}"
vault kv get secret/myapp/created-from-akeyless


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 4b: Two-way sync — Vault → Akeyless (payments)
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 4b: Create in payments Vault → visible via Akeyless USC ---"

# Write directly into the payments Vault
export VAULT_ADDR="${VAULT_ADDR_PAYMENTS:-http://127.0.0.1:8201}"
vault kv put secret/payments/created-from-vault value="hello-from-payments-vault"

# Verify Akeyless sees it immediately — no sync job, no polling
akeyless usc list --usc-name "$USC_PAYMENTS"
akeyless usc get --usc-name "$USC_PAYMENTS" --secret-id "payments/created-from-vault"

# Reset to backend vault
export VAULT_ADDR="${VAULT_ADDR_BACKEND:-http://127.0.0.1:8200}"


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 5: HVP — vault CLI with zero code changes
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 5: vault CLI via Akeyless HVP — zero code changes ---"

# PRE-REQUISITE: Set up ~/.vault-token before running this chapter.
# Format: <Access Id>..<Access Key>  (two dots between them)
# Example:
#   echo -n 'p-xxxxxxxxxxxx..your-access-key' > ~/.vault-token

export ORIGINAL_VAULT_ADDR="$VAULT_ADDR"

# One VAULT_ADDR change — that's it.
export VAULT_ADDR='https://hvp.akeyless.io'
cat ~/.vault-token   # show the <Access Id>..<Access Key> token format

# Standard vault commands work unchanged — Akeyless is now the backend
vault kv get secret/myapp/db-password
vault kv get secret/myapp/api-key

export VAULT_ADDR="$ORIGINAL_VAULT_ADDR"


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 6: RBAC — single policy denies access to BOTH Vaults
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 6: One RBAC deny blocks access across both Vault clusters ---"

# Authenticate as the denied identity
akeyless auth \
  --access-id "<DENIED_ACCESS_ID>" \
  --access-key "<DENIED_ACCESS_KEY>"

# Attempt access to backend Vault — denied
akeyless usc get --usc-name "$USC_BACKEND" --secret-id "myapp/db-password"
# Expected: Unauthorized

# Attempt access to payments Vault — also denied (same policy, second cluster)
akeyless usc get --usc-name "$USC_PAYMENTS" --secret-id "payments/stripe-key"
# Expected: Unauthorized

# Re-authenticate as admin before continuing
# akeyless auth --access-id p-xxxxxxxxxxxx --access-key <your-access-key>


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 7: Centralized audit trail — both Vaults, one log
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 7: One audit trail covers both Vault clusters ---"

# Every operation from this demo — USC reads from both clusters, writes, HVP
# calls, and both RBAC denials — is in a single Akeyless audit log.
echo "Open: https://console.akeyless.io"
echo "Navigate: Logs → filter by your Access ID or by action (get, list, create)"
echo "Both USC connectors (backend + payments) appear in the same log."

# Optional: fetch recent audit logs via CLI
akeyless get-audit-event-log --limit 30
