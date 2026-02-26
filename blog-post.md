# HashiCorp Vault + Akeyless: Governance Without Rip-and-Replace

## Video

<!-- Embed video here -->

Imagine you are a CISO sitting across from your platform team lead. The message is direct: "We need to migrate off Vault." On the surface this sounds straightforward — your organization has expanded, the governance gaps in your current Vault deployment are real, and a modern secrets platform is the right long-term answer. But then the scope of that migration actually lands. Every CI/CD pipeline in the organization references Vault endpoints. Kubernetes workloads authenticate to Vault using service account tokens bound to specific roles. Developers have built runbooks, scripts, and automation around the Vault CLI. The SRE team has written custom tooling on top of the Vault API. Migrating off Vault means retraining multiple teams with different levels of readiness, rewriting pipelines that touch production systems, re-testing everything in environments where any regression has real consequences, and managing the risk of a cutover window where something critical breaks at the worst possible moment.

The total cost of that migration — in engineering time, testing, coordination, and risk exposure — is almost always higher than the initial estimate. Projects like this have a habit of stretching from quarters into years, during which the governance gap stays open.

What if you didn't have to close it that way? What if you could place a governance layer over your existing Vault deployment — centralizing the audit trail, applying consistent RBAC, gaining cross-team visibility — without touching a single application, pipeline, or workflow? That is exactly what this post covers.

## The Reality of Enterprise Secret Management

HashiCorp Vault does not just run in enterprise environments. It gets woven into them. Teams adopt it at the infrastructure layer first — Kubernetes secrets engines, PKI, AWS dynamic credentials — and then application teams start pulling static secrets from KV. CI/CD pipelines get Vault agent sidecars or direct API calls. Platform engineers build internal tools that assume Vault is present. Over time, Vault becomes load-bearing infrastructure in the same way DNS or LDAP does: not just a service that runs, but one that dozens of other things depend on in implicit ways that only surface when you try to change it.

The organizational reality compounds this. Platform teams that are ready to adopt a new secrets management platform are often blocked by the fact that other teams are not. The team running a decade-old Java monolith does not want to change its secrets retrieval path. The team managing legacy CI/CD tooling has vault commands embedded in shell scripts that have not been touched in years. Adoption timelines fragment across teams, and a "complete migration" becomes a coordination problem as much as a technical one.

Meanwhile, the governance gaps that originally prompted the migration conversation remain open during the entire transition period. There is no single place to see who accessed which secret, when, and from where. RBAC policies are defined per-Vault-namespace, which means a coherent access control model requires maintaining policy consistency across multiple independent Vault clusters. Audit logs are only available with Vault Enterprise, and even then require log-shipping infrastructure to aggregate across instances. A CISO asking "who has had access to the production database credentials in the last 90 days" gets an answer that involves manually correlating data from multiple systems — if it is possible to answer at all.

The "all or nothing" migration approach keeps that governance gap open for the entire duration of the project. For large enterprises, that can be years.

## A Better Path: Govern Without Migrating

Akeyless is not exclusively a replacement for Vault. It is a secrets management control plane that can wrap existing infrastructure — including Vault — and govern it without requiring that infrastructure to be replaced.

The coexistence story is straightforward: teams that have already adopted the Akeyless CLI and console govern their secrets natively. Teams still on Vault continue to use the Vault CLI and Vault APIs without modification. Both sets of operations flow through the Akeyless control plane and produce entries in the same unified audit trail, enforced by the same RBAC policies.

The key architectural insight is this: Vault becomes a secret store that Akeyless governs. The secrets do not move. The keys do not rotate. The Vault cluster does not change. What moves is the control plane — access decisions, audit logging, and policy enforcement now happen in Akeyless, while the underlying storage and retrieval continue to happen in Vault.

This frames a natural progression. You start by layering Akeyless governance over your existing Vault deployment. Teams that are ready migrate at their own pace, moving secrets from Vault KV into Akeyless native storage when it makes sense for them. Teams that are not ready continue operating unchanged. At no point is there a hard cutover or a forced migration deadline. The governance gap closes immediately; the migration happens incrementally.

It is worth being precise about what that initial state — call it phase zero — actually looks like. On day one, before any secrets have moved, the Akeyless audit trail is active over every Vault access that flows through USC or HVP. That is not a partial view: it covers every read, write, and list operation against the paths you have connected. RBAC is already enforced centrally at this point — access decisions are made by Akeyless policies regardless of where the secret physically lives. A team that has not started migrating is still governed by the same access control model as a team that has completed it. When migration does begin, it proceeds at whatever granularity makes sense: one team's namespace, one application's secret set, one service at a time. The underlying governance model does not change at any point in that process.

## Two Integration Models

Akeyless provides two distinct mechanisms for governing Vault. They serve different audiences, and they can be used simultaneously within the same organization.

### Universal Secret Connector (USC)

The Universal Secret Connector is a named configuration object in Akeyless that binds an Akeyless Gateway to a Vault Target. The Gateway is a component you deploy inside your infrastructure — on Kubernetes, a VM, or in Docker — that holds a persistent connection to your Vault instance. The Vault Target is the Akeyless-side configuration that stores the Vault address and authentication credentials for that connection.

Once a USC is configured, it exposes a set of operations — list, read, create, update, delete — that operate on secrets stored in Vault KV, accessed through the Akeyless control plane. When you run `akeyless usc get`, the request is authenticated against Akeyless, checked against Akeyless access policies for your identity, and if authorized, the Gateway fetches the secret value from Vault and returns it through the control plane. The secret value is never copied out of Vault permanently. Akeyless reads it in-place on each authorized request.

Requirements for USC are straightforward: Vault KV version 2 (KV v1 is not supported for USC), and a Vault token with `create`, `delete`, `update`, `read`, and `list` capabilities on the paths you want to govern. The Akeyless Gateway needs network access to your Vault instance — typically a service address within the same cluster or VPC.

The operational benefit of USC is that Akeyless RBAC now governs access to your Vault secrets. You can define path-level access policies, assign them to Akeyless identities (users, service accounts, machine identities), and every read, write, or list operation produces an audit log entry in the Akeyless control plane — regardless of whether that secret was created through Akeyless or directly in Vault.

USC is the right model for teams who are adopting the Akeyless CLI and console and want to govern their existing Vault secrets from the Akeyless plane without waiting for a full migration.

### HashiCorp Vault Proxy (HVP)

The HashiCorp Vault Proxy is an API compatibility layer hosted by Akeyless at `hvp.akeyless.io`. It speaks the native Vault OSS HTTP API — the same wire protocol that the `vault` CLI, Vault SDK clients, and Vault-compatible plugins use to communicate with a Vault server.

The operational change for teams using HVP is a single environment variable: `VAULT_ADDR=https://hvp.akeyless.io`. That is the entire change. Every `vault kv get`, every `vault kv list`, every `vault kv put` continues to work exactly as before. Scripts do not change. Pipelines do not change. Runbooks do not change. The application literally cannot tell the difference because HVP speaks the same protocol.

Authentication through HVP uses the Vault token format, but the token value is an Akeyless access credential formatted as `<Access Id>..<Access Key>`. This maps the request to an Akeyless identity, which is then authorized against Akeyless policies before the request is proxied to your Vault instance.

HVP supports static KV secrets in both KV v1 and KV v2 formats. It also supports dynamic secrets through Akeyless's own dynamic secret producers — 20+ producers covering AWS, Azure, GCP, database engines, Kubernetes, and more. Teams that currently use Vault dynamic secrets engines can have equivalent dynamic credentials generated by Akeyless, delivered through the same HVP interface their tooling already uses.

HVP is the right model for teams that are not changing anything — not their CLI, not their SDK calls, not their CI/CD configuration. They redirect one environment variable and immediately gain Akeyless RBAC enforcement and audit logging on every operation.

Both models can be active simultaneously. A platform team adopting Akeyless natively uses USC to govern existing Vault secrets. A legacy application team uses HVP to continue using the vault CLI unchanged. Both operations flow through the same Akeyless control plane and produce entries in the same audit trail. Neither team is blocked by the other's adoption pace.

## Architecture at a Glance

```
┌─────────────────────────────────────────────────────────────────┐
│                    Akeyless Control Plane (SaaS)                │
│              RBAC Enforcement · Audit Log · Key Management       │
└────────────────────────┬────────────────────────────────────────┘
                         │
            ┌────────────▼────────────┐
            │    Akeyless Gateway     │  ← Deployed in your environment
            │   (K8s / VM / Docker)   │     (home lab K8s in this demo)
            └────┬────────────────────┘
                 │
    ┌────────────▼──────────────────────────────────────┐
    │              Akeyless Vault Target                 │
    │    URL: http://vault:8200  Token: vault-token      │
    └────────────┬──────────────────────────────────────┘
                 │
    ┌────────────▼──────────────────────────────────────┐
    │            HashiCorp Vault (KV v2)                 │
    │         secret/myapp/db-password                   │
    │         secret/myapp/api-key                       │
    └───────────────────────────────────────────────────┘

Traffic flows:

  akeyless CLI → USC → Gateway → Vault Target → Vault KV
  vault CLI    → https://hvp.akeyless.io → Akeyless Control Plane
```

The Akeyless Gateway is the only component that needs to run inside your network. It handles outbound connections to the Akeyless control plane (no inbound ports required) and inbound connections from the control plane for proxied requests. The Gateway maintains the authenticated connection to Vault via the Vault Target configuration — your Vault token never leaves your environment.

For the USC path, the flow is: Akeyless CLI authenticates to the control plane, the control plane authorizes the request against your access policies, the authorized request is forwarded to the Gateway, the Gateway authenticates to Vault using the Vault Target credentials, fetches or writes the secret, and returns the result through the control plane to the CLI. Every step after the initial authentication check produces an audit log entry.

For the HVP path, the vault CLI sends a standard Vault HTTP request to `hvp.akeyless.io`. The Akeyless control plane authenticates the request using the Akeyless access credential passed as the Vault token, authorizes it against the relevant access policies, and proxies the operation through to the underlying Vault instance or Akeyless dynamic secret producer. Same audit log, same RBAC enforcement.

## Two-Way Secret Sync

One of the more important operational properties of the USC integration is that it is genuinely bidirectional, and that bidirectionality is immediate with no replication lag.

When you write a secret through the Akeyless USC — using `akeyless usc create` — that secret is physically written to Vault KV by the Gateway using the Vault Target credentials. It is not stored in Akeyless. It lands in Vault. A team member who is still using the vault CLI natively, pointed at the same Vault instance, can immediately read that secret with `vault kv get`. They do not know or care that the secret was created through Akeyless. Their workflow is unchanged.

The reverse is equally true. When a team creates a secret directly in Vault — with `vault kv put` — that secret is immediately visible through the Akeyless USC. `akeyless usc list` will show it. `akeyless usc get` will retrieve it. There is no polling interval, no sync job, no replication mechanism to wait for. Akeyless reads directly from Vault, so the state of the Vault KV store is always the authoritative and current view.

This property matters enormously for brownfield deployments. Every secret that already exists in your Vault instance is immediately governable through USC the moment you connect a Gateway and configure a Vault Target. You do not need to inventory your secrets, migrate them one by one, or coordinate a cutover. The governance layer activates over the existing state of your Vault without disruption.

The governance implication is worth stating plainly. Regardless of which team created a secret — whether it was written by an Akeyless-native team through USC, by a legacy team using vault CLI natively, or by an automated process that has been running for years — Akeyless RBAC controls who can access it through the USC and HVP paths. A secret that existed in Vault before Akeyless was introduced is subject to the same access policy enforcement as a secret created through Akeyless after the integration was set up.

Your platform team adopts Akeyless today. Your legacy applications team keeps using vault commands. Both are now governed by the same control plane, the same access policies, and the same audit trail.

## Getting Started

The demo in this post's companion video runs on a Vault dev server running locally via Docker and an Akeyless Gateway deployed on a local Kubernetes cluster using Helm. The setup requires the vault CLI, the akeyless CLI, kubectl, and helm. An Akeyless account is required — the free tier at console.akeyless.io is sufficient to run everything shown in the demo.

The demo repository contains setup scripts that handle the full configuration. Three commands cover the initial environment:

```bash
./demo/setup-vault-dev.sh
helm upgrade --install akeyless-gateway akeyless/akeyless-api-gateway \
  --namespace akeyless --values demo/gateway-values.yaml
./demo/akeyless-setup.sh
```

The first script starts the Vault dev server and seeds the demo secrets. The Helm command deploys the Akeyless Gateway into the `akeyless` namespace on your local cluster. The third script creates the Vault Target, configures the Universal Secret Connector, and sets up the access policies used in the RBAC chapter. Full setup instructions and the complete command reference for each demo chapter are in the `demo/` folder in the repository.

## What We Did in the Demo

We started with a clean baseline. The Vault dev server was running with two secrets seeded under `secret/myapp/` — a database credential at `secret/myapp/db-password` containing a password, and an API key at `secret/myapp/api-key`. We listed those secrets and retrieved them using the vault CLI pointed directly at the local instance. Standard Vault, no Akeyless in the picture. The point was to establish exactly what exists in Vault before any integration, so the subsequent steps have a clear before-and-after.

Chapter 2 shifted to the Kubernetes side, where we ran `kubectl get pods -n akeyless` to confirm the Akeyless Gateway was running. This is the bridging component — it sits inside your infrastructure, holds a persistent connection to the Akeyless control plane over HTTPS, and maintains the authenticated connection to the Vault instance through the Vault Target. Seeing the pod in a running state confirmed the bridge was in place.

Chapter 3 was the first real demonstration of USC governance. We switched entirely to the Akeyless CLI — no vault command in sight — and ran `akeyless usc list` against our connector named `demo-vault-usc`. Both secrets we had just looked at in Vault appeared in the output, with the same paths, immediately. We then ran `akeyless usc get` for each path and retrieved the same credential values. Nothing had moved. The secrets were still physically in Vault. But the access had just been authenticated by Akeyless, authorized against an Akeyless access policy, and logged in the Akeyless audit trail. From a governance standpoint, that read was now visible and attributable.

Chapter 4 demonstrated the bidirectional sync in two parts. In 4a, we created a new secret through Akeyless — `akeyless usc create` with a service token value — and then switched back to the vault CLI to verify it with `vault kv get`. The secret was there. It had been written directly to Vault KV by the Gateway acting on behalf of the Akeyless operation. A team member using only the vault CLI would see this secret with no indication that it was created through Akeyless. In 4b, we reversed the flow: created a secret directly in Vault with `vault kv put`, then immediately switched back to the Akeyless CLI and ran `akeyless usc list`. The new secret appeared in the list without delay. `akeyless usc get` retrieved it correctly. No sync job, no propagation lag — Akeyless had simply read directly from the authoritative Vault KV store, which now included the natively-created secret.

Chapter 5 demonstrated the HashiCorp Vault Proxy. We changed exactly one environment variable — `VAULT_ADDR` pointed from the local Vault address to `https://hvp.akeyless.io` — and then ran the same vault CLI commands from Chapter 1. `vault kv list secret/myapp`, `vault kv get secret/myapp/db-password`, `vault kv get secret/myapp/created-from-akeyless` (the one we had created through Akeyless in 4a). Every command produced identical output to what we had seen in Chapter 1. The vault CLI did not behave any differently. From the CLI's perspective, it was talking to a Vault server. Akeyless was handling the authentication, authorization, and audit logging transparently behind that API surface.

Chapter 6 was the governance proof point on enforcement. We authenticated to Akeyless as a different identity — one configured with access to the USC connector but with a path-level policy that excluded `secret/myapp/db-password`. We then attempted `akeyless usc get` on the db-password path. The request was denied at the Akeyless control plane with an "Unauthorized" error. The request never reached the Gateway, never touched the Vault Target, never hit Vault itself. Akeyless evaluated the access policy for that identity against that path, found no matching allow rule, and rejected the request outright. This is what granular, enforced governance looks like — not just logging who accessed what, but actively preventing access that should not be permitted.

Chapter 7 pulled the thread together in the Akeyless console's Logs view. Every operation from the entire demo session was present: the USC list and get calls from Chapter 3, the USC create from 4a, the USC list and get that confirmed the natively-created Vault secret in 4b, all the HVP vault CLI calls from Chapter 5 — attributed to the Akeyless identity that authenticated with HVP, not a generic service account — and the denied access attempt from Chapter 6, with status "Denied" and full attribution. One audit trail, one view, covering every path into the governed secrets regardless of which tool generated the request. That is what a CISO needs to be able to answer the "who accessed what, when, from where" question.

## Next Steps

If your organization is running Vault today and the governance gaps are real — fragmented audit logs, per-namespace RBAC with no cross-team visibility, no single source of truth for access history — you can close those gaps without a migration project. The Akeyless free tier is available at console.akeyless.io. The USC and HVP integrations work with the secrets and workflows you already have.

For documentation, the Akeyless overview is at docs.akeyless.io/docs/what-is-akeyless. The USC-specific documentation, including the full requirements and configuration steps for the Vault Target and connector, is at docs.akeyless.io/docs/hashicorp-vault-usc. The HVP documentation, including the full list of supported operations, authentication formats, and dynamic secret producers, is at docs.akeyless.io/docs/hashicorp-vault-proxy. The demo repository linked in this post contains the setup scripts and command reference to reproduce everything shown in the video.

If you are running Vault today and want to layer governance on top of it without disruption — start here.
