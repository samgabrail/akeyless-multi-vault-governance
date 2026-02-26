# HashiCorp Vault + Akeyless Governance Content Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Produce a blog post, video script, and self-contained demo that demonstrate Akeyless governing an existing HashiCorp Vault deployment via USC and HVP — without migration.

**Architecture:** Three flat content files (blog-post.md, video-script.md) plus a demo/ folder with shell scripts and K8s Helm values. The blog post embeds the video and references the demo. The video script drives both the slide deck content and the demo screencast chapters.

**Tech Stack:** Markdown, bash scripts, Helm (Akeyless Gateway), HashiCorp Vault dev mode, akeyless CLI, vault CLI

---

### Task 1: Demo — Vault dev mode setup script

**Files:**
- Create: `demo/setup-vault-dev.sh`

**Context:**
Vault dev mode starts a fully in-memory Vault server with a known root token (`root`). KV v2 is enabled by default at `secret/`. We seed two secrets so the demo has something to show before any Akeyless setup.

**Step 1: Create the script**

```bash
#!/usr/bin/env bash
# demo/setup-vault-dev.sh
# Starts HashiCorp Vault in dev mode and seeds sample secrets.
# Prerequisites: vault CLI installed, port 8200 free.

set -euo pipefail

export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

echo "==> Starting Vault in dev mode (background)..."
vault server -dev -dev-root-token-id=root &
VAULT_PID=$!
echo "    Vault PID: $VAULT_PID"

echo "==> Waiting for Vault to be ready..."
sleep 2
vault status

echo "==> Enabling KV v2 at secret/ (already default in dev mode, verifying)..."
vault secrets list | grep -q "^secret/" && echo "    KV v2 already enabled." || \
  vault secrets enable -version=2 -path=secret kv

echo "==> Seeding sample secrets..."
vault kv put secret/myapp/db-password value="sup3r-s3cret-db-pass"
vault kv put secret/myapp/api-key value="akl-demo-api-key-12345"

echo ""
echo "==> Vault is ready."
echo "    VAULT_ADDR: $VAULT_ADDR"
echo "    VAULT_TOKEN: root"
echo "    Secrets seeded:"
echo "      secret/myapp/db-password"
echo "      secret/myapp/api-key"
echo ""
echo "    To stop Vault: kill $VAULT_PID"
echo "    Save PID: export VAULT_PID=$VAULT_PID"
```

**Step 2: Make executable**

```bash
chmod +x demo/setup-vault-dev.sh
```

**Step 3: Verify it works**

Run: `./demo/setup-vault-dev.sh`

Expected output: Vault status shows `Initialized: true`, `Sealed: false`. Then:
```
Success! Data written to: secret/data/myapp/db-password
Success! Data written to: secret/data/myapp/api-key
```

Verify: `vault kv get secret/myapp/db-password` returns `value: sup3r-s3cret-db-pass`

Kill vault: `kill $VAULT_PID`

---

### Task 2: Demo — Akeyless Gateway Helm values

**Files:**
- Create: `demo/gateway-values.yaml`

**Context:**
The Akeyless Gateway is deployed via Helm on a K8s cluster. The values file configures the gateway to connect to the Akeyless SaaS control plane using an API key auth method. The viewer is assumed to have already created an API key auth method in their Akeyless account and to have their Access ID and Access Key available.

**Step 1: Create the values file**

```yaml
# demo/gateway-values.yaml
# Helm values for deploying the Akeyless Gateway on Kubernetes.
# Chart: akeyless/akeyless-api-gateway
#
# Prerequisites:
#   helm repo add akeyless https://akeyless-community.github.io/helm-charts
#   helm repo update
#
# Deploy:
#   helm upgrade --install akeyless-gateway akeyless/akeyless-api-gateway \
#     -n akeyless --create-namespace \
#     -f demo/gateway-values.yaml
#
# Replace ALL <placeholder> values before deploying.

akeylessUserAuth:
  # Your Akeyless API Key Access ID (format: p-xxxxxxxxxxxx)
  adminAccessId: "<YOUR_AKEYLESS_ACCESS_ID>"
  # Credentials secret — create with:
  #   kubectl create secret generic akeyless-admin-credentials \
  #     -n akeyless \
  #     --from-literal=admin-access-key=<YOUR_AKEYLESS_ACCESS_KEY>
  adminCredentialsSecretName: "akeyless-admin-credentials"
  adminCredentialsSecretKey: "admin-access-key"

# Expose Gateway externally so Akeyless SaaS can reach it.
# For a home lab, NodePort or a local LoadBalancer (e.g. MetalLB) works fine.
service:
  type: LoadBalancer
  ports:
    - name: web
      port: 8000
      targetPort: 8000
    - name: hvp
      port: 8200
      targetPort: 8200

# Resource limits suitable for a home lab
resources:
  requests:
    cpu: "250m"
    memory: "512Mi"
  limits:
    cpu: "1"
    memory: "1Gi"
```

**Step 2: Verify the file is valid YAML**

```bash
python3 -c "import yaml; yaml.safe_load(open('demo/gateway-values.yaml'))" && echo "Valid YAML"
```

Expected: `Valid YAML`

---

### Task 3: Demo — Akeyless setup script (Target + USC + RBAC)

**Files:**
- Create: `demo/akeyless-setup.sh`

**Context:**
This script uses the `akeyless` CLI to:
1. Create a HashiCorp Vault Target (the connection definition pointing at the local Vault dev server)
2. Create a Universal Secret Connector (USC) that ties the Gateway to the Target
3. Create an RBAC demo: an API key auth method with restricted read-only access and a separate auth method that is denied

The `akeyless` CLI must already be authenticated (`akeyless auth` or `AKEYLESS_TOKEN` env var set). The Gateway URL must be reachable from where this script runs.

**Step 1: Create the script**

```bash
#!/usr/bin/env bash
# demo/akeyless-setup.sh
# Creates the Akeyless resources needed for the demo:
#   - HashiCorp Vault Target
#   - Universal Secret Connector (USC)
#   - RBAC: read-only role + denied-access role
#
# Prerequisites:
#   - akeyless CLI installed and authenticated
#   - Vault running in dev mode (./setup-vault-dev.sh)
#   - VAULT_ADDR exported (default: http://127.0.0.1:8200)
#   - AKEYLESS_GATEWAY_URL exported (your Gateway's external URL)
#
# Usage:
#   export VAULT_ADDR='http://127.0.0.1:8200'
#   export AKEYLESS_GATEWAY_URL='https://<your-gateway-ip>:8000'
#   ./demo/akeyless-setup.sh

set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
GATEWAY_URL="${AKEYLESS_GATEWAY_URL:-}"
TARGET_NAME="demo-vault-target"
USC_NAME="demo-vault-usc"
READONLY_ROLE="demo-readonly-role"
READONLY_AUTH="demo-readonly-auth"
DENIED_ROLE="demo-denied-role"
DENIED_AUTH="demo-denied-auth"

if [[ -z "$GATEWAY_URL" ]]; then
  echo "ERROR: AKEYLESS_GATEWAY_URL is not set."
  echo "  Export your Gateway URL, e.g.:"
  echo "  export AKEYLESS_GATEWAY_URL='https://192.168.1.100:8000'"
  exit 1
fi

echo "==> Creating HashiCorp Vault Target: $TARGET_NAME"
akeyless target create hashi-vault \
  --name "$TARGET_NAME" \
  --hashi-url "$VAULT_ADDR" \
  --vault-token "$VAULT_TOKEN"

echo ""
echo "==> Creating Universal Secret Connector: $USC_NAME"
akeyless create-usc \
  --usc-name "$USC_NAME" \
  --target-to-associate "$TARGET_NAME" \
  --gw-cluster-url "$GATEWAY_URL"

echo ""
echo "==> Verifying USC can list Vault secrets..."
akeyless usc list --usc-name "$USC_NAME"

echo ""
echo "==> Setting up RBAC — read-only role..."
akeyless create-role --name "$READONLY_ROLE" || true
akeyless set-role-rule \
  --role-name "$READONLY_ROLE" \
  --path "/demo-vault-usc/*" \
  --capability read \
  --capability list

echo "==> Creating read-only API key auth method..."
akeyless auth-method create api-key --name "$READONLY_AUTH" || true
akeyless assoc-role-am \
  --role-name "$READONLY_ROLE" \
  --am-name "$READONLY_AUTH"

echo ""
echo "==> Setting up RBAC — denied role (to demonstrate access control)..."
akeyless create-role --name "$DENIED_ROLE" || true
akeyless set-role-rule \
  --role-name "$DENIED_ROLE" \
  --path "/demo-vault-usc/*" \
  --capability deny

echo "==> Creating denied API key auth method..."
akeyless auth-method create api-key --name "$DENIED_AUTH" || true
akeyless assoc-role-am \
  --role-name "$DENIED_ROLE" \
  --am-name "$DENIED_AUTH"

echo ""
echo "==> Setup complete!"
echo "    Target:       $TARGET_NAME"
echo "    USC:          $USC_NAME"
echo "    Read-only:    role=$READONLY_ROLE  auth=$READONLY_AUTH"
echo "    Denied:       role=$DENIED_ROLE  auth=$DENIED_AUTH"
```

**Step 2: Make executable**

```bash
chmod +x demo/akeyless-setup.sh
```

---

### Task 4: Demo — demo commands script

**Files:**
- Create: `demo/demo-commands.sh`

**Context:**
This is the script the presenter runs live during the screencast. Each section is clearly labeled with a chapter marker comment. It is not meant to be run as a single bash script (`set -e` is intentional to stop on errors), but rather copied and pasted command-by-command or run in a terminal with `source`.

```bash
#!/usr/bin/env bash
# demo/demo-commands.sh
# Live demo commands — run section by section during the screencast.
# Not meant to be executed as a single script.
#
# Prerequisites: Vault running, akeyless-setup.sh already completed.
# Environment:
#   export VAULT_ADDR='http://127.0.0.1:8200'
#   export VAULT_TOKEN='root'
#   export USC_NAME='demo-vault-usc'

USC_NAME="${USC_NAME:-demo-vault-usc}"

# ─────────────────────────────────────────────────────────
# CHAPTER 1: Verify Vault dev mode has our seeded secrets
# ─────────────────────────────────────────────────────────
echo "--- Chapter 1: Vault dev secrets ---"
vault kv list secret/myapp
vault kv get secret/myapp/db-password
vault kv get secret/myapp/api-key

# ─────────────────────────────────────────────────────────
# CHAPTER 2: (Gateway already running on K8s — show in UI or kubectl)
# kubectl get pods -n akeyless
# ─────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────
# CHAPTER 3: List and read Vault secrets via Akeyless USC
# ─────────────────────────────────────────────────────────
echo "--- Chapter 3: USC list & get ---"
akeyless usc list --usc-name "$USC_NAME"
akeyless usc get --usc-name "$USC_NAME" --secret-id "myapp/db-password"
akeyless usc get --usc-name "$USC_NAME" --secret-id "myapp/api-key"

# ─────────────────────────────────────────────────────────
# CHAPTER 4a: Two-way sync — Create in Akeyless, verify in Vault
# ─────────────────────────────────────────────────────────
echo "--- Chapter 4a: Create via Akeyless USC → verify in Vault ---"
akeyless usc create \
  --usc-name "$USC_NAME" \
  --secret-name "myapp/created-from-akeyless" \
  --value "value=hello-from-akeyless"

# Verify it now exists natively in Vault
vault kv get secret/myapp/created-from-akeyless

# ─────────────────────────────────────────────────────────
# CHAPTER 4b: Two-way sync — Create in Vault, verify in Akeyless
# ─────────────────────────────────────────────────────────
echo "--- Chapter 4b: Create in Vault → verify via Akeyless USC ---"
vault kv put secret/myapp/created-from-vault value="hello-from-vault"

# Verify Akeyless can see it immediately via USC
akeyless usc list --usc-name "$USC_NAME"
akeyless usc get --usc-name "$USC_NAME" --secret-id "myapp/created-from-vault"

# ─────────────────────────────────────────────────────────
# CHAPTER 5: HVP — use vault CLI against Akeyless backend
# ─────────────────────────────────────────────────────────
echo "--- Chapter 5: HVP vault CLI compatibility ---"
# Save original VAULT_ADDR
ORIGINAL_VAULT_ADDR="$VAULT_ADDR"

export VAULT_ADDR='https://hvp.akeyless.io'
# ~/.vault-token must contain: <Access Id>..<Access Key>
# (set this manually before the demo or show the file contents)

vault kv get secret/myapp/db-password
vault kv get secret/myapp/api-key

# Restore original
export VAULT_ADDR="$ORIGINAL_VAULT_ADDR"

# ─────────────────────────────────────────────────────────
# CHAPTER 6: RBAC — demonstrate a denied read
# ─────────────────────────────────────────────────────────
echo "--- Chapter 6: RBAC deny in action ---"
# Authenticate as the denied auth method to get a token
# (show the denied-auth Access ID and Key from akeyless-setup.sh output)
# akeyless auth --access-id <denied-access-id> --access-key <denied-access-key>
# Then attempt:
# akeyless usc get --usc-name "$USC_NAME" --secret-id "myapp/db-password"
# Expected: Permission denied error

# ─────────────────────────────────────────────────────────
# CHAPTER 7: Audit trail — show in Akeyless console
# Open https://console.akeyless.io → Logs → filter by USC actions
# All operations from chapters 3, 4a, 4b, 5 are visible here
# ─────────────────────────────────────────────────────────
echo "--- Chapter 7: Open Akeyless Console → Logs ---"
echo "    URL: https://console.akeyless.io"
echo "    Filter: action=get, action=list, action=create"
```

**Step 2: Make executable**

```bash
chmod +x demo/demo-commands.sh
```

---

### Task 5: Demo — README

**Files:**
- Create: `demo/README.md`

**Context:**
Self-contained guide. Someone who has never watched the video should be able to run the full demo from this file alone. Covers prerequisites, environment setup, and each chapter in prose + command form.

**Step 1: Write the README**

Content sections:
1. Overview (what this demo proves)
2. Prerequisites (vault CLI, akeyless CLI, kubectl, helm, Akeyless account)
3. Environment variables reference table
4. Step-by-step: start Vault dev mode
5. Step-by-step: deploy Gateway on K8s (helm command + values file reference)
6. Step-by-step: run akeyless-setup.sh
7. Demo walkthrough (chapter by chapter, matches video)
8. Cleanup

Include all commands inline. Reference `demo-commands.sh` for copy-paste convenience.

---

### Task 6: Video script

**Files:**
- Create: `video-script.md`

**Context:**
Pure screencast delivery — no talking head. The script has two parts:
1. **Slides section** (~3 min): narrator reads the slide content, slides are simple text/diagram slides
2. **Demo section** (~9 min): narrator walks through demo-commands.sh chapter by chapter

Format: Each slide or chapter gets a labeled block with `[SLIDE N]` or `[CHAPTER N]`, a **Narration:** block (what the presenter says), and an **On screen:** block (what is shown). Slide content is written out in full. Demo narration cues are written out with the exact commands shown.

Slides:
- Slide 1: Title — "HashiCorp Vault + Akeyless: Governance Without Rip-and-Replace"
- Slide 2: The problem — Vault is everywhere, governance is fragmented, migration feels risky
- Slide 3: The two models — USC (govern in-place) vs HVP (CLI compatibility layer) — side by side
- Slide 4: Architecture — control plane diagram (Akeyless SaaS → Gateway → Vault; HVP path)
- Slide 5: Demo agenda — list the 7 chapters
- Closing slide: Recap + links

---

### Task 7: Blog post

**Files:**
- Create: `blog-post.md`

**Context:**
~2,000–2,500 words. Executive + technical hybrid. Opens with the business problem for architects, transitions to technical proof for engineers. Embeds the video at the top. Near the end, "What We Did in the Demo" section explains what was shown in the video in narrative prose.

**Structure to implement:**

```markdown
# HashiCorp Vault + Akeyless: Governance Without Rip-and-Replace

## Video
<!-- embed video here -->

[Intro — 200w: the rip-and-replace dilemma]

## The Reality of Enterprise Secret Management
[~300w: Vault is deeply embedded, teams adopt at different speeds,
 governance gaps emerge — no central audit, siloed RBAC, no cross-team
 visibility]

## A Better Path: Govern Without Migrating
[~300w: Akeyless as a control plane over Vault, not a replacement.
 The coexistence story — Akeyless-native teams + Vault-native teams,
 unified governance layer over both]

## Two Integration Models
[~350w: USC — govern secrets that live in Vault via Akeyless control
 plane. HVP — vault CLI and API compatibility, zero client-side changes.
 When to use each.]

## Architecture at a Glance
[~200w: text-based ASCII diagram showing:
  vault CLI → hvp.akeyless.io → Akeyless control plane
  akeyless CLI → USC → Gateway → Vault Target → Vault KV]

## Two-Way Secret Sync
[~300w: why this matters for mixed adoption — teams on Akeyless can
 create secrets that Vault teams consume natively, and vice versa.
 No migration required, no disruption.]

## Getting Started
[~150w: prereqs, pointer to demo/ folder and video above]

## What We Did in the Demo
[~300w: narrative walkthrough of all 7 chapters — what was shown,
 what it proves about governance]

## Next Steps
[~100w: CTA — free tier link, docs.akeyless.io, Vault USC docs,
 HVP docs]
```

**Writing guidance:**
- Intro hook: open with the scenario of a CISO being told "we need to migrate off Vault" and the real cost of that conversation
- Use concrete numbers where possible (Vault token with 5 capabilities, 8 SIEM destinations, 20+ dynamic secret producers via HVP)
- "What We Did in the Demo" should read as a story, not a command list — past tense narrative
- Avoid marketing language; favor technical precision

---

### Task 8: Update root README

**Files:**
- Modify: `README.md`

**Step 1: Replace the placeholder README**

```markdown
# HashiCorp Vault + Akeyless: Governance Without Rip-and-Replace

Demo, blog post, and video script showing how Akeyless governs existing
HashiCorp Vault deployments through the Universal Secret Connector (USC)
and HashiCorp Vault Proxy (HVP) — without migrating secrets.

## Contents

| File | Description |
|------|-------------|
| `blog-post.md` | Full blog post (~2,000 words), executive + technical hybrid |
| `video-script.md` | Video script with slide narration and demo chapter cues |
| `demo/README.md` | Self-contained demo walkthrough |
| `demo/setup-vault-dev.sh` | Start Vault in dev mode + seed secrets |
| `demo/gateway-values.yaml` | Helm values for Akeyless Gateway on K8s |
| `demo/akeyless-setup.sh` | Create Vault Target, USC, RBAC in Akeyless |
| `demo/demo-commands.sh` | Live demo commands (chapter by chapter) |

## Quick Start

See `demo/README.md` for full prerequisites and setup instructions.

```bash
# 1. Start Vault dev mode
./demo/setup-vault-dev.sh

# 2. Deploy Akeyless Gateway on K8s (edit gateway-values.yaml first)
helm upgrade --install akeyless-gateway akeyless/akeyless-api-gateway \
  -n akeyless --create-namespace -f demo/gateway-values.yaml

# 3. Configure Akeyless resources
export AKEYLESS_GATEWAY_URL='https://<your-gateway-ip>:8000'
./demo/akeyless-setup.sh

# 4. Run the demo
source demo/demo-commands.sh
```

## Key Concepts Demonstrated

- **USC (Universal Secret Connector):** Manage secrets that physically live in Vault via the Akeyless control plane
- **Two-way sync:** Create secrets from either side; both see them immediately
- **HVP (HashiCorp Vault Proxy):** Use the `vault` CLI unchanged, backed by Akeyless
- **RBAC:** Akeyless path-based roles govern access across both USC and HVP
- **Audit trail:** Every operation logged centrally, regardless of which tool was used
```

---

## Execution Order

1. Task 1 — `demo/setup-vault-dev.sh`
2. Task 2 — `demo/gateway-values.yaml`
3. Task 3 — `demo/akeyless-setup.sh`
4. Task 4 — `demo/demo-commands.sh`
5. Task 5 — `demo/README.md`
6. Task 6 — `video-script.md`
7. Task 7 — `blog-post.md`
8. Task 8 — `README.md`
