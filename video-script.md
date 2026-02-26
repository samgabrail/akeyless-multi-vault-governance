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
8. [CHAPTER 3] USC List and Get (~1:15)
9. [CHAPTER 4a] Akeyless USC Create → Vault Verify (~1:15)
10. [CHAPTER 4b] Vault Create → Akeyless Verify (~1:00)
11. [CHAPTER 5] HashiCorp Vault Proxy (~1:30)
12. [CHAPTER 6] RBAC — Access Denied (~1:15)
13. [CHAPTER 7] Audit Trail (~1:00)
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

Here's what the plumbing looks like. In your environment — in this demo it's a Kubernetes cluster — you're running an Akeyless Gateway. That Gateway holds a connection to your Vault instance through what Akeyless calls a Vault Target. The Universal Secret Connector sits on top of that target, so when you do a USC read through the Akeyless CLI, the request goes: Akeyless control plane, down to the Gateway, through the Vault Target, and into Vault itself. All governed, all logged.

For the vault CLI path, Akeyless exposes a public endpoint that speaks the native Vault HTTP API. Your vault client doesn't know the difference. The request hits Akeyless, gets authenticated and authorized against Akeyless policies, and Akeyless proxies it to your Vault instance.

In both cases, every operation hits the same Akeyless control plane and produces the same audit log entry. That's the key point.

---

## [SLIDE 5]: Demo Agenda

**Duration:** ~0:20

**On screen:**

> **What We're About to Do**
>
> 1. Verify the Vault dev server has secrets
> 2. Confirm the Akeyless Gateway is running on Kubernetes
> 3. Read Vault secrets through the Akeyless USC
> 4a. Create a secret via Akeyless — verify it appears in Vault
> 4b. Create a secret in Vault — verify Akeyless picks it up
> 5. Use the `vault` CLI unchanged via HashiCorp Vault Proxy
> 6. Test RBAC enforcement — show access denied
> 7. Review the unified audit trail in the Akeyless console

**Narration:**

Here's what we're going to cover. Seven chapters, about nine minutes of live demo. Let's get into it.

---

## [CHAPTER 1]: Verify Vault Dev Secrets

**Duration:** ~1:00

**On screen:**

Terminal showing:

```bash
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

vault kv list secret/myapp
vault kv get secret/myapp/db-password
vault kv get secret/myapp/api-key
```

And the resulting output — two secrets visible at `secret/myapp/`.

**Narration:**

Let's start from the beginning. This is a Vault dev server running locally — no Akeyless in the picture yet. I've got `VAULT_ADDR` pointed at the local instance and I'm using the root token.

First I'll list what's in the `secret/myapp` path. You can see two paths there — `db-password` and `api-key`. Let me pull those.

`vault kv get secret/myapp/db-password` — this has a password field. Standard database credential structure. And `vault kv get secret/myapp/api-key` — there's an API key. These are the secrets we seeded for the demo.

This is completely vanilla Vault. There's nothing special happening here. These secrets exist in Vault, they're accessible with the vault CLI, and there is zero central visibility into who's reading them. That's the problem we're solving. Keep that in mind as we go through the rest of this demo.

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

The Gateway has been pre-configured with a Vault Target that points at the dev server we just looked at, and a Universal Secret Connector built on top of that target. That setup is what lets the next steps work. Let's go use it.

---

## [CHAPTER 3]: USC List and Get

**Duration:** ~1:15

**On screen:**

Terminal showing:

```bash
akeyless usc list --usc-name demo-vault-usc

akeyless usc get \
  --usc-name demo-vault-usc \
  --secret-id secret/myapp/db-password

akeyless usc get \
  --usc-name demo-vault-usc \
  --secret-id secret/myapp/api-key
```

Output showing the same secret values we saw in Vault directly.

**Narration:**

This is the key moment of the USC demo. I'm now using the Akeyless CLI — not the vault CLI. And I'm reading secrets out of Vault through the Akeyless control plane.

`akeyless usc list` with the name of our connector — `demo-vault-usc`. You can see the same two secrets we just saw in Vault. Same paths, same structure.

Now let me get the database secret. `akeyless usc get`, specifying the USC name and the secret id. And there it is — same password that's physically stored in Vault.

Notice what just happened here. That read request was authenticated against Akeyless, checked against Akeyless access policies, and logged in the Akeyless audit trail. The secret never left your Vault instance — Akeyless read it on behalf of the authenticated identity and returned it. Vault didn't change. The workflow on the Akeyless side is completely standard Akeyless.

Let me grab the API key too. Same pattern, same result.

This is what USC gives you — a governance layer over secrets that continue to live in your existing Vault. You don't move them. You just govern the access.

---

## [CHAPTER 4a]: Akeyless USC Create → Vault Verify

**Duration:** ~1:15

**On screen:**

Terminal showing:

```bash
# Create via Akeyless USC
akeyless usc create \
  --usc-name demo-vault-usc \
  --secret-name secret/myapp/created-from-akeyless \
  --secret-value '{"token":"eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9","service":"payments"}'

# Switch back to vault CLI and verify
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

vault kv get secret/myapp/created-from-akeyless
```

Output showing the secret is present in Vault.

**Narration:**

Now let's go the other direction — create a secret through Akeyless and verify it lands in Vault.

`akeyless usc create` — I'm giving it the USC name, a path under `secret/myapp/created-from-akeyless`, and a JSON value with a service token. The command completes.

Now I'll switch back to the vault CLI — same `VAULT_ADDR` and token we used at the start. `vault kv get secret/myapp/created-from-akeyless`.

There it is. The secret we just created through the Akeyless control plane physically exists in Vault. The team that's still using Vault natively — the one we said we didn't want to disrupt — can read this secret with the exact same workflow they've always used. They don't know Akeyless was involved. They don't need to know.

That's the bidirectional nature of the USC. Akeyless and Vault are in sync not because of any replication mechanism, but because Akeyless is reading and writing directly to your Vault instance.

---

## [CHAPTER 4b]: Vault Create → Akeyless Verify

**Duration:** ~1:00

**On screen:**

Terminal showing:

```bash
# Create natively in Vault
vault kv put secret/myapp/created-from-vault \
  connection_string="postgres://admin:secret@db.internal:5432/prod" \
  environment="production"

# Verify via Akeyless USC
akeyless usc list --usc-name demo-vault-usc

akeyless usc get \
  --usc-name demo-vault-usc \
  --secret-id secret/myapp/created-from-vault
```

Output showing the new secret is immediately visible through USC.

**Narration:**

And the reverse. I'll create a secret the old-fashioned way — straight into Vault with `vault kv put`. This simulates a secret that was already in Vault before anyone thought about governance, or that a team put there directly.

Now switch back to the Akeyless CLI. `akeyless usc list` — and `created-from-vault` is already there. `akeyless usc get` on that path — same values we just wrote.

There's no sync job here, no polling interval, no replication lag. Akeyless reads directly from Vault, so whatever's in Vault is immediately accessible through the Akeyless control plane. This is important for brownfield deployments — every secret that already exists in Vault is already governable through USC the moment you connect it. You don't have to migrate anything.

---

## [CHAPTER 5]: HashiCorp Vault Proxy

**Duration:** ~1:30

**On screen:**

Terminal showing:

```bash
# The one change: point VAULT_ADDR at Akeyless HVP
export VAULT_ADDR='https://hvp.akeyless.io'

# Token is an Akeyless access token (starts with t-)
export VAULT_TOKEN='t-abc123...'

# Same vault commands, completely unchanged
vault kv list secret/myapp

vault kv get secret/myapp/db-password

vault kv get secret/myapp/created-from-akeyless
```

Output identical to what we saw in Chapter 1.

**Narration:**

Now for the HashiCorp Vault Proxy. This is the path for teams where changing their tooling is off the table.

One environment variable change. `VAULT_ADDR` now points at `hvp.akeyless.io` instead of the local Vault server. That's it. That's the entire change.

The token is slightly different — it's an Akeyless access token, which starts with `t-`. In a real deployment you'd generate this through your normal Akeyless authentication flow — IAM, JWT, certificate, whatever your teams use. The vault CLI doesn't care what the token format is; it just passes it as a header.

Now let's run the exact same commands from Chapter 1. `vault kv list secret/myapp` — same output. `vault kv get secret/myapp/db-password` — same password. `vault kv get secret/myapp/created-from-akeyless` — the one we created via Akeyless USC, now visible through the vault CLI.

Same command. Same output. Zero code changes. Zero changes to scripts, pipelines, or runbooks. Akeyless is now the backend, every request is authenticated and authorized by Akeyless, and every request is logged.

That is what zero-disruption migration looks like in practice.

---

## [CHAPTER 6]: RBAC — Access Denied

**Duration:** ~1:15

**On screen:**

Terminal showing:

```bash
# Authenticate as a restricted identity
akeyless auth \
  --access-id p-abc123 \
  --access-key '...'

# Attempt to read a secret this identity shouldn't access
akeyless usc get \
  --usc-name demo-vault-usc \
  --secret-id secret/myapp/db-password

# Output: Access denied — unauthorized
```

Error output clearly showing the access denial.

**Narration:**

Governance isn't just visibility — it's control. Let me show you what enforcement looks like.

I'll authenticate as a different identity — one that's been given access to the USC connector, but not to the `secret/myapp/db-password` path specifically. Akeyless supports path-level access policies the same way you'd scope any other secret.

`akeyless auth` with this identity's credentials. Authentication succeeds — this is a valid Akeyless identity.

Now `akeyless usc get` on the database path.

Denied. "Unauthorized." The request never reached Vault. Akeyless evaluated the access policy for this identity against this path, found no matching allow rule, and rejected the request at the control plane level.

This is what governance means in practice. It's not about seeing who accessed what after the fact — although the audit trail does that. It's about being able to say "this team, this service, this CI job can access these secrets and nothing else," and having that enforced consistently regardless of which underlying secret store the secret happens to live in.

---

## [CHAPTER 7]: Audit Trail

**Duration:** ~1:00

**On screen:**

Browser showing the Akeyless console Logs page, with a filtered view showing log entries from this demo session. Entries visible include:

- USC list operations
- USC get operations (db-password, api-key, created-from-akeyless, created-from-vault)
- USC create (created-from-akeyless)
- HVP vault kv list and get operations
- The denied USC get attempt from Chapter 6, with status "Denied"

**Narration:**

Last stop — the audit trail. I'll navigate to the Logs section in the Akeyless console.

Here's every operation from this demo. The USC list and get calls from Chapter 3. The create from Chapter 4a. The vault CLI calls through HVP from Chapter 5 — notice those show up here too, attributed to the Akeyless identity that authenticated with HVP, not a generic "vault" user. And at the bottom, that denied access attempt from Chapter 6 — status "Denied," identity, path, timestamp, all there.

One audit trail. Regardless of which tool your teams use. Whether they went through the Akeyless CLI, the Akeyless console, or the vault CLI pointed at HVP, every operation ends up in the same log. You can ship this to your SIEM, set up alerts on it, pull it for compliance reports — all from a single source.

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

So that's the full picture. USC and HVP are two different entry points into the same control plane. One is for teams ready to adopt the Akeyless CLI, the other is for teams that aren't going anywhere near it. Both give you the same RBAC enforcement, the same audit trail, and the same central visibility that closes the governance gap — without requiring a single secret to be migrated or a single workflow to change.

If you want to try this yourself, the free tier at console.akeyless.io is a good place to start, and the full documentation for both USC and HVP is at docs.akeyless.io. Thanks for watching.
