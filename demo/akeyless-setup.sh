#!/usr/bin/env bash
# akeyless-setup.sh
#
# Sets up all Akeyless resources required for the multi-vault governance demo.
# Connects Akeyless to a locally-running HashiCorp Vault dev server via a
# Universal Secret Connector (USC), then creates RBAC roles and API key auth
# methods to demonstrate read-only and denied access policies.
#
# Prerequisites:
#   - akeyless CLI installed and authenticated (run `akeyless auth` first)
#   - HashiCorp Vault dev server running locally (see setup-vault-dev.sh)
#   - An Akeyless Gateway reachable at $AKEYLESS_GATEWAY_URL
#
# Required environment variables:
#   AKEYLESS_GATEWAY_URL   URL of your Akeyless Gateway cluster (no default — must be set)
#
# Optional environment variables (defaults shown):
#   VAULT_ADDR             HashiCorp Vault address  (default: http://127.0.0.1:8200)
#   VAULT_TOKEN            HashiCorp Vault token    (default: root)
#
# Usage:
#   export AKEYLESS_GATEWAY_URL="https://your-gateway.example.com:8000"
#   bash demo/akeyless-setup.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Resource names — change these to customise the demo without editing logic
# ---------------------------------------------------------------------------
VAULT_TARGET_NAME="demo-vault-target"
USC_NAME="demo-vault-usc"
USC_PATH="/demo-vault-usc/*"

READONLY_ROLE_NAME="demo-readonly-role"
READONLY_AUTH_NAME="demo-readonly-auth"

DENIED_ROLE_NAME="demo-denied-role"
DENIED_AUTH_NAME="demo-denied-auth"

# ---------------------------------------------------------------------------
# Defaults for optional env vars
# ---------------------------------------------------------------------------
VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"

# ---------------------------------------------------------------------------
# Step 1 — Validate required environment variables
# ---------------------------------------------------------------------------
echo "==> Validating environment variables"

MISSING_VARS=0

if [[ -z "${AKEYLESS_GATEWAY_URL:-}" ]]; then
    echo "ERROR: AKEYLESS_GATEWAY_URL is not set."
    echo "       Set it to the URL of your Akeyless Gateway, e.g.:"
    echo "         export AKEYLESS_GATEWAY_URL=\"https://your-gateway.example.com:8000\""
    MISSING_VARS=1
fi

if [[ "$MISSING_VARS" -ne 0 ]]; then
    echo ""
    echo "One or more required environment variables are missing. Aborting."
    exit 1
fi

echo "    VAULT_ADDR           = $VAULT_ADDR"
echo "    VAULT_TOKEN          = (set)"
echo "    AKEYLESS_GATEWAY_URL = $AKEYLESS_GATEWAY_URL"

# ---------------------------------------------------------------------------
# Step 2 — Create HashiCorp Vault Target
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating HashiCorp Vault Target: $VAULT_TARGET_NAME"

akeyless target create hashi-vault \
    --name "$VAULT_TARGET_NAME" \
    --hashi-url "$VAULT_ADDR" \
    --vault-token "$VAULT_TOKEN"

echo "    Target '$VAULT_TARGET_NAME' created."

# ---------------------------------------------------------------------------
# Step 3 — Create Universal Secret Connector (USC)
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating Universal Secret Connector: $USC_NAME"

akeyless create-usc \
    --usc-name "$USC_NAME" \
    --target-to-associate "$VAULT_TARGET_NAME" \
    --gw-cluster-url "$AKEYLESS_GATEWAY_URL"

echo "    USC '$USC_NAME' created and associated with target '$VAULT_TARGET_NAME'."

# ---------------------------------------------------------------------------
# Step 4 — Verify USC by listing secrets
# ---------------------------------------------------------------------------
echo ""
echo "==> Verifying USC by listing secrets under '$USC_NAME'"

akeyless usc list --usc-name "$USC_NAME"

echo "    USC verification successful."

# ---------------------------------------------------------------------------
# Step 5 — Create read-only RBAC role
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating read-only RBAC role: $READONLY_ROLE_NAME"

akeyless create-role \
    --name "$READONLY_ROLE_NAME" || true

akeyless set-role-rule \
    --role-name "$READONLY_ROLE_NAME" \
    --path "$USC_PATH" \
    --capability read \
    --capability list || true

echo "    Role '$READONLY_ROLE_NAME' created with read + list on '$USC_PATH'."

# ---------------------------------------------------------------------------
# Step 6 — Create API key auth method for read-only role and associate it
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating API key auth method: $READONLY_AUTH_NAME"

akeyless create-auth-method-api-key \
    --name "$READONLY_AUTH_NAME" || true

akeyless assoc-role-am \
    --role-name "$READONLY_ROLE_NAME" \
    --am-name "$READONLY_AUTH_NAME" || true

echo "    Auth method '$READONLY_AUTH_NAME' created and associated with role '$READONLY_ROLE_NAME'."

# ---------------------------------------------------------------------------
# Step 7 — Create denied RBAC role
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating denied RBAC role: $DENIED_ROLE_NAME"

akeyless create-role \
    --name "$DENIED_ROLE_NAME" || true

akeyless set-role-rule \
    --role-name "$DENIED_ROLE_NAME" \
    --path "$USC_PATH" \
    --capability deny || true

echo "    Role '$DENIED_ROLE_NAME' created with deny on '$USC_PATH'."

# ---------------------------------------------------------------------------
# Step 8 — Create API key auth method for denied role and associate it
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating API key auth method: $DENIED_AUTH_NAME"

akeyless create-auth-method-api-key \
    --name "$DENIED_AUTH_NAME" || true

akeyless assoc-role-am \
    --role-name "$DENIED_ROLE_NAME" \
    --am-name "$DENIED_AUTH_NAME" || true

echo "    Auth method '$DENIED_AUTH_NAME' created and associated with role '$DENIED_ROLE_NAME'."

# ---------------------------------------------------------------------------
# Step 9 — Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "==> Akeyless demo setup complete!"
echo "============================================================"
echo ""
echo "Resources created:"
echo ""
echo "  [Target]"
echo "    Name : $VAULT_TARGET_NAME"
echo "    URL  : $VAULT_ADDR"
echo ""
echo "  [Universal Secret Connector]"
echo "    Name    : $USC_NAME"
echo "    Path    : $USC_PATH"
echo "    Gateway : $AKEYLESS_GATEWAY_URL"
echo ""
echo "  [Read-Only Access]"
echo "    Role        : $READONLY_ROLE_NAME"
echo "    Auth Method : $READONLY_AUTH_NAME"
echo "    Capabilities: read, list"
echo ""
echo "  [Denied Access]"
echo "    Role        : $DENIED_ROLE_NAME"
echo "    Auth Method : $DENIED_AUTH_NAME"
echo "    Capabilities: deny"
echo ""
echo "Next steps:"
echo "  - Use '$READONLY_AUTH_NAME' credentials to demonstrate read-only access"
echo "  - Use '$DENIED_AUTH_NAME' credentials to demonstrate access denial"
echo "  - Run 'akeyless usc list --usc-name $USC_NAME' to browse Vault secrets"
echo "============================================================"
