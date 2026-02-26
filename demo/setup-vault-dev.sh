#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# setup-vault-dev.sh
#
# Starts HashiCorp Vault in dev mode with a known root token, waits for it
# to be ready, verifies the KV v2 engine at secret/, seeds demo secrets, and
# prints a summary of everything the caller needs to know.
#
# Usage:
#   source demo/setup-vault-dev.sh   # exports VAULT_PID into the current shell
#   # or
#   ./demo/setup-vault-dev.sh        # run standalone; VAULT_PID printed at end
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="root"

VAULT_LOG_FILE="/tmp/vault-dev.log"

echo ""
echo "========================================================"
echo "  Akeyless Demo — HashiCorp Vault Dev Server Setup"
echo "========================================================"
echo ""
echo "VAULT_ADDR  : ${VAULT_ADDR}"
echo "VAULT_TOKEN : ${VAULT_TOKEN}"
echo ""

# ---------------------------------------------------------------------------
# Start Vault in dev mode as a background process
# ---------------------------------------------------------------------------
echo "[1/5] Starting Vault in dev mode..."

vault server \
  -dev \
  -dev-root-token-id="${VAULT_TOKEN}" \
  -dev-listen-address="127.0.0.1:8200" \
  >"${VAULT_LOG_FILE}" 2>&1 &

export VAULT_PID=$!
trap 'kill "${VAULT_PID}" 2>/dev/null || true' EXIT
echo "      Vault PID: ${VAULT_PID} (log: ${VAULT_LOG_FILE})"

# ---------------------------------------------------------------------------
# Wait for Vault to become ready
# ---------------------------------------------------------------------------
echo ""
echo "[2/5] Waiting for Vault to become ready..."

MAX_WAIT=30   # seconds
ELAPSED=0
until vault status >/dev/null 2>&1; do
  if [ "${ELAPSED}" -ge "${MAX_WAIT}" ]; then
    echo "ERROR: Vault did not become ready within ${MAX_WAIT} seconds." >&2
    echo "       Check the log at ${VAULT_LOG_FILE}" >&2
    kill "${VAULT_PID}" 2>/dev/null || true
    [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return 1 || exit 1
  fi
  sleep 1
  ELAPSED=$(( ELAPSED + 1 ))
done

echo "      Vault is ready (waited ${ELAPSED}s)."

# ---------------------------------------------------------------------------
# Verify KV v2 is enabled at secret/ (default in dev mode — report only)
# ---------------------------------------------------------------------------
echo ""
echo "[3/5] Verifying KV v2 engine at secret/..."
if vault secrets list | grep -q "^secret/"; then
  echo "    KV v2 engine already enabled at secret/ (dev mode default)."
else
  echo "    Enabling KV v2 at secret/..."
  vault secrets enable -version=2 -path=secret kv
fi

# ---------------------------------------------------------------------------
# Seed demo secrets using KV v2 API (vault kv put)
# ---------------------------------------------------------------------------
echo ""
echo "[4/5] Seeding demo secrets..."

vault kv put secret/myapp/db-password \
  password="sup3r-s3cret-db-pass"
echo "      secret/myapp/db-password  => password=sup3r-s3cret-db-pass"

vault kv put secret/myapp/api-key \
  api_key="akl-demo-api-key-12345"
echo "      secret/myapp/api-key      => api_key=akl-demo-api-key-12345"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "[5/5] Setup complete."
echo ""
echo "========================================================"
echo "  Demo Environment Summary"
echo "========================================================"
echo "  VAULT_ADDR  : ${VAULT_ADDR}"
echo "  VAULT_TOKEN : ${VAULT_TOKEN}"
echo "  VAULT_PID   : ${VAULT_PID}"
echo "  Log file    : ${VAULT_LOG_FILE}"
echo ""
echo "  Secrets seeded:"
echo "    secret/myapp/db-password  (key: password)"
echo "    secret/myapp/api-key      (key: api_key)"
echo ""
echo "  To read a secret:"
echo "    VAULT_ADDR=${VAULT_ADDR} VAULT_TOKEN=${VAULT_TOKEN} \\"
echo "      vault kv get secret/myapp/db-password"
echo ""
echo "  To stop Vault when done:"
echo "    kill ${VAULT_PID}"
echo "========================================================"
echo ""

trap - EXIT
