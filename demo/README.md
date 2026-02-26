# Demo: HashiCorp Vault + Akeyless Governance

## Overview

This demo proves that Akeyless can act as a centralized governance layer over an existing HashiCorp Vault deployment — with no migration required. Using the Universal Secret Connector (USC), secrets remain in-place inside Vault while Akeyless provides unified visibility, write-through management, and policy enforcement. The HashiCorp Vault Proxy (HVP) then shows that existing tooling and application code continues to work against the Akeyless backend with a single environment variable change, and the audit trail chapter demonstrates that every operation — reads, writes, HVP calls, and RBAC denials — is captured in one place.

---

## What You'll See

- **Chapter 1 — Vault baseline**: Vault is running with real secrets seeded before any Akeyless interaction, establishing that there is nothing unusual about this Vault instance.
- **Chapter 2 — Gateway health check**: The Akeyless Gateway is deployed on Kubernetes and reachable; confirms the bridge between Vault and the Akeyless control plane is live.
- **Chapter 3 — Manage Vault secrets from Akeyless**: The USC exposes existing Vault secrets through the Akeyless API without moving them, proving governance without migration.
- **Chapter 4a — Two-way sync (Akeyless → Vault)**: A secret created through the Akeyless USC appears immediately in Vault natively, proving write-through to the source system.
- **Chapter 4b — Two-way sync (Vault → Akeyless)**: A secret written directly to Vault is immediately visible through the USC, proving Akeyless stays in sync without a scheduled job.
- **Chapter 5 — HVP (zero code changes)**: One `VAULT_ADDR` change routes existing `vault` CLI commands through Akeyless HVP, demonstrating full Vault CLI compatibility.
- **Chapter 6 — RBAC denial**: An identity with an explicit deny policy is blocked from reading a secret, proving that Akeyless policy enforcement sits in front of Vault regardless of Vault's own ACLs.
- **Chapter 7 — Centralized audit trail**: Every operation from the session — USC reads, writes, HVP calls, and the RBAC denial — is visible in the Akeyless audit log as a unified record.

---

## Prerequisites

### Tools Required

| Tool | Notes |
|---|---|
| `vault` CLI | Any recent version of the HashiCorp Vault CLI |
| `akeyless` CLI | [Install instructions](https://docs.akeyless.io/docs/cli) |
| `kubectl` | For inspecting Gateway pods and services |
| `helm` | For deploying the Akeyless Gateway chart |

You also need an Akeyless account. The free tier is sufficient for this demo: [https://console.akeyless.io](https://console.akeyless.io)

### Akeyless Setup

1. Log in to [https://console.akeyless.io](https://console.akeyless.io).
2. Navigate to **Auth Methods** and create a new **API Key** auth method. Give it a name you will remember (e.g., `demo-admin-auth`).
3. Copy the **Access ID** (format: `p-xxxxxxxxxxxx`) and **Access Key** — you will need both throughout the demo.
4. Authenticate the CLI before running any of the scripts below:

```bash
akeyless auth \
  --access-id p-xxxxxxxxxxxx \
  --access-key <your-access-key>
```

> The CLI stores the resulting token in `~/.akeyless/` and reuses it for subsequent commands. If the token expires during the demo, re-run the `akeyless auth` command above.

---

## Environment Variables

Set these in your terminal before running any demo scripts. The scripts will read from the environment and will fail early with a clear error message if a required variable is missing.

| Variable | Default | Description |
|---|---|---|
| `VAULT_ADDR` | `http://127.0.0.1:8200` | Address of the Vault dev server |
| `VAULT_TOKEN` | `root` | Root token for the Vault dev server |
| `AKEYLESS_GATEWAY_URL` | _(required)_ | External URL of your deployed Gateway, e.g. `https://192.168.1.100:8000` |
| `USC_NAME` | `demo-vault-usc` | Name of the USC created by `akeyless-setup.sh` |

Quick-copy block for your terminal:

```bash
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'
export AKEYLESS_GATEWAY_URL='https://<your-gateway-external-ip>:8000'
export USC_NAME='demo-vault-usc'
```

---

## Step 1: Start Vault in Dev Mode

Run the setup script from the repo root:

```bash
./demo/setup-vault-dev.sh
```

> Run this with `source` if you want `VAULT_PID` exported into your current shell so you can stop Vault with `kill $VAULT_PID` at the end:
> ```bash
> source ./demo/setup-vault-dev.sh
> ```

What this script does:

- Starts `vault server -dev` at `127.0.0.1:8200` with root token `root`
- Waits up to 30 seconds for Vault to report healthy
- Confirms that the KV v2 engine is mounted at `secret/` (it is by default in dev mode)
- Seeds two demo secrets:
  - `secret/myapp/db-password` — key `password`, value `sup3r-s3cret-db-pass`
  - `secret/myapp/api-key` — key `api_key`, value `akl-demo-api-key-12345`
- Prints a summary including the Vault PID and log file path (`/tmp/vault-dev.log`)

**Keep this terminal open.** The Vault process must remain running throughout the demo. If you sourced the script, `VAULT_PID` is available in your shell for the cleanup step.

---

## Step 2: Deploy Akeyless Gateway on Kubernetes

The Gateway is the bridge between your Kubernetes cluster network and the Akeyless control plane. It is also what the USC uses to reach your local Vault server.

### 2a: Add the Helm chart repository

```bash
helm repo add akeyless https://akeyless-community.github.io/helm-charts
helm repo update
```

### 2b: Create the credentials secret

Replace `<YOUR_AKEYLESS_ACCESS_KEY>` with the access key from your Akeyless auth method.

```bash
kubectl create secret generic akeyless-admin-credentials \
  -n akeyless --create-namespace \
  --from-literal=admin-access-key=<YOUR_AKEYLESS_ACCESS_KEY>
```

### 2c: Edit gateway-values.yaml

Open `demo/gateway-values.yaml` and set `adminAccessId` to your Access ID:

```yaml
akeylessUserAuth:
  adminAccessId: "p-xxxxxxxxxxxx"   # <-- replace this
```

> The file already has placeholder comments marking every value that must be changed. Do not deploy without updating `adminAccessId` — the Gateway will fail to authenticate.

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

Look for the `EXTERNAL-IP` column on the `akeyless-gateway` service. That value is your `AKEYLESS_GATEWAY_URL`. Set it now:

```bash
export AKEYLESS_GATEWAY_URL='https://<EXTERNAL-IP>:8000'
```

> If `EXTERNAL-IP` shows `<pending>`, your cluster's load balancer is still provisioning. Wait a minute and re-run `kubectl get svc -n akeyless`. On a local cluster (e.g., kind or minikube) you may need to use port-forwarding or a NodePort instead.

---

## Step 3: Configure Akeyless Resources

With both `VAULT_ADDR` and `AKEYLESS_GATEWAY_URL` set, run the Akeyless setup script:

```bash
export AKEYLESS_GATEWAY_URL='https://<your-gateway-external-ip>:8000'
./demo/akeyless-setup.sh
```

What this script creates:

| Resource | Name | Purpose |
|---|---|---|
| HashiCorp Vault Target | `demo-vault-target` | Stores the connection details and token for your Vault dev server |
| Universal Secret Connector | `demo-vault-usc` | Bridges the Vault target into the Akeyless secret namespace |
| Read-only RBAC role | `demo-readonly-role` | Grants `read` and `list` on all paths under `demo-vault-usc/*` |
| Read-only API key auth | `demo-readonly-auth` | API key identity associated with the read-only role |
| Denied RBAC role | `demo-denied-role` | Explicit `deny` on all paths under `demo-vault-usc/*` |
| Denied API key auth | `demo-denied-auth` | API key identity associated with the denied role — used in Chapter 6 |

The script prints a summary at the end showing all created resources. After running `akeyless-setup.sh`, retrieve the Access IDs and Access Keys for `demo-denied-auth` from the Akeyless console (Settings → Auth Methods) — you will need the denied identity's credentials for Chapter 6.

---

## Demo Walkthrough

Each chapter below corresponds to a chapter in the accompanying video. All commands are also collected in `demo/demo-commands.sh`. You can source that file and run individual sections, or copy-paste directly from this document.

```bash
# Optional: source the commands file so each chapter's commands are available as-is
source demo/demo-commands.sh
```

---

### Chapter 1: Verify Vault Has Our Secrets

Establish the baseline: Vault is running normally with secrets that exist entirely independent of Akeyless.

```bash
vault kv list secret/myapp
vault kv get secret/myapp/db-password
vault kv get secret/myapp/api-key
```

Expected output includes `db-password` and `api-key` listed under `myapp/`, and the secret data fields (`password`, `api_key`) visible in the `vault kv get` output.

> At this point Akeyless has not been involved at all. These are ordinary Vault secrets in an ordinary Vault KV v2 engine.

---

### Chapter 2: Confirm Gateway Is Running

```bash
kubectl get pods -n akeyless
kubectl get svc -n akeyless
```

You should see Gateway pod(s) in `Running` state and the service with an `EXTERNAL-IP`. This confirms the bridge is live before the USC demo begins.

---

### Chapter 3: Manage Vault Secrets from Akeyless

Show that the USC makes Vault secrets visible and manageable from the Akeyless control plane — without migrating them out of Vault.

```bash
akeyless usc list --usc-name demo-vault-usc
akeyless usc get --usc-name demo-vault-usc --secret-id "myapp/db-password"
```

> Vault remains the system of record. The USC reads through to Vault in real time — there is no copy or cache stored inside Akeyless. Every read you see here is a live read from your Vault dev server.

---

### Chapter 4a: Two-Way Sync — Akeyless to Vault

Create a secret through the Akeyless USC and verify it lands directly in Vault.

```bash
akeyless usc create \
  --usc-name demo-vault-usc \
  --secret-name "myapp/created-from-akeyless" \
  --value "value=hello-from-akeyless"

vault kv get secret/myapp/created-from-akeyless
```

The `vault kv get` command should return the new secret with no additional steps. The USC write went through the Gateway and directly into Vault's KV engine.

---

### Chapter 4b: Two-Way Sync — Vault to Akeyless

Create a secret natively in Vault using the standard `vault kv put` workflow, then verify it is immediately visible through the USC — with no import step and no sync job.

```bash
vault kv put secret/myapp/created-from-vault value="hello-from-vault"

akeyless usc list --usc-name demo-vault-usc
akeyless usc get --usc-name demo-vault-usc --secret-id "myapp/created-from-vault"
```

The new secret should appear in the `usc list` output and be fully readable via `usc get`.

---

### Chapter 5: vault CLI via Akeyless HVP (Zero Code Changes)

The HashiCorp Vault Proxy (HVP) allows any tool or application that speaks the Vault HTTP API to use Akeyless as the backend. The only change required on the client side is the `VAULT_ADDR` environment variable.

**Set up the HVP token.** The vault CLI reads `~/.vault-token` for authentication. The HVP token format is `<Access ID>..<Access Key>`:

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

The output is identical to what Vault returned directly. No application code changed. No SDK swap. No re-architecture.

**Restore the original Vault address after this chapter:**

```bash
export VAULT_ADDR='http://127.0.0.1:8200'
```

> The `ORIGINAL_VAULT_ADDR` save-and-restore pattern is also in `demo/demo-commands.sh` so the rest of the demo chapters continue to work against the local Vault dev server.

---

### Chapter 6: RBAC — Deny in Action

Authenticate as the denied identity created by `akeyless-setup.sh` and attempt to read a secret. Replace the placeholders with the actual Access ID and Access Key printed by the setup script for `demo-denied-auth`.

```bash
akeyless auth \
  --access-id <DENIED_ACCESS_ID> \
  --access-key <DENIED_ACCESS_KEY>

akeyless usc get --usc-name demo-vault-usc --secret-id "myapp/db-password"
```

Expected result: an `Unauthorized` or `Permission denied` error. The `demo-denied-role` has an explicit `deny` capability on `demo-vault-usc/*`, so access is blocked regardless of what Vault's own ACLs would allow.

> This proves that Akeyless policy enforcement is authoritative. An identity denied in Akeyless cannot reach the underlying Vault secret, even if that secret is technically accessible in Vault directly.

Re-authenticate as your admin identity after this chapter:

```bash
akeyless auth \
  --access-id p-xxxxxxxxxxxx \
  --access-key <your-access-key>
```

---

### Chapter 7: Centralized Audit Trail

Every operation performed during this demo — USC reads, USC writes, HVP calls, and the RBAC denial from Chapter 6 — is recorded in the Akeyless audit log.

**In the console:**

1. Open [https://console.akeyless.io](https://console.akeyless.io)
2. Navigate to **Logs** in the left sidebar
3. Filter by your Access ID or by action type (`get`, `list`, `create`)

You will see a timestamped record of every operation from this session across all chapters.

**Optionally, fetch recent log entries via CLI:**

```bash
akeyless get-audit-event-log --limit 20
```

> This is the "single pane of glass" value proposition: one audit trail that covers Vault-backed secrets (via USC), HVP traffic, and all direct Akeyless operations — regardless of which underlying vault system holds the data.

---

## Cleanup

### Stop the Vault dev server

If you sourced `setup-vault-dev.sh`:

```bash
kill $VAULT_PID
```

If you ran it standalone, find the PID from the script's summary output and kill it directly:

```bash
kill <VAULT_PID printed by setup-vault-dev.sh>
```

The Vault log is at `/tmp/vault-dev.log` and can be deleted with `rm /tmp/vault-dev.log`.

### Remove Akeyless resources

Delete all resources created by `akeyless-setup.sh` in reverse order:

```bash
# Disassociate auth methods from roles before deleting
akeyless delete-auth-method --name demo-denied-auth
akeyless delete-auth-method --name demo-readonly-auth

# Delete RBAC roles
akeyless delete-role --name demo-denied-role
akeyless delete-role --name demo-readonly-role

# Delete the USC
akeyless delete-usc --usc-name demo-vault-usc

# Delete the Vault Target
akeyless delete-target --name demo-vault-target
```

> Run these with your admin Access ID authenticated. If you re-authenticated as the denied identity in Chapter 6, re-authenticate as admin first (`akeyless auth --access-id p-xxxxxxxxxxxx --access-key <your-access-key>`).

### Remove the Kubernetes Gateway

```bash
helm uninstall akeyless-gateway -n akeyless
kubectl delete namespace akeyless
```

### Remove the HVP token

```bash
rm ~/.vault-token
```
