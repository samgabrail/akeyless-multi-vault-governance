#!/usr/bin/env bash
# akeyless-setup.sh
#
# Sets up all Akeyless resources for the multi-vault governance demo.
# Connects Akeyless to:
#
#   Vault 1 — backend team         (default: http://127.0.0.1:8200)
#   Vault 2 — payments team        (default: http://127.0.0.1:8202)
#   AWS Secrets Manager            (optional extension)
#   Kubernetes Secrets             (optional extension)
#
# Each backend gets its own target and MVG connector (currently surfaced in the
# product and CLI as USC). A single set of Akeyless RBAC roles governs access
# across all configured backends, demonstrating centralized governance without
# per-backend policy management.
#
# Topology note:
#   - This demo uses ONE Gateway URL for both Vaults to keep setup simple.
#   - Production deployments usually run one Gateway per private location/region,
#     close to each local Vault cluster and its workloads.
#   - Vault Enterprise teams may use DR or Performance Replication, but many
#     organizations still run isolated Vault clusters with no replication.
#
# Prerequisites:
#   - akeyless CLI installed and authenticated
#   - Both Vault dev servers running (see setup-vault-dev.sh)
#   - An Akeyless Gateway reachable at $AKEYLESS_GATEWAY_URL
#   - Optional: AWS and Kubernetes demo env vars if enabling those extensions
#
# Required environment variables:
#   AKEYLESS_GATEWAY_URL       URL of your Akeyless Gateway (no default — must be set)
#   AKEYLESS_PROFILE           akeyless CLI profile to use (default: demo)
#
# Optional environment variables (defaults shown):
#   VAULT_ADDR_BACKEND         http://127.0.0.1:8200
#   VAULT_ADDR_PAYMENTS        http://127.0.0.1:8202
#   VAULT_TOKEN                root
#   ENABLE_AWS_DEMO            false
#   ENABLE_K8S_DEMO            false
#   AWS_REGION                 us-east-2
#   AWS_USC_PREFIX             demo/mvg/aws/
#   K8S_NAMESPACE              mvg-demo
#
# NOTE: VAULT_ADDR_BACKEND and VAULT_ADDR_PAYMENTS are the addresses the
# Gateway uses to reach your Vault instances. If your Gateway runs on
# Kubernetes and Vault runs on localhost, use the host machine's network
# address (e.g., http://192.168.1.100:8200) rather than 127.0.0.1.
# Vault dev mode must also be started with -dev-listen-address="0.0.0.0:8200"
# so the Gateway can reach it on the network IP.
#
# Usage:
#   export AKEYLESS_GATEWAY_URL="https://your-gateway-ip:8000"
#   export AKEYLESS_PROFILE="demo"
#   bash demo/akeyless-setup.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Resource names
# ---------------------------------------------------------------------------
TARGET_BACKEND="demo-vault-target-backend"
TARGET_PAYMENTS="demo-vault-target-payments"
TARGET_AWS="demo-aws-target"
TARGET_K8S="demo-k8s-target"

USC_BACKEND="demo-vault-usc-backend"
USC_PAYMENTS="demo-vault-usc-payments"
USC_AWS="demo-aws-usc"
USC_K8S="demo-k8s-usc"

USC_PATH_BACKEND="/demo-vault-usc-backend/*"
USC_PATH_PAYMENTS="/demo-vault-usc-payments/*"
USC_PATH_AWS="/demo-aws-usc/*"
USC_PATH_K8S="/demo-k8s-usc/*"

READONLY_ROLE_NAME="demo-readonly-role"
READONLY_AUTH_NAME="demo-readonly-auth"

DENIED_ROLE_NAME="demo-denied-role"
DENIED_AUTH_NAME="demo-denied-auth"

# ---------------------------------------------------------------------------
# Defaults for optional env vars
# ---------------------------------------------------------------------------
VAULT_ADDR_BACKEND="${VAULT_ADDR_BACKEND:-http://127.0.0.1:8200}"
VAULT_ADDR_PAYMENTS="${VAULT_ADDR_PAYMENTS:-http://127.0.0.1:8202}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
AKEYLESS_PROFILE="${AKEYLESS_PROFILE:-demo}"
ENABLE_AWS_DEMO="${ENABLE_AWS_DEMO:-false}"
ENABLE_K8S_DEMO="${ENABLE_K8S_DEMO:-false}"
AWS_REGION="${AWS_REGION:-us-east-2}"
AWS_USC_PREFIX="${AWS_USC_PREFIX:-demo/mvg/aws/}"
K8S_NAMESPACE="${K8S_NAMESPACE:-mvg-demo}"

# ---------------------------------------------------------------------------
# Step 1 — Validate required environment variables
# ---------------------------------------------------------------------------
echo "==> Validating environment variables"

if [[ -z "${AKEYLESS_GATEWAY_URL:-}" ]]; then
    echo "ERROR: AKEYLESS_GATEWAY_URL is not set."
    echo "       Set it to the URL of your Akeyless Gateway, e.g.:"
    echo "         export AKEYLESS_GATEWAY_URL=\"https://192.168.1.82:8000\""
    exit 1
fi

echo "    VAULT_ADDR_BACKEND   = $VAULT_ADDR_BACKEND"
echo "    VAULT_ADDR_PAYMENTS  = $VAULT_ADDR_PAYMENTS"
echo "    VAULT_TOKEN          = (set)"
echo "    AKEYLESS_GATEWAY_URL = $AKEYLESS_GATEWAY_URL"
echo "    AKEYLESS_PROFILE     = $AKEYLESS_PROFILE"
echo "    ENABLE_AWS_DEMO      = $ENABLE_AWS_DEMO"
echo "    ENABLE_K8S_DEMO      = $ENABLE_K8S_DEMO"

# Helper: run akeyless with the configured profile
akl() { akeyless "$@" --profile "$AKEYLESS_PROFILE"; }

# ---------------------------------------------------------------------------
# Step 2 — Create Vault Target for backend team
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating Vault Target: $TARGET_BACKEND"

akl target create hashi-vault \
    --name "$TARGET_BACKEND" \
    --hashi-url "$VAULT_ADDR_BACKEND" \
    --vault-token "$VAULT_TOKEN"

echo "    Target '$TARGET_BACKEND' created."

# ---------------------------------------------------------------------------
# Step 3 — Create Vault Target for payments team
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating Vault Target: $TARGET_PAYMENTS"

akl target create hashi-vault \
    --name "$TARGET_PAYMENTS" \
    --hashi-url "$VAULT_ADDR_PAYMENTS" \
    --vault-token "$VAULT_TOKEN"

echo "    Target '$TARGET_PAYMENTS' created."

# ---------------------------------------------------------------------------
# Step 4 — Create USC for backend team
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating USC: $USC_BACKEND"

akl create-usc \
    --name "$USC_BACKEND" \
    --target-to-associate "$TARGET_BACKEND" \
    --gateway-url "$AKEYLESS_GATEWAY_URL"

echo "    USC '$USC_BACKEND' created."

# ---------------------------------------------------------------------------
# Step 5 — Create USC for payments team
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating USC: $USC_PAYMENTS"

akl create-usc \
    --name "$USC_PAYMENTS" \
    --target-to-associate "$TARGET_PAYMENTS" \
    --gateway-url "$AKEYLESS_GATEWAY_URL"

echo "    USC '$USC_PAYMENTS' created."

# ---------------------------------------------------------------------------
# Step 6 — Optional AWS target + USC
# ---------------------------------------------------------------------------
if [[ "$ENABLE_AWS_DEMO" == "true" ]]; then
    if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        echo "ERROR: ENABLE_AWS_DEMO=true requires AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY." >&2
        exit 1
    fi

    echo ""
    echo "==> Creating AWS target: $TARGET_AWS"
    if [[ -n "${AWS_SESSION_TOKEN:-}" ]]; then
        akl target create aws \
            --name "$TARGET_AWS" \
            --access-key-id "$AWS_ACCESS_KEY_ID" \
            --access-key "$AWS_SECRET_ACCESS_KEY" \
            --session-token "$AWS_SESSION_TOKEN" \
            --region "$AWS_REGION"
    else
        akl target create aws \
            --name "$TARGET_AWS" \
            --access-key-id "$AWS_ACCESS_KEY_ID" \
            --access-key "$AWS_SECRET_ACCESS_KEY" \
            --region "$AWS_REGION"
    fi

    echo ""
    echo "==> Creating AWS USC: $USC_AWS"
    akl create-usc \
        --name "$USC_AWS" \
        --target-to-associate "$TARGET_AWS" \
        --gateway-url "$AKEYLESS_GATEWAY_URL" \
        --usc-prefix "$AWS_USC_PREFIX" \
        --use-prefix-as-filter true
fi

# ---------------------------------------------------------------------------
# Step 7 — Optional Kubernetes target + USC
# ---------------------------------------------------------------------------
if [[ "$ENABLE_K8S_DEMO" == "true" ]]; then
    if [[ -z "${K8S_CLUSTER_ENDPOINT:-}" || -z "${K8S_CLUSTER_CA_CERT:-}" || -z "${K8S_CLUSTER_TOKEN:-}" ]]; then
        echo "ERROR: ENABLE_K8S_DEMO=true requires K8S_CLUSTER_ENDPOINT, K8S_CLUSTER_CA_CERT, and K8S_CLUSTER_TOKEN." >&2
        echo "       Use demo/setup-cloud-and-k8s-demo.sh to generate them." >&2
        exit 1
    fi

    echo ""
    echo "==> Creating Kubernetes target: $TARGET_K8S"
    akl target create k8s \
        --name "$TARGET_K8S" \
        --k8s-cluster-endpoint "$K8S_CLUSTER_ENDPOINT" \
        --k8s-cluster-ca-cert "$K8S_CLUSTER_CA_CERT" \
        --k8s-cluster-token "$K8S_CLUSTER_TOKEN"

    echo ""
    echo "==> Creating Kubernetes USC: $USC_K8S"
    akl create-usc \
        --name "$USC_K8S" \
        --target-to-associate "$TARGET_K8S" \
        --gateway-url "$AKEYLESS_GATEWAY_URL" \
        --k8s-namespace "$K8S_NAMESPACE"
fi

# ---------------------------------------------------------------------------
# Step 8 — Verify configured USCs by listing secrets
# ---------------------------------------------------------------------------
echo ""
echo "==> Verifying USC '$USC_BACKEND'..."
akl usc list --usc-name "$USC_BACKEND"

echo ""
echo "==> Verifying USC '$USC_PAYMENTS'..."
akl usc list --usc-name "$USC_PAYMENTS"

if [[ "$ENABLE_AWS_DEMO" == "true" ]]; then
    echo ""
    echo "==> Verifying USC '$USC_AWS'..."
    akl usc list --usc-name "$USC_AWS"
fi

if [[ "$ENABLE_K8S_DEMO" == "true" ]]; then
    echo ""
    echo "==> Verifying USC '$USC_K8S'..."
    akl usc list --usc-name "$USC_K8S"
fi

# ---------------------------------------------------------------------------
# Step 9 — Create read-only RBAC role covering all configured USCs
#
# A single role governing every backend is the central point of this
# demo: one policy, many secret stores, zero per-backend configuration.
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating read-only RBAC role: $READONLY_ROLE_NAME"

akl create-role \
    --name "$READONLY_ROLE_NAME" || true

akl set-role-rule \
    --role-name "$READONLY_ROLE_NAME" \
    --path "$USC_PATH_BACKEND" \
    --capability read \
    --capability list || true

akl set-role-rule \
    --role-name "$READONLY_ROLE_NAME" \
    --path "$USC_PATH_PAYMENTS" \
    --capability read \
    --capability list || true

if [[ "$ENABLE_AWS_DEMO" == "true" ]]; then
    akl set-role-rule \
        --role-name "$READONLY_ROLE_NAME" \
        --path "$USC_PATH_AWS" \
        --capability read \
        --capability list || true
fi

if [[ "$ENABLE_K8S_DEMO" == "true" ]]; then
    akl set-role-rule \
        --role-name "$READONLY_ROLE_NAME" \
        --path "$USC_PATH_K8S" \
        --capability read \
        --capability list || true
fi

echo "    Role '$READONLY_ROLE_NAME' created with read + list on all configured USCs."

# ---------------------------------------------------------------------------
# Step 10 — Create API key auth method for read-only role
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating API key auth method: $READONLY_AUTH_NAME"

akl create-auth-method \
    --name "$READONLY_AUTH_NAME" || true

akl assoc-role-am \
    --role-name "$READONLY_ROLE_NAME" \
    --am-name "$READONLY_AUTH_NAME" || true

echo "    Auth method '$READONLY_AUTH_NAME' associated with '$READONLY_ROLE_NAME'."

# ---------------------------------------------------------------------------
# Step 11 — Create denied RBAC role covering all configured USCs
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating denied RBAC role: $DENIED_ROLE_NAME"

akl create-role \
    --name "$DENIED_ROLE_NAME" || true

akl set-role-rule \
    --role-name "$DENIED_ROLE_NAME" \
    --path "$USC_PATH_BACKEND" \
    --capability deny || true

akl set-role-rule \
    --role-name "$DENIED_ROLE_NAME" \
    --path "$USC_PATH_PAYMENTS" \
    --capability deny || true

if [[ "$ENABLE_AWS_DEMO" == "true" ]]; then
    akl set-role-rule \
        --role-name "$DENIED_ROLE_NAME" \
        --path "$USC_PATH_AWS" \
        --capability deny || true
fi

if [[ "$ENABLE_K8S_DEMO" == "true" ]]; then
    akl set-role-rule \
        --role-name "$DENIED_ROLE_NAME" \
        --path "$USC_PATH_K8S" \
        --capability deny || true
fi

echo "    Role '$DENIED_ROLE_NAME' created with deny on all configured USCs."

# ---------------------------------------------------------------------------
# Step 12 — Create API key auth method for denied role
# ---------------------------------------------------------------------------
echo ""
echo "==> Creating API key auth method: $DENIED_AUTH_NAME"

akl create-auth-method \
    --name "$DENIED_AUTH_NAME" || true

akl assoc-role-am \
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
if [[ "$ENABLE_AWS_DEMO" == "true" ]]; then
echo "    $USC_AWS       → $TARGET_AWS"
fi
if [[ "$ENABLE_K8S_DEMO" == "true" ]]; then
echo "    $USC_K8S       → $TARGET_K8S"
fi
echo "    Gateway        : $AKEYLESS_GATEWAY_URL"
echo ""
echo "  [Read-Only Access — governs all configured USCs]"
echo "    Role        : $READONLY_ROLE_NAME"
echo "    Auth Method : $READONLY_AUTH_NAME"
echo "    Paths       : $USC_PATH_BACKEND"
echo "                  $USC_PATH_PAYMENTS"
if [[ "$ENABLE_AWS_DEMO" == "true" ]]; then
echo "                  $USC_PATH_AWS"
fi
if [[ "$ENABLE_K8S_DEMO" == "true" ]]; then
echo "                  $USC_PATH_K8S"
fi
echo "    Capabilities: read, list"
echo ""
echo "  [Denied Access — governs all configured USCs]"
echo "    Role        : $DENIED_ROLE_NAME"
echo "    Auth Method : $DENIED_AUTH_NAME"
echo "    Paths       : $USC_PATH_BACKEND"
echo "                  $USC_PATH_PAYMENTS"
if [[ "$ENABLE_AWS_DEMO" == "true" ]]; then
echo "                  $USC_PATH_AWS"
fi
if [[ "$ENABLE_K8S_DEMO" == "true" ]]; then
echo "                  $USC_PATH_K8S"
fi
echo "    Capabilities: deny"
echo ""
echo "Next steps:"
echo "  - Get the Access ID + Key for '$DENIED_AUTH_NAME' from the Akeyless"
echo "    console (Settings → Auth Methods) for use in Chapter 8 of the demo."
echo "    Or retrieve via CLI:"
echo "      akeyless auth-method describe --name $DENIED_AUTH_NAME --profile $AKEYLESS_PROFILE"
echo "  - Run demo commands from demo/demo-commands.sh"
echo "============================================================"
