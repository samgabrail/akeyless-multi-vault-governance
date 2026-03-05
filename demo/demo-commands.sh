#!/usr/bin/env bash
# Live demo commands — run section by section during the screencast.
# Source this file or copy-paste chapters into your terminal.
# Do NOT run this as a single script — it is designed to be executed chapter by chapter.

# ─────────────────────────────────────────────────────────────────────────────
# ENV VAR SETUP — set these before starting the demo
# ─────────────────────────────────────────────────────────────────────────────
# export VAULT_ADDR='http://127.0.0.1:8200'    # backend vault (active default)
# export VAULT_ADDR_BACKEND='http://127.0.0.1:8200'
# export VAULT_ADDR_PAYMENTS='http://127.0.0.1:8202'
# export VAULT_TOKEN='root'
# export USC_BACKEND='demo-vault-usc-backend'
# export USC_PAYMENTS='demo-vault-usc-payments'
# export AKEYLESS_GW='https://192.168.1.82:8000'    # your Gateway URL
# export AKEYLESS_PROFILE='demo'                     # akeyless CLI profile name


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 1: Two isolated Vault instances — no Akeyless yet
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 1: Two separate Vault clusters, zero shared governance ---"

# Backend team's Vault (port 8200)
export VAULT_ADDR="${VAULT_ADDR_BACKEND:-http://127.0.0.1:8200}"
vault kv list secret/myapp
vault kv get secret/myapp/db-password
vault kv get secret/myapp/api-key

# Payments team's Vault (port 8202) — completely separate cluster
export VAULT_ADDR="${VAULT_ADDR_PAYMENTS:-http://127.0.0.1:8202}"
vault kv list secret/payments
vault kv get secret/payments/stripe-key
vault kv get secret/payments/db-url

# Reset to backend vault for subsequent chapters
export VAULT_ADDR="${VAULT_ADDR_BACKEND:-http://127.0.0.1:8200}"


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 2: Gateway already running on K8s — show pods
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 2: Akeyless Gateway running on K8s ---"

# Demo topology: one Gateway bridges both Vault instances in one private network.
# Production topology: deploy one Gateway per private location/region near each
# Vault cluster and its application workloads.
kubectl get pods -n akeyless
kubectl get svc -n akeyless


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 3: Read secrets from BOTH Vaults via Akeyless USC
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 3: Both Vaults governed from one Akeyless control plane ---"

# Backend team's Vault — via USC
akeyless usc list \
  --usc-name "${USC_BACKEND:-demo-vault-usc-backend}" \
  --profile "${AKEYLESS_PROFILE:-demo}"

akeyless usc get \
  --usc-name "${USC_BACKEND:-demo-vault-usc-backend}" \
  --secret-id "secret/myapp/db-password" \
  --profile "${AKEYLESS_PROFILE:-demo}"

# Payments team's Vault — via USC
akeyless usc list \
  --usc-name "${USC_PAYMENTS:-demo-vault-usc-payments}" \
  --profile "${AKEYLESS_PROFILE:-demo}"

akeyless usc get \
  --usc-name "${USC_PAYMENTS:-demo-vault-usc-payments}" \
  --secret-id "secret/payments/stripe-key" \
  --profile "${AKEYLESS_PROFILE:-demo}"

# Key point: same CLI, same RBAC, same audit trail — two separate Vault clusters.


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 4a: Two-way sync — Akeyless → Vault (backend)
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 4a: Create via Akeyless USC → appears in backend Vault ---"

# Write a new secret through Akeyless — it physically lands in backend Vault
# Value must be base64-encoded JSON matching Vault KV format: {"key": "value"}
ENCODED_VALUE=$(echo -n '{"value":"hello-from-akeyless"}' | base64 -w0)

akeyless usc create \
  --usc-name "${USC_BACKEND:-demo-vault-usc-backend}" \
  --secret-name "secret/myapp/created-from-akeyless" \
  --value "$ENCODED_VALUE" \
  --profile "${AKEYLESS_PROFILE:-demo}"

# Verify it exists natively in backend Vault
export VAULT_ADDR="${VAULT_ADDR_BACKEND:-http://127.0.0.1:8200}"
vault kv get secret/myapp/created-from-akeyless


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 4b: Two-way sync — Vault → Akeyless (payments)
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 4b: Create in payments Vault → visible via Akeyless USC ---"

# Write directly into the payments Vault
export VAULT_ADDR="${VAULT_ADDR_PAYMENTS:-http://127.0.0.1:8202}"
vault kv put secret/payments/created-from-vault value="hello-from-payments-vault"

# Verify Akeyless sees it immediately — no sync job, no polling
akeyless usc list \
  --usc-name "${USC_PAYMENTS:-demo-vault-usc-payments}" \
  --profile "${AKEYLESS_PROFILE:-demo}"

akeyless usc get \
  --usc-name "${USC_PAYMENTS:-demo-vault-usc-payments}" \
  --secret-id "secret/payments/created-from-vault" \
  --profile "${AKEYLESS_PROFILE:-demo}"

# Reset to backend vault
export VAULT_ADDR="${VAULT_ADDR_BACKEND:-http://127.0.0.1:8200}"


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 5: HVP — vault CLI with zero code changes
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 5: vault CLI via Akeyless HVP — zero code changes ---"

# PRE-REQUISITE (one-time, run before the demo):
#
# HVP at hvp.akeyless.io uses Akeyless's own KV store as the backend for
# static secrets — it does not read through to the local Vault instances.
# Seed the demo secrets into Akeyless KV via HVP before recording:
#
#   export VAULT_ADDR='https://hvp.akeyless.io'
#   vault kv put secret/myapp/db-password password="sup3r-s3cret-db-pass"
#   vault kv put secret/myapp/api-key api_key="akl-demo-api-key-12345"
#   export VAULT_ADDR='http://127.0.0.1:8200'
#
# Also set ~/.vault-token:
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

# Get a token for the denied identity (replace with actual values from akeyless-setup.sh output)
DENIED_TOKEN=$(akeyless auth \
  --access-id "<DENIED_ACCESS_ID>" \
  --access-key "<DENIED_ACCESS_KEY>" \
  --access-type access_key \
  --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

# Attempt access to backend Vault — denied
akeyless usc get \
  --usc-name "${USC_BACKEND:-demo-vault-usc-backend}" \
  --secret-id "secret/myapp/db-password" \
  --gateway-url "${AKEYLESS_GW:-https://192.168.1.82:8000}" \
  --token "$DENIED_TOKEN"
# Expected: 403 Forbidden / no read permission

# Attempt access to payments Vault — also denied (same policy, second cluster)
akeyless usc get \
  --usc-name "${USC_PAYMENTS:-demo-vault-usc-payments}" \
  --secret-id "secret/payments/stripe-key" \
  --gateway-url "${AKEYLESS_GW:-https://192.168.1.82:8000}" \
  --token "$DENIED_TOKEN"
# Expected: 403 Forbidden / no read permission


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 7: Centralized audit trail — both Vaults, one log
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 7: One audit trail covers both Vault clusters ---"

# Every operation from this demo — USC reads from both clusters, writes, HVP
# calls, and both RBAC denials — is in a single Akeyless audit log.
echo "Open: https://console.akeyless.io"
echo "Navigate: Logs → filter by your Access ID or by action (get, list, create)"
echo "Both USC connectors (backend + payments) appear in the same log."
