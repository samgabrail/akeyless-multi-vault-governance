#!/usr/bin/env bash
# akeyless-setup.sh
#
# Sets up all Akeyless resources for the multi-vault governance demo.
# Connects Akeyless to TWO independently-running Vault dev servers:
#
#   Vault 1 — backend team   (default: http://127.0.0.1:8200)
#   Vault 2 — payments team  (default: http://127.0.0.1:8201)
#
# Each Vault gets its own Vault Target and Universal Secret Connector (USC).
# A single set of Akeyless RBAC roles governs access to secrets across both,
# demonstrating centralized governance without per-cluster policy management.
#
# Prerequisites:
#   - akeyless CLI installed and authenticated (run `akeyless auth` first)
#   - Both Vault dev servers running (see setup-vault-dev.sh)
#   - An Akeyless Gateway reachable at $AKEYLESS_GATEWAY_URL
#
# Required environment variables:
#   AKEYLESS_GATEWAY_URL       URL of your Akeyless Gateway (no default — must be set)
#
# Optional environment variables (defaults shown):
#   VAULT_ADDR_BACKEND         http://127.0.0.1:8200
#   VAULT_ADDR_PAYMENTS        http://127.0.0.1:8201
#   VAULT_TOKEN                root
#
# NOTE: VAULT_ADDR_BACKEND and VAULT_ADDR_PAYMENTS are the addresses the
# Gateway uses to reach your Vault instances. If your Gateway runs on
# Kubernetes and Vault runs on localhost, use the host machine's network
# address (e.g., http://192.168.1.100:8200) rather than 127.0.0.1.
#
# Usage:
#   export AKEYLESS_GATEWAY_URL="https://your-gateway.example.com:8000"
#   bash demo/akeyless-setup.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Resource names
# ---------------------------------------------------------------------------
TARGET_BACKEND="demo-vault-target-backend"
TARGET_PAYMENTS="demo-vault-target-payments"

USC_BACKEND="demo-vault-usc-backend"
USC_PAYMENTS="demo-vault-usc-payments"

USC_PATH_BACKEND="/demo-vault-usc-backend/*"
USC_PATH_PAYMENTS="/demo-vault-usc-payments/*"

READONLY_ROLE_NAME="demo-readonly-role"
READONLY_AUTH_NAME="demo-readonly-auth"

DENIED_ROLE_NAME="demo-denied-role"
DENIED_AUTH_NAME="demo-denied-auth"

# ---------------------------------------------------------------------------
# Defaults for optional env vars
# ---------------------------------------------------------------------------
VAULT_ADDR_BACKEND="${VAULT_ADDR_BACKEND:-http://127.0.0.1:8200}"
VAULT_ADDR_PAYMENTS="${VAULT_ADDR_PAYMENTS:-http://127.0.0.1:8201}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"

# ---------------------------------------------------------------------------
# Step 1 — Validate required environment variables
# ---------------------------------------------------------------------------
echo "==> Validating environment variables"

if [[ -z "${AKEYLESS_GATEWAY_URL:-}" ]]; then
    echo "ERROR: AKEYLESS_GATEWAY_URL is not set."
    echo "       Set it to the URL of your Akeyless Gateway, e.g.:"
    echo "         export AKEYLESS_GATEWAY_URL=\"https://your-gateway.example.com:8000\""
    exit 1
fi

echo "    VAULT_ADDR_BACKEND   = $VAULT_ADDR_BACKEND"
echo "    VAULT_ADDR_PAYMENTS  = $VAULT_ADDR_PAYMENTS"
echo "    VAULT_TOKEN          = (set)"
echo "    AKEYLESS_GATEWAY_URL = $AKEYLESS_GATEWAY_URL"

# ---------------------------------------------------------------------------
# Step 2 — Create Vault Target for backend team
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating Vault Target: $TARGET_BACKEND"

akeyless target create hashi-vault \
    --name "$TARGET_BACKEND" \
    --hashi-url "$VAULT_ADDR_BACKEND" \
    --vault-token "$VAULT_TOKEN"

echo "    Target '$TARGET_BACKEND' created."

# ---------------------------------------------------------------------------
# Step 3 — Create Vault Target for payments team
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating Vault Target: $TARGET_PAYMENTS"

akeyless target create hashi-vault \
    --name "$TARGET_PAYMENTS" \
    --hashi-url "$VAULT_ADDR_PAYMENTS" \
    --vault-token "$VAULT_TOKEN"

echo "    Target '$TARGET_PAYMENTS' created."

# ---------------------------------------------------------------------------
# Step 4 — Create USC for backend team
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating USC: $USC_BACKEND"

akeyless create-usc \
    --usc-name "$USC_BACKEND" \
    --target-to-associate "$TARGET_BACKEND" \
    --gw-cluster-url "$AKEYLESS_GATEWAY_URL"

echo "    USC '$USC_BACKEND' created."

# ---------------------------------------------------------------------------
# Step 5 — Create USC for payments team
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating USC: $USC_PAYMENTS"

akeyless create-usc \
    --usc-name "$USC_PAYMENTS" \
    --target-to-associate "$TARGET_PAYMENTS" \
    --gw-cluster-url "$AKEYLESS_GATEWAY_URL"

echo "    USC '$USC_PAYMENTS' created."

# ---------------------------------------------------------------------------
# Step 6 — Verify both USCs by listing secrets
# ---------------------------------------------------------------------------
echo ""
echo "==> Verifying USC '$USC_BACKEND'..."
akeyless usc list --usc-name "$USC_BACKEND"

echo ""
echo "==> Verifying USC '$USC_PAYMENTS'..."
akeyless usc list --usc-name "$USC_PAYMENTS"

# ---------------------------------------------------------------------------
# Step 7 — Create read-only RBAC role covering BOTH USCs
#
# A single role governing both Vault instances is the central point of
# this demo: one policy, two clusters, zero per-cluster configuration.
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating read-only RBAC role: $READONLY_ROLE_NAME"

akeyless create-role \
    --name "$READONLY_ROLE_NAME" || true

akeyless set-role-rule \
    --role-name "$READONLY_ROLE_NAME" \
    --path "$USC_PATH_BACKEND" \
    --capability read \
    --capability list || true

akeyless set-role-rule \
    --role-name "$READONLY_ROLE_NAME" \
    --path "$USC_PATH_PAYMENTS" \
    --capability read \
    --capability list || true

echo "    Role '$READONLY_ROLE_NAME' created with read + list on both USCs."

# ---------------------------------------------------------------------------
# Step 8 — Create API key auth method for read-only role
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating API key auth method: $READONLY_AUTH_NAME"

akeyless create-auth-method-api-key \
    --name "$READONLY_AUTH_NAME" || true

akeyless assoc-role-am \
    --role-name "$READONLY_ROLE_NAME" \
    --am-name "$READONLY_AUTH_NAME" || true

echo "    Auth method '$READONLY_AUTH_NAME' associated with '$READONLY_ROLE_NAME'."

# ---------------------------------------------------------------------------
# Step 9 — Create denied RBAC role covering BOTH USCs
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating denied RBAC role: $DENIED_ROLE_NAME"

akeyless create-role \
    --name "$DENIED_ROLE_NAME" || true

akeyless set-role-rule \
    --role-name "$DENIED_ROLE_NAME" \
    --path "$USC_PATH_BACKEND" \
    --capability deny || true

akeyless set-role-rule \
    --role-name "$DENIED_ROLE_NAME" \
    --path "$USC_PATH_PAYMENTS" \
    --capability deny || true

echo "    Role '$DENIED_ROLE_NAME' created with deny on both USCs."

# ---------------------------------------------------------------------------
# Step 10 — Create API key auth method for denied role
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating API key auth method: $DENIED_AUTH_NAME"

akeyless create-auth-method-api-key \
    --name "$DENIED_AUTH_NAME" || true

akeyless assoc-role-am \
    --role-name "$DENIED_ROLE_NAME" \
    --am-name "$DENIED_AUTH_NAME" || true

echo "    Auth method '$DENIED_AUTH_NAME' associated with '$DENIED_ROLE_NAME'."

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "==> Akeyless demo setup complete!"
echo "============================================================"
echo ""
echo "  [Vault Targets]"
echo "    $TARGET_BACKEND    → $VAULT_ADDR_BACKEND"
echo "    $TARGET_PAYMENTS   → $VAULT_ADDR_PAYMENTS"
echo ""
echo "  [Universal Secret Connectors]"
echo "    $USC_BACKEND   → $TARGET_BACKEND"
echo "    $USC_PAYMENTS  → $TARGET_PAYMENTS"
echo "    Gateway        : $AKEYLESS_GATEWAY_URL"
echo ""
echo "  [Read-Only Access — governs BOTH USCs]"
echo "    Role        : $READONLY_ROLE_NAME"
echo "    Auth Method : $READONLY_AUTH_NAME"
echo "    Paths       : $USC_PATH_BACKEND"
echo "                  $USC_PATH_PAYMENTS"
echo "    Capabilities: read, list"
echo ""
echo "  [Denied Access — governs BOTH USCs]"
echo "    Role        : $DENIED_ROLE_NAME"
echo "    Auth Method : $DENIED_AUTH_NAME"
echo "    Paths       : $USC_PATH_BACKEND"
echo "                  $USC_PATH_PAYMENTS"
echo "    Capabilities: deny"
echo ""
echo "Next steps:"
echo "  - Get the Access ID + Key for '$DENIED_AUTH_NAME' from the Akeyless"
echo "    console (Settings → Auth Methods) for use in Chapter 6 of the demo."
echo "  - Run demo commands from demo/demo-commands.sh"
echo "============================================================"
