# Demo: HashiCorp Vault + Akeyless Governance

## Overview

This demo shows Akeyless acting as a centralized governance layer over **two independent HashiCorp Vault instances** — with no migration required. The two Vault instances represent separate teams in an enterprise: a backend team and a payments team, each running their own Vault cluster with their own secrets.

Neither Vault instance knows the other exists. There is no shared policy, no shared audit log, and no cross-team visibility — until Akeyless is connected. Once connected, a single Akeyless control plane governs both: one RBAC model, one audit trail, zero secrets moved.

The demo also shows the HashiCorp Vault Proxy (HVP), which lets teams continue using the `vault` CLI unchanged while Akeyless handles authentication, authorization, and audit logging behind the scenes.

---

## What You'll See

| Chapter | What It Proves |
|---|---|
| **1 — Two Vault baselines** | Two separate Vault instances, each with real secrets, no shared governance |
| **2 — Gateway health check** | One Akeyless Gateway bridges both Vault instances to the control plane |
| **3 — Both Vaults from one control plane** | USC lists and reads secrets from both clusters — same CLI, same policies, same audit trail |
| **4a — Two-way sync (Akeyless → Vault)** | Write a secret via Akeyless USC; it lands natively in backend Vault |
| **4b — Two-way sync (Vault → Akeyless)** | Write natively in payments Vault; Akeyless sees it immediately with no sync job |
| **5 — HVP (zero code changes)** | One `VAULT_ADDR` change routes existing `vault` CLI commands through Akeyless |
| **6 — RBAC denial (both clusters)** | One Akeyless policy denies access to secrets across both Vault clusters |
| **7 — Unified audit trail** | All operations from both clusters appear in one audit log |

---

## Prerequisites

### Tools Required

| Tool | Notes |
|---|---|
| `vault` CLI | Any recent version of the HashiCorp Vault CLI |
| `akeyless` CLI | [Install instructions](https://docs.akeyless.io/docs/cli) |
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
| `VAULT_ADDR_PAYMENTS` | `http://127.0.0.1:8201` | Address of payments team's Vault |
| `VAULT_TOKEN` | `root` | Root token (same for both dev instances) |
| `AKEYLESS_GATEWAY_URL` | _(required)_ | External URL of your deployed Gateway |
| `USC_BACKEND` | `demo-vault-usc-backend` | USC name for backend Vault |
| `USC_PAYMENTS` | `demo-vault-usc-payments` | USC name for payments Vault |

Quick-copy block:

```bash
export VAULT_ADDR_BACKEND='http://127.0.0.1:8200'
export VAULT_ADDR_PAYMENTS='http://127.0.0.1:8201'
export VAULT_TOKEN='root'
export AKEYLESS_GATEWAY_URL='https://<your-gateway-external-ip>:8000'
export USC_BACKEND='demo-vault-usc-backend'
export USC_PAYMENTS='demo-vault-usc-payments'
```

> **Gateway networking note:** `VAULT_ADDR_BACKEND` and `VAULT_ADDR_PAYMENTS` are the addresses your Akeyless Gateway uses to reach the Vault instances. If your Gateway runs on Kubernetes and Vault runs on your local machine, use your host machine's network IP (e.g., `http://192.168.1.100:8200`) rather than `127.0.0.1`. On Docker Desktop, `http://host.docker.internal:8200` works.

---

## Step 1: Start Both Vault Dev Servers

```bash
source ./demo/setup-vault-dev.sh
```

What this does:

- Starts **backend Vault** on port 8200 with root token `root`
- Starts **payments Vault** on port 8201 with root token `root`
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

## Step 2: Deploy Akeyless Gateway on Kubernetes

One Gateway handles connections to both Vault instances.

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
| Vault Target | `demo-vault-target-backend` | Connection to backend Vault (port 8200) |
| Vault Target | `demo-vault-target-payments` | Connection to payments Vault (port 8201) |
| USC | `demo-vault-usc-backend` | Akeyless window into backend Vault |
| USC | `demo-vault-usc-payments` | Akeyless window into payments Vault |
| Read-only role | `demo-readonly-role` | `read` + `list` on paths under both USCs |
| Read-only auth | `demo-readonly-auth` | API key identity for read-only role |
| Denied role | `demo-denied-role` | `deny` on paths under both USCs |
| Denied auth | `demo-denied-auth` | API key identity for denied role (used in Chapter 6) |

Retrieve the Access ID and Key for `demo-denied-auth` from the Akeyless console (Settings → Auth Methods) before running Chapter 6.

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
export VAULT_ADDR='http://127.0.0.1:8201'
vault kv list secret/payments
vault kv get secret/payments/stripe-key
vault kv get secret/payments/db-url
```

> These are two separate, unrelated Vault instances. No shared policies. No shared audit log. No way to ask "who accessed what across both teams" without manually checking each cluster. This is the governance gap.

---

### Chapter 2: One Gateway, Two Clusters

```bash
kubectl get pods -n akeyless
kubectl get svc -n akeyless
```

One Gateway pod bridges both Vault instances to the Akeyless control plane.

---

### Chapter 3: Both Vaults from One Control Plane

```bash
# Backend Vault via USC
akeyless usc list --usc-name demo-vault-usc-backend
akeyless usc get --usc-name demo-vault-usc-backend --secret-id "myapp/db-password"

# Payments Vault via USC
akeyless usc list --usc-name demo-vault-usc-payments
akeyless usc get --usc-name demo-vault-usc-payments --secret-id "payments/stripe-key"
```

> Both Vault clusters are visible from the same Akeyless CLI session. Same RBAC model governs both. Same audit trail captures both. Secrets have not moved — each USC reads directly from its respective Vault instance in real time.

---

### Chapter 4a: Two-Way Sync — Akeyless to Vault (Backend)

```bash
akeyless usc create \
  --usc-name demo-vault-usc-backend \
  --secret-name "myapp/created-from-akeyless" \
  --value "value=hello-from-akeyless"

export VAULT_ADDR='http://127.0.0.1:8200'
vault kv get secret/myapp/created-from-akeyless
```

The Akeyless write went through the Gateway directly into backend Vault's KV engine.

---

### Chapter 4b: Two-Way Sync — Vault to Akeyless (Payments)

```bash
export VAULT_ADDR='http://127.0.0.1:8201'
vault kv put secret/payments/created-from-vault value="hello-from-payments-vault"

akeyless usc list --usc-name demo-vault-usc-payments
akeyless usc get --usc-name demo-vault-usc-payments --secret-id "payments/created-from-vault"
```

No sync job. No import step. The USC reads directly from Vault, so anything written natively to payments Vault is immediately visible through Akeyless.

---

### Chapter 5: vault CLI via HVP (Zero Code Changes)

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

### Chapter 6: RBAC — One Policy Denies Both Clusters

```bash
akeyless auth \
  --access-id <DENIED_ACCESS_ID> \
  --access-key <DENIED_ACCESS_KEY>

# Attempt backend Vault — denied
akeyless usc get --usc-name demo-vault-usc-backend --secret-id "myapp/db-password"
# Expected: Unauthorized

# Attempt payments Vault — also denied (same policy, different cluster)
akeyless usc get --usc-name demo-vault-usc-payments --secret-id "payments/stripe-key"
# Expected: Unauthorized
```

> One Akeyless role with a `deny` capability on both USC paths blocks access to both Vault clusters simultaneously. No per-cluster ACL update required.

Re-authenticate as admin:

```bash
akeyless auth --access-id p-xxxxxxxxxxxx --access-key <your-access-key>
```

---

### Chapter 7: Unified Audit Trail — Both Clusters, One Log

1. Open [https://console.akeyless.io](https://console.akeyless.io)
2. Navigate to **Logs**
3. Filter by your Access ID or action type

Every operation from the session is here: USC reads and writes against both clusters, HVP calls, and both RBAC denials — attributed, timestamped, in one place.

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
akeyless delete-auth-method --name demo-denied-auth
akeyless delete-auth-method --name demo-readonly-auth
akeyless delete-role --name demo-denied-role
akeyless delete-role --name demo-readonly-role
akeyless delete-usc --usc-name demo-vault-usc-payments
akeyless delete-usc --usc-name demo-vault-usc-backend
akeyless delete-target --name demo-vault-target-payments
akeyless delete-target --name demo-vault-target-backend
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
