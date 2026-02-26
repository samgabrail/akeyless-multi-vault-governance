#!/usr/bin/env bash
# Live demo commands — run section by section during the screencast.
# Source this file or copy-paste chapters into your terminal.
# Do NOT run this as a single script — it is designed to be executed chapter by chapter.

# ─────────────────────────────────────────────────────────────────────────────
# ENV VAR SETUP — set these before starting the demo
# ─────────────────────────────────────────────────────────────────────────────
# export VAULT_ADDR='http://127.0.0.1:8200'
# export VAULT_TOKEN='root'
# export USC_NAME='demo-vault-usc'


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 1: Verify Vault dev secrets
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 1: Vault has our seeded secrets ---"

# Confirm the secrets we seeded during setup are present in the local Vault dev server
vault kv list secret/myapp
vault kv get secret/myapp/db-password
vault kv get secret/myapp/api-key


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 2: Gateway already running on K8s — show pods
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 2: Akeyless Gateway running on K8s ---"

# Show the Akeyless Gateway deployed and healthy in the cluster
kubectl get pods -n akeyless
kubectl get svc -n akeyless


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 3: List and read Vault secrets via Akeyless USC
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 3: Manage Vault secrets from Akeyless ---"

# The Universal Secrets Connector (USC) exposes existing Vault secrets through Akeyless.
# No migration required — Vault is still the system of record.
akeyless usc list --usc-name "$USC_NAME"
akeyless usc get --usc-name "$USC_NAME" --secret-id "myapp/db-password"
akeyless usc get --usc-name "$USC_NAME" --secret-id "myapp/api-key"


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 4a: Two-way sync — Create in Akeyless, verify in Vault
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 4a: Create via Akeyless USC → appears in Vault ---"

# Write a new secret through the Akeyless USC — this writes directly into Vault.
akeyless usc create \
  --usc-name "$USC_NAME" \
  --secret-name "myapp/created-from-akeyless" \
  --value "value=hello-from-akeyless"

# Verify it now exists natively in Vault — proves the write went all the way through
vault kv get secret/myapp/created-from-akeyless


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 4b: Two-way sync — Create in Vault, verify in Akeyless
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 4b: Create in Vault → visible via Akeyless USC ---"

# Write directly to Vault as you normally would
vault kv put secret/myapp/created-from-vault value="hello-from-vault"

# Verify Akeyless sees it immediately — no import step, no sync job
akeyless usc list --usc-name "$USC_NAME"
akeyless usc get --usc-name "$USC_NAME" --secret-id "myapp/created-from-vault"


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 5: HVP — use vault CLI against Akeyless backend
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 5: vault CLI via Akeyless HVP — zero code changes ---"

# PRE-REQUISITE: Set up ~/.vault-token before running this chapter.
# Format: <Access Id>..<Access Key>  (two dots between them)
# Example:
#   echo -n 'p-xxxxxxxxxxxx..your-access-key' > ~/.vault-token

# Save original Vault address so we can restore it after this chapter
export ORIGINAL_VAULT_ADDR="$VAULT_ADDR"

# Point the vault CLI at the Akeyless HashiCorp Vault Proxy endpoint.
# No changes to application code — only the VAULT_ADDR env var changes.
export VAULT_ADDR='https://hvp.akeyless.io'
# Show the audience the HVP token format: <Access Id>..<Access Key>
# This is the only client-side change — no code changes required.
cat ~/.vault-token

# Now run standard vault commands — they hit Akeyless, not the local Vault server.
# The same commands, the same CLI, same workflow — Akeyless is now the backend.
vault kv get secret/myapp/db-password
vault kv get secret/myapp/api-key

# Restore original Vault address
export VAULT_ADDR="$ORIGINAL_VAULT_ADDR"


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 6: RBAC — show denied access
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 6: Akeyless RBAC — deny in action ---"

# Authenticate as the denied identity (Access ID from akeyless-setup.sh output)
# Replace <DENIED_ACCESS_ID> and <DENIED_ACCESS_KEY> with actual values
akeyless auth \
  --access-id "<DENIED_ACCESS_ID>" \
  --access-key "<DENIED_ACCESS_KEY>"

# Attempt to read a secret — this identity has no policy granting access
akeyless usc get --usc-name "$USC_NAME" --secret-id "myapp/db-password"
# Expected: Unauthorized / Permission denied
# This proves that Akeyless RBAC enforcement sits in front of the Vault secrets.


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 7: Audit trail
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 7: Centralized audit trail ---"

# Every operation from this demo — USC reads, writes, HVP calls, RBAC denials —
# is captured in the Akeyless audit log. This is the single pane of glass for
# all secret access across Vault and Akeyless.
echo "Open: https://console.akeyless.io"
echo "Navigate: Logs → filter by your Access ID or by action (get, list, create)"
echo "Every USC operation, HVP call, and RBAC event is logged here."

# Optional: fetch recent audit logs via CLI
akeyless get-audit-event-log --limit 20
