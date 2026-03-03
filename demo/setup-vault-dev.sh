#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# setup-vault-dev.sh
#
# Starts TWO HashiCorp Vault dev instances representing two independent teams:
#
#   Vault 1 — "backend" team   → port 8200, log: /tmp/vault-backend.log
#   Vault 2 — "payments" team  → port 8202, log: /tmp/vault-payments.log
#
# Each instance is a fully independent Vault cluster. Neither knows the other
# exists. This is the starting point for the multi-vault governance demo.
#
# Usage:
#   source demo/setup-vault-dev.sh   # exports VAULT_PID_BACKEND + VAULT_PID_PAYMENTS
#   # or
#   ./demo/setup-vault-dev.sh        # PIDs printed at end only
# ---------------------------------------------------------------------------

VAULT_TOKEN="root"
VAULT_ADDR_BACKEND="http://127.0.0.1:8200"
VAULT_ADDR_PAYMENTS="http://127.0.0.1:8202"
LOG_BACKEND="/tmp/vault-backend.log"
LOG_PAYMENTS="/tmp/vault-payments.log"

echo ""
echo "========================================================"
echo "  Akeyless Demo — HashiCorp Vault Dev Servers (x2)"
echo "========================================================"
echo ""
echo "  Vault Backend  : ${VAULT_ADDR_BACKEND}  (log: ${LOG_BACKEND})"
echo "  Vault Payments : ${VAULT_ADDR_PAYMENTS}  (log: ${LOG_PAYMENTS})"
echo "  Token (both)   : ${VAULT_TOKEN}"
echo ""

# ---------------------------------------------------------------------------
# Start Vault 1 — backend team
# ---------------------------------------------------------------------------
echo "[1/6] Starting backend Vault (port 8200)..."

vault server \
  -dev \
  -dev-root-token-id="${VAULT_TOKEN}" \
  -dev-listen-address="127.0.0.1:8200" \
  >"${LOG_BACKEND}" 2>&1 &

export VAULT_PID_BACKEND=$!
echo "      PID: ${VAULT_PID_BACKEND}"

# Trap to clean up on exit if something goes wrong during this script
trap 'kill "${VAULT_PID_BACKEND}" 2>/dev/null || true; kill "${VAULT_PID_PAYMENTS:-0}" 2>/dev/null || true' EXIT

# ---------------------------------------------------------------------------
# Wait for Vault 1 to become ready before starting Vault 2.
# Both instances try to write ~/.vault-token on startup; starting them
# sequentially avoids the rename race condition that causes Vault 2 to exit.
# ---------------------------------------------------------------------------
echo ""
echo "[2/6] Waiting for backend Vault to become ready..."

MAX_WAIT=30
ELAPSED=0
until VAULT_ADDR="${VAULT_ADDR_BACKEND}" VAULT_TOKEN="${VAULT_TOKEN}" vault status >/dev/null 2>&1; do
  if [ "${ELAPSED}" -ge "${MAX_WAIT}" ]; then
    echo "ERROR: backend Vault did not become ready within ${MAX_WAIT}s. Check ${LOG_BACKEND}" >&2
    exit 1
  fi
  sleep 1
  ELAPSED=$(( ELAPSED + 1 ))
done
echo "      Ready (${ELAPSED}s)."

# ---------------------------------------------------------------------------
# Start Vault 2 — payments team (after Vault 1 is fully up)
# ---------------------------------------------------------------------------
echo ""
echo "[3/6] Starting payments Vault (port 8202)..."

vault server \
  -dev \
  -dev-root-token-id="${VAULT_TOKEN}" \
  -dev-listen-address="127.0.0.1:8202" \
  >"${LOG_PAYMENTS}" 2>&1 &

export VAULT_PID_PAYMENTS=$!
echo "      PID: ${VAULT_PID_PAYMENTS}"

# ---------------------------------------------------------------------------
# Wait for Vault 2 to become ready
# ---------------------------------------------------------------------------
echo "[4/6] Waiting for payments Vault to become ready..."

ELAPSED=0
until VAULT_ADDR="${VAULT_ADDR_PAYMENTS}" VAULT_TOKEN="${VAULT_TOKEN}" vault status >/dev/null 2>&1; do
  if [ "${ELAPSED}" -ge "${MAX_WAIT}" ]; then
    echo "ERROR: payments Vault did not become ready within ${MAX_WAIT}s. Check ${LOG_PAYMENTS}" >&2
    exit 1
  fi
  sleep 1
  ELAPSED=$(( ELAPSED + 1 ))
done
echo "      Ready (${ELAPSED}s)."

# ---------------------------------------------------------------------------
# Seed Vault 1 — backend team secrets
# ---------------------------------------------------------------------------
echo ""
echo "[5/6] Seeding backend Vault (secret/myapp/)..."

export VAULT_ADDR="${VAULT_ADDR_BACKEND}"
export VAULT_TOKEN="${VAULT_TOKEN}"

vault kv put secret/myapp/db-password \
  password="sup3r-s3cret-db-pass"
echo "      secret/myapp/db-password   => password=sup3r-s3cret-db-pass"

vault kv put secret/myapp/api-key \
  api_key="akl-demo-api-key-12345"
echo "      secret/myapp/api-key       => api_key=akl-demo-api-key-12345"

# ---------------------------------------------------------------------------
# Seed Vault 2 — payments team secrets
# ---------------------------------------------------------------------------
echo ""
echo "[6/6] Seeding payments Vault (secret/payments/)..."

export VAULT_ADDR="${VAULT_ADDR_PAYMENTS}"
# VAULT_TOKEN is the same for both dev instances

vault kv put secret/payments/stripe-key \
  key="sk_demo_payments_abc123"
echo "      secret/payments/stripe-key => key=sk_demo_payments_abc123"

vault kv put secret/payments/db-url \
  url="postgres://payments:secret@db.payments.internal:5432/prod"
echo "      secret/payments/db-url     => url=postgres://payments:..."

# ---------------------------------------------------------------------------
# Restore VAULT_ADDR to backend (port 8200) for subsequent demo steps
# ---------------------------------------------------------------------------
export VAULT_ADDR="${VAULT_ADDR_BACKEND}"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "========================================================"
echo "  Setup Complete"
echo "========================================================"
echo ""
echo "  Backend Vault (port 8200)"
echo "    PID  : ${VAULT_PID_BACKEND}"
echo "    Log  : ${LOG_BACKEND}"
echo "    Secrets:"
echo "      secret/myapp/db-password  (key: password)"
echo "      secret/myapp/api-key      (key: api_key)"
echo ""
echo "  Payments Vault (port 8202)"
echo "    PID  : ${VAULT_PID_PAYMENTS}"
echo "    Log  : ${LOG_PAYMENTS}"
echo "    Secrets:"
echo "      secret/payments/stripe-key  (key: key)"
echo "      secret/payments/db-url      (key: url)"
echo ""
echo "  Both vaults use token: ${VAULT_TOKEN}"
echo "  VAULT_ADDR is set to backend Vault: ${VAULT_ADDR_BACKEND}"
echo ""
echo "  To switch between vaults:"
echo "    export VAULT_ADDR='${VAULT_ADDR_BACKEND}'   # backend"
echo "    export VAULT_ADDR='${VAULT_ADDR_PAYMENTS}'   # payments"
echo ""
echo "  To stop both vaults:"
echo "    kill ${VAULT_PID_BACKEND} ${VAULT_PID_PAYMENTS}"
echo "========================================================"
echo ""

trap - EXIT
