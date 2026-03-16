---
name: Azure Demo Resources
description: Azure Key Vault and service principal credentials created for the MVG demo
type: project
---

Azure Key Vault and service principal were created during E2E demo run on 2026-03-13.

- Subscription: **Azure subscription 1** (`ef5fc751-43ae-4d4c-92c8-e0e86c47af79`)
- Resource group: `rg-mvg-demo` (eastus)
- Key Vault: `akl-mvg-demo-kv` (name `mvg-demo-kv` was taken globally — soft-deleted by someone else)
- Service principal: `sp-akeyless-mvg-demo`
  - App ID (CLIENT_ID): `17eef820-4ed5-486d-a2e2-35af42c4db76`
  - Tenant ID: `86237e9c-1249-4619-8397-6560bd47d2a6`
  - Role: Key Vault Secrets Officer on the vault scope
  - Credentials stored in `demo/.akeyless-demo.env`

**Why:** The default vault name `mvg-demo-kv` was globally reserved by another tenant, so `akl-mvg-demo-kv` is the actual vault name used in this demo.

**How to apply:** When running `test-e2e.sh`, either `source demo/.akeyless-demo.env` first (which now includes Azure SP creds) or pass `AZURE_VAULT_NAME`, `AZURE_TENANT_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET` explicitly. The env file is the canonical source.
