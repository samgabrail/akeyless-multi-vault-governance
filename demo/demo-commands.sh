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
# export DEMO_APP_CLIENT_ID='217ffd30-f65f-43ff-84d3-491dde1f2d96'
# export ROTATED_AZURE_APP='MVG-demo/azure-app-rotated-secret'
# export AZURE_APP_KV_SECRET_NAME='demo-app-client-secret'
# export DB_ROTATED='MVG-demo/db-rotated-password'


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

# Run vault status to show an error proving we are using Akeyless backend
vault status

# Error checking seal status: Error making API request.

# URL: GET https://hvp.akeyless.io/v1/sys/seal-status
# Code: 404. Errors:

# * route entry not found or unsupported path. See the API docs for the appropriate API endpoints to use


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
echo "--- Chapter 7b: Akeyless updates one source secret and syncs it into each external vault ---"

# ── HashiCorp Vault rotation ─────────────────────────────────────────────────
export VAULT_ADDR="${VAULT_ADDR_BACKEND:-http://127.0.0.1:8200}"

echo "==> Current value in HashiCorp Vault (before rotation):"
vault kv get -field=api_key secret/myapp/api-key

# Update the Akeyless source secret, then sync it into Vault through the USC.
akeyless update-secret-val \
  --name "${ROTATED_VAULT:-MVG-demo/vault-rotated-api-key}" \
  --value "{\"api_key\":\"vault-rotated-$(date +%s)\"}" \
  --format json \
  --profile "${AKEYLESS_PROFILE:-demo}"

akeyless static-secret-sync \
  --name "${ROTATED_VAULT:-MVG-demo/vault-rotated-api-key}" \
  --usc-name "${USC_BACKEND:-MVG-demo/vault-usc-backend}" \
  --remote-secret-name "secret/myapp/api-key" \
  --gateway-url "${AKEYLESS_GW:-https://192.168.1.82:8000}" \
  --profile "${AKEYLESS_PROFILE:-demo}"

sleep 3

echo "==> Value in HashiCorp Vault AFTER Akeyless rotation:"
vault kv get -field=api_key secret/myapp/api-key
# Output: a new value — Akeyless synced it back. The old value is gone.

# ── AWS Secrets Manager rotation ─────────────────────────────────────────────
akeyless update-secret-val \
  --name "${ROTATED_AWS:-MVG-demo/aws-rotated-secret}" \
  --value "{\"api_key\":\"aws-rotated-$(date +%s)\"}" \
  --format json \
  --profile "${AKEYLESS_PROFILE:-demo}"

akeyless static-secret-sync \
  --name "${ROTATED_AWS:-MVG-demo/aws-rotated-secret}" \
  --usc-name "${USC_AWS:-MVG-demo/aws-usc}" \
  --remote-secret-name "${AWS_DEMO_SECRET_NAME:-demo/mvg/aws/payments-api-key}" \
  --gateway-url "${AKEYLESS_GW:-https://192.168.1.82:8000}" \
  --profile "${AKEYLESS_PROFILE:-demo}"

echo "==> (AWS sync triggered — verify in AWS Console or:"
echo "    aws secretsmanager get-secret-value --secret-id ${AWS_DEMO_SECRET_NAME:-demo/mvg/aws/payments-api-key} --region ${AWS_REGION:-us-east-2})"

# ── Azure Key Vault rotation ─────────────────────────────────────────────────
akeyless update-secret-val \
  --name "${ROTATED_AZURE:-MVG-demo/azure-rotated-api-key}" \
  --value "azure-rotated-$(date +%s)" \
  --profile "${AKEYLESS_PROFILE:-demo}"

akeyless static-secret-sync \
  --name "${ROTATED_AZURE:-MVG-demo/azure-rotated-api-key}" \
  --usc-name "${USC_AZURE:-MVG-demo/azure-usc}" \
  --remote-secret-name "${AZURE_ROTATED_SECRET_NAME:-demo-azure-rotated-api-key}" \
  --gateway-url "${AKEYLESS_GW:-https://192.168.1.82:8000}" \
  --profile "${AKEYLESS_PROFILE:-demo}"

echo "==> (Azure sync triggered — verify in Azure Portal or:"
echo "    az keyvault secret show --vault-name ${AZURE_VAULT_NAME:-mvg-demo-kv} --name ${AZURE_ROTATED_SECRET_NAME:-demo-azure-rotated-api-key})"

# Key point: Akeyless owns the source secret and can push the current value back
# to HashiCorp Vault, AWS SM, and Azure KV through the Gateway. One update point,
# three governed backends, and one audit trail for every read, denial, and sync.


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 7c: Azure App Registration rotation — Akeyless rotates, Key Vault delivers
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 7c: Akeyless rotates an Azure App Registration client secret, Key Vault delivers it ---"

# Story: "We must use Azure Key Vault, but we want Akeyless as the central rotation
# engine. The app reads only from Key Vault — it doesn't know Akeyless exists."
#
# Azure setup (done once, automated in setup-cloud-and-k8s-demo.sh):
#   • sp-akeyless-mvg-demo  → privileged app (Akeyless Azure target)
#   • demo-akeyless-mvg-target → demo app whose client secret Akeyless will rotate
#   • sp-akeyless-mvg-demo is owner of demo-akeyless-mvg-target + has
#     Application.ReadWrite.OwnedBy permission (admin consent granted)

# 1. Show the demo app's current client secret metadata in Azure portal / CLI
#    (Azure portal: App Registrations → demo-akeyless-mvg-target → Certificates & secrets)
echo "==> Current client secrets on demo-akeyless-mvg-target (before rotation)"
export PYTHONPATH=/opt/az/lib/python3.13/site-packages
/opt/az/bin/python3.13 -m azure.cli ad app credential list \
  --id "${DEMO_APP_CLIENT_ID:-217ffd30-f65f-43ff-84d3-491dde1f2d96}" \
  --query "[].{name:displayName, hint:hint, expiry:endDateTime}" \
  --output table

# 2. Trigger a manual rotation via the Gateway API ("Rotate Now" equivalent)
#    After rotation, Akeyless automatically syncs the new client secret to Key Vault.
DEMO_TOKEN=$(akeyless auth \
  --access-id "$(grep access_id ~/.akeyless/profiles/${AKEYLESS_PROFILE:-demo}.toml | awk -F"'" '{print $2}')" \
  --access-key "$(grep access_key ~/.akeyless/profiles/${AKEYLESS_PROFILE:-demo}.toml | awk -F"'" '{print $2}')" \
  --access-type access_key --json 2>/dev/null \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")

echo ""
echo "==> Triggering rotation (Akeyless creates a new Azure client secret + syncs to Key Vault)"
curl -sk -X POST "${AKEYLESS_GW:-https://192.168.1.82:8000}/api/v2/rotate-secret" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"/${ROTATED_AZURE_APP:-MVG-demo/azure-app-rotated-secret}\",\"token\":\"$DEMO_TOKEN\"}" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print('Rotated:', d.get('name', d.get('error','')))"
sleep 5

# 3. Alternatively: force a sync of the current rotated value into Key Vault right now
#    (useful for seeding Key Vault before the first automatic rotation fires)
echo ""
echo "==> Syncing current rotated value into Key Vault"
akeyless rotated-secret sync \
  --name "${ROTATED_AZURE_APP:-MVG-demo/azure-app-rotated-secret}" \
  --usc-name "${USC_AZURE:-MVG-demo/azure-usc}" \
  --remote-secret-name "${AZURE_APP_KV_SECRET_NAME:-demo-app-client-secret}" \
  --gateway-url "${AKEYLESS_GW:-https://192.168.1.82:8000}" \
  --profile "${AKEYLESS_PROFILE:-demo}"

# 4. Show the new secret version in Key Vault — the app reads from here, untouched
echo ""
echo "==> Key Vault: demo-app-client-secret (app sees only this)"
/opt/az/bin/python3.13 -m azure.cli keyvault secret show \
  --vault-name "${AZURE_VAULT_NAME:-akl-mvg-demo-kv}" \
  --name "${AZURE_APP_KV_SECRET_NAME:-demo-app-client-secret}" \
  --query "{name:name, version:id, updated:attributes.updated}" \
  --output json

# 5. Confirm Key Vault has the value via Akeyless USC too — same source, one audit trail
echo ""
echo "==> Same secret visible via Akeyless USC (one governance plane, two views)"
akeyless usc get \
  --usc-name "${USC_AZURE:-MVG-demo/azure-usc}" \
  --secret-id "${AZURE_APP_KV_SECRET_NAME:-demo-app-client-secret}" \
  --profile "${AKEYLESS_PROFILE:-demo}"

# 6. Show the new client secret metadata on the demo app in Azure — rotation happened
echo ""
echo "==> Client secrets on demo-akeyless-mvg-target AFTER rotation (new secret created)"
/opt/az/bin/python3.13 -m azure.cli ad app credential list \
  --id "${DEMO_APP_CLIENT_ID:-217ffd30-f65f-43ff-84d3-491dde1f2d96}" \
  --query "[].{name:displayName, hint:hint, expiry:endDateTime}" \
  --output table

# Key point: Akeyless rotated the Azure App Registration client secret, synced it into
# Key Vault, and the app never changed. One rotation event, one audit log entry,
# zero app changes. Same model works for AWS Secrets Manager, HashiCorp Vault, etc.


# ─────────────────────────────────────────────────────────────────────────────
# CHAPTER 7d: Database rotation — same rotation engine, non-Azure target
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Chapter 7d: Akeyless rotates a MySQL database password — not Azure-specific ---"

# Story: "Akeyless is not an Azure-only tool. The same rotation engine that just
# rotated an Azure App Registration secret can rotate database credentials, AWS IAM
# access keys, HashiCorp Vault AppRoles — any target with an Akeyless Target."
#
# PRE-REQUISITE: run once before the demo:
#   kubectl apply -f demo/demo-mysql.yaml
#   export ENABLE_DB_DEMO=true
#   export MYSQL_HOST=demo-mysql.akeyless.svc.cluster.local
#   export MYSQL_USER=root  MYSQL_PASSWORD='DemoRoot@2026!'  MYSQL_DB_NAME=demo
#   kubectl exec -n akeyless deployment/demo-mysql -- \
#     mysql -uroot -p'DemoRoot@2026!' -e \
#     "CREATE USER IF NOT EXISTS 'akl_demo_user'@'%' IDENTIFIED BY 'InitialPass2026!';
#      GRANT SELECT ON demo.* TO 'akl_demo_user'@'%'; FLUSH PRIVILEGES;"

# 1. Show the demo user can log in with current (pre-rotation) password
echo "==> Before rotation: akl_demo_user password is InitialPass2026!"
kubectl --context proxmox-k3s exec -n akeyless deployment/demo-mysql -- \
  mysql -uakl_demo_user -p'InitialPass2026!' -e "SELECT 'login OK' AS status, NOW() AS at;" 2>/dev/null | grep -v Warning

# 2. Show the current rotated secret value in Akeyless
echo ""
echo "==> Current DB rotated secret value in Akeyless"
akeyless rotated-secret get-value \
  --name "${DB_ROTATED:-MVG-demo/db-rotated-password}" \
  --profile "${AKEYLESS_PROFILE:-demo}"

# 3. Trigger rotation via Gateway API
DEMO_TOKEN=$(akeyless auth \
  --access-id "$(grep access_id ~/.akeyless/profiles/${AKEYLESS_PROFILE:-demo}.toml | awk -F"'" '{print $2}')" \
  --access-key "$(grep access_key ~/.akeyless/profiles/${AKEYLESS_PROFILE:-demo}.toml | awk -F"'" '{print $2}')" \
  --access-type access_key --json 2>/dev/null \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")

echo ""
echo "==> Triggering DB rotation (Akeyless generates new password and updates MySQL)"
curl -sk -X POST "${AKEYLESS_GW:-https://192.168.1.82:8000}/api/v2/rotate-secret" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"/${DB_ROTATED:-MVG-demo/db-rotated-password}\",\"token\":\"$DEMO_TOKEN\"}" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print('Rotated:', d.get('name', d.get('error','')))"
sleep 5
echo "    After rotation, the old password no longer works:"

# 4. Verify old password is rejected after rotation
kubectl --context proxmox-k3s exec -n akeyless deployment/demo-mysql -- \
  mysql -uakl_demo_user -p'InitialPass2026!' -e "SELECT 1;" 2>&1 | grep -E "ERROR|Access denied" || echo "(rotate first, then re-run this line)"

# 5. Read the NEW password from Akeyless and log in with it
echo ""
echo "==> New password from Akeyless (post-rotation)"
akeyless rotated-secret get-value \
  --name "${DB_ROTATED:-MVG-demo/db-rotated-password}" \
  --profile "${AKEYLESS_PROFILE:-demo}"

# Key point: same Akeyless rotation engine works on MySQL, PostgreSQL, AWS IAM,
# Azure App Registrations, HashiCorp Vault — governed from one control plane.
# Any USC (Vault, AWS SM, Azure KV, K8s) can receive the rotated value on sync.


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
