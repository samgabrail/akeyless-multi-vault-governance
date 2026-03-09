#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

AKEYLESS_PROFILE="${AKEYLESS_PROFILE:-demo}"
AKEYLESS_DEMO_ENV_FILE="${AKEYLESS_DEMO_ENV_FILE:-$SCRIPT_DIR/.akeyless-demo.env}"
VAULT_ADDR_BACKEND="${VAULT_ADDR_BACKEND:-http://127.0.0.1:8200}"
VAULT_ADDR_PAYMENTS="${VAULT_ADDR_PAYMENTS:-http://127.0.0.1:8202}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
AWS_REGION="${AWS_REGION:-us-east-2}"
AWS_DEMO_SECRET_NAME="${AWS_DEMO_SECRET_NAME:-demo/mvg/aws/payments-api-key}"
K8S_NAMESPACE="${K8S_NAMESPACE:-mvg-demo}"
K8S_DEMO_SECRET_NAME="${K8S_DEMO_SECRET_NAME:-payments-config}"
REQUIRE_AWS_E2E="${REQUIRE_AWS_E2E:-false}"
CLEANUP_ONLY=false
FULL_CLEANUP=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cleanup)
            FULL_CLEANUP=true
            ;;
        --cleanup-only)
            CLEANUP_ONLY=true
            FULL_CLEANUP=true
            ;;
        *)
            echo "Usage: $0 [--cleanup] [--cleanup-only]" >&2
            exit 1
            ;;
    esac
    shift
done

run() {
    local name="$1"
    shift
    echo "=== $name ==="
    "$@"
    echo "--- exit=0 ---"
}

profile_field() {
    local field="$1"
    sed -n "s/^  ${field} = '\\(.*\\)'$/\\1/p" "$HOME/.akeyless/profiles/${AKEYLESS_PROFILE}.toml"
}

resolve_host_ip() {
    hostname -I | awk '{print $1}'
}

ensure_gateway_url() {
    if [[ -n "${AKEYLESS_GATEWAY_URL:-}" ]]; then
        return
    fi

    AKEYLESS_GATEWAY_URL="$(profile_field gateway_url)"
    if [[ -z "$AKEYLESS_GATEWAY_URL" ]]; then
        echo "ERROR: AKEYLESS_GATEWAY_URL is not set and no gateway_url was found in profile '$AKEYLESS_PROFILE'." >&2
        exit 1
    fi
}

normalize_vault_addresses_for_gateway() {
    local host_ip

    host_ip="$(resolve_host_ip)"
    if [[ -z "$host_ip" ]]; then
        echo "ERROR: failed to determine a routable host IP for the Vault targets." >&2
        exit 1
    fi

    if [[ "$VAULT_ADDR_BACKEND" == "http://127.0.0.1:8200" ]]; then
        VAULT_ADDR_BACKEND="http://${host_ip}:8200"
        export VAULT_ADDR_BACKEND
    fi

    if [[ "$VAULT_ADDR_PAYMENTS" == "http://127.0.0.1:8202" ]]; then
        VAULT_ADDR_PAYMENTS="http://${host_ip}:8202"
        export VAULT_ADDR_PAYMENTS
    fi
}

cleanup_demo_resources() {
    echo "==> Cleaning up demo resources"

    akeyless auth-method delete --name demo-denied-auth --profile "$AKEYLESS_PROFILE" >/dev/null 2>&1 || true
    akeyless auth-method delete --name demo-readonly-auth --profile "$AKEYLESS_PROFILE" >/dev/null 2>&1 || true
    akeyless delete-role --name demo-denied-role --profile "$AKEYLESS_PROFILE" >/dev/null 2>&1 || true
    akeyless delete-role --name demo-readonly-role --profile "$AKEYLESS_PROFILE" >/dev/null 2>&1 || true
    akeyless delete-item --name /demo-k8s-usc --profile "$AKEYLESS_PROFILE" >/dev/null 2>&1 || true
    akeyless delete-item --name /demo-aws-usc --profile "$AKEYLESS_PROFILE" >/dev/null 2>&1 || true
    akeyless delete-item --name /demo-vault-usc-payments --profile "$AKEYLESS_PROFILE" >/dev/null 2>&1 || true
    akeyless delete-item --name /demo-vault-usc-backend --profile "$AKEYLESS_PROFILE" >/dev/null 2>&1 || true
    akeyless target delete --name demo-k8s-target --force-deletion --profile "$AKEYLESS_PROFILE" >/dev/null 2>&1 || true
    akeyless target delete --name demo-aws-target --force-deletion --profile "$AKEYLESS_PROFILE" >/dev/null 2>&1 || true
    akeyless target delete --name demo-vault-target-payments --force-deletion --profile "$AKEYLESS_PROFILE" >/dev/null 2>&1 || true
    akeyless target delete --name demo-vault-target-backend --force-deletion --profile "$AKEYLESS_PROFILE" >/dev/null 2>&1 || true

    kubectl delete namespace "$K8S_NAMESPACE" >/dev/null 2>&1 || true

    if command -v aws >/dev/null 2>&1 && aws sts get-caller-identity >/dev/null 2>&1; then
        aws secretsmanager delete-secret \
            --region "$AWS_REGION" \
            --secret-id "$AWS_DEMO_SECRET_NAME" \
            --force-delete-without-recovery >/dev/null 2>&1 || true
    fi

    rm -f "$AKEYLESS_DEMO_ENV_FILE"
}

if [[ "$CLEANUP_ONLY" == "true" ]]; then
    cleanup_demo_resources
    exit 0
fi

ensure_gateway_url
normalize_vault_addresses_for_gateway

export VAULT_TOKEN
export AKEYLESS_PROFILE

if ! vault status -address="$VAULT_ADDR_BACKEND" >/dev/null 2>&1 || ! vault status -address="$VAULT_ADDR_PAYMENTS" >/dev/null 2>&1; then
    run "start vault dev servers" bash "$SCRIPT_DIR/setup-vault-dev.sh"
fi

cloud_setup_output="$(bash "$SCRIPT_DIR/setup-cloud-and-k8s-demo.sh")"
printf '%s\n' "$cloud_setup_output"
eval "$(printf '%s\n' "$cloud_setup_output" | sed -n "s/^export /export /p")"

run "reconcile akeyless demo resources" env AKEYLESS_GATEWAY_URL="$AKEYLESS_GATEWAY_URL" bash "$SCRIPT_DIR/akeyless-setup.sh"
source "$AKEYLESS_DEMO_ENV_FILE"

demo_access_id="$(profile_field access_id)"
demo_access_key="$(profile_field access_key)"
if [[ -z "$demo_access_id" || -z "$demo_access_key" ]]; then
    echo "ERROR: failed to read access_id/access_key from profile '$AKEYLESS_PROFILE'." >&2
    exit 1
fi

ts="$(date +%Y%m%d%H%M%S)"
backend_test_secret="secret/myapp/e2e-akeyless-$ts"
payments_test_secret="secret/payments/e2e-vault-$ts"
encoded_value="$(printf '{"value":"e2e-from-akeyless-%s"}' "$ts" | base64 -w0)"
export VAULT_ADDR="$VAULT_ADDR_BACKEND"

cleanup_test_secrets() {
    export VAULT_ADDR="$VAULT_ADDR_BACKEND"
    vault kv metadata delete "$backend_test_secret" >/dev/null 2>&1 || true
    export VAULT_ADDR="$VAULT_ADDR_PAYMENTS"
    vault kv metadata delete "$payments_test_secret" >/dev/null 2>&1 || true
}

trap cleanup_test_secrets EXIT

run "vault backend list" vault kv list secret/myapp
run "vault backend get db-password" vault kv get -format=json secret/myapp/db-password
export VAULT_ADDR="$VAULT_ADDR_PAYMENTS"
run "vault payments list" vault kv list secret/payments
run "vault payments get stripe-key" vault kv get -format=json secret/payments/stripe-key

run "gateway pods" kubectl get pods -n akeyless
run "gateway service" kubectl get svc -n akeyless

run "usc list backend" akeyless usc list --usc-name "$USC_BACKEND" --profile "$AKEYLESS_PROFILE"
run "usc list payments" akeyless usc list --usc-name "$USC_PAYMENTS" --profile "$AKEYLESS_PROFILE"
run "usc get backend db-password" akeyless usc get --usc-name "$USC_BACKEND" --secret-id secret/myapp/db-password --profile "$AKEYLESS_PROFILE"
run "usc get payments stripe-key" akeyless usc get --usc-name "$USC_PAYMENTS" --secret-id secret/payments/stripe-key --profile "$AKEYLESS_PROFILE"

export VAULT_ADDR="$VAULT_ADDR_BACKEND"
run "usc create backend unique secret" akeyless usc create --usc-name "$USC_BACKEND" --secret-name "$backend_test_secret" --value "$encoded_value" --profile "$AKEYLESS_PROFILE"
run "vault verify backend unique secret" vault kv get -format=json "$backend_test_secret"

export VAULT_ADDR="$VAULT_ADDR_PAYMENTS"
run "vault create payments unique secret" vault kv put "$payments_test_secret" value="e2e-from-vault-$ts"
run "usc get payments unique secret" akeyless usc get --usc-name "$USC_PAYMENTS" --secret-id "$payments_test_secret" --profile "$AKEYLESS_PROFILE"

export VAULT_ADDR='https://hvp.akeyless.io'
export VAULT_TOKEN="${demo_access_id}..${demo_access_key}"
run "hvp get db-password" vault kv get -format=json secret/myapp/db-password
run "hvp get api-key" vault kv get -format=json secret/myapp/api-key

aws_usc_verified=false
if [[ "${ENABLE_AWS_DEMO:-false}" == "true" ]]; then
    echo "=== usc list aws ==="
    if akeyless usc list --usc-name "$USC_AWS" --profile "$AKEYLESS_PROFILE"; then
        echo "--- exit=0 ---"
        run "usc get aws" akeyless usc get --usc-name "$USC_AWS" --secret-id "$AWS_DEMO_SECRET_NAME" --profile "$AKEYLESS_PROFILE"
        aws_usc_verified=true
    elif [[ "$REQUIRE_AWS_E2E" == "true" ]]; then
        echo "AWS USC validation failed and REQUIRE_AWS_E2E=true." >&2
        exit 1
    else
        echo "Skipped: AWS target/USC was created, but gateway validation failed."
        echo "--- exit=0 ---"
    fi
else
    echo "=== usc aws ==="
    echo "Skipped: ENABLE_AWS_DEMO=false"
    echo "--- exit=0 ---"
fi

if [[ "${ENABLE_K8S_DEMO:-false}" == "true" ]]; then
    run "usc list k8s" akeyless usc list --usc-name "$USC_K8S" --profile "$AKEYLESS_PROFILE"
    run "usc get k8s" akeyless usc get --usc-name "$USC_K8S" --secret-id "$K8S_DEMO_SECRET_NAME" --profile "$AKEYLESS_PROFILE"
else
    echo "=== usc k8s ==="
    echo "Skipped: ENABLE_K8S_DEMO=false"
    echo "--- exit=0 ---"
fi

denied_token="$(akeyless auth --access-id "$DENIED_ACCESS_ID" --access-key "$DENIED_ACCESS_KEY" --access-type access_key --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')"

echo "=== denied backend ==="
if akeyless usc get --usc-name "$USC_BACKEND" --secret-id secret/myapp/db-password --gateway-url "$AKEYLESS_GW" --token "$denied_token" >/dev/null 2>&1; then
    echo "Expected 403 for denied backend access, but request succeeded." >&2
    exit 1
fi
echo "403 verified"
echo "--- exit=0 ---"

echo "=== denied payments ==="
if akeyless usc get --usc-name "$USC_PAYMENTS" --secret-id secret/payments/stripe-key --gateway-url "$AKEYLESS_GW" --token "$denied_token" >/dev/null 2>&1; then
    echo "Expected 403 for denied payments access, but request succeeded." >&2
    exit 1
fi
echo "403 verified"
echo "--- exit=0 ---"

if [[ "${ENABLE_K8S_DEMO:-false}" == "true" ]]; then
    echo "=== denied k8s ==="
    if akeyless usc get --usc-name "$USC_K8S" --secret-id "$K8S_DEMO_SECRET_NAME" --gateway-url "$AKEYLESS_GW" --token "$denied_token" >/dev/null 2>&1; then
        echo "Expected 403 for denied k8s access, but request succeeded." >&2
        exit 1
    fi
    echo "403 verified"
    echo "--- exit=0 ---"
fi

if [[ "${ENABLE_AWS_DEMO:-false}" == "true" && "$aws_usc_verified" == "true" ]]; then
    echo "=== denied aws ==="
    if akeyless usc get --usc-name "$USC_AWS" --secret-id "$AWS_DEMO_SECRET_NAME" --gateway-url "$AKEYLESS_GW" --token "$denied_token" >/dev/null 2>&1; then
        echo "Expected 403 for denied aws access, but request succeeded." >&2
        exit 1
    fi
    echo "403 verified"
    echo "--- exit=0 ---"
fi

echo "E2E demo validation completed successfully."

if [[ "$FULL_CLEANUP" == "true" ]]; then
    cleanup_demo_resources
fi
