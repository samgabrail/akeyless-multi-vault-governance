# Akeyless Multi Vault Governance

Demo, blog post, and video script for the webinar:

`Akeyless Multi Vault Governance: Centralized Governance Across HashiCorp Vault and Cloud Secrets Managers`

The repo is still Vault-led, but now extends the story with AWS Secrets Manager, Azure Key Vault, and automated secret rotation to show how MVG centralizes RBAC, audit, and visibility across mixed secret backends without migrating secrets.

## Contents

| File | Description |
|------|-------------|
| [`blog-post.md`](./blog-post.md) | Full blog post (~2,500 words), executive + technical hybrid |
| [`video-script.md`](./video-script.md) | Video script with slide narration and demo chapter cues (~12 min) |
| [`demo/README.md`](./demo/README.md) | Self-contained demo walkthrough |
| [`demo/setup-vault-dev.sh`](./demo/setup-vault-dev.sh) | Start Vault in dev mode and seed sample secrets |
| [`demo/gateway-values.yaml`](./demo/gateway-values.yaml) | Helm values for Akeyless Gateway on Kubernetes |
| [`demo/akeyless-setup.sh`](./demo/akeyless-setup.sh) | Create Vault, AWS, and Azure targets, USCs, and RBAC roles in Akeyless; configure Azure App Registration and MySQL rotated secrets and DB rotation |
| [`demo/setup-cloud-and-k8s-demo.sh`](./demo/setup-cloud-and-k8s-demo.sh) | Seed AWS Secrets Manager and Azure Key Vault demo resources; configure Azure App Registration permissions |
| [`demo/demo-mysql.yaml`](./demo/demo-mysql.yaml) | MySQL 8.0 deployment for the database rotation demo (runs in akeyless namespace) |
| [`demo/test-e2e.sh`](./demo/test-e2e.sh) | Repeatable end-to-end validation harness for the full demo |
| [`demo/demo-commands.sh`](./demo/demo-commands.sh) | Live demo commands organized by chapter |
| [`IMPLEMENTATION_TRACKER.md`](./IMPLEMENTATION_TRACKER.md) | Progress tracker for the webinar/blog expansion |

## Quick Start

See [`demo/README.md`](./demo/README.md) for full prerequisites and setup instructions.

```bash
# 1. Start Vault dev mode (seeds two sample secrets)
./demo/setup-vault-dev.sh

# 2. Seed AWS and Azure demo resources
./demo/setup-cloud-and-k8s-demo.sh

# 3. Deploy Akeyless Gateway on Kubernetes (edit gateway-values.yaml first)
helm upgrade --install akeyless-gateway akeyless/akeyless-api-gateway \
  -n akeyless --create-namespace \
  -f demo/gateway-values.yaml

# 4. Configure Akeyless resources (Targets, USC, RBAC, rotation)
export AKEYLESS_GATEWAY_URL='https://<your-gateway-ip>:8000'
./demo/akeyless-setup.sh

# 5. Run the demo chapter by chapter
source demo/demo-commands.sh

# Or run the repeatable validation harness
bash demo/test-e2e.sh
```

## Demo Topology vs Production

- **Demo topology:** Two isolated Vault instances, one AWS Secrets Manager account, and one Azure Key Vault share one Akeyless governance layer for simplicity.
- **Typical production Vault topology:** One Vault cluster per geographic location, deployed close to application workloads to reduce latency.
- **Vault Enterprise pattern:** Teams often use Disaster Recovery replication or Performance Replication between regions.
- **Common real-world pattern:** Many organizations run isolated Vault clusters with no replication due to ownership, cost, or operational boundaries.
- **Why Akeyless matters here:** MVG gives one RBAC and audit layer across isolated Vault clusters and extends the same governance model to cloud secrets managers and Azure Key Vault.
- **Typical production Gateway topology:** One Akeyless Gateway per private location/region (for example, us-east Vault + us-east Gateway, us-central Vault + us-central Gateway).

## Key Concepts Demonstrated

- **MVG (current product surface: USC):** Manage secrets that physically live in Vault, AWS Secrets Manager, or Azure Key Vault via the Akeyless control plane — list, read, create, update, delete — all governed by Akeyless RBAC
- **Two-way sync:** Create a secret from Akeyless via USC and it appears natively in Vault; create one in Vault and it's immediately visible through Akeyless — no sync job, no polling
- **HVP (HashiCorp Vault Proxy):** Use the `vault` CLI unchanged with `VAULT_ADDR=https://hvp.akeyless.io` — Akeyless becomes the backend with zero code changes
- **RBAC:** Path-based Akeyless roles govern access across Vault, AWS, Azure, and HVP paths centrally
- **Audit trail:** Every operation — Vault MVG reads/writes, AWS and Azure reads, HVP calls, denied requests — logged in one place in the Akeyless console
- **Azure Key Vault governance:** The same USC pattern that governs Vault KV and AWS Secrets Manager also governs Azure Key Vault secrets — list, read, governed by Akeyless RBAC
- **Automated secret rotation:** Akeyless rotates Azure App Registration client secrets and MySQL database passwords on a schedule, then syncs the new values back to governed secret stores (Azure Key Vault, HashiCorp Vault) via USC — no rotation scripts, no per-vault cron jobs

## Prerequisites

- [`vault`](https://developer.hashicorp.com/vault/downloads) CLI
- [`akeyless`](https://docs.akeyless.io/docs/cli) CLI (authenticated)
- `aws` CLI
- `az` CLI (for Azure rotation demo)
- `kubectl` + `helm`
- Akeyless account — [console.akeyless.io](https://console.akeyless.io)

## Related Resources

- [Akeyless Docs](https://docs.akeyless.io/docs/what-is-akeyless)
- [HashiCorp Vault USC](https://docs.akeyless.io/docs/hc-vault-universal-secrets-connector)
- [HashiCorp Vault Proxy (HVP)](https://docs.akeyless.io/docs/hashicorp-vault-proxy)
