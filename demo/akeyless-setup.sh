#!/usr/bin/env bash
# akeyless-setup.sh
#
# Reconciles all Akeyless demo resources for the multi-vault governance demo.
# The script is intentionally rerunnable: it resets demo-scoped targets, USCs,
# roles, and auth methods, then recreates them from the current environment.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

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

VAULT_ADDR_BACKEND="${VAULT_ADDR_BACKEND:-http://127.0.0.1:8200}"
VAULT_ADDR_PAYMENTS="${VAULT_ADDR_PAYMENTS:-http://127.0.0.1:8202}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
AKEYLESS_PROFILE="${AKEYLESS_PROFILE:-demo}"
ENABLE_AWS_DEMO="${ENABLE_AWS_DEMO:-false}"
ENABLE_K8S_DEMO="${ENABLE_K8S_DEMO:-false}"
AWS_REGION="${AWS_REGION:-us-east-2}"
AWS_USC_PREFIX="${AWS_USC_PREFIX:-demo/mvg/aws/}"
K8S_NAMESPACE="${K8S_NAMESPACE:-mvg-demo}"
AKEYLESS_DEMO_ENV_FILE="${AKEYLESS_DEMO_ENV_FILE:-$SCRIPT_DIR/.akeyless-demo.env}"

echo "==> Validating environment variables"

if [[ -z "${AKEYLESS_GATEWAY_URL:-}" ]]; then
    echo "ERROR: AKEYLESS_GATEWAY_URL is not set."
    echo "       Set it to the URL of your Akeyless Gateway, e.g.:"
    echo "         export AKEYLESS_GATEWAY_URL=\"https://192.168.1.82:8000\""
    exit 1
fi

if [[ "$ENABLE_AWS_DEMO" == "true" ]]; then
    if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        echo "ERROR: ENABLE_AWS_DEMO=true requires AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY." >&2
        exit 1
    fi
fi

if [[ "$ENABLE_K8S_DEMO" == "true" ]]; then
    if [[ -z "${K8S_CLUSTER_ENDPOINT:-}" || -z "${K8S_CLUSTER_CA_CERT:-}" || -z "${K8S_CLUSTER_TOKEN:-}" ]]; then
        echo "ERROR: ENABLE_K8S_DEMO=true requires K8S_CLUSTER_ENDPOINT, K8S_CLUSTER_CA_CERT, and K8S_CLUSTER_TOKEN." >&2
        echo "       Use demo/setup-cloud-and-k8s-demo.sh to generate them." >&2
        exit 1
    fi
fi

echo "    VAULT_ADDR_BACKEND   = $VAULT_ADDR_BACKEND"
echo "    VAULT_ADDR_PAYMENTS  = $VAULT_ADDR_PAYMENTS"
echo "    VAULT_TOKEN          = (set)"
echo "    AKEYLESS_GATEWAY_URL = $AKEYLESS_GATEWAY_URL"
echo "    AKEYLESS_PROFILE     = $AKEYLESS_PROFILE"
echo "    ENABLE_AWS_DEMO      = $ENABLE_AWS_DEMO"
echo "    ENABLE_K8S_DEMO      = $ENABLE_K8S_DEMO"

akl() {
    env -u AKEYLESS_GATEWAY_URL akeyless "$@" --profile "$AKEYLESS_PROFILE"
}

json_field() {
    local field="$1"
    python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1], ""))' "$field"
}

item_exists() {
    local name="$1"
    akl describe-item --name "/$name" >/dev/null 2>&1
}

target_exists() {
    local name="$1"
    akl target get --name "$name" >/dev/null 2>&1
}

wait_until_missing() {
    local kind="$1"
    local name="$2"
    local attempt

    for attempt in {1..10}; do
        if [[ "$kind" == "item" ]] && ! item_exists "$name"; then
            return 0
        fi

        if [[ "$kind" == "target" ]] && ! target_exists "$name"; then
            return 0
        fi

        sleep 1
    done

    echo "ERROR: timed out waiting for $kind '$name' to be deleted." >&2
    exit 1
}

delete_item_if_exists() {
    local name="$1"
    akl delete-item --name "/$name" >/dev/null 2>&1 || true
    wait_until_missing item "$name"
}

delete_target_if_exists() {
    local name="$1"
    akl target delete --name "$name" --force-deletion >/dev/null 2>&1 || true
    wait_until_missing target "$name"
}

delete_auth_method_if_exists() {
    local name="$1"
    akl auth-method delete --name "$name" >/dev/null 2>&1 || true
}

delete_role_if_exists() {
    local name="$1"
    akl delete-role --name "$name" >/dev/null 2>&1 || true
}

echo ""
echo "==> Resetting existing demo-scoped Akeyless resources"

delete_auth_method_if_exists "$DENIED_AUTH_NAME"
delete_auth_method_if_exists "$READONLY_AUTH_NAME"
delete_role_if_exists "$DENIED_ROLE_NAME"
delete_role_if_exists "$READONLY_ROLE_NAME"

delete_item_if_exists "$USC_K8S"
delete_item_if_exists "$USC_AWS"
delete_item_if_exists "$USC_PAYMENTS"
delete_item_if_exists "$USC_BACKEND"

delete_target_if_exists "$TARGET_K8S"
delete_target_if_exists "$TARGET_AWS"
delete_target_if_exists "$TARGET_PAYMENTS"
delete_target_if_exists "$TARGET_BACKEND"

echo "    Removed existing demo objects, if any."

echo ""
echo "==> Creating Vault target: $TARGET_BACKEND"
akl target create hashi-vault \
    --name "$TARGET_BACKEND" \
    --hashi-url "$VAULT_ADDR_BACKEND" \
    --vault-token "$VAULT_TOKEN"

echo ""
echo "==> Creating Vault target: $TARGET_PAYMENTS"
akl target create hashi-vault \
    --name "$TARGET_PAYMENTS" \
    --hashi-url "$VAULT_ADDR_PAYMENTS" \
    --vault-token "$VAULT_TOKEN"

echo ""
echo "==> Creating USC: $USC_BACKEND"
akl create-usc \
    --name "$USC_BACKEND" \
    --target-to-associate "$TARGET_BACKEND" \
    --gateway-url "$AKEYLESS_GATEWAY_URL"

echo ""
echo "==> Creating USC: $USC_PAYMENTS"
akl create-usc \
    --name "$USC_PAYMENTS" \
    --target-to-associate "$TARGET_PAYMENTS" \
    --gateway-url "$AKEYLESS_GATEWAY_URL"

if [[ "$ENABLE_AWS_DEMO" == "true" ]]; then
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

if [[ "$ENABLE_K8S_DEMO" == "true" ]]; then
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

echo ""
echo "==> Verifying USC '$USC_BACKEND'..."
akl usc list --usc-name "$USC_BACKEND"

echo ""
echo "==> Verifying USC '$USC_PAYMENTS'..."
akl usc list --usc-name "$USC_PAYMENTS"

if [[ "$ENABLE_AWS_DEMO" == "true" ]]; then
    echo ""
    echo "==> Verifying USC '$USC_AWS'..."
    if ! akl usc list --usc-name "$USC_AWS"; then
        echo "WARNING: AWS USC '$USC_AWS' was created, but listing secrets failed." >&2
        echo "         This usually means the gateway cannot use the configured AWS credentials yet." >&2
    fi
fi

if [[ "$ENABLE_K8S_DEMO" == "true" ]]; then
    echo ""
    echo "==> Verifying USC '$USC_K8S'..."
    akl usc list --usc-name "$USC_K8S"
fi

echo ""
echo "==> Creating read-only RBAC role: $READONLY_ROLE_NAME"
akl create-role --name "$READONLY_ROLE_NAME"
akl set-role-rule --role-name "$READONLY_ROLE_NAME" --path "$USC_PATH_BACKEND" --capability read --capability list
akl set-role-rule --role-name "$READONLY_ROLE_NAME" --path "$USC_PATH_PAYMENTS" --capability read --capability list
if [[ "$ENABLE_AWS_DEMO" == "true" ]]; then
    akl set-role-rule --role-name "$READONLY_ROLE_NAME" --path "$USC_PATH_AWS" --capability read --capability list
fi
if [[ "$ENABLE_K8S_DEMO" == "true" ]]; then
    akl set-role-rule --role-name "$READONLY_ROLE_NAME" --path "$USC_PATH_K8S" --capability read --capability list
fi

echo ""
echo "==> Creating denied RBAC role: $DENIED_ROLE_NAME"
akl create-role --name "$DENIED_ROLE_NAME"
akl set-role-rule --role-name "$DENIED_ROLE_NAME" --path "$USC_PATH_BACKEND" --capability deny
akl set-role-rule --role-name "$DENIED_ROLE_NAME" --path "$USC_PATH_PAYMENTS" --capability deny
if [[ "$ENABLE_AWS_DEMO" == "true" ]]; then
    akl set-role-rule --role-name "$DENIED_ROLE_NAME" --path "$USC_PATH_AWS" --capability deny
fi
if [[ "$ENABLE_K8S_DEMO" == "true" ]]; then
    akl set-role-rule --role-name "$DENIED_ROLE_NAME" --path "$USC_PATH_K8S" --capability deny
fi

echo ""
echo "==> Creating API key auth method: $READONLY_AUTH_NAME"
readonly_auth_json="$(akl auth-method create api-key --name "$READONLY_AUTH_NAME" --json)"
readonly_access_id="$(printf '%s' "$readonly_auth_json" | json_field access_id)"
readonly_access_key="$(printf '%s' "$readonly_auth_json" | json_field access_key)"
akl assoc-role-am --role-name "$READONLY_ROLE_NAME" --am-name "$READONLY_AUTH_NAME"

echo ""
echo "==> Creating API key auth method: $DENIED_AUTH_NAME"
denied_auth_json="$(akl auth-method create api-key --name "$DENIED_AUTH_NAME" --json)"
denied_access_id="$(printf '%s' "$denied_auth_json" | json_field access_id)"
denied_access_key="$(printf '%s' "$denied_auth_json" | json_field access_key)"
akl assoc-role-am --role-name "$DENIED_ROLE_NAME" --am-name "$DENIED_AUTH_NAME"

cat > "$AKEYLESS_DEMO_ENV_FILE" <<EOF
export AKEYLESS_PROFILE='$AKEYLESS_PROFILE'
export AKEYLESS_GW='$AKEYLESS_GATEWAY_URL'
export USC_BACKEND='$USC_BACKEND'
export USC_PAYMENTS='$USC_PAYMENTS'
export USC_AWS='$USC_AWS'
export USC_K8S='$USC_K8S'
export AWS_DEMO_SECRET_NAME='${AWS_DEMO_SECRET_NAME:-demo/mvg/aws/payments-api-key}'
export K8S_NAMESPACE='$K8S_NAMESPACE'
export K8S_DEMO_SECRET_NAME='${K8S_DEMO_SECRET_NAME:-payments-config}'
export READONLY_ACCESS_ID='$readonly_access_id'
export READONLY_ACCESS_KEY='$readonly_access_key'
export DENIED_ACCESS_ID='$denied_access_id'
export DENIED_ACCESS_KEY='$denied_access_key'
EOF

echo ""
echo "============================================================"
echo "==> Akeyless demo setup complete"
echo "============================================================"
echo "  Gateway            : $AKEYLESS_GATEWAY_URL"
echo "  Read-only auth     : $READONLY_AUTH_NAME ($readonly_access_id)"
echo "  Denied auth        : $DENIED_AUTH_NAME ($denied_access_id)"
echo "  Export file        : $AKEYLESS_DEMO_ENV_FILE"
echo ""
echo "Next steps:"
echo "  source $AKEYLESS_DEMO_ENV_FILE"
echo "  bash $SCRIPT_DIR/test-e2e.sh"
