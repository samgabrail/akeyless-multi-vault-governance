# HashiCorp Vault + Akeyless: Governance Without Rip-and-Replace

**Total Runtime:** ~12 minutes
**Format:** Screencast with slide intro
**Video Type:** Technical demo — no camera, narrator voiceover

---

## Table of Contents

1. [SLIDE 1] Title (~0:20)
2. [SLIDE 2] The Problem (~0:45)
3. [SLIDE 3] The Akeyless Approach (~0:45)
4. [SLIDE 4] Architecture (~0:45)
5. [SLIDE 5] Demo Agenda (~0:20)
6. [CHAPTER 1] Verify Vault Dev Secrets (~1:00)
7. [CHAPTER 2] Gateway on Kubernetes (~0:45)
8. [CHAPTER 3] Discover Secrets via USC (~0:45)
9. [CHAPTER 4] Read Secrets via USC (~1:00)
10. [CHAPTER 5] Bi-Directional Secret Sync (~2:15)
11. [CHAPTER 6] HashiCorp Vault Proxy (~1:30)
12. [CHAPTER 7] RBAC — Access Denied (~1:15)
13. [CHAPTER 8] Audit Trail (~1:00)
14. [CLOSING SLIDE] Wrap Up (~0:30)

---

## [SLIDE 1]: Title

**Duration:** ~0:20

**On screen:**

> **HashiCorp Vault + Akeyless: Governance Without Rip-and-Replace**
>
> [Akeyless logo]

**Narration:**

Hey, welcome. In the next twelve minutes or so we're going to look at a real problem that comes up constantly in security-conscious organizations: you've got HashiCorp Vault deployed, teams depend on it, and you need central governance — but you don't have the appetite or the budget to rip it all out and start over. I'm going to show you exactly how Akeyless solves that.

---

## [SLIDE 2]: The Problem

**Duration:** ~0:45

**On screen:**

> **The Governance Gap**
>
> - Vault is deeply embedded — teams built workflows around it
> - Secrets are siloed: each Vault instance is its own island
> - No central audit: CISO can't answer "who accessed what, when, from where?"
> - No central access control: every Vault has its own policies
> - Ripping it out is too expensive, too risky, too disruptive

**Narration:**

Here's the situation that most enterprises are actually in. Vault is everywhere. It's in your CI/CD pipelines, your Kubernetes clusters, your application configs. Developers have muscle memory around it. Runbooks reference it. SRE teams have built tooling on top of it. And it works — for what it does.

The problem is at the governance layer. If I'm a CISO and I ask "who accessed the database password for the production payments service in the last 30 days," the answer involves logging into multiple Vault instances, grepping through different audit logs, and hoping nothing fell through the cracks. Access policies are managed per-Vault, so there's no consistent enforcement model across teams. Every Vault cluster is essentially its own little kingdom.

The obvious answer — migrate everything to a new secrets platform — sounds great until you price it out. The migration risk alone is enough to kill the project. So the governance gap stays open.

---

## [SLIDE 3]: The Akeyless Approach

**Duration:** ~0:45

**On screen:**

> **Two Ways to Govern Vault — Without Replacing It**
>
> | Universal Secret Connector (USC) | HashiCorp Vault Proxy (HVP) |
> |---|---|
> | Govern secrets that live in Vault | `vault` CLI works unchanged |
> | Akeyless control plane wraps Vault | Just change `VAULT_ADDR` |
> | Teams use Akeyless CLI or Console | Akeyless becomes the backend |
> | Akeyless RBAC + audit on every operation | Full audit trail automatically |

**Narration:**

Akeyless gives you two complementary ways to get there.

The first is the Universal Secret Connector — USC for short. This is how you manage secrets that physically live in your Vault instance, but govern them from the Akeyless control plane. You're applying Akeyless RBAC to those secrets, every read and write is logged in the Akeyless audit trail, and teams using the Akeyless CLI or console never need to know the underlying secret is stored in Vault.

The second is the HashiCorp Vault Proxy, or HVP. This is for the teams where changing tooling just isn't going to happen. They use the `vault` CLI today. They're not switching. With HVP, they don't have to — they point `VAULT_ADDR` at an Akeyless endpoint and everything works exactly as before. Same commands, same output, but now every request flows through the Akeyless control plane and gets logged.

These two approaches are complementary. You can use both at the same time.

---

## [SLIDE 4]: Architecture

**Duration:** ~0:45

**On screen:**

```
vault CLI  ──────────────────────────────────────────────────────────┐
                                                                      ▼
                              https://hvp.akeyless.io ─→ Akeyless Control Plane
                                                                      │
akeyless CLI ──→ USC ──→ Akeyless Gateway ──→ Vault Target ──→ HashiCorp Vault KV
                                                                      │
                              Both paths ──→ Akeyless RBAC + Audit Log
```

**Narration:**

Here’s what the plumbing looks like. In your environment — in this demo it's a Kubernetes cluster — you're running an Akeyless Gateway. That Gateway holds a connection to your Vault instance through what Akeyless calls a Vault Target. The Universal Secret Connector sits on top of that target, so when you do a USC read through the Akeyless CLI, the request goes: Akeyless control plane, down to the Gateway, through the Vault Target, and into Vault itself. All governed, all logged.

One topology clarification: this demo uses a single Gateway for both Vault clusters because everything is in one private network. In production, you typically deploy one Gateway per private location or region, close to each local Vault cluster.

For the vault CLI path, Akeyless exposes a public endpoint that speaks the native Vault HTTP API. Your vault client doesn't know the difference. The request hits Akeyless, gets authenticated and authorized against Akeyless policies, and Akeyless serves the secret from its own KV store — or from one of its 20+ dynamic secret producers for dynamic credentials. The vault CLI sees a Vault response; Akeyless is the backend.

In both cases, every operation hits the same Akeyless control plane and produces the same audit log entry. That's the key point.

---

## [SLIDE 5]: Demo Agenda

**Duration:** ~0:20

**On screen:**

> **What We're About to Do**
>
> 1. Show two isolated Vault instances — no shared governance
> 2. Confirm the demo Gateway bridges both (production usually uses one per location)
> 3. Discover secrets across both Vault instances
> 4. Read secrets from both Vaults via Akeyless USC
> 5. Create secrets via Akeyless or Vault and keep them synchronized
> 6. Use the `vault` CLI unchanged via HashiCorp Vault Proxy
> 7. One RBAC policy denies access across both Vault clusters
> 8. One audit trail covers both Vault clusters

**Narration:**

Here's what we're going to cover. Eight chapters, about ten minutes of live demo. Two separate Vault clusters, one governance layer. Let's get into it.

---

> **Note:** The demo below uses the CLI for precision. In practice, the UI often demos better for live audiences — consider switching to the Akeyless Console for Chapter 3, 4, 6, and 7 if recording for a general audience.
>
> **Topology note:** This demo intentionally uses one Gateway for two Vault dev clusters in one private network. Production deployments usually place Vault clusters per region close to workloads and deploy one Akeyless Gateway per private location/region.

## [CHAPTER 1]: Two Vault Instances — No Shared Governance

**Duration:** ~1:15

**On screen:**

Terminal showing:

```bash
# Backend team's Vault (port 8200)
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

vault kv list secret/myapp
vault kv get secret/myapp/db-password
vault kv get secret/myapp/api-key

# Payments team's Vault (port 8202) — completely separate cluster
export VAULT_ADDR='http://127.0.0.1:8202'

vault kv list secret/payments
vault kv get secret/payments/stripe-key
vault kv get secret/payments/db-url
```

Two separate clusters, each with their own secrets.

**Narration:**

Let's start from the beginning — no Akeyless in the picture yet. We have two completely independent Vault instances running locally.

This first one on port 8200 is the backend team's Vault. I'll list what's under `secret/myapp` — there's `db-password` and `api-key`. Standard KV secrets, standard Vault.

Now let me switch to port 8202. This is the payments team's Vault — a completely separate cluster. Different secrets, different KV structure: `stripe-key` and `db-url` under `secret/payments`.

These two clusters have nothing in common. No shared policies. No shared audit log. If a CISO asks "who accessed the payments Stripe key in the last 30 days," the answer comes from this cluster's logs only — and only if Vault Enterprise is configured to ship them somewhere. The backend team's activity is completely invisible from here, and vice versa. This is the governance gap we're going to close.

And in production, this pattern is usually regional. Teams keep Vault close to applications for latency. Vault Enterprise teams may use DR or Performance Replication between regions, but many organizations still run isolated clusters with no replication — which is exactly where Akeyless multi-vault governance helps.

---

## [CHAPTER 2]: Gateway on Kubernetes

**Duration:** ~0:45

**On screen:**

Terminal showing:

```bash
kubectl get pods -n akeyless

# Output shows akeyless-gateway pod(s) running
```

**Narration:**

Now let's look at what's running on the Kubernetes side. I'll query the `akeyless` namespace.

You can see the Akeyless Gateway pod is running. This is the component that lives inside your infrastructure — it's the bridge between the Akeyless control plane in the cloud and your internal resources. In a real deployment this would be sitting inside your private network, with network access to your Vault instance but no inbound internet exposure required.

The Gateway has been pre-configured with two Vault Targets — one pointing at the backend Vault on port 8200, one pointing at the payments Vault on port 8202 — and a Universal Secret Connector on top of each. One Gateway, two clusters for demo simplicity. In production you'd normally have one Gateway in each private location where Vault runs. That's the setup that lets the next steps work. Let's go use it.

---

## [CHAPTER 3]: Discover Secrets Across Both Vaults

**Duration:** ~0:45

**On screen:**

Terminal showing:

```bash
# Backend team's Vault via USC
akeyless usc list --usc-name demo-vault-usc-backend

# Payments team's Vault via USC
akeyless usc list --usc-name demo-vault-usc-payments
```

Output showing both secret inventories.

**Narration:**

This is the key moment. I'm now using the Akeyless CLI, and I'm going to discover what already exists in both Vault clusters from the same session.

`akeyless usc list` on `demo-vault-usc-backend` — there are the backend team's secrets. Same paths we saw directly in Vault.

Now — same CLI, same session — let me switch to the payments connector. `akeyless usc list` on `demo-vault-usc-payments` — payments secrets.

Two separate Vault clusters. One Akeyless CLI session. Same RBAC policies govern both. Same audit trail captures both. And I didn't migrate or sync anything first. Akeyless can discover what's already in each Vault the moment the connectors are in place.

---

## [CHAPTER 4]: Read Secrets via USC

**Duration:** ~1:00

**On screen:**

Terminal showing:

```bash
# Backend team's Vault via USC
akeyless usc get \
  --usc-name demo-vault-usc-backend \
  --secret-id myapp/db-password

# Payments team's Vault via USC
akeyless usc get \
  --usc-name demo-vault-usc-payments \
  --secret-id payments/stripe-key
```

Output showing the same secret values we saw in each Vault directly.

**Narration:**

Now let me read a secret from each cluster through the Akeyless control plane.

`akeyless usc get` on the backend connector for `myapp/db-password` — same password, physically stored in backend Vault, read through Akeyless.

Now the payments connector. `akeyless usc get` for `payments/stripe-key` — same result. Different Vault cluster, same control plane, same policy model.

Neither secret left its respective Vault. Akeyless reads directly from each one in place. You don't move anything; you just add governance.

---

## [CHAPTER 5a]: Akeyless USC Create → Vault Verify (Backend)

**Duration:** ~1:15

**On screen:**

Terminal showing:

```bash
# Create via Akeyless USC for backend Vault
akeyless usc create \
  --usc-name demo-vault-usc-backend \
  --secret-name myapp/created-from-akeyless \
  --value "value=hello-from-akeyless"

# Switch to backend Vault CLI and verify
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

vault kv get secret/myapp/created-from-akeyless
```

Output showing the secret is present in backend Vault.

**Narration:**

Now let's go the other direction — create a secret through Akeyless and verify it lands physically in Vault.

`akeyless usc create` on the backend connector. The command completes.

Now I'll switch back to the vault CLI pointed at port 8200 — the backend team's Vault. `vault kv get secret/myapp/created-from-akeyless`.

There it is. Written through the Akeyless control plane, physically landed in Vault. The backend team using the vault CLI natively would see this secret with no indication Akeyless was involved. They don't know. They don't need to know.

The USC writes directly to Vault KV via the Gateway — not a copy, not a sync. The Gateway is the write path.

---

## [CHAPTER 5b]: Vault Create → Akeyless Verify (Payments)

**Duration:** ~1:00

**On screen:**

Terminal showing:

```bash
# Write natively to the payments Vault
export VAULT_ADDR='http://127.0.0.1:8202'
vault kv put secret/payments/created-from-vault value="hello-from-payments-vault"

# Verify Akeyless sees it immediately
akeyless usc list --usc-name demo-vault-usc-payments

akeyless usc get \
  --usc-name demo-vault-usc-payments \
  --secret-id payments/created-from-vault
```

Output showing the new secret is immediately visible through USC.

**Narration:**

Now the reverse — and this time I'll use the payments Vault to make it clear this works across clusters.

I'll write a secret directly into the payments Vault on port 8202 with `vault kv put`. Native Vault, no Akeyless involved in the write.

Now switch to the Akeyless CLI. `akeyless usc list` on the payments connector — and `created-from-vault` is already there. `akeyless usc get` — same value.

No sync job. No import step. No polling delay. Akeyless reads directly from the live Vault KV engine. Whatever's in payments Vault is immediately visible through the payments USC. This applies to every secret in that Vault — including ones that existed for years before Akeyless was connected.

---

## [CHAPTER 6]: HashiCorp Vault Proxy

**Duration:** ~1:30

**On screen:**

Terminal showing:

```bash
# The one change: point VAULT_ADDR at Akeyless HVP
export VAULT_ADDR='https://hvp.akeyless.io'

# Token format: <Access Id>..<Access Key>  (two dots between them)
cat ~/.vault-token

# Same vault commands, completely unchanged
vault kv get secret/myapp/db-password

vault kv get secret/myapp/api-key
```

Output identical to what we saw in Chapter 1.

**Narration:**

Now for the HashiCorp Vault Proxy. This is the path for teams where changing their tooling is off the table.

One environment variable change. `VAULT_ADDR` now points at `hvp.akeyless.io`. That's it.

The token format is your Akeyless Access ID and Access Key joined with two dots. The vault CLI doesn't care what the token value is — it just passes it as a header.

Before I run the demo commands, a quick note on how HVP works for static KV secrets: HVP uses Akeyless's own KV store as the backend. It is not reading through to the local Vault instances we showed in Chapter 1. To populate it for this demo, we ran `vault kv put` against HVP — the exact same command teams use to write secrets — which landed those secrets in Akeyless's KV store. That's also the migration path: teams write their existing secrets into Akeyless via `vault kv put` through HVP, and their applications keep reading via `vault kv get` with zero changes.

`vault kv get secret/myapp/db-password` — same password. `vault kv get secret/myapp/api-key` — same key.

Same command. Same output. Zero code changes. Zero changes to scripts, pipelines, or runbooks. Akeyless is the backend, every request is authenticated and authorized, and every request is logged.

That is what zero-disruption migration looks like in practice.

---

## [CHAPTER 7]: RBAC — One Policy, Both Clusters Denied

**Duration:** ~1:30

**On screen:**

Terminal showing:

```bash
# Authenticate as the denied identity
akeyless auth \
  --access-id <DENIED_ACCESS_ID> \
  --access-key '<DENIED_ACCESS_KEY>'

# Attempt backend Vault — denied
akeyless usc get \
  --usc-name demo-vault-usc-backend \
  --secret-id myapp/db-password
# Output: Unauthorized

# Attempt payments Vault — also denied
akeyless usc get \
  --usc-name demo-vault-usc-payments \
  --secret-id payments/stripe-key
# Output: Unauthorized
```

Error output on both attempts.

**Narration:**

Governance isn't just visibility — it's enforcement. Let me show you what that looks like at scale.

I'll authenticate as a denied identity. This identity has a single Akeyless role with a `deny` capability applied to paths under both USC connectors — backend and payments.

`akeyless auth`. Credentials accepted — this is a valid identity.

Now `akeyless usc get` on the backend database credential. Denied. The request never reached Vault.

Now `akeyless usc get` on the payments Stripe key. Also denied.

One Akeyless policy blocked access to two separate Vault clusters simultaneously. I didn't update any Vault ACL policy. I didn't touch either cluster. I changed one Akeyless role and both clusters were governed immediately.

This is what centralized governance means at scale. When you need to revoke a team's access, you do it once in Akeyless. Every connected Vault instance enforces it.

---

## [CHAPTER 8]: Audit Trail

**Duration:** ~1:00

**On screen:**

Browser showing the Akeyless console Logs page, with a filtered view showing log entries from this demo session. Entries visible include:

- USC list operations (backend connector, then payments connector)
- USC get operations from both connectors
- USC create (backend, Chapter 5a)
- Native Vault write picked up by payments USC (Chapter 5b)
- HVP vault kv list and get operations (Chapter 6)
- Two denied USC get attempts from Chapter 7 — both with status "Denied"

**Narration:**

Last stop — the audit trail. One log for both clusters.

Here's everything from this session. The USC discovery calls from Chapter 3. The USC reads from both connectors in Chapter 4. The create through the backend connector in 5a. The write we made natively in the payments Vault, picked up via USC in 5b. The HVP vault CLI calls from Chapter 6 — attributed to the Akeyless identity, not a generic token. And down here, both denial attempts from Chapter 7 — one for the backend cluster, one for payments, both status "Denied."

Two Vault clusters. One log. Every operation — regardless of which tool triggered it, regardless of which cluster held the secret — is in this single view. Forwardable to your SIEM. Filterable by identity, by action, by path, by cluster. This is what a CISO actually needs.

---

## [CLOSING SLIDE]: Wrap Up

**Duration:** ~0:30

**On screen:**

> **Governance Without Rip-and-Replace**
>
> - Universal Secret Connector: manage Vault secrets from the Akeyless control plane
> - HashiCorp Vault Proxy: `vault` CLI unchanged, Akeyless becomes the backend
> - Both paths produce a unified audit trail and enforce Akeyless RBAC
> - No migration required — works with the secrets and workflows you have today
>
> **Get started:**
> - Docs: docs.akeyless.io
> - Free tier: console.akeyless.io

**Narration:**

So that's the full picture. Two separate Vault clusters, one Akeyless control plane. USC and HVP are two different entry points into that control plane — one for teams adopting Akeyless natively, one for teams keeping the vault CLI. Both give you the same RBAC enforcement, the same audit trail, and the same central visibility across every connected Vault instance — without migrating a single secret or changing a single workflow.

If you want to try this yourself, the free tier at console.akeyless.io is a good place to start, and the full documentation for both USC and HVP is at docs.akeyless.io. Thanks for watching.
