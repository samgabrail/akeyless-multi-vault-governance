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
# export AKEYLESS_DEMO_FOLDER='MVG-demo'
# export USC_BACKEND='MVG-demo/vault-usc-backend'
# export USC_PAYMENTS='MVG-demo/vault-usc-payments'
# export USC_AWS='MVG-demo/aws-usc'
# export USC_AZURE='MVG-demo/azure-usc'
# export AKEYLESS_GW='https://192.168.1.82:8000'    # your Gateway URL
# export AKEYLESS_PROFILE='demo'                     # akeyless CLI profile name
# export AWS_DEMO_SECRET_NAME='demo/mvg/aws/payments-api-key'
# export AZURE_VAULT_NAME='mvg-demo-kv'
# export AZURE_STATIC_SECRET_NAME='payments-api-key'
# export AZURE_ROTATED_SECRET_NAME='demo-azure-rotated-api-key'
# export ROTATED_VAULT='MVG-demo/vault-rotated-api-key'
# export ROTATED_AWS='MVG-demo/aws-rotated-secret'
# export ROTATED_AZURE='MVG-demo/azure-rotated-api-key'


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
# CHAPTER 3: Discover secrets across BOTH Vaults via Akeyless USC
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 3: Discover secrets across both Vault clusters ---"

# Backend team's Vault — inventory via USC
akeyless usc list \
  --usc-name "${USC_BACKEND:-MVG-demo/vault-usc-backend}" \
  --profile "${AKEYLESS_PROFILE:-demo}"

# Payments team's Vault — inventory via USC
akeyless usc list \
  --usc-name "${USC_PAYMENTS:-MVG-demo/vault-usc-payments}" \
  --profile "${AKEYLESS_PROFILE:-demo}"

# Key point: same CLI session can discover both Vault inventories with one
# governance layer on top.


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 4: Read secrets from BOTH Vaults via Akeyless USC
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 4: Read secrets from both Vault clusters via USC ---"

# Backend team's Vault — read via USC
akeyless usc get \
  --usc-name "${USC_BACKEND:-MVG-demo/vault-usc-backend}" \
  --secret-id "secret/myapp/db-password" \
  --profile "${AKEYLESS_PROFILE:-demo}"

# Payments team's Vault — read via USC
akeyless usc get \
  --usc-name "${USC_PAYMENTS:-MVG-demo/vault-usc-payments}" \
  --secret-id "secret/payments/stripe-key" \
  --profile "${AKEYLESS_PROFILE:-demo}"

# Key point: same CLI, same RBAC, same audit trail — two separate Vault clusters.


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 5a: Two-way sync — Akeyless → Vault (backend)
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 5a: Create via Akeyless USC → appears in backend Vault ---"

# Write a new secret through Akeyless — it physically lands in backend Vault
# Value must be base64-encoded JSON matching Vault KV format: {"key": "value"}
ENCODED_VALUE=$(echo -n '{"value":"hello-from-akeyless"}' | base64 -w0)

akeyless usc create \
  --usc-name "${USC_BACKEND:-MVG-demo/vault-usc-backend}" \
  --secret-name "secret/myapp/created-from-akeyless" \
  --value "$ENCODED_VALUE" \
  --profile "${AKEYLESS_PROFILE:-demo}"

# Verify it exists natively in backend Vault
export VAULT_ADDR="${VAULT_ADDR_BACKEND:-http://127.0.0.1:8200}"
vault kv get secret/myapp/created-from-akeyless


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 5b: Two-way sync — Vault → Akeyless (payments)
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 5b: Create in payments Vault → visible via Akeyless USC ---"

# Write directly into the payments Vault
export VAULT_ADDR="${VAULT_ADDR_PAYMENTS:-http://127.0.0.1:8202}"
vault kv put secret/payments/created-from-vault value="hello-from-payments-vault"

# Verify Akeyless sees it immediately — no sync job, no polling
akeyless usc list \
  --usc-name "${USC_PAYMENTS:-MVG-demo/vault-usc-payments}" \
  --profile "${AKEYLESS_PROFILE:-demo}"

akeyless usc get \
  --usc-name "${USC_PAYMENTS:-MVG-demo/vault-usc-payments}" \
  --secret-id "secret/payments/created-from-vault" \
  --profile "${AKEYLESS_PROFILE:-demo}"

# Reset to backend vault
export VAULT_ADDR="${VAULT_ADDR_BACKEND:-http://127.0.0.1:8200}"


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 6: HVP — vault CLI with zero code changes
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 6: vault CLI via Akeyless HVP — zero code changes ---"

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
# CHAPTER 7: Extend MVG to AWS Secrets Manager and Azure Key Vault
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 7: Extend MVG to AWS Secrets Manager and Azure Key Vault ---"

# AWS Secrets Manager via USC-backed MVG
akeyless usc list \
  --usc-name "${USC_AWS:-MVG-demo/aws-usc}" \
  --profile "${AKEYLESS_PROFILE:-demo}"

akeyless usc get \
  --usc-name "${USC_AWS:-MVG-demo/aws-usc}" \
  --secret-id "${AWS_DEMO_SECRET_NAME:-demo/mvg/aws/payments-api-key}" \
  --profile "${AKEYLESS_PROFILE:-demo}"

# Azure Key Vault via USC-backed MVG
akeyless usc list \
  --usc-name "${USC_AZURE:-MVG-demo/azure-usc}" \
  --profile "${AKEYLESS_PROFILE:-demo}"

akeyless usc get \
  --usc-name "${USC_AZURE:-MVG-demo/azure-usc}" \
  --secret-id "${AZURE_STATIC_SECRET_NAME:-payments-api-key}" \
  --profile "${AKEYLESS_PROFILE:-demo}"

# Key point: HashiCorp Vault, AWS Secrets Manager, and Azure Key Vault — all
# governed from one Akeyless control plane with one RBAC model and one audit log.


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 7b: Automated Secret Rotation — PCI-DSS / SOC2 compliance story
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 7b: Akeyless auto-rotates secrets back into each external vault ---"

# ── HashiCorp Vault rotation ─────────────────────────────────────────────────
export VAULT_ADDR="${VAULT_ADDR_BACKEND:-http://127.0.0.1:8200}"

echo "==> Current value in HashiCorp Vault (before rotation):"
vault kv get -field=api_key secret/myapp/api-key

# Trigger Akeyless to rotate the Vault secret immediately.
# Akeyless generates a new value and writes it back through the Gateway.
akeyless rotated-secret set-next-rotation-date \
  --name "${ROTATED_VAULT:-MVG-demo/vault-rotated-api-key}" \
  --next-rotation-date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --profile "${AKEYLESS_PROFILE:-demo}"

sleep 10   # allow Gateway to execute the rotation

echo "==> Value in HashiCorp Vault AFTER Akeyless rotation:"
vault kv get -field=api_key secret/myapp/api-key
# Output: a new value — Akeyless wrote it back. The old value is gone.

# ── AWS Secrets Manager rotation ─────────────────────────────────────────────
akeyless rotated-secret set-next-rotation-date \
  --name "${ROTATED_AWS:-MVG-demo/aws-rotated-secret}" \
  --next-rotation-date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --profile "${AKEYLESS_PROFILE:-demo}"

echo "==> (AWS rotation triggered — verify in AWS Console or:"
echo "    aws secretsmanager get-secret-value --secret-id ${AWS_DEMO_SECRET_NAME:-demo/mvg/aws/payments-api-key} --region ${AWS_REGION:-us-east-2})"

# ── Azure Key Vault rotation ─────────────────────────────────────────────────
akeyless rotated-secret set-next-rotation-date \
  --name "${ROTATED_AZURE:-MVG-demo/azure-rotated-api-key}" \
  --next-rotation-date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --profile "${AKEYLESS_PROFILE:-demo}"

echo "==> (Azure rotation triggered — verify in Azure Portal or:"
echo "    az keyvault secret show --vault-name ${AZURE_VAULT_NAME:-mvg-demo-kv} --name ${AZURE_ROTATED_SECRET_NAME:-demo-azure-rotated-api-key})"

# Key point: Akeyless owns the rotation schedule (30-day default, configurable).
# It writes the new value back to HashiCorp Vault, AWS SM, and Azure KV through
# the Gateway. No per-vault rotation scripts. No Lambda. No cron jobs.
# One schedule governs all three backends — and every rotation event is logged
# in the same Akeyless audit trail that covers all reads and denials.


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 8: RBAC — single policy denies access across all governed backends
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 8: One RBAC deny blocks access across Vault, AWS, and Azure ---"

# Get a token for the denied identity (replace with actual values from akeyless-setup.sh output)
DENIED_TOKEN=$(akeyless auth \
  --access-id "<DENIED_ACCESS_ID>" \
  --access-key "<DENIED_ACCESS_KEY>" \
  --access-type access_key \
  --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

# Attempt access to backend Vault — denied
akeyless usc get \
  --usc-name "${USC_BACKEND:-MVG-demo/vault-usc-backend}" \
  --secret-id "secret/myapp/db-password" \
  --gateway-url "${AKEYLESS_GW:-https://192.168.1.82:8000}" \
  --token "$DENIED_TOKEN"
# Expected: 403 Forbidden / no read permission

# Attempt access to payments Vault — also denied (same policy, second cluster)
akeyless usc get \
  --usc-name "${USC_PAYMENTS:-MVG-demo/vault-usc-payments}" \
  --secret-id "secret/payments/stripe-key" \
  --gateway-url "${AKEYLESS_GW:-https://192.168.1.82:8000}" \
  --token "$DENIED_TOKEN"
# Expected: 403 Forbidden / no read permission

# Attempt access to AWS Secrets Manager path — also denied
akeyless usc get \
  --usc-name "${USC_AWS:-MVG-demo/aws-usc}" \
  --secret-id "${AWS_DEMO_SECRET_NAME:-demo/mvg/aws/payments-api-key}" \
  --gateway-url "${AKEYLESS_GW:-https://192.168.1.82:8000}" \
  --token "$DENIED_TOKEN"
# Expected: 403 Forbidden / no read permission

# Attempt access to Azure Key Vault secret — also denied
akeyless usc get \
  --usc-name "${USC_AZURE:-MVG-demo/azure-usc}" \
  --secret-id "${AZURE_STATIC_SECRET_NAME:-payments-api-key}" \
  --gateway-url "${AKEYLESS_GW:-https://192.168.1.82:8000}" \
  --token "$DENIED_TOKEN"
# Expected: 403 Forbidden / no read permission


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 9: Centralized audit trail — every backend, one log
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 9: One audit trail covers Vault, AWS, Azure, and all rotation events ---"

# Every operation from this demo — Vault MVG reads/writes, HVP calls, AWS and
# Azure reads, rotation events, and all RBAC denials — is in a single Akeyless
# audit log.
echo "Open: https://console.akeyless.io"
echo "Navigate: Logs → filter by your Access ID or by action (get, list, create, rotate)"
echo "Vault, AWS, and Azure Key Vault USC connectors appear in the same log."
echo "Rotation events show the secret name, timestamp, and triggering identity."
