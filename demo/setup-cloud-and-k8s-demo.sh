#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# setup-cloud-and-k8s-demo.sh
#
# Seeds the cloud demo backends used in the webinar extension:
#   - AWS Secrets Manager
#   - Azure Key Vault
#
# Prints export commands for the follow-on demo/akeyless-setup.sh step.
# ---------------------------------------------------------------------------

AWS_REGION="${AWS_REGION:-us-east-2}"
AWS_DEMO_SECRET_NAME="${AWS_DEMO_SECRET_NAME:-demo/mvg/aws/payments-api-key}"
AWS_DEMO_SECRET_VALUE="${AWS_DEMO_SECRET_VALUE:-{\"api_key\":\"aws-demo-payments-key-v1\"}}"

AZURE_VAULT_NAME="${AZURE_VAULT_NAME:-akl-mvg-demo-kv}"
AZURE_STATIC_SECRET_NAME="${AZURE_STATIC_SECRET_NAME:-payments-api-key}"
# This is the secret Akeyless will rotate on a schedule; seeded with a v1 value.
AZURE_ROTATED_SECRET_NAME="${AZURE_ROTATED_SECRET_NAME:-demo-azure-rotated-api-key}"

echo ""
echo "========================================================"
echo "  Akeyless Demo — AWS + Azure Key Vault Seed Setup"
echo "========================================================"

AWS_DEMO_READY=false
AZURE_DEMO_READY=false

aws_secret_deleted() {
  python3 -c 'import json,sys; sys.exit(0 if json.load(sys.stdin).get("DeletedDate") else 1)'
}

if command -v aws >/dev/null 2>&1; then
  echo ""
  echo "[1/3] Seeding AWS Secrets Manager secret..."
  if aws sts get-caller-identity --output json >/dev/null 2>&1; then
    aws_secret_description="$(aws secretsmanager describe-secret \
      --region "$AWS_REGION" \
      --secret-id "$AWS_DEMO_SECRET_NAME" \
      --output json 2>/dev/null || true)"

    if [[ -n "$aws_secret_description" ]]; then
      if printf '%s' "$aws_secret_description" | aws_secret_deleted; then
        aws secretsmanager restore-secret \
          --region "$AWS_REGION" \
          --secret-id "$AWS_DEMO_SECRET_NAME" >/dev/null

        for _ in {1..30}; do
          aws_secret_description="$(aws secretsmanager describe-secret \
            --region "$AWS_REGION" \
            --secret-id "$AWS_DEMO_SECRET_NAME" \
            --output json 2>/dev/null || true)"

          if [[ -n "$aws_secret_description" ]] && ! printf '%s' "$aws_secret_description" | aws_secret_deleted; then
            if aws secretsmanager get-secret-value \
            --region "$AWS_REGION" \
            --secret-id "$AWS_DEMO_SECRET_NAME" >/dev/null 2>&1; then
              break
            fi
          fi
          sleep 1
        done
      fi

      aws secretsmanager put-secret-value \
        --region "$AWS_REGION" \
        --secret-id "$AWS_DEMO_SECRET_NAME" \
        --secret-string "$AWS_DEMO_SECRET_VALUE" >/dev/null
      echo "      Updated: $AWS_DEMO_SECRET_NAME ($AWS_REGION)"
    else
      aws secretsmanager create-secret \
        --region "$AWS_REGION" \
        --name "$AWS_DEMO_SECRET_NAME" \
        --secret-string "$AWS_DEMO_SECRET_VALUE" >/dev/null
      echo "      Created: $AWS_DEMO_SECRET_NAME ($AWS_REGION)"
    fi
    AWS_DEMO_READY=true
  else
    echo "      Skipped AWS setup: aws CLI is installed but not authenticated."
  fi
else
  echo ""
  echo "[1/3] Skipped AWS setup: aws CLI not installed."
fi

AZURE_APP_KV_SECRET_NAME="${AZURE_APP_KV_SECRET_NAME:-demo-app-client-secret}"
# demo-akeyless-mvg-target: the "demo app" whose client secret Akeyless rotates
# sp-akeyless-mvg-demo: the privileged app (Akeyless Azure target) that performs rotation
DEMO_APP_CLIENT_ID="${DEMO_APP_CLIENT_ID:-217ffd30-f65f-43ff-84d3-491dde1f2d96}"
PRIV_APP_CLIENT_ID="${PRIV_APP_CLIENT_ID:-17eef820-4ed5-486d-a2e2-35af42c4db76}"

echo ""
echo "[2/3] Seeding Azure Key Vault secrets..."

if command -v az >/dev/null 2>&1; then
  if az account show >/dev/null 2>&1; then
    if [[ -z "$AZURE_VAULT_NAME" ]]; then
      echo "      Skipped Azure setup: AZURE_VAULT_NAME is not set."
    else
      az keyvault secret purge \
        --vault-name "$AZURE_VAULT_NAME" \
        --name "$AZURE_STATIC_SECRET_NAME" >/dev/null 2>&1 || true
      az keyvault secret purge \
        --vault-name "$AZURE_VAULT_NAME" \
        --name "${AZURE_ROTATED_SECRET_NAME}" >/dev/null 2>&1 || true
      az keyvault secret purge \
        --vault-name "$AZURE_VAULT_NAME" \
        --name "${AZURE_APP_KV_SECRET_NAME}" >/dev/null 2>&1 || true

      # Static secret — governed read-only via USC (shown in Chapter 7)
      az keyvault secret set \
        --vault-name "$AZURE_VAULT_NAME" \
        --name "$AZURE_STATIC_SECRET_NAME" \
        --value "azure-demo-payments-key-11111" \
        --output none
      echo "      Created/Updated: $AZURE_STATIC_SECRET_NAME"

      # Rotated secret seed — Akeyless will overwrite this value on each rotation
      az keyvault secret set \
        --vault-name "$AZURE_VAULT_NAME" \
        --name "${AZURE_ROTATED_SECRET_NAME}" \
        --value "azure-original-value-before-rotation" \
        --output none
      echo "      Created/Updated: ${AZURE_ROTATED_SECRET_NAME} (initial value: v1)"

      AZURE_DEMO_READY=true
    fi

    # ── Azure App Registration setup for rotation demo ────────────────────────
    # One-time: ensure sp-akeyless-mvg-demo can rotate credentials on the demo app.
    # Safe to re-run — all operations are idempotent.
    echo ""
    echo "      [Azure App] Verifying rotation permissions for demo-akeyless-mvg-target..."

    PRIV_SP_OBJ_ID="$(az ad sp show --id "$PRIV_APP_CLIENT_ID" --query id -o tsv 2>/dev/null || true)"
    DEMO_APP_OBJ_ID="$(az ad app show --id "$DEMO_APP_CLIENT_ID" --query id -o tsv 2>/dev/null || true)"

    if [[ -z "$PRIV_SP_OBJ_ID" || -z "$DEMO_APP_OBJ_ID" ]]; then
      echo "      WARNING: could not find one or both Azure app registrations — skipping rotation setup." >&2
    else
      # Add sp-akeyless-mvg-demo as owner of the demo app (required for api-key rotation)
      existing_owner="$(az ad app owner list --id "$DEMO_APP_OBJ_ID" \
        --query "[?id=='$PRIV_SP_OBJ_ID'].id" -o tsv 2>/dev/null || true)"
      if [[ -z "$existing_owner" ]]; then
        az ad app owner add \
          --id "$DEMO_APP_OBJ_ID" \
          --owner-object-id "$PRIV_SP_OBJ_ID" >/dev/null 2>&1
        echo "      Added sp-akeyless-mvg-demo as owner of demo-akeyless-mvg-target"
      else
        echo "      Owner already set: sp-akeyless-mvg-demo owns demo-akeyless-mvg-target"
      fi

      # Grant Application.ReadWrite.OwnedBy via direct appRoleAssignment on the SP.
      # Note: az ad app permission admin-consent only handles delegated permissions;
      # application permissions (Role type) require an appRoleAssignment on the SP.
      GRAPH_SP_ID="$(az ad sp show --id "00000003-0000-0000-c000-000000000000" --query id -o tsv 2>/dev/null || true)"
      existing_assignment="$(az rest --method GET \
        --url "https://graph.microsoft.com/v1.0/servicePrincipals/${PRIV_SP_OBJ_ID}/appRoleAssignments" \
        --query "value[?appRoleId=='18a4783c-866b-4cc7-a460-3d5e5662c884'].appRoleId" \
        -o tsv 2>/dev/null || true)"
      if [[ -z "$existing_assignment" ]]; then
        az rest --method POST \
          --url "https://graph.microsoft.com/v1.0/servicePrincipals/${PRIV_SP_OBJ_ID}/appRoleAssignments" \
          --body "{\"principalId\":\"${PRIV_SP_OBJ_ID}\",\"resourceId\":\"${GRAPH_SP_ID}\",\"appRoleId\":\"18a4783c-866b-4cc7-a460-3d5e5662c884\"}" \
          >/dev/null 2>&1
        echo "      Granted Application.ReadWrite.OwnedBy to sp-akeyless-mvg-demo"
      else
        echo "      Application.ReadWrite.OwnedBy already granted"
      fi
    fi
  else
    echo "      Skipped Azure setup: az CLI is installed but not authenticated."
  fi
else
  echo "      Skipped Azure setup: az CLI not installed."
fi

echo ""
echo "[3/3] Export these before running demo/akeyless-setup.sh"
echo ""
echo "export ENABLE_AWS_DEMO=$AWS_DEMO_READY"
echo "export ENABLE_AZURE_DEMO=$AZURE_DEMO_READY"
echo "export AWS_REGION='$AWS_REGION'"
echo "export AWS_DEMO_SECRET_NAME='$AWS_DEMO_SECRET_NAME'"
echo "export AWS_USC_PREFIX=''"
echo "export AZURE_VAULT_NAME='$AZURE_VAULT_NAME'"
echo "export AZURE_STATIC_SECRET_NAME='$AZURE_STATIC_SECRET_NAME'"
echo "export AZURE_ROTATED_SECRET_NAME='$AZURE_ROTATED_SECRET_NAME'"
echo "export DEMO_APP_CLIENT_ID='$DEMO_APP_CLIENT_ID'"
echo "export AZURE_APP_KV_SECRET_NAME='$AZURE_APP_KV_SECRET_NAME'"
echo ""
echo "If your AWS credentials are not already exported in this shell, also set:"
echo "export AWS_ACCESS_KEY_ID='<your-access-key-id>'"
echo "export AWS_SECRET_ACCESS_KEY='<your-secret-access-key>'"
echo "export AWS_SESSION_TOKEN='<your-session-token>'   # only if using STS creds"
echo ""
echo "For Azure, ensure the following service principal env vars are set:"
echo "export AZURE_TENANT_ID='<your-tenant-id>'"
echo "export AZURE_CLIENT_ID='<your-client-id>'"
echo "export AZURE_CLIENT_SECRET='<your-client-secret>'"
echo ""
echo "For DB rotation demo (optional):"
echo "export ENABLE_DB_DEMO=false   # set to true + supply MYSQL_HOST/MYSQL_USER/MYSQL_PASSWORD"
echo ""
