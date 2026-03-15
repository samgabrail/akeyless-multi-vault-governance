# Demo: Akeyless Multi Vault Governance

## Overview

This demo shows Akeyless acting as a centralized governance layer across **two independent HashiCorp Vault instances**, **AWS Secrets Manager**, and **Azure Key Vault** — with no migration required. The two Vault instances represent separate teams in an enterprise: a backend team and a payments team, each running their own Vault cluster with their own secrets. AWS Secrets Manager and Azure Key Vault are included to show how the same MVG layer extends beyond Vault into the cloud-native secrets stores many enterprises already run alongside it.

Neither Vault instance knows the other exists. There is no shared policy, no shared audit log, and no cross-team visibility — until Akeyless is connected. The same fragmentation often exists across cloud secrets managers. Once connected, a single Akeyless control plane governs all of them: one RBAC model, one audit trail, zero secrets moved.

The demo also shows the HashiCorp Vault Proxy (HVP), which lets teams continue using the `vault` CLI unchanged while Akeyless handles authentication, authorization, and audit logging behind the scenes. This keeps Vault as the primary story while proving that MVG extends beyond Vault into cloud environments.

The rotation chapters demonstrate that Akeyless can own the rotation lifecycle for both cloud credentials (Azure App Registration client secrets) and database credentials, then automatically sync the new values to the downstream stores that applications already read from — whether that is Azure Key Vault or a HashiCorp Vault KV path.

> **Terminology note:** In this repo, narrative copy uses **MVG** for multi-vault governance. In the current product, CLI, and docs, this capability is still surfaced as **USC**.
>
> **Production topology clarification:** This repo uses one Akeyless Gateway for both Vault instances, AWS, and Azure only to keep the demo small. In production, teams usually place Vault clusters per region and close to workloads for latency, and deploy one Akeyless Gateway per private location/region. Vault Enterprise teams may use DR or Performance Replication, but many organizations still run isolated Vault clusters with no replication because of ownership boundaries, cost, or operational complexity. MVG is designed for exactly that isolated-cluster model, and it extends the same governance approach to cloud secrets managers.

---

## What You'll See

| Chapter | What It Proves |
|---|---|
| **1 — Two isolated Vault instances** | Confirm the two Vault clusters start with no shared governance |
| **2 — Gateway bridges both** | Demo shows one Akeyless Gateway connecting both Vault instances |
| **3 — Discover secrets** | USC inventories secrets across both Vault clusters from one Akeyless session |
| **4 — Read secrets via USC** | USC reads secrets from both clusters through the Akeyless control plane |
| **5 — Bi-directional secret sync** | The demo shows both Akeyless → Vault and Vault → Akeyless flows |
| **6 — vault CLI via HVP** | One `VAULT_ADDR` change routes existing `vault` CLI commands through Akeyless |
| **7a — Extend MVG to AWS and Azure Key Vault** | Same USC pattern governs AWS Secrets Manager and Azure Key Vault |
| **7b — Azure App Registration rotation** | Akeyless rotates an Azure App credential and syncs it to Key Vault — zero app changes |
| **7c — Database rotation → Vault sync** | Akeyless rotates a MySQL password and syncs it to the payments Vault |
| **8 — One RBAC policy, many backends** | One Akeyless policy denies access across Vault, AWS, and Azure |
| **9 — One unified audit trail** | All operations including rotations appear in one log |

---

## Prerequisites

### Tools Required

| Tool | Notes |
|---|---|
| `vault` CLI | Any recent version of the HashiCorp Vault CLI |
| `akeyless` CLI | [Install instructions](https://docs.akeyless.io/docs/cli) |
| `aws` CLI | Needed for the AWS Secrets Manager extension |
| `az` CLI | Needed for the Azure Key Vault and App Registration extension |
| `kubectl` | For inspecting Gateway pods and services, and for the MySQL rotation demo |
| `helm` | For deploying the Akeyless Gateway chart |

You also need an Akeyless account. The free tier is sufficient: [https://console.akeyless.io](https://console.akeyless.io)

### Akeyless Setup

1. Log in to [https://console.akeyless.io](https://console.akeyless.io).
2. Navigate to **Auth Methods** and create a new **API Key** auth method (e.g., `demo-admin-auth`).
3. Copy the **Access ID** (format: `p-xxxxxxxxxxxx`) and **Access Key**.
4. Authenticate the CLI:

```bash
akeyless auth \
  --access-id p-xxxxxxxxxxxx \
  --access-key <your-access-key>
```

---

## Environment Variables

### Core Variables

| Variable | Default | Description |
|---|---|---|
| `VAULT_ADDR_BACKEND` | `http://127.0.0.1:8200` | Address of backend team's Vault |
| `VAULT_ADDR_PAYMENTS` | `http://127.0.0.1:8202` | Address of payments team's Vault |
| `VAULT_TOKEN` | `root` | Root token (same for both dev instances) |
| `AKEYLESS_DEMO_FOLDER` | `MVG-demo` | Akeyless folder used for demo targets, USCs, and rotated secrets |
| `AKEYLESS_GATEWAY_URL` | _(required)_ | External URL of your deployed Gateway |
| `USC_BACKEND` | `MVG-demo/vault-usc-backend` | USC name for backend Vault |
| `USC_PAYMENTS` | `MVG-demo/vault-usc-payments` | USC name for payments Vault |
| `USC_AWS` | `MVG-demo/aws-usc` | USC name for AWS Secrets Manager |

### AWS Variables

| Variable | Default | Description |
|---|---|---|
| `ENABLE_AWS_DEMO` | `false` | Whether to create the AWS target + USC |
| `AWS_REGION` | `us-east-2` | Region for AWS Secrets Manager |
| `AWS_USC_PREFIX` | `demo/mvg/aws/` | Prefix filtered by the AWS USC |
| `AWS_DEMO_SECRET_NAME` | `demo/mvg/aws/payments-api-key` | AWS secret used in the demo |

### Azure Variables

| Variable | Default | Description |
|---|---|---|
| `ENABLE_AZURE_DEMO` | `true` (auto-detected) | Whether to create Azure targets/USCs |
| `AZURE_VAULT_NAME` | `akl-mvg-demo-kv` | Azure Key Vault name |
| `AZURE_STATIC_SECRET_NAME` | `payments-api-key` | Static KV secret governed via USC |
| `AZURE_ROTATED_SECRET_NAME` | `demo-azure-rotated-api-key` | Azure KV secret that receives synced rotation values |
| `DEMO_APP_CLIENT_ID` | `217ffd30-f65f-43ff-84d3-491dde1f2d96` | App Registration whose client secret Akeyless rotates |
| `AZURE_APP_KV_SECRET_NAME` | `demo-app-client-secret` | KV secret receiving the rotated app credential |

### Database Rotation Variables

| Variable | Default | Description |
|---|---|---|
| `ENABLE_DB_DEMO` | `true` | Whether to create the MySQL target + rotated secret |
| `MYSQL_HOST` | `demo-mysql.akeyless.svc.cluster.local` | MySQL host (K8s service name) |
| `MYSQL_USER` | `root` | Root admin user for the DB target |
| `MYSQL_PASSWORD` | `DemoRoot@2026!` | Root password |
| `MYSQL_ROTATED_USER` | `akl_demo_user` | DB user whose password Akeyless rotates |
| `MYSQL_ROTATED_INITIAL_PASS` | `InitialPass2026!` | Initial password (reset by test-e2e.sh before each run) |
| `DB_ROTATED_VAULT_PATH` | `secret/payments/db-rotated-password` | Vault path where rotated DB password is synced |

Quick-copy block:

```bash
export VAULT_ADDR_BACKEND='http://127.0.0.1:8200'
export VAULT_ADDR_PAYMENTS='http://127.0.0.1:8202'
export VAULT_TOKEN='root'
export AKEYLESS_DEMO_FOLDER='MVG-demo'
export AKEYLESS_GATEWAY_URL='https://<your-gateway-external-ip>:8000'
export ENABLE_AWS_DEMO='true'
export ENABLE_AZURE_DEMO='true'
export ENABLE_DB_DEMO='true'
export AWS_REGION='us-east-2'
export AWS_USC_PREFIX='demo/mvg/aws/'
export AWS_DEMO_SECRET_NAME='demo/mvg/aws/payments-api-key'
export AZURE_VAULT_NAME='akl-mvg-demo-kv'
export AZURE_STATIC_SECRET_NAME='payments-api-key'
export AZURE_ROTATED_SECRET_NAME='demo-azure-rotated-api-key'
export DEMO_APP_CLIENT_ID='217ffd30-f65f-43ff-84d3-491dde1f2d96'
export AZURE_APP_KV_SECRET_NAME='demo-app-client-secret'
export USC_BACKEND='MVG-demo/vault-usc-backend'
export USC_PAYMENTS='MVG-demo/vault-usc-payments'
export USC_AWS='MVG-demo/aws-usc'
```

> **Gateway networking note:** `VAULT_ADDR_BACKEND` and `VAULT_ADDR_PAYMENTS` are the addresses your Akeyless Gateway uses to reach the Vault instances. If your Gateway runs on Kubernetes and Vault runs on your local machine, use your host machine's network IP (e.g., `http://192.168.1.100:8200`) rather than `127.0.0.1`. On Docker Desktop, `http://host.docker.internal:8200` works.

---

## Step 1: Start Both Vault Dev Servers

```bash
source ./demo/setup-vault-dev.sh
```

What this does:

- Starts **backend Vault** on port 8200 with root token `root`
- Starts **payments Vault** on port 8202 with root token `root`
- Waits for both to report healthy
- Seeds backend Vault with:
  - `secret/myapp/db-password` — `password=sup3r-s3cret-db-pass`
  - `secret/myapp/api-key` — `api_key=akl-demo-api-key-12345`
- Seeds payments Vault with:
  - `secret/payments/stripe-key` — `key=sk_demo_payments_abc123`
  - `secret/payments/db-url` — `url=postgres://payments:...`
- Exports `VAULT_PID_BACKEND` and `VAULT_PID_PAYMENTS` into your shell

**Keep this terminal open.** Both Vault processes must remain running throughout the demo.

---

## Step 1b: Seed AWS, Azure, and MySQL Demo Resources

This step expands the demo from a Vault-only story into a true MVG story.

```bash
./demo/setup-cloud-and-k8s-demo.sh
```

What this does:

- Creates or updates the AWS Secrets Manager secret used in the demo
- Creates or updates the Azure Key Vault secrets used in the demo
- Configures the Azure App Registration (`demo-akeyless-mvg-target`, client ID `217ffd30-f65f-43ff-84d3-491dde1f2d96`) with permissions that allow Akeyless to rotate its client secret
- Deploys the `demo-mysql` pod in the `akeyless` namespace (from `demo/demo-mysql.yaml`) and seeds the `akl_demo_user` account
- Prints the `export` commands needed for `demo/akeyless-setup.sh`

After this step, copy the printed `export ...` lines into your shell. `ENABLE_AWS_DEMO` is printed as `true` only if the local AWS CLI is actually authenticated. `ENABLE_AZURE_DEMO` is printed as `true` only if `az account show` succeeds. If your AWS credentials are not already present in the environment, also export:

```bash
export AWS_ACCESS_KEY_ID='<your-access-key-id>'
export AWS_SECRET_ACCESS_KEY='<your-secret-access-key>'
export AWS_SESSION_TOKEN='<your-session-token>'   # only if using STS creds
```

---

## Step 2: Deploy Akeyless Gateway on Kubernetes

For this demo, one Gateway handles connections to both Vault instances, AWS, and Azure. In production, deploy one Gateway per private location/region, close to the local Vault cluster and application workloads.

### 2a: Add the Helm chart repository

```bash
helm repo add akeyless https://akeyless-community.github.io/helm-charts
helm repo update
```

### 2b: Create the credentials secret

```bash
kubectl create secret generic akeyless-admin-credentials \
  -n akeyless --create-namespace \
  --from-literal=admin-access-key=<YOUR_AKEYLESS_ACCESS_KEY>
```

### 2c: Edit gateway-values.yaml

Set `adminAccessId` to your Access ID:

```yaml
akeylessUserAuth:
  adminAccessId: "p-xxxxxxxxxxxx"   # <-- replace this
```

### 2d: Deploy the Gateway

```bash
helm upgrade --install akeyless-gateway akeyless/akeyless-api-gateway \
  -n akeyless --create-namespace \
  -f demo/gateway-values.yaml
```

### 2e: Get the Gateway URL

```bash
kubectl get svc -n akeyless
```

Set `AKEYLESS_GATEWAY_URL` to the external IP:

```bash
export AKEYLESS_GATEWAY_URL='https://<EXTERNAL-IP>:8000'
```

---

## Step 3: Configure Akeyless Resources

With `AKEYLESS_GATEWAY_URL` (and optionally `VAULT_ADDR_BACKEND` / `VAULT_ADDR_PAYMENTS`) set:

```bash
./demo/akeyless-setup.sh
```

What this creates:

| Resource | Name | Purpose |
|---|---|---|
| Vault Target | `MVG-demo/vault-target-backend` | Connection to backend Vault (port 8200) |
| Vault Target | `MVG-demo/vault-target-payments` | Connection to payments Vault (port 8202) |
| AWS Target | `MVG-demo/aws-target` | Connection to AWS Secrets Manager |
| Azure Target | `MVG-demo/azure-target` | Connection to Azure Key Vault |
| USC | `MVG-demo/vault-usc-backend` | Akeyless window into backend Vault |
| USC | `MVG-demo/vault-usc-payments` | Akeyless window into payments Vault |
| USC | `MVG-demo/aws-usc` | Akeyless window into AWS Secrets Manager |
| USC | `MVG-demo/azure-usc` | Akeyless window into Azure Key Vault |
| Azure App Rotated Secret | `MVG-demo/azure-app-rotated-secret` | Rotates the Azure App Registration client secret; synced to `demo-app-client-secret` in Azure KV |
| DB Target | `MVG-demo/db-target` | Connection to MySQL (demo-mysql pod in akeyless namespace) |
| DB Rotated Secret | `MVG-demo/db-rotated-password` | Rotates `akl_demo_user` password; synced to `secret/payments/db-rotated-password` in payments Vault |
| Read-only role | `demo-readonly-role` | `read` + `list` on paths under all configured USCs |
| Read-only auth | `demo-readonly-auth` | API key identity for read-only role |
| Denied role | `demo-denied-role` | `deny` on paths under all configured USCs |
| Denied auth | `demo-denied-auth` | API key identity for denied role (used in Chapter 8) |

The script is rerunnable and rewrites the demo-scoped Akeyless objects on each run. It also writes `demo/.akeyless-demo.env` with the generated Access IDs and Access Keys for the read-only and denied auth methods.

All Akeyless targets, USCs, and rotated-secret items are created under the `/MVG-demo` folder by default.

Load that file before running the demo or the E2E test:

```bash
source demo/.akeyless-demo.env
```

## Step 4: Run the Repeatable End-to-End Test

```bash
bash demo/test-e2e.sh
```

What it does:

- Ensures both Vault dev servers are running
- Seeds AWS, Azure, and MySQL demo backends
- Reconciles Akeyless targets, USCs, rotated secrets, roles, and auth methods
- Verifies Vault MVG, HVP, AWS MVG, Azure MVG, App Registration rotation, DB rotation → Vault sync, and centralized deny RBAC
- Uses unique test secret names and removes them afterward
- Skips AWS validation automatically when local AWS credentials are not usable
- `ENABLE_DB_DEMO=true` by default — DB rotation and Vault sync are included in every test run

Optional cleanup:

```bash
bash demo/test-e2e.sh --cleanup
```

---

## Demo Walkthrough

All commands are in `demo/demo-commands.sh`. Source it or copy-paste by chapter.

---

### Chapter 1: Two Vault Instances — No Shared Governance

Establish the baseline: two independent Vault clusters with real secrets and no visibility between them.

```bash
# Backend team's Vault
export VAULT_ADDR='http://127.0.0.1:8200'
vault kv list secret/myapp
vault kv get secret/myapp/db-password
vault kv get secret/myapp/api-key

# Payments team's Vault — completely separate cluster
export VAULT_ADDR='http://127.0.0.1:8202'
vault kv list secret/payments
vault kv get secret/payments/stripe-key
vault kv get secret/payments/db-url
```

> These are two separate, unrelated Vault instances. No shared policies. No shared audit log. No way to ask "who accessed what across both teams" without manually checking each cluster. This is the governance gap.

---

### Chapter 2: Demo Gateway, Two Clusters

```bash
kubectl get pods -n akeyless
kubectl get svc -n akeyless
```

In this demo, one Gateway pod bridges both Vault instances to the Akeyless control plane. In production, this is usually one Gateway per private location/region.

---

### Chapter 3: Discover Secrets Across Both Vaults

```bash
# Backend Vault via USC
akeyless usc list --usc-name MVG-demo/vault-usc-backend

# Payments Vault via USC
akeyless usc list --usc-name MVG-demo/vault-usc-payments
```

> Both Vault clusters are visible from the same Akeyless CLI session. Same RBAC model governs both. Same audit trail captures both. Secrets have not moved — each USC inventories its respective Vault instance in real time.

---

### Chapter 4: Read Secrets via USC

```bash
akeyless usc get --usc-name MVG-demo/vault-usc-backend --secret-id "myapp/db-password"
akeyless usc get --usc-name MVG-demo/vault-usc-payments --secret-id "payments/stripe-key"
```

This is the proof that Akeyless is reading live secrets from both Vault clusters through the control plane, without moving them into Akeyless storage.

---

### Chapter 5a: Two-Way Sync — Akeyless to Vault (Backend)

```bash
akeyless usc create \
  --usc-name MVG-demo/vault-usc-backend \
  --secret-name "myapp/created-from-akeyless" \
  --value "value=hello-from-akeyless"

export VAULT_ADDR='http://127.0.0.1:8200'
vault kv get secret/myapp/created-from-akeyless
```

The Akeyless write went through the Gateway directly into backend Vault's KV engine.

---

### Chapter 5b: Two-Way Sync — Vault to Akeyless (Payments)

```bash
export VAULT_ADDR='http://127.0.0.1:8202'
vault kv put secret/payments/created-from-vault value="hello-from-payments-vault"

akeyless usc list --usc-name MVG-demo/vault-usc-payments
akeyless usc get --usc-name MVG-demo/vault-usc-payments --secret-id "payments/created-from-vault"
```

No sync job. No import step. The USC reads directly from Vault, so anything written natively to payments Vault is immediately visible through Akeyless.

---

### Chapter 6: vault CLI via HVP (Zero Code Changes)

**One-time setup — seed secrets into Akeyless KV via HVP:**

HVP at `hvp.akeyless.io` uses Akeyless's own KV store as the backend for static secrets — it does not read through to your local Vault instances. Run these commands once before the demo (or before recording) to populate the Akeyless KV store with the same secret values used in Chapter 1:

```bash
export VAULT_ADDR='https://hvp.akeyless.io'
vault kv put secret/myapp/db-password password="sup3r-s3cret-db-pass"
vault kv put secret/myapp/api-key api_key="akl-demo-api-key-12345"
export VAULT_ADDR='http://127.0.0.1:8200'   # restore
```

This is also the migration pattern in practice: teams write their existing Vault secrets into Akeyless via `vault kv put` through HVP, and their applications continue reading via `vault kv get` with no other changes.

**Set up the HVP token:**

```bash
echo -n "p-xxxxxxxxxxxx..<your-access-key>" > ~/.vault-token
```

**Point the vault CLI at HVP:**

```bash
export VAULT_ADDR='https://hvp.akeyless.io'
```

**Run standard vault commands — they now hit Akeyless:**

```bash
vault kv get secret/myapp/db-password
vault kv get secret/myapp/api-key
```

**Restore after this chapter:**

```bash
export VAULT_ADDR='http://127.0.0.1:8200'
```

---

### Chapter 7a: Extend MVG to AWS and Azure Key Vault

```bash
# AWS Secrets Manager via USC
akeyless usc list --usc-name MVG-demo/aws-usc
akeyless usc get --usc-name MVG-demo/aws-usc --secret-id "demo/mvg/aws/payments-api-key"

# Azure Key Vault via USC
akeyless usc list --usc-name MVG-demo/azure-usc
akeyless usc get --usc-name MVG-demo/azure-usc --secret-id "payments-api-key"
```

> The same Akeyless control plane that governs the two Vault clusters is also governing AWS Secrets Manager and Azure Key Vault in the same session. Same RBAC. Same audit trail. Zero changes to the downstream stores.

---

### Chapter 7b: Azure App Registration Rotation

This chapter shows Akeyless rotating the client secret for the `demo-akeyless-mvg-target` Azure App Registration (client ID `217ffd30-f65f-43ff-84d3-491dde1f2d96`) and then automatically syncing the new credential to the `demo-app-client-secret` secret in Azure Key Vault via the Azure USC. The consuming application reads from Key Vault as usual — it requires no changes.

```bash
# Show the app's current credentials in Azure AD
az ad app credential list --id "$DEMO_APP_CLIENT_ID" \
  --query '[].{hint:hint,endDateTime:endDateTime}' -o table

# Obtain a demo token for Gateway API calls
DEMO_TOKEN=$(akeyless auth \
  --access-id "$READONLY_ACCESS_ID" \
  --access-key "$READONLY_ACCESS_KEY" \
  --access-type access_key --json \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")

# Trigger rotation via Gateway API
curl -sk -X POST "${AKEYLESS_GW}/api/v2/rotate-secret" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"/MVG-demo/azure-app-rotated-secret\",\"token\":\"$DEMO_TOKEN\"}"
sleep 5

# New credential visible in Azure AD
az ad app credential list --id "$DEMO_APP_CLIENT_ID" \
  --query '[].{hint:hint,endDateTime:endDateTime}' -o table

# And synced automatically to Azure Key Vault via USC
akeyless usc get --usc-name MVG-demo/azure-usc --secret-id demo-app-client-secret
```

> Akeyless owned the rotation, Azure AD has the new credential, and Azure Key Vault has the updated value — all without any application restart or code change.

---

### Chapter 7c: Database Rotation → Vault Sync

This chapter shows Akeyless rotating the `akl_demo_user` password on the `demo-mysql` pod in the `akeyless` namespace, then automatically syncing the new credential to `secret/payments/db-rotated-password` in the payments HashiCorp Vault via the payments USC. Applications that read from that Vault path always receive the current password.

```bash
# Show current rotated password value (hint only)
akeyless rotated-secret get-value --name /MVG-demo/db-rotated-password --profile demo

# Verify the rotated user can log in with the current password
CURRENT_PASS=$(akeyless rotated-secret get-value \
  --name /MVG-demo/db-rotated-password --profile demo --json \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('password',''))")

kubectl exec -n akeyless deployment/demo-mysql -- \
  mysql -u akl_demo_user -p"${CURRENT_PASS}" -e "SELECT 1;" demo

# Trigger rotation via Gateway API
curl -sk -X POST "${AKEYLESS_GW}/api/v2/rotate-secret" \
  -H "Content-Type: application/json" \
  -d "{\"name\":\"/MVG-demo/db-rotated-password\",\"token\":\"$DEMO_TOKEN\"}"
sleep 5

# Old password is now rejected
kubectl exec -n akeyless deployment/demo-mysql -- \
  mysql -u akl_demo_user -p"${CURRENT_PASS}" -e "SELECT 1;" demo
# Expected: Access denied

# New password is in Akeyless
akeyless rotated-secret get-value --name /MVG-demo/db-rotated-password --profile demo

# And it has been synced to payments Vault automatically
export VAULT_ADDR='http://127.0.0.1:8202'
vault kv get secret/payments/db-rotated-password
```

> Akeyless rotated the database credential, invalidated the old one, and the new value is already in both Akeyless and the payments Vault — with no manual sync step and no application downtime.

---

### Chapter 8: RBAC — One Policy Denies Vault, AWS, and Azure

```bash
akeyless auth \
  --access-id <DENIED_ACCESS_ID> \
  --access-key <DENIED_ACCESS_KEY>

# Attempt backend Vault — denied
akeyless usc get --usc-name MVG-demo/vault-usc-backend --secret-id "myapp/db-password"
# Expected: Unauthorized

# Attempt payments Vault — also denied (same policy, different cluster)
akeyless usc get --usc-name MVG-demo/vault-usc-payments --secret-id "payments/stripe-key"
# Expected: Unauthorized

# Attempt AWS secret — also denied
akeyless usc get --usc-name MVG-demo/aws-usc --secret-id "demo/mvg/aws/payments-api-key"
# Expected: Unauthorized

# Attempt Azure Key Vault secret — also denied
akeyless usc get --usc-name MVG-demo/azure-usc --secret-id "payments-api-key"
# Expected: Unauthorized
```

> One Akeyless role with a `deny` capability on every configured USC path blocks access across Vault, AWS, and Azure simultaneously. No per-backend ACL update required.

Re-authenticate as admin:

```bash
akeyless auth --access-id p-xxxxxxxxxxxx --access-key <your-access-key>
```

---

### Chapter 9: Unified Audit Trail — Vault, AWS, Azure, One Log

1. Open [https://console.akeyless.io](https://console.akeyless.io)
2. Navigate to **Logs**
3. Filter by your Access ID or action type

Every operation from the session is here: Vault MVG reads and writes, HVP calls, AWS and Azure reads, App Registration and database rotations, and all RBAC denials — attributed, timestamped, in one place.

```bash
akeyless get-audit-event-log --limit 30
```

---

## Cleanup

### Stop both Vault instances

```bash
kill $VAULT_PID_BACKEND $VAULT_PID_PAYMENTS
```

### Remove Akeyless resources

```bash
akeyless auth-method delete --name demo-denied-auth --profile demo
akeyless auth-method delete --name demo-readonly-auth --profile demo
akeyless delete-role --name demo-denied-role --profile demo
akeyless delete-role --name demo-readonly-role --profile demo
akeyless rotated-secret delete --name /MVG-demo/azure-app-rotated-secret --profile demo || true
akeyless rotated-secret delete --name /MVG-demo/db-rotated-password --profile demo || true
akeyless delete-item --name /MVG-demo/aws-rotated-secret --profile demo || true
akeyless delete-item --name /MVG-demo/vault-rotated-api-key --profile demo || true
akeyless delete-item --name /MVG-demo/vault-usc-payments --profile demo
akeyless delete-item --name /MVG-demo/vault-usc-backend --profile demo
akeyless delete-item --name /MVG-demo/azure-usc --profile demo || true
akeyless delete-item --name /MVG-demo/aws-usc --profile demo || true
akeyless target delete --name MVG-demo/azure-target --force-deletion --profile demo || true
akeyless target delete --name MVG-demo/db-target --force-deletion --profile demo || true
akeyless target delete --name MVG-demo/aws-target --force-deletion --profile demo || true
akeyless target delete --name MVG-demo/vault-target-payments --force-deletion --profile demo
akeyless target delete --name MVG-demo/vault-target-backend --force-deletion --profile demo
```

### Remove the Kubernetes Gateway and MySQL pod

```bash
helm uninstall akeyless-gateway -n akeyless
kubectl delete -f demo/demo-mysql.yaml -n akeyless || true
```

### Remove the HVP token

```bash
rm ~/.vault-token
```

### Remove AWS demo data

```bash
aws secretsmanager delete-secret \
  --region "${AWS_REGION:-us-east-2}" \
  --secret-id "${AWS_DEMO_SECRET_NAME:-demo/mvg/aws/payments-api-key}" \
  --force-delete-without-recovery
```

### Remove Azure demo data

```bash
az keyvault secret delete \
  --vault-name "${AZURE_VAULT_NAME:-akl-mvg-demo-kv}" \
  --name "${AZURE_STATIC_SECRET_NAME:-payments-api-key}" || true

az keyvault secret delete \
  --vault-name "${AZURE_VAULT_NAME:-akl-mvg-demo-kv}" \
  --name "${AZURE_APP_KV_SECRET_NAME:-demo-app-client-secret}" || true
```
