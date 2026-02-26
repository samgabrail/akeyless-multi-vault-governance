# HashiCorp Vault + Akeyless: Governance Without Rip-and-Replace

Demo, blog post, and video script showing how Akeyless governs existing HashiCorp Vault deployments through the Universal Secret Connector (USC) and HashiCorp Vault Proxy (HVP) — without migrating secrets.

## Contents

| File | Description |
|------|-------------|
| [`blog-post.md`](./blog-post.md) | Full blog post (~2,500 words), executive + technical hybrid |
| [`video-script.md`](./video-script.md) | Video script with slide narration and demo chapter cues (~12 min) |
| [`demo/README.md`](./demo/README.md) | Self-contained demo walkthrough |
| [`demo/setup-vault-dev.sh`](./demo/setup-vault-dev.sh) | Start Vault in dev mode and seed sample secrets |
| [`demo/gateway-values.yaml`](./demo/gateway-values.yaml) | Helm values for Akeyless Gateway on Kubernetes |
| [`demo/akeyless-setup.sh`](./demo/akeyless-setup.sh) | Create Vault Target, USC, and RBAC roles in Akeyless |
| [`demo/demo-commands.sh`](./demo/demo-commands.sh) | Live demo commands organized by chapter |

## Quick Start

See [`demo/README.md`](./demo/README.md) for full prerequisites and setup instructions.

```bash
# 1. Start Vault dev mode (seeds two sample secrets)
./demo/setup-vault-dev.sh

# 2. Deploy Akeyless Gateway on Kubernetes (edit gateway-values.yaml first)
helm upgrade --install akeyless-gateway akeyless/akeyless-api-gateway \
  -n akeyless --create-namespace \
  -f demo/gateway-values.yaml

# 3. Configure Akeyless resources (Target, USC, RBAC)
export AKEYLESS_GATEWAY_URL='https://<your-gateway-ip>:8000'
./demo/akeyless-setup.sh

# 4. Run the demo chapter by chapter
source demo/demo-commands.sh
```

## Key Concepts Demonstrated

- **USC (Universal Secret Connector):** Manage secrets that physically live in Vault via the Akeyless control plane — list, read, create, update, delete — all governed by Akeyless RBAC
- **Two-way sync:** Create a secret from Akeyless via USC and it appears natively in Vault; create one in Vault and it's immediately visible through Akeyless — no sync job, no polling
- **HVP (HashiCorp Vault Proxy):** Use the `vault` CLI unchanged with `VAULT_ADDR=https://hvp.akeyless.io` — Akeyless becomes the backend with zero code changes
- **RBAC:** Path-based Akeyless roles govern access across both USC and HVP paths centrally
- **Audit trail:** Every operation — USC reads/writes, HVP calls, denied requests — logged in one place in the Akeyless console

## Prerequisites

- [`vault`](https://developer.hashicorp.com/vault/downloads) CLI
- [`akeyless`](https://docs.akeyless.io/docs/cli) CLI (authenticated)
- `kubectl` + `helm`
- Akeyless account — [console.akeyless.io](https://console.akeyless.io)

## Related Resources

- [Akeyless Docs](https://docs.akeyless.io/docs/what-is-akeyless)
- [HashiCorp Vault USC](https://docs.akeyless.io/docs/hashicorp-vault-usc)
- [HashiCorp Vault Proxy (HVP)](https://docs.akeyless.io/docs/hashicorp-vault-proxy)
