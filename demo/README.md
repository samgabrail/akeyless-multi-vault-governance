# Demo: Akeyless Multi Vault Governance

## Overview

This demo shows Akeyless acting as a centralized governance layer across **two independent HashiCorp Vault instances**, **AWS Secrets Manager**, and **Kubernetes Secrets** — with no migration required. The two Vault instances represent separate teams in an enterprise: a backend team and a payments team, each running their own Vault cluster with their own secrets. AWS Secrets Manager and Kubernetes Secrets are included to show how the same MVG layer extends beyond Vault into the cloud-native and platform-native systems many enterprises already run alongside it.

Neither Vault instance knows the other exists. There is no shared policy, no shared audit log, and no cross-team visibility — until Akeyless is connected. The same fragmentation often exists across cloud secrets managers and Kubernetes Secrets. Once connected, a single Akeyless control plane governs all of them: one RBAC model, one audit trail, zero secrets moved.

The demo also shows the HashiCorp Vault Proxy (HVP), which lets teams continue using the `vault` CLI unchanged while Akeyless handles authentication, authorization, and audit logging behind the scenes. This keeps Vault as the primary story while proving that MVG extends beyond Vault into cloud and Kubernetes environments.

> **Terminology note:** In this repo, narrative copy uses **MVG** for multi-vault governance. In the current product, CLI, and docs, this capability is still surfaced as **USC**.
>
> **Production topology clarification:** This repo uses one Akeyless Gateway for both Vault instances, AWS, and Kubernetes only to keep the demo small. In production, teams usually place Vault clusters per region and close to workloads for latency, and deploy one Akeyless Gateway per private location/region. Vault Enterprise teams may use DR or Performance Replication, but many organizations still run isolated Vault clusters with no replication because of ownership boundaries, cost, or operational complexity. MVG is designed for exactly that isolated-cluster model, and it extends the same governance approach to cloud secrets managers and Kubernetes.

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
| **7 — Extend MVG to AWS and Kubernetes** | The same MVG layer discovers and reads secrets from AWS Secrets Manager and Kubernetes |
| **8 — One RBAC policy, many backends** | One Akeyless policy denies access across Vault, AWS, and Kubernetes |
| **9 — One unified audit trail** | All operations from all governed backends appear in one audit log |

---

## Prerequisites

### Tools Required

| Tool | Notes |
|---|---|
| `vault` CLI | Any recent version of the HashiCorp Vault CLI |
| `akeyless` CLI | [Install instructions](https://docs.akeyless.io/docs/cli) |
| `aws` CLI | Needed for the AWS Secrets Manager extension |
| `kubectl` | For inspecting Gateway pods and services |
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

| Variable | Default | Description |
|---|---|---|
| `VAULT_ADDR_BACKEND` | `http://127.0.0.1:8200` | Address of backend team's Vault |
| `VAULT_ADDR_PAYMENTS` | `http://127.0.0.1:8202` | Address of payments team's Vault |
| `VAULT_TOKEN` | `root` | Root token (same for both dev instances) |
| `AKEYLESS_DEMO_FOLDER` | `MVG-demo` | Akeyless folder used for demo targets, USCs, and rotated secrets |
| `AKEYLESS_GATEWAY_URL` | _(required)_ | External URL of your deployed Gateway |
| `ENABLE_AWS_DEMO` | `false` | Whether to create the AWS target + USC |
| `ENABLE_K8S_DEMO` | `false` | Whether to create the Kubernetes target + USC |
| `AWS_REGION` | `us-east-2` | Region for AWS Secrets Manager |
| `AWS_USC_PREFIX` | `demo/mvg/aws/` | Prefix filtered by the AWS USC |
| `AWS_DEMO_SECRET_NAME` | `demo/mvg/aws/payments-api-key` | AWS secret used in the demo |
| `K8S_NAMESPACE` | `mvg-demo` | Namespace used for the Kubernetes demo |
| `K8S_DEMO_SECRET_NAME` | `payments-config` | Kubernetes Secret object used in the demo |
| `USC_BACKEND` | `MVG-demo/vault-usc-backend` | USC name for backend Vault |
| `USC_PAYMENTS` | `MVG-demo/vault-usc-payments` | USC name for payments Vault |
| `USC_AWS` | `MVG-demo/aws-usc` | USC name for AWS Secrets Manager |
| `USC_K8S` | `MVG-demo/k8s-usc` | USC name for Kubernetes Secrets |

Quick-copy block:

```bash
export VAULT_ADDR_BACKEND='http://127.0.0.1:8200'
export VAULT_ADDR_PAYMENTS='http://127.0.0.1:8202'
export VAULT_TOKEN='root'
export AKEYLESS_DEMO_FOLDER='MVG-demo'
export AKEYLESS_GATEWAY_URL='https://<your-gateway-external-ip>:8000'
export ENABLE_AWS_DEMO='true'
export ENABLE_K8S_DEMO='true'
export AWS_REGION='us-east-2'
export AWS_USC_PREFIX='demo/mvg/aws/'
export AWS_DEMO_SECRET_NAME='demo/mvg/aws/payments-api-key'
export K8S_NAMESPACE='mvg-demo'
export K8S_DEMO_SECRET_NAME='payments-config'
export USC_BACKEND='MVG-demo/vault-usc-backend'
export USC_PAYMENTS='MVG-demo/vault-usc-payments'
export USC_AWS='MVG-demo/aws-usc'
export USC_K8S='MVG-demo/k8s-usc'
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

## Step 1b: Seed AWS and Kubernetes Demo Resources

This step is what expands the webinar from a Vault-only story into a true MVG story.

```bash
./demo/setup-cloud-and-k8s-demo.sh
```

What this does:

- Creates or updates the AWS Secrets Manager secret used in the demo
- Creates the Kubernetes namespace and secret used in the demo
- Creates a Kubernetes service account with read/list access to secrets in that namespace
- Prints the `export` commands needed for `demo/akeyless-setup.sh`

After this step, copy the printed `export ...` lines into your shell. `ENABLE_AWS_DEMO` is printed as `true` only if the local AWS CLI is actually authenticated. If your AWS credentials are not already present in the environment, also export:

```bash
export AWS_ACCESS_KEY_ID='<your-access-key-id>'
export AWS_SECRET_ACCESS_KEY='<your-secret-access-key>'
export AWS_SESSION_TOKEN='<your-session-token>'   # only if using STS creds
```

---

## Step 2: Deploy Akeyless Gateway on Kubernetes

For this demo, one Gateway handles connections to both Vault instances. In production, deploy one Gateway per private location/region, close to the local Vault cluster and application workloads.

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
| Kubernetes Target | `MVG-demo/k8s-target` | Connection to the Kubernetes cluster |
| USC | `MVG-demo/vault-usc-backend` | Akeyless window into backend Vault |
| USC | `MVG-demo/vault-usc-payments` | Akeyless window into payments Vault |
| USC | `MVG-demo/aws-usc` | Akeyless window into AWS Secrets Manager |
| USC | `MVG-demo/k8s-usc` | Akeyless window into Kubernetes Secrets |
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
- Seeds AWS and Kubernetes demo backends
- Reconciles Akeyless targets, USCs, roles, and auth methods
- Verifies Vault MVG, HVP, Kubernetes MVG, and centralized deny RBAC
- Uses unique test secret names and removes them afterward
- Skips AWS validation automatically when local AWS credentials are not usable

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

### Chapter 7: Extend MVG to AWS and Kubernetes

```bash
akeyless usc list --usc-name MVG-demo/aws-usc
akeyless usc get --usc-name MVG-demo/aws-usc --secret-id "demo/mvg/aws/payments-api-key"

akeyless usc list --usc-name MVG-demo/k8s-usc
akeyless usc get --usc-name MVG-demo/k8s-usc --secret-id "payments-config"
```

This is the “true MVG” proof point. The same Akeyless control plane that is governing the two Vault clusters is also governing AWS Secrets Manager and Kubernetes Secrets in the same session.

---

### Chapter 8: RBAC — One Policy Denies Vault, AWS, and Kubernetes

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

# Attempt Kubernetes secret — also denied
akeyless usc get --usc-name MVG-demo/k8s-usc --secret-id "payments-config"
# Expected: Unauthorized
```

> One Akeyless role with a `deny` capability on every configured USC path blocks access across Vault, AWS, and Kubernetes simultaneously. No per-backend ACL update required.

Re-authenticate as admin:

```bash
akeyless auth --access-id p-xxxxxxxxxxxx --access-key <your-access-key>
```

---

### Chapter 9: Unified Audit Trail — Vault, AWS, Kubernetes, One Log

1. Open [https://console.akeyless.io](https://console.akeyless.io)
2. Navigate to **Logs**
3. Filter by your Access ID or action type

Every operation from the session is here: Vault MVG reads and writes, HVP calls, AWS and Kubernetes reads, and all RBAC denials — attributed, timestamped, in one place.

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
akeyless delete-item --name /MVG-demo/azure-rotated-api-key --profile demo || true
akeyless delete-item --name /MVG-demo/aws-rotated-secret --profile demo || true
akeyless delete-item --name /MVG-demo/vault-rotated-api-key --profile demo || true
akeyless delete-item --name /MVG-demo/vault-usc-payments --profile demo
akeyless delete-item --name /MVG-demo/vault-usc-backend --profile demo
akeyless delete-item --name /MVG-demo/azure-usc --profile demo || true
akeyless delete-item --name /MVG-demo/aws-usc --profile demo || true
akeyless delete-item --name /MVG-demo/k8s-usc --profile demo || true
akeyless target delete --name MVG-demo/azure-target --force-deletion --profile demo || true
akeyless target delete --name MVG-demo/aws-target --force-deletion --profile demo || true
akeyless target delete --name MVG-demo/k8s-target --force-deletion --profile demo || true
akeyless target delete --name MVG-demo/vault-target-payments --force-deletion --profile demo
akeyless target delete --name MVG-demo/vault-target-backend --force-deletion --profile demo
```

### Remove the Kubernetes Gateway

```bash
helm uninstall akeyless-gateway -n akeyless
kubectl delete namespace akeyless
```

### Remove the HVP token

```bash
rm ~/.vault-token
```

### Remove AWS and Kubernetes demo data

```bash
aws secretsmanager delete-secret \
  --region "${AWS_REGION:-us-east-2}" \
  --secret-id "${AWS_DEMO_SECRET_NAME:-demo/mvg/aws/payments-api-key}" \
  --force-delete-without-recovery

kubectl delete namespace "${K8S_NAMESPACE:-mvg-demo}"
```
