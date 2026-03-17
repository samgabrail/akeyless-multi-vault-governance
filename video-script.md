# Akeyless Multi Vault Governance: Centralized Governance Across HashiCorp Vault and Cloud Secrets Managers

**Total Runtime:** ~30 minutes (15 min slides + 15 min live demo)
**Format:** Webinar — slide deck followed by live UI demo
**Video Type:** Live webinar, also published to YouTube
**Audience:** Platform engineers / DevOps

---

## Table of Contents

### Slides (~15 min)
1. [SLIDE 1] Title (~0:20)
2. [SLIDE 2] The Problem (~1:30)
3. [SLIDE 3] The Akeyless Approach (~1:30)
4. [SLIDE 4] Architecture (~1:30)
5. [SLIDE 5] Multi-Cluster Governance (~1:30)
6. [SLIDE 6] Rotation + Sync (~1:30)
7. [SLIDE 7] HashiCorp Vault Proxy (~1:00)
8. [SLIDE 8] RBAC + Audit (~1:00)
9. [SLIDE 9] Demo Agenda (~0:30)

### Live Demo (~15 min)
10. [ACT 1] Multi-Cluster Governance (~4:00)
11. [ACT 2] Rotation + Sync (~6:00)
12. [ACT 3] HVP — Zero Disruption (~2:00)
13. [ACT 4] RBAC Governance (~2:00)
14. [ACT 5] Audit Trail (~1:00)

### Close
15. [CLOSING SLIDE] Wrap Up (~0:30)

---

## [SLIDE 1]: Title

**Duration:** ~0:20

**On screen:**

> **Akeyless Multi Vault Governance**
>
> Governance Over Multiple Vault Clusters and Any Cloud Secrets Manager — Without Rip-and-Replace
>
> [Akeyless logo]

**Narration:**

In this session we're going to look at a problem that comes up constantly in security-conscious organizations: you've got HashiCorp Vault — possibly multiple isolated clusters — plus cloud secrets managers, and you need central governance without ripping any of it out. I'm going to show you exactly how Akeyless Multi Vault Governance solves that, live, in the UI.

---

## [SLIDE 2]: The Problem

**Duration:** ~1:30

**On screen:**

> **The Governance Gap**
>
> - Multiple isolated Vault clusters — different teams, different networks
> - Secrets siloed across Vaults and cloud secrets managers
> - No central audit: CISO can't answer "who accessed what, when, from where?"
> - No central access control: every backend has its own policies
> - No consistent rotation: custom scripts per vault type, each with its own schedule
> - Ripping it out is too expensive, too risky, too disruptive

**Narration:**

Here's the situation most enterprises are actually in. HashiCorp Vault is deeply embedded — and often not just one cluster. You might have a backend team Vault and a payments team Vault running in isolated networks. AWS Secrets Manager in one environment. Azure Key Vault used by platform teams in another. Developers have muscle memory around all of it. Runbooks reference it. SRE teams have built tooling on top of it.

The problem is at the governance layer. If a CISO asks "who accessed the production payments credentials in the last 30 days," the answer involves logging into multiple Vault instances, cloud consoles, and hoping nothing fell through the cracks. Access policies are managed per backend — there's no consistent enforcement model. And rotation, if you're doing it at all, means a custom script per vault type, each with its own error handling and schedule.

The obvious answer — migrate everything to a new platform — sounds great until you price it out. The migration risk alone is enough to kill the project. So the governance gap stays open.

---

## [SLIDE 3]: The Akeyless Approach

**Duration:** ~1:30

**On screen:**

> **Two Integration Models for MVG**
>
> | Universal Secret Connector (USC) | HashiCorp Vault Proxy (HVP) |
> |---|---|
> | Govern Vault, cloud secrets in place | `vault` CLI works unchanged |
> | Akeyless control plane wraps existing backends | Just change `VAULT_ADDR` |
> | Akeyless RBAC + audit on every operation | Full audit trail automatically |
> | Automated rotation writes back to each external vault | — |

**Narration:**

Akeyless Multi Vault Governance gives you two complementary entry points.

The first is the Universal Secret Connector — USC. This is how you govern secrets that physically live in Vault, AWS Secrets Manager, or Azure Key Vault. You connect each backend to the Akeyless control plane, and from that point forward Akeyless manages policy, audit, visibility, and automated rotation across all of them.

The second is the HashiCorp Vault Proxy, or HVP. This is for teams where changing Vault tooling simply isn't going to happen. They use the `vault` CLI today. They're not switching. With HVP, they don't need to — they point `VAULT_ADDR` at an Akeyless endpoint and everything works exactly as before.

These two approaches are complementary. USC gives you governance across existing secret stores. HVP preserves native Vault workflows where the Vault API has to stay exactly as it is. You can use both.

---

## [SLIDE 4]: Architecture

**Duration:** ~1:30

**On screen:**

```
vault CLI  ──────────────────────────────────────────────────────────┐
                                                                      ▼
                              https://hvp.akeyless.io ─→ Akeyless Control Plane
                                                                      │
Akeyless UI / CLI ──→ USC / MVG ──→ Akeyless Gateway ─┬─→ Vault Target ─→ Vault KV (cluster 1)
                                                        ├─→ Vault Target ─→ Vault KV (cluster 2)
                                                        ├─→ Azure Target ─→ Azure Key Vault
                                                        └─→ DB Target   ─→ MySQL
                                                                      │
                                Both paths ──→ Akeyless RBAC + Audit Log
                                Rotation   ──→ Gateway rotates credential → syncs to KV / Vault
```

**Narration:**

Here's the plumbing. Inside your infrastructure — in this demo it's a Kubernetes cluster — you run an Akeyless Gateway. That Gateway holds connections to the backends you want to govern: in today's demo, two Vault clusters, an Azure Key Vault, and a MySQL database for the rotation demos.

One topology note: this demo uses a single Gateway because everything is co-located. In production you'd typically deploy one Gateway per private location, close to each Vault cluster and its workloads.

For the Akeyless USC path, requests go from the Akeyless control plane down to the Gateway and into whichever backend holds the secret. For the vault CLI path, Akeyless exposes a public endpoint that speaks the native Vault HTTP API.

For rotation, the Gateway is the write path. When Akeyless triggers a rotation it generates a new credential at the source — calling Microsoft Graph for an Azure App Registration, or issuing an ALTER USER for MySQL — and then syncs the new value to every governed store associated with that secret. Every operation, regardless of path, produces an entry in the same Akeyless audit log.

---

## [SLIDE 5]: Multi-Cluster Governance + Bidirectional Sync

**Duration:** ~1:30

**On screen:**

> **One Control Plane, Multiple Isolated Clusters**
>
> - Connect any number of Vault clusters via Universal Secret Connectors
> - Browse, read, and write secrets across all connected backends — from one place
> - Bidirectional sync: create in Vault → visible in Akeyless; create in Akeyless → lands in Vault
> - Existing secrets governed from day one — no migration, no import
> - Works the same for AWS Secrets Manager, Azure Key Vault, and Kubernetes Secrets

**Narration:**

The core use case for MVG is multi-cluster governance. You have two teams. Two Vault clusters. No shared governance. You connect both to Akeyless via Universal Secret Connectors — the Gateway brokers the connection — and from that point on you have a single control plane over both.

This isn't a migration. The secrets stay in each Vault. Akeyless reads and writes directly through the Gateway. And it's bidirectional: if a secret is created in Vault, Akeyless sees it immediately. If a secret is created in Akeyless, it lands in Vault. No sync job. No polling delay.

The same USC model extends beyond Vault — AWS Secrets Manager, Azure Key Vault, Kubernetes Secrets. You're not locked to one cloud or one platform.

---

## [SLIDE 6]: Automated Rotation + Sync

**Duration:** ~1:30

**On screen:**

> **Rotation Without Custom Scripts**
>
> - Akeyless rotation engine supports: Azure App Registrations, AWS IAM, MySQL/Postgres, Vault AppRoles, and more
> - Rotation happens at the source — no manual credential distribution
> - Rotated values automatically sync to every governed store via USC
> - App reads from Vault (or Key Vault) as always — nothing changes for consumers
> - Every rotation event logged with timestamp, identity, and write-back confirmation

**Narration:**

Rotation is where the operational pain really shows up in organizations with multiple secret stores. Today you might have a Lambda function that rotates an Azure App Registration secret and a separate pipeline that rotates your database password and a cron job for your Vault AppRoles. Each with its own schedule, its own error handling, its own audit trail — or none at all.

Akeyless replaces all of that with one rotation engine. It calls the API at the source — Microsoft Graph, the database, whatever the target is — generates a new credential, and syncs the result to every governed store associated with that secret. The app reading from Vault or Key Vault gets the new value automatically. It doesn't need to be restarted. It doesn't know a rotation happened.

---

## [SLIDE 7]: HashiCorp Vault Proxy

**Duration:** ~1:00

**On screen:**

> **Zero Workflow Disruption**
>
> ```bash
> # Before Akeyless:
> export VAULT_ADDR='https://vault.internal:8200'
> vault kv get secret/myapp/db-password
>
> # After Akeyless HVP:
> export VAULT_ADDR='https://hvp.akeyless.io'
> vault kv get secret/myapp/db-password   # identical output
> ```
>
> - Same CLI, same scripts, same pipelines
> - Akeyless becomes the backend — fully transparent to consumers
> - Full RBAC and audit on every vault CLI call

**Narration:**

For teams where the vault CLI is embedded in pipelines, runbooks, and developer muscle memory, HVP is the zero-disruption path. Change one environment variable — `VAULT_ADDR` — and the same vault commands produce the same output. Akeyless is now the backend, every request is authenticated and audited, and the teams using it don't need to know Akeyless exists.

---

## [SLIDE 8]: RBAC + Audit

**Duration:** ~1:00

**On screen:**

> **One Policy, Every Backend**
>
> - Akeyless roles scoped to USC paths — deny in Akeyless, denied across Vault, AWS, and Azure
> - No changes to native Vault ACLs, AWS IAM, or Azure RBAC required
> - Every read, write, rotation, and denial logged in the same Akeyless audit trail
> - Filterable by identity, action, path, backend — forwardable to your SIEM

**Narration:**

The governance story closes here. Access control in Akeyless is defined once — a role, a set of paths, a capability — and that policy enforces across every connected backend simultaneously. To revoke a team's access to secrets across two Vault clusters and an Azure Key Vault, you make one change in Akeyless. No Vault policy updates. No Azure RBAC changes.

And every action — reads, writes, rotations, denials, across every backend — lands in a single Akeyless audit log. That's the answer to the CISO's question: who accessed what, when, from where, regardless of which vault it lived in.

---

## [SLIDE 9]: Demo Agenda

**Duration:** ~0:30

**On screen:**

> **What We're About to Show (15 min)**
>
> **Act 1** — Two isolated Vault clusters, one Akeyless control plane, bidirectional sync
>
> **Act 2** — Azure App Registration rotation → synced to Azure Key Vault; DB rotation → synced to HashiCorp Vault
>
> **Act 3** — Native `vault` CLI against Akeyless HVP — zero changes
>
> **Act 4** — RBAC: one denied role blocks access across both clusters
>
> **Act 5** — Audit trail: every rotation, access, and denial in one log

**Narration:**

Let's get into the live demo. Five acts, fifteen minutes. The whole demo runs in the Akeyless UI, the Vault UI, and the Azure portal — except for Act 3 where I'll use the vault CLI in the terminal to prove zero workflow disruption. Let's go.

---

> **Demo note:** All infrastructure is pre-configured by the e2e setup script before the session. Nothing is created from scratch during the demo. The only live creation is two secrets in Act 1 to demonstrate bidirectional sync.

---

## [ACT 1]: Multi-Cluster Governance

**Duration:** ~4:00
**Tools:** Akeyless UI + Vault UI

**On screen:**

Akeyless console:
- Targets page showing `demo-vault-target-backend` (port 8200) and `demo-vault-target-payments` (port 8202)
- Universal Secrets Connectors showing `MVG-demo/vault-usc-backend` and `MVG-demo/vault-usc-payments`
- Browsing existing secrets already synced under each USC

Vault UI (`http://localhost:8200/ui`):
- Creating `secret/myapp/created-from-vault`

Akeyless UI:
- Showing `created-from-vault` appearing under `MVG-demo/vault-usc-backend`

Akeyless UI:
- Creating `secret/myapp/created-from-akeyless` under `MVG-demo/vault-usc-backend`

Vault UI:
- Showing `created-from-akeyless` at `secret/myapp/created-from-akeyless`

**Narration:**

Let me open the Akeyless console. First, I'll show you the targets — two isolated HashiCorp Vault clusters. This one on port 8200 is the backend team's Vault. This one on port 8202 is the payments team's Vault. Completely separate clusters, different networks.

Now the Universal Secrets Connectors. These are the bridges Akeyless uses to govern what's in each cluster. You can see `vault-usc-backend` and `vault-usc-payments`. Browse the secrets — all of these came from the Vault clusters directly. Nothing was imported. Nothing was migrated. Akeyless reads them in place from the moment the connector is live.

Now I'll show you bidirectional sync. I'll switch to the Vault UI for the backend cluster and create a new secret here — `created-from-vault`. Back in the Akeyless UI, under `vault-usc-backend` — there it is, already synced.

Now the other direction. I'll create `created-from-akeyless` here in the Akeyless UI under the backend connector. Switch to the Vault UI — and there it is, landed in Vault.

One control plane. Two isolated clusters. Any secrets manager. Bidirectional, in real time.

---

## [ACT 2]: Rotation + Sync

**Duration:** ~6:00
**Tools:** Akeyless UI, Azure portal, Vault UI

**On screen:**

Akeyless UI → Rotated Secrets → `MVG-demo/azure-app-rotated-secret` → Rotate Now

Azure portal (pre-opened tab):
- `akl-mvg-demo-kv` → Secrets → `demo-app-client-secret` — showing updated value and new timestamp

Akeyless UI → Rotated Secrets → `MVG-demo/db-rotated-password` → Rotate Now

Vault UI (`http://localhost:8200/ui`):
- `secret/myapp/db-password` — showing updated value

**Narration:**

Now the rotation engine. Two examples.

First: Azure App Registration. In the Akeyless UI, I'll open `MVG-demo/azure-app-rotated-secret` and hit Rotate Now. Akeyless calls the Microsoft Graph API, creates a new client secret on the `demo-akeyless-mvg-target` app registration, then syncs the new value to Azure Key Vault automatically.

I'll switch to the Azure portal — Key Vault `akl-mvg-demo-kv`, Secrets, `demo-app-client-secret`. There's the updated value. The timestamp confirms it was just rotated. This is where the application reads from. The app reads from Key Vault — it never touches the rotation API, it never needs to be restarted. The new credential is simply there.

Second: database rotation. Back in the Akeyless UI — `MVG-demo/db-rotated-password`, Rotate Now. Akeyless issues an ALTER USER on the MySQL instance. The new password is the authoritative value in Akeyless.

Now I'll switch to the Vault UI — `secret/myapp/db-password`. The updated password is already there, synced via the USC. The application that reads its database credential from HashiCorp Vault gets the current password automatically. Nothing changed for the app.

Two completely different rotation backends — Azure App Registration via the Microsoft Graph API, MySQL via ALTER USER — same rotation engine, each result synced to its governed store, every event in the same audit trail.

---

## [ACT 3]: HVP — Zero Disruption

**Duration:** ~2:00
**Tools:** Terminal

**On screen:**

Terminal:

```bash
export VAULT_ADDR='https://hvp.akeyless.io'

vault kv get secret/myapp/db-password
vault kv get secret/myapp/api-key
```

Output identical to what would come from a native Vault instance.

**Narration:**

One environment variable. `VAULT_ADDR` now points at the Akeyless HashiCorp Vault Proxy.

The token in `~/.vault-token` is an Akeyless Access ID and Key — the vault CLI just treats it as a bearer token and doesn't inspect the format.

`vault kv get secret/myapp/db-password` — there's the password, same value. `vault kv get secret/myapp/api-key` — same key.

Same commands. Same output. Nothing in the script, the pipeline, or the runbook changed. Akeyless is the backend, every request is authenticated and authorized by Akeyless RBAC, and every request is in the Akeyless audit log. Teams using the vault CLI don't need to know Akeyless exists.

---

## [ACT 4]: RBAC Governance

**Duration:** ~2:00
**Tools:** Akeyless UI + Terminal

**On screen:**

Akeyless console:
- Access Roles → `demo-readonly-role` — showing scope covering both USCs
- Access Roles → `demo-denied-role` — showing deny capability

Terminal:

```bash
DENIED_TOKEN=$(akeyless auth \
  --access-id "$DENIED_ACCESS_ID" \
  --access-key "$DENIED_ACCESS_KEY" \
  --access-type access_key --json 2>/dev/null \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['token'])")

akeyless usc get \
  --usc-name "$USC_BACKEND" \
  --secret-id "secret/myapp/db-password" \
  --gateway-url "$AKEYLESS_GW" \
  --token "$DENIED_TOKEN"
# Output: permission denied
```

**Narration:**

The governance story closes with access control. In the Akeyless UI I'll show you two roles.

`demo-readonly-role` — read access scoped to both USC connectors. One role, both clusters.

`demo-denied-role` — explicitly blocked from both. I'll authenticate as this identity in the terminal and attempt to read a secret from the backend Vault cluster via the USC.

Denied. The request never reached Vault. Akeyless enforced the policy before the Gateway forwarded anything.

One deny in Akeyless, both clusters enforced simultaneously. No Vault ACL policy changes. No native Vault policy to maintain. When you need to revoke access across your entire secret estate, you make one change here.

---

## [ACT 5]: Audit Trail

**Duration:** ~1:00
**Tools:** Akeyless UI → Logs tab

**On screen:**

Akeyless console Logs tab, filtered to current session. Visible entries:
- Azure App Registration rotation event (Act 2) — timestamp, secret name, triggering identity
- DB rotation event (Act 2) — timestamp, secret name, write-back to Vault confirmed
- Denied access attempt from Act 4 — status: Denied

**Narration:**

Last stop — the audit trail. I'll filter the Logs tab to the start of this demo session.

Here are the rotation events: the Azure App Registration rotation with its timestamp, the identity that triggered it, and confirmation the new value synced to Key Vault. And the database rotation — same format, confirming the new password was written and synced to Vault.

And here's the denied access attempt from Act 4 — identity, path, status: Denied.

Every action across every governed backend, in one place. Forwardable to your SIEM, filterable by identity or action. This is what the CISO actually needs: a single answer to "who accessed what, when, from where" — regardless of whether the secret lived in HashiCorp Vault, Azure Key Vault, or anywhere else.

---

## [CLOSING SLIDE]: Wrap Up

**Duration:** ~0:30

**On screen:**

> **Governance Over Your Entire Secret Estate — Without Migration**
>
> - USC: centralized RBAC, audit, visibility, and rotation across Vault and cloud secrets managers
> - HVP: keeps the vault CLI exactly as it is — zero workflow disruption
> - Automated rotation across Azure App Registrations, databases, and any governed backend
> - Rotated values sync automatically to every governed store
> - No migration required — adopt by team, by cluster, by environment
>
> **Get started:**
> - Docs: docs.akeyless.io
> - Free tier: console.akeyless.io

**Narration:**

That's the full picture. Two isolated Vault clusters as the core story, extended to Azure Key Vault through the same Akeyless control plane — with automated rotation that covers cloud credentials and database passwords, writing results back to every governed store automatically.

USC and HVP are two different entry points: one for Akeyless-native governance across your existing backends, one for teams keeping the vault CLI exactly as it is. Rotation is a third dimension on top — the same Gateway that reads and writes your secrets also rotates them and syncs the results.

All of it — reads, writes, rotations, denials — produces entries in the same audit trail. That is the complete governance story.

Free tier at console.akeyless.io, full docs at docs.akeyless.io. Thanks for joining.
