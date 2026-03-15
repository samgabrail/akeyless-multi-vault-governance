#!/usr/bin/env bash
# akeyless-setup.sh
#
# Reconciles all Akeyless demo resources for the multi-vault governance demo.
# The script is intentionally rerunnable: it resets demo-scoped targets, USCs,
# rotated secrets, roles, and auth methods, then recreates them from the
# current environment.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

DEMO_FOLDER="${AKEYLESS_DEMO_FOLDER:-MVG-demo}"

TARGET_BACKEND="${DEMO_FOLDER}/vault-target-backend"
TARGET_PAYMENTS="${DEMO_FOLDER}/vault-target-payments"
TARGET_AWS="${DEMO_FOLDER}/aws-target"
TARGET_AZURE="${DEMO_FOLDER}/azure-target"

USC_BACKEND="${DEMO_FOLDER}/vault-usc-backend"
USC_PAYMENTS="${DEMO_FOLDER}/vault-usc-payments"
USC_AWS="${DEMO_FOLDER}/aws-usc"
USC_AZURE="${DEMO_FOLDER}/azure-usc"

USC_PATH_BACKEND="/${USC_BACKEND}/*"
USC_PATH_PAYMENTS="/${USC_PAYMENTS}/*"
USC_PATH_AWS="/${USC_AWS}/*"
USC_PATH_AZURE="/${USC_AZURE}/*"

# Rotated secret item names (Akeyless items that manage rotation schedules)
ROTATED_VAULT="${DEMO_FOLDER}/vault-rotated-api-key"
ROTATED_AWS="${DEMO_FOLDER}/aws-rotated-secret"
ROTATED_AZURE="${DEMO_FOLDER}/azure-rotated-api-key"
ROTATED_AZURE_APP="${DEMO_FOLDER}/azure-app-rotated-secret"

TARGET_DB="${DEMO_FOLDER}/db-target"
DB_ROTATED="${DEMO_FOLDER}/db-rotated-password"
DB_ROTATED_VAULT_PATH="${DB_ROTATED_VAULT_PATH:-secret/payments/db-rotated-password}"

READONLY_ROLE_NAME="demo-readonly-role"
READONLY_AUTH_NAME="demo-readonly-auth"

DENIED_ROLE_NAME="demo-denied-role"
DENIED_AUTH_NAME="demo-denied-auth"

VAULT_ADDR_BACKEND="${VAULT_ADDR_BACKEND:-http://127.0.0.1:8200}"
VAULT_ADDR_PAYMENTS="${VAULT_ADDR_PAYMENTS:-http://127.0.0.1:8202}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
AKEYLESS_PROFILE="${AKEYLESS_PROFILE:-demo}"
ENABLE_AWS_DEMO="${ENABLE_AWS_DEMO:-false}"
ENABLE_AZURE_DEMO="${ENABLE_AZURE_DEMO:-false}"
AWS_REGION="${AWS_REGION:-us-east-2}"
AWS_USC_PREFIX="${AWS_USC_PREFIX:-}"
AZURE_VAULT_NAME="${AZURE_VAULT_NAME:-mvg-demo-kv}"
AZURE_STATIC_SECRET_NAME="${AZURE_STATIC_SECRET_NAME:-payments-api-key}"
AZURE_ROTATED_SECRET_NAME="${AZURE_ROTATED_SECRET_NAME:-demo-azure-rotated-api-key}"
# demo-akeyless-mvg-target: the "demo app" whose client secret Akeyless rotates
DEMO_APP_CLIENT_ID="${DEMO_APP_CLIENT_ID:-217ffd30-f65f-43ff-84d3-491dde1f2d96}"
AZURE_APP_KV_SECRET_NAME="${AZURE_APP_KV_SECRET_NAME:-demo-app-client-secret}"
ENABLE_DB_DEMO="${ENABLE_DB_DEMO:-false}"
MYSQL_HOST="${MYSQL_HOST:-}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
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

if [[ "$ENABLE_AZURE_DEMO" == "true" ]]; then
    if [[ -z "${AZURE_TENANT_ID:-}" || -z "${AZURE_CLIENT_ID:-}" || -z "${AZURE_CLIENT_SECRET:-}" ]]; then
        echo "ERROR: ENABLE_AZURE_DEMO=true requires AZURE_TENANT_ID, AZURE_CLIENT_ID, and AZURE_CLIENT_SECRET." >&2
        echo "       Use demo/setup-cloud-and-k8s-demo.sh to confirm they are set." >&2
        exit 1
    fi
fi

if [[ "$ENABLE_DB_DEMO" == "true" ]]; then
    if [[ -z "${MYSQL_HOST:-}" || -z "${MYSQL_USER:-}" || -z "${MYSQL_PASSWORD:-}" ]]; then
        echo "ERROR: ENABLE_DB_DEMO=true requires MYSQL_HOST, MYSQL_USER, and MYSQL_PASSWORD." >&2
        exit 1
    fi
fi

echo "    VAULT_ADDR_BACKEND   = $VAULT_ADDR_BACKEND"
echo "    VAULT_ADDR_PAYMENTS  = $VAULT_ADDR_PAYMENTS"
echo "    VAULT_TOKEN          = (set)"
echo "    AKEYLESS_GATEWAY_URL = $AKEYLESS_GATEWAY_URL"
echo "    AKEYLESS_PROFILE     = $AKEYLESS_PROFILE"
echo "    ENABLE_AWS_DEMO      = $ENABLE_AWS_DEMO"
echo "    ENABLE_AZURE_DEMO    = $ENABLE_AZURE_DEMO"

akl() {
    env -u AKEYLESS_GATEWAY_URL akeyless "$@" --profile "$AKEYLESS_PROFILE"
}

azure_cli_available() {
    if [[ -n "${AZ_CLI_BIN:-}" ]] && "$AZ_CLI_BIN" account show >/dev/null 2>&1; then
        return 0
    fi

    if command -v az >/dev/null 2>&1 && az account show >/dev/null 2>&1; then
        return 0
    fi

    return 1
}

azure_cli() {
    if [[ -n "${AZ_CLI_BIN:-}" ]]; then
        "$AZ_CLI_BIN" "$@"
    else
        az "$@"
    fi
}

json_field() {
    local field="$1"
    python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1], ""))' "$field"
}

secret_exists() {
    local name="$1"
    akl describe-item --name "/$name" >/dev/null 2>&1
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

delete_rotated_secret_if_exists() {
    local name="$1"
    akl rotated-secret delete --name "/$name" >/dev/null 2>&1 || true
    # rotated-secret delete is async; also try delete-item as fallback
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

# Delete rotated secrets before their targets (avoid dependency conflicts)
# True rotated secret items (created via rotated-secret create) need rotated-secret delete
delete_rotated_secret_if_exists "$ROTATED_AZURE_APP"
delete_rotated_secret_if_exists "$DB_ROTATED"
# Static secrets used as sync sources (created via create-secret) use delete-item
delete_item_if_exists "$ROTATED_AZURE"
delete_item_if_exists "$ROTATED_AWS"
delete_item_if_exists "$ROTATED_VAULT"

delete_item_if_exists "$USC_AZURE"
delete_item_if_exists "$USC_AWS"
delete_item_if_exists "$USC_PAYMENTS"
delete_item_if_exists "$USC_BACKEND"

delete_target_if_exists "$TARGET_AZURE"
delete_target_if_exists "$TARGET_AWS"
delete_target_if_exists "$TARGET_DB"
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
    if [[ -n "$AWS_USC_PREFIX" ]]; then
        akl create-usc \
            --name "$USC_AWS" \
            --target-to-associate "$TARGET_AWS" \
            --gateway-url "$AKEYLESS_GATEWAY_URL" \
            --usc-prefix "$AWS_USC_PREFIX" \
            --use-prefix-as-filter true
    else
        akl create-usc \
            --name "$USC_AWS" \
            --target-to-associate "$TARGET_AWS" \
            --gateway-url "$AKEYLESS_GATEWAY_URL"
    fi
fi

if [[ "$ENABLE_AZURE_DEMO" == "true" ]]; then
    echo ""
    echo "==> Creating Azure Key Vault target: $TARGET_AZURE"
    akl target create azure \
        --name "$TARGET_AZURE" \
        --tenant-id "$AZURE_TENANT_ID" \
        --client-id "$AZURE_CLIENT_ID" \
        --client-secret "$AZURE_CLIENT_SECRET"

    echo ""
    echo "==> Creating Azure Key Vault USC: $USC_AZURE"
    akl create-usc \
        --name "$USC_AZURE" \
        --target-to-associate "$TARGET_AZURE" \
        --gateway-url "$AKEYLESS_GATEWAY_URL" \
        --azure-kv-name "$AZURE_VAULT_NAME"

    echo ""
    echo "==> Creating Azure App Registration rotated secret: $ROTATED_AZURE_APP"
    # Rotates the client secret on the 'demo-akeyless-mvg-target' app registration.
    # Prerequisites (automated in setup-cloud-and-k8s-demo.sh):
    #   1. sp-akeyless-mvg-demo must be an owner of demo-akeyless-mvg-target
    #   2. sp-akeyless-mvg-demo must have an appRoleAssignment for
    #      Application.ReadWrite.OwnedBy (Graph role 18a4783c-...) — note: this
    #      requires a direct POST to /servicePrincipals/{id}/appRoleAssignments,
    #      NOT az ad app permission admin-consent (which only handles delegated perms)
    akl rotated-secret create azure \
        --name "$ROTATED_AZURE_APP" \
        --target-name "$TARGET_AZURE" \
        --rotator-type api-key \
        --authentication-credentials use-target-creds \
        --app-id "$DEMO_APP_CLIENT_ID" \
        --auto-rotate true \
        --rotation-interval 1 \
        --tag "compliance=pci-dss" --tag "demo=mvg" \
        --gateway-url "$AKEYLESS_GATEWAY_URL"

    echo ""
    echo "==> Purging soft-deleted KV secret '$AZURE_APP_KV_SECRET_NAME' if present (prevents 409 on sync)"
    if azure_cli_available; then
        azure_cli keyvault secret purge \
            --vault-name "$AZURE_VAULT_NAME" \
            --name "$AZURE_APP_KV_SECRET_NAME" >/dev/null 2>&1 || true
        sleep 5
    fi

    echo ""
    echo "==> Syncing $ROTATED_AZURE_APP → Key Vault secret '$AZURE_APP_KV_SECRET_NAME'"
    akl rotated-secret sync \
        --name "$ROTATED_AZURE_APP" \
        --usc-name "$USC_AZURE" \
        --remote-secret-name "$AZURE_APP_KV_SECRET_NAME" \
        --gateway-url "$AKEYLESS_GATEWAY_URL"
fi

if [[ "$ENABLE_DB_DEMO" == "true" ]]; then
    echo ""
    echo "==> Creating MySQL target: $TARGET_DB"
    # MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_PORT, MYSQL_DB_NAME must be set.
    # For a self-contained demo, deploy a MySQL pod in the akeyless namespace:
    #   kubectl apply -f demo/demo-mysql.yaml   (creates demo-mysql service + deployment)
    # then set: MYSQL_HOST=demo-mysql.akeyless.svc.cluster.local MYSQL_USER=root
    #           MYSQL_PASSWORD=DemoRoot@2026! MYSQL_DB_NAME=demo
    akl target create db \
        --name "$TARGET_DB" \
        --db-type mysql \
        --host "$MYSQL_HOST" \
        --port "${MYSQL_PORT:-3306}" \
        --user-name "$MYSQL_USER" \
        --pwd "$MYSQL_PASSWORD" \
        --db-name "${MYSQL_DB_NAME:-demo}"

    echo ""
    echo "==> Creating MySQL rotated secret: $DB_ROTATED"
    # Rotates the password for MYSQL_ROTATED_USER (default: akl_demo_user).
    # Ensure the user exists first: CREATE USER 'akl_demo_user'@'%' IDENTIFIED BY '...';
    akl rotated-secret create mysql \
        --name "$DB_ROTATED" \
        --target-name "$TARGET_DB" \
        --rotator-type password \
        --rotated-username "${MYSQL_ROTATED_USER:-akl_demo_user}" \
        --rotated-password "${MYSQL_ROTATED_INITIAL_PASS:-InitialPass2026!}" \
        --auto-rotate true \
        --rotation-interval 1 \
        --tag "compliance=pci-dss" --tag "demo=mvg" \
        --gateway-url "$AKEYLESS_GATEWAY_URL"

    echo ""
    echo "==> Syncing $DB_ROTATED → Vault payments secret '$DB_ROTATED_VAULT_PATH'"
    akl rotated-secret sync \
        --name "$DB_ROTATED" \
        --usc-name "$USC_PAYMENTS" \
        --remote-secret-name "$DB_ROTATED_VAULT_PATH" \
        --gateway-url "$AKEYLESS_GATEWAY_URL"
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

if [[ "$ENABLE_AZURE_DEMO" == "true" ]]; then
    echo ""
    echo "==> Verifying USC '$USC_AZURE'..."
    if ! akl usc list --usc-name "$USC_AZURE"; then
        echo "WARNING: Azure USC '$USC_AZURE' was created, but listing secrets failed." >&2
        echo "         This usually means the gateway cannot reach Azure Key Vault yet." >&2
    fi
fi

echo ""
echo "==> Creating read-only RBAC role: $READONLY_ROLE_NAME"
akl create-role --name "$READONLY_ROLE_NAME"
akl set-role-rule --role-name "$READONLY_ROLE_NAME" --path "$USC_PATH_BACKEND" --capability read --capability list
akl set-role-rule --role-name "$READONLY_ROLE_NAME" --path "$USC_PATH_PAYMENTS" --capability read --capability list
if [[ "$ENABLE_AWS_DEMO" == "true" ]]; then
    akl set-role-rule --role-name "$READONLY_ROLE_NAME" --path "$USC_PATH_AWS" --capability read --capability list
fi
if [[ "$ENABLE_AZURE_DEMO" == "true" ]]; then
    akl set-role-rule --role-name "$READONLY_ROLE_NAME" --path "$USC_PATH_AZURE" --capability read --capability list
fi
# Allow the readonly identity to read rotated secret values
akl set-role-rule --role-name "$READONLY_ROLE_NAME" --path "/$ROTATED_VAULT" --capability read
if [[ "$ENABLE_AWS_DEMO" == "true" ]]; then
    akl set-role-rule --role-name "$READONLY_ROLE_NAME" --path "/$ROTATED_AWS" --capability read
fi
if [[ "$ENABLE_AZURE_DEMO" == "true" ]]; then
    akl set-role-rule --role-name "$READONLY_ROLE_NAME" --path "/$ROTATED_AZURE" --capability read
    akl set-role-rule --role-name "$READONLY_ROLE_NAME" --path "/$ROTATED_AZURE_APP" --capability read
fi
if [[ "$ENABLE_DB_DEMO" == "true" ]]; then
    akl set-role-rule --role-name "$READONLY_ROLE_NAME" --path "/$DB_ROTATED" --capability read
fi

echo ""
echo "==> Creating denied RBAC role: $DENIED_ROLE_NAME"
akl create-role --name "$DENIED_ROLE_NAME"
akl set-role-rule --role-name "$DENIED_ROLE_NAME" --path "$USC_PATH_BACKEND" --capability deny
akl set-role-rule --role-name "$DENIED_ROLE_NAME" --path "$USC_PATH_PAYMENTS" --capability deny
if [[ "$ENABLE_AWS_DEMO" == "true" ]]; then
    akl set-role-rule --role-name "$DENIED_ROLE_NAME" --path "$USC_PATH_AWS" --capability deny
fi
if [[ "$ENABLE_AZURE_DEMO" == "true" ]]; then
    akl set-role-rule --role-name "$DENIED_ROLE_NAME" --path "$USC_PATH_AZURE" --capability deny
fi

echo ""
echo "==> Creating Akeyless-owned sync source for HashiCorp Vault (backend): $ROTATED_VAULT"
akl create-secret \
    --name "$ROTATED_VAULT" \
    --value '{"api_key":"akl-demo-api-key-rotated-v1"}' \
    --format json \
    --tag "compliance=pci-dss" --tag "demo=mvg"
akl static-secret-sync \
    --name "$ROTATED_VAULT" \
    --usc-name "$USC_BACKEND" \
    --remote-secret-name "secret/myapp/api-key" \
    --gateway-url "$AKEYLESS_GATEWAY_URL"

if [[ "$ENABLE_AWS_DEMO" == "true" ]]; then
    echo ""
    echo "==> Creating Akeyless-owned sync source for AWS Secrets Manager: $ROTATED_AWS"
    akl create-secret \
        --name "$ROTATED_AWS" \
        --value '{"api_key":"aws-demo-payments-key-rotated-v1"}' \
        --format json \
        --tag "compliance=pci-dss" --tag "demo=mvg"
    akl static-secret-sync \
        --name "$ROTATED_AWS" \
        --usc-name "$USC_AWS" \
        --remote-secret-name "${AWS_DEMO_SECRET_NAME:-demo/mvg/aws/payments-api-key}" \
        --gateway-url "$AKEYLESS_GATEWAY_URL"
fi

if [[ "$ENABLE_AZURE_DEMO" == "true" ]]; then
    echo ""
    echo "==> Creating Akeyless-owned sync source for Azure Key Vault: $ROTATED_AZURE"
    if azure_cli_available; then
        azure_cli keyvault secret purge \
            --vault-name "$AZURE_VAULT_NAME" \
            --name "$AZURE_ROTATED_SECRET_NAME" >/dev/null 2>&1 || true
    fi
    akl create-secret \
        --name "$ROTATED_AZURE" \
        --value 'azure-demo-rotated-value-v1' \
        --tag "compliance=pci-dss" --tag "demo=mvg"
    akl static-secret-sync \
        --name "$ROTATED_AZURE" \
        --usc-name "$USC_AZURE" \
        --remote-secret-name "$AZURE_ROTATED_SECRET_NAME" \
        --gateway-url "$AKEYLESS_GATEWAY_URL"
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
export AKEYLESS_DEMO_FOLDER='$DEMO_FOLDER'
export AKEYLESS_GW='$AKEYLESS_GATEWAY_URL'
export USC_BACKEND='$USC_BACKEND'
export USC_PAYMENTS='$USC_PAYMENTS'
export USC_AWS='$USC_AWS'
export USC_AZURE='$USC_AZURE'
export AWS_DEMO_SECRET_NAME='${AWS_DEMO_SECRET_NAME:-demo/mvg/aws/payments-api-key}'
export AZURE_VAULT_NAME='$AZURE_VAULT_NAME'
export AZURE_STATIC_SECRET_NAME='${AZURE_STATIC_SECRET_NAME:-payments-api-key}'
export AZURE_ROTATED_SECRET_NAME='${AZURE_ROTATED_SECRET_NAME:-demo-azure-rotated-api-key}'
export ROTATED_VAULT='$ROTATED_VAULT'
export ROTATED_AWS='$ROTATED_AWS'
export ROTATED_AZURE='$ROTATED_AZURE'
export AZURE_TENANT_ID='${AZURE_TENANT_ID:-}'
export AZURE_CLIENT_ID='${AZURE_CLIENT_ID:-}'
export AZURE_CLIENT_SECRET='${AZURE_CLIENT_SECRET:-}'
export DEMO_APP_CLIENT_ID='$DEMO_APP_CLIENT_ID'
export ROTATED_AZURE_APP='$ROTATED_AZURE_APP'
export AZURE_APP_KV_SECRET_NAME='$AZURE_APP_KV_SECRET_NAME'
export DB_ROTATED='$DB_ROTATED'
export DB_ROTATED_VAULT_PATH='$DB_ROTATED_VAULT_PATH'
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
