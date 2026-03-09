# Akeyless Multi Vault Governance: Centralized Governance Across HashiCorp Vault and Cloud Secrets Managers

## Video

<!-- Embed video here -->

Imagine you are a CISO sitting across from your platform team lead. The message is direct: "We need centralized governance across our secret stores." On the surface this sounds straightforward — your organization has expanded, the governance gaps in your current Vault deployment are real, and cloud-native secret managers have appeared across teams and environments. But then the actual estate lands. Every CI/CD pipeline in the organization references Vault endpoints. Kubernetes workloads still use native Secrets in some clusters. One platform team uses AWS Secrets Manager. Developers have built runbooks, scripts, and automation around the Vault CLI. The SRE team has written custom tooling on top of the Vault API. A "full migration" means retraining multiple teams with different levels of readiness, rewriting pipelines that touch production systems, re-testing everything in environments where any regression has real consequences, and managing the risk of a cutover window where something critical breaks at the worst possible moment.

The total cost of that migration — in engineering time, testing, coordination, and risk exposure — is almost always higher than the initial estimate. Projects like this have a habit of stretching from quarters into years, during which the governance gap stays open.

What if you didn't have to close it that way? What if you could place a governance layer over your existing Vault deployment and adjacent cloud secrets managers — centralizing the audit trail, applying consistent RBAC, gaining cross-team visibility — without touching a single application, pipeline, or workflow? That is exactly what this post covers.

One terminology note up front: in this post, I will refer to Akeyless multi-vault governance as **MVG**. In today's product, CLI, and documentation, this same capability is still surfaced as **USC** (Universal Secret Connector). The naming is in transition, so when you see `akeyless usc ...` in commands or USC in the docs, that is the current product surface for MVG.

## What You Will Learn

- Add centralized RBAC to Vault and cloud secrets managers with no migration
- Capture every access event in one audit trail
- Connect Vault using HashiCorp Vault Proxy (HVP) or integrate cloud secrets managers with the current USC implementation of MVG
- Roll out governance incrementally across teams, namespaces, environments, and secret platforms

## The Reality of Enterprise Secret Management

HashiCorp Vault does not just run in enterprise environments. It gets woven into them. Teams adopt it at the infrastructure layer first — Kubernetes secrets engines, PKI, AWS dynamic credentials — and then application teams start pulling static secrets from KV. CI/CD pipelines get Vault agent sidecars or direct API calls. Platform engineers build internal tools that assume Vault is present. Over time, Vault becomes load-bearing infrastructure in the same way DNS or LDAP does: not just a service that runs, but one that dozens of other things depend on in implicit ways that only surface when you try to change it.

The organizational reality compounds this. Platform teams that are ready to adopt a new secrets management platform are often blocked by the fact that other teams are not. The team running a decade-old Java monolith does not want to change its secrets retrieval path. The team managing legacy CI/CD tooling has vault commands embedded in shell scripts that have not been touched in years. Adoption timelines fragment across teams, and a "complete migration" becomes a coordination problem as much as a technical one.

Meanwhile, the governance gaps that originally prompted the migration conversation remain open during the entire transition period. There is no single place to see who accessed which secret, when, and from where. RBAC policies are defined per Vault, per cloud account, or per Kubernetes cluster, which means a coherent access control model requires maintaining policy consistency across multiple independent systems. Audit logs are fragmented by backend. A CISO asking "who has had access to the production database credentials in the last 90 days" gets an answer that involves manually correlating data from multiple systems — if it is possible to answer at all.

The "all or nothing" migration approach keeps that governance gap open for the entire duration of the project. For large enterprises, that can be years.

## Operational Reality

The practical cost of running Vault without a centralized governance layer compounds over time in ways that are easy to underestimate.

Audit log aggregation requires Vault Enterprise. If your organization is running Vault OSS or Vault Community Edition, you do not have access to the audit device features that enable proper log shipping to a SIEM. Teams either accept this gap or invest in an upgrade cycle that adds licensing cost and operational overhead.

RBAC management is namespace-local. Every Vault namespace has its own set of policies, and there is no mechanism to define a policy once and apply it globally across namespaces or clusters. As the number of namespaces grows, so does the policy maintenance burden. Policy drift — where different namespaces gradually diverge from each other — is common in organizations that have been running Vault for several years.

SIEM integration requires per-cluster configuration. Even with Vault Enterprise and audit logging enabled, getting those logs into a central SIEM requires configuring audit backends on each cluster individually. Changes to the SIEM pipeline mean changes to every cluster.

Akeyless centralizes all of this without requiring additional cluster management, additional licensing, or migration projects. The audit trail and RBAC enforcement live in the Akeyless control plane. Connecting a new Vault instance to MVG or HVP extends that centralized governance to the new instance automatically.

## Why This Is Still a Vault-Led Story

It is worth being explicit about the target use case. This is not a generic "we can connect to many backends" story. The strongest operational problem here is still HashiCorp Vault: multiple isolated Vault clusters, owned by different teams or regions, with no centralized governance layer on top.

Vault Enterprise users often utilize Disaster Recovery replication or Performance Replication between regions to improve centralization. That matters, and it solves part of the problem in some organizations. But many enterprises still operate isolated Vault clusters without replication because different teams own different environments, or because the cost and complexity of replication are not justified for every workload.

That is the exact use case this webinar and demo target first. Then, once that Vault story is established, we extend the same governance model to cloud secrets managers and Kubernetes to show the broader value of MVG in mixed estates.

## Why Native Vault Governance Breaks at Scale

The governance limitations of standalone Vault deployments become more pronounced as organizations scale across teams, environments, and cloud regions.

RBAC is scoped per cluster or namespace. There is no global policy model in Vault OSS that spans clusters. When your organization has five teams running five Vault instances, you have five independent access control models that must be kept in sync manually.

Audit logs remain per cluster unless Vault Enterprise is licensed and configured. Even with Enterprise, each cluster writes its own audit log, and aggregation requires external tooling. A complete picture of who accessed what across the entire organization requires stitching together logs from multiple sources.

Cross-cloud or multi-cluster visibility requires external log aggregation at minimum — and often custom tooling on top of that. There is no native mechanism in Vault to provide a unified view of access activity across clusters in different regions or cloud providers, and it certainly does not extend to AWS Secrets Manager, Azure Key Vault, GCP Secret Manager, or Kubernetes Secrets.

Vault Enterprise addresses some of these limitations through replication, namespaces, and centralized audit configuration. But it does so at higher cost and with additional operational complexity. Teams that adopt Vault Enterprise to close the governance gap often find that the configuration and maintenance of that layer becomes a project in its own right.

## A Better Path: Govern Without Migrating

Akeyless is not exclusively a replacement for Vault. It is a secrets management control plane that can wrap existing infrastructure — including Vault — and govern it without requiring that infrastructure to be replaced.

The coexistence story is straightforward: teams that have already adopted the Akeyless CLI and console govern their secrets natively. Teams still on Vault continue to use the Vault CLI and Vault APIs without modification. Both sets of operations flow through the Akeyless control plane and produce entries in the same unified audit trail, enforced by the same RBAC policies.

The key architectural insight is this: Vault becomes a secret store that Akeyless governs. The secrets do not move. The keys do not rotate. The Vault cluster does not change. What moves is the control plane — access decisions, audit logging, and policy enforcement now happen in Akeyless, while the underlying storage and retrieval continue to happen in Vault.

This frames a natural progression. You start by layering Akeyless governance over your existing Vault deployment. Teams that are ready migrate at their own pace, moving secrets from Vault KV into Akeyless native storage when it makes sense for them. Teams that are not ready continue operating unchanged. At no point is there a hard cutover or a forced migration deadline. The governance gap closes immediately; the migration happens incrementally.

This becomes even more critical in multi-Vault environments, where different teams operate separate clusters across regions or clouds. Akeyless provides centralized RBAC and audit across all Vault instances, not just one.

In production, most teams place Vault clusters per geographic region and as close to applications as possible to reduce latency. Vault Enterprise users often add Disaster Recovery replication or Performance Replication between regions. But many organizations still operate isolated Vault clusters with no replication, because different teams own different environments or because replication cost and complexity is not justified for every workload.

That isolated-cluster model is where Akeyless MVG is especially useful: secrets stay in each local Vault, while RBAC and audit become centralized across all clusters. The same governance model can then be applied to cloud secrets managers and Kubernetes Secrets, which are often the next silos security teams need to bring under the same policy and audit umbrella.

It is worth being precise about what that initial state — call it phase zero — actually looks like. On day one, before any secrets have moved, the Akeyless audit trail is active over every Vault access that flows through MVG or HVP. That is not a partial view: it covers every read, write, and list operation against the paths you have connected. RBAC is already enforced centrally at this point — access decisions are made by Akeyless policies regardless of where the secret physically lives. A team that has not started migrating is still governed by the same access control model as a team that has completed it. When migration does begin, it proceeds at whatever granularity makes sense: one team's namespace, one application's secret set, one service at a time. The underlying governance model does not change at any point in that process.

## Two Integration Models

Akeyless provides two distinct mechanisms for governing Vault and adjacent secret stores. They serve different audiences, and they can be used simultaneously within the same organization.

### Multi-Vault Governance (MVG)

MVG is the governance layer Akeyless places over your existing secret estate. In today's product surface, this capability is configured through Universal Secret Connector objects in Akeyless, bound to targets such as Vault, AWS, and Kubernetes. The Gateway is a component you deploy inside your infrastructure — on Kubernetes, a VM, or in Docker — that holds persistent connectivity to the backends you want to govern.

Once MVG is configured, it exposes a set of operations — list, read, create, update, delete — that operate on secrets stored in the governed backend, accessed through the Akeyless control plane. When you run `akeyless usc get`, the request is authenticated against Akeyless, checked against Akeyless access policies for your identity, and if authorized, the Gateway fetches the secret value from the relevant backend and returns it through the control plane. The secret value is never copied out permanently. Akeyless reads it in place on each authorized request.

Requirements for MVG depend on the backend. For Vault, the requirements are straightforward: Vault KV version 2, and a Vault token with `create`, `delete`, `update`, `read`, and `list` capabilities on the paths you want to govern. For AWS Secrets Manager or Kubernetes, MVG uses the corresponding target credentials and namespace or prefix scoping. The Akeyless Gateway needs network access to the backend you want to govern.

The operational benefit of MVG is that Akeyless RBAC now governs access to your Vault secrets. You can define path-level access policies, assign them to Akeyless identities (users, service accounts, machine identities), and every read, write, or list operation produces an audit log entry in the Akeyless control plane — regardless of whether that secret was created through Akeyless or directly in Vault.

It is important to be precise about how Akeyless RBAC interacts with existing Vault ACL policies. Akeyless operates as an overlay governance layer — it does not replace or remove Vault's own access control. For a request to succeed through MVG, it must satisfy both the Vault ACL policies on the target path and the Akeyless access policies for the requesting identity. Both policy systems must allow the operation. This is defense-in-depth, not policy substitution.

MVG is the right model for teams who are adopting the Akeyless CLI and console and want to govern their existing Vault secrets from the Akeyless plane without waiting for a full migration.

### HashiCorp Vault Proxy (HVP)

The HashiCorp Vault Proxy is an API compatibility layer hosted by Akeyless at `hvp.akeyless.io`. It speaks the native Vault OSS HTTP API — the same wire protocol that the `vault` CLI, Vault SDK clients, and Vault-compatible plugins use to communicate with a Vault server.

The operational change for teams using HVP is a single environment variable: `VAULT_ADDR=https://hvp.akeyless.io`. That is the entire change. Every `vault kv get`, every `vault kv list`, every `vault kv put` continues to work exactly as before. Scripts do not change. Pipelines do not change. Runbooks do not change. The application literally cannot tell the difference because HVP speaks the same protocol.

Authentication through HVP uses the Vault token format, but the token value is an Akeyless access credential formatted as `<Access Id>..<Access Key>`. This maps the request to an Akeyless identity, which is then authorized against Akeyless policies before the operation is executed.

It is worth being precise about where HVP stores and serves static KV secrets. HVP uses Akeyless's own KV store as the backend — it does not read through to your existing local Vault instance for static secrets. When a team points `VAULT_ADDR` at HVP and runs `vault kv put`, that secret lands in Akeyless's native KV store, governed by Akeyless RBAC, and logged in the Akeyless audit trail. When they run `vault kv get`, they are reading from that same Akeyless KV store. The vault CLI is the interface; Akeyless is the store. This makes HVP the natural tool for teams migrating their KV secrets from Vault into Akeyless — they write secrets in via `vault kv put`, their applications keep reading via `vault kv get`, and nothing else changes.

HVP also supports dynamic secrets through Akeyless's own dynamic secret producers — 20+ producers covering AWS, Azure, GCP, database engines, Kubernetes, and more. Teams that currently use Vault dynamic secrets engines can have equivalent dynamic credentials generated by Akeyless, delivered through the same HVP endpoint their tooling already targets.

HVP is the right model for teams that are not changing anything — not their CLI, not their SDK calls, not their CI/CD configuration. They redirect one environment variable and immediately gain Akeyless RBAC enforcement and audit logging on every operation. The migration of KV secrets into Akeyless happens via that same interface, at whatever pace the team chooses.

Both models can be active simultaneously. A platform team adopting Akeyless natively uses MVG to govern existing Vault, AWS, or Kubernetes secrets. A legacy application team uses HVP to continue using the vault CLI unchanged. Both operations flow through the same Akeyless control plane and produce entries in the same audit trail. Neither team is blocked by the other's adoption pace.

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
    │   Vault Targets · AWS Target · Kubernetes Target   │
    └───────┬───────────────────────┬───────────────────┘
            │                       │
   ┌────────▼────────┐     ┌────────▼──────────────┐
   │ HashiCorp Vault │     │ AWS / Kubernetes      │
   │   (2 clusters)  │     │ Secrets backends      │
   └─────────────────┘     └───────────────────────┘

Traffic flows:

  akeyless CLI → MVG (current CLI command: usc) → Gateway → Vault / AWS / K8S targets
  vault CLI    → https://hvp.akeyless.io → Akeyless Control Plane
```

The Akeyless Gateway is the only component that needs to run inside your network. It handles outbound connections to the Akeyless control plane (no inbound ports required) and inbound connections from the control plane for proxied requests. The Gateway maintains the authenticated connection to Vault via the Vault Target configuration — your Vault token never leaves your environment.

In a real production deployment, this is typically one Gateway per private location or region, close to the Vault cluster in that location. For example, a Vault cluster in AWS us-east would normally use a Gateway in us-east, and a Vault cluster in us-central would use a separate Gateway in us-central. The single-Gateway setup in this demo is intentionally simplified because both demo Vault instances run in the same private network.

For the MVG path, the flow is: Akeyless CLI authenticates to the control plane, the control plane authorizes the request against your access policies, the authorized request is forwarded to the Gateway, the Gateway authenticates to the target backend using the stored target credentials, fetches or writes the secret, and returns the result through the control plane to the CLI. Every step after the initial authentication check produces an audit log entry.

That matters because the same pattern now spans more than Vault. A team can keep secrets in Vault, AWS Secrets Manager, or Kubernetes, and the governance experience stays the same from the Akeyless side.

For the HVP path, the vault CLI sends a standard Vault HTTP request to `hvp.akeyless.io`. The Akeyless control plane authenticates the request using the Akeyless access credential passed as the Vault token, authorizes it against the relevant access policies, and serves the operation from Akeyless's own KV store (for static secrets) or from an Akeyless dynamic secret producer. Same audit log, same RBAC enforcement.

## Beyond Vault: Cloud Secrets Managers and Kubernetes

The primary use case in this demo is still Vault. That is deliberate. But many enterprises are not "Vault only" in practice. They also have cloud-native secret stores, and they still have Kubernetes Secrets in places where platform teams have not yet standardized on a single secret backend.

That is where the broader MVG story matters. The same governance layer you place over isolated Vault clusters can also govern AWS Secrets Manager, Azure Key Vault, GCP Secret Manager, and Kubernetes Secrets. In the live demo for this post, AWS Secrets Manager and Kubernetes are the two non-Vault examples.

This is not presented as a replacement for the Vault story. It is an extension of it. First prove that Akeyless closes the governance gap across isolated Vault clusters. Then show that the exact same control plane also closes adjacent governance gaps across cloud and Kubernetes.

## Two-Way Secret Sync

One of the more important operational properties of MVG is that it is genuinely bidirectional, and that bidirectionality is immediate with no replication lag.

When you write a secret through Akeyless MVG — using today's `akeyless usc create` command — that secret is physically written to Vault KV by the Gateway using the Vault Target credentials. It is not stored in Akeyless. It lands in Vault. A team member who is still using the vault CLI natively, pointed at the same Vault instance, can immediately read that secret with `vault kv get`. They do not know or care that the secret was created through Akeyless. Their workflow is unchanged.

The reverse is equally true. When a team creates a secret directly in Vault — with `vault kv put` — that secret is immediately visible through Akeyless MVG. `akeyless usc list` will show it. `akeyless usc get` will retrieve it. There is no polling interval, no sync job, no replication mechanism to wait for. MVG operates as a direct read/write interface against the Vault KV engine via the Gateway, meaning visibility reflects live Vault state rather than periodic synchronization. Akeyless reads directly from Vault, so the state of the Vault KV store is always the authoritative and current view.

This property matters enormously for brownfield deployments. Every secret that already exists in your Vault instance is immediately governable through MVG the moment you connect a Gateway and configure a Vault Target. You do not need to inventory your secrets, migrate them one by one, or coordinate a cutover. The governance layer activates over the existing state of your Vault without disruption.

The governance implication is worth stating plainly. Regardless of which team created a secret — whether it was written by an Akeyless-native team through MVG, by a legacy team using vault CLI natively, or by an automated process that has been running for years — Akeyless RBAC controls who can access it through the MVG and HVP paths. A secret that existed in Vault before Akeyless was introduced is subject to the same access policy enforcement as a secret created through Akeyless after the integration was set up.

Your platform team adopts Akeyless today. Your legacy applications team keeps using vault commands. Both are now governed by the same control plane, the same access policies, and the same audit trail.

## Getting Started

The demo in this post's companion video runs two Vault dev servers locally — one representing a backend team and one representing a payments team — alongside AWS Secrets Manager and Kubernetes Secrets, all governed through an Akeyless Gateway deployed on a local Kubernetes cluster using Helm. This one-Gateway-for-many-backends setup is demo-only; production deployments typically run one Gateway per private location/region. The setup requires the vault CLI, the akeyless CLI, the aws CLI, kubectl, and helm. An Akeyless account is required — the free tier at console.akeyless.io is sufficient to run everything shown in the demo.

The demo repository contains setup scripts that handle the full configuration. Four commands cover the initial environment:

```bash
./demo/setup-vault-dev.sh
./demo/setup-cloud-and-k8s-demo.sh
helm upgrade --install akeyless-gateway akeyless/akeyless-api-gateway \
  --namespace akeyless --values demo/gateway-values.yaml
./demo/akeyless-setup.sh
```

The first script starts both Vault dev servers and seeds demo secrets in each. The second seeds the AWS and Kubernetes resources used in the extension chapter and prints the environment variables needed for the corresponding targets. The Helm command deploys the Akeyless Gateway into the `akeyless` namespace on your local cluster. The final script creates the Vault, AWS, and Kubernetes targets, the MVG connectors using today's USC objects, and the access policies used in the RBAC chapter. Full setup instructions and the complete command reference for each demo chapter are in the `demo/` folder in the repository.

## What We Did in the Demo

Chapter 1 established the starting point: two completely independent Vault clusters. The backend team's Vault (port 8200) had secrets at `secret/myapp/db-password` and `secret/myapp/api-key`. The payments team's Vault (port 8202) had entirely separate secrets at `secret/payments/stripe-key` and `secret/payments/db-url`. We listed and retrieved secrets from each using the vault CLI pointed at each instance directly. No governance, no shared visibility — just two isolated clusters, each its own island.

Chapter 2 shifted to the Kubernetes side to confirm the Akeyless Gateway was running. In this demo, one Gateway pod handles connections to both Vault instances through separate Vault Targets. In production, you would usually deploy one Gateway per private location/region and connect each local Vault cluster to its local Gateway.

Chapter 3 focused on discovery. We switched to the Akeyless CLI and ran `akeyless usc list` twice — once against `demo-vault-usc-backend` and once against `demo-vault-usc-payments`. Both Vault clusters appeared in the same CLI session, and both inventories were visible immediately through Akeyless MVG. This is the first governance proof point: you can discover what already exists across separate Vault instances without migrating or syncing secrets anywhere.

Chapter 4 moved from discovery to retrieval. We ran `akeyless usc get` against a secret in the backend cluster and then against one in the payments cluster. Nothing had moved from either Vault. MVG read directly from each respective instance. But every one of those reads was authenticated against Akeyless, authorized against the same access policies, and logged in the same audit trail. Two clusters, one governance layer, activated with no migration.

Chapter 5 demonstrated the bidirectional sync in two parts. In 5a, we created a new secret through Akeyless MVG for the backend cluster and then verified it with `vault kv get` pointed at port 8200. The secret was there, written directly to Vault KV by the Gateway. A backend team member using only the vault CLI would see this secret with no indication that Akeyless was involved. In 5b, we wrote a secret natively to the payments Vault with `vault kv put` pointed at port 8202, then immediately queried it through MVG. It appeared in `akeyless usc list` instantly and was fully readable via `akeyless usc get`. No sync job, no propagation lag — MVG is a live read/write interface against the Vault KV engine.

Chapter 6 demonstrated the HashiCorp Vault Proxy. We changed exactly one environment variable — `VAULT_ADDR` pointed to `https://hvp.akeyless.io` — and ran `vault kv get` against the same secret paths. Identical output. The vault CLI did not behave differently in any way. From its perspective it was talking to a Vault server. Behind the scenes, the secrets were being served from Akeyless's own KV store — seeded there in advance via `vault kv put` through HVP itself, which is the same command teams would use to migrate their existing Vault KV secrets into Akeyless. Akeyless handled the authentication, authorization, and audit logging transparently behind that API surface.

Chapter 7 extended the story beyond Vault. We switched to an AWS Secrets Manager connector and a Kubernetes connector and used the same `akeyless usc list` and `akeyless usc get` flow to discover and read secrets from both. This is where the broader MVG value becomes obvious: the same control plane that now governs the two isolated Vault clusters also governs the adjacent secret backends many enterprises already operate.

Chapter 8 was the governance proof point on enforcement. We authenticated as a denied identity — one with an explicit `deny` policy applied to paths under the Vault, AWS, and Kubernetes MVG connectors — and attempted reads across all of them. Vault denied. AWS denied. Kubernetes denied. One Akeyless role blocked access across the entire mixed estate without touching individual backend policies for the consuming identity.

Chapter 9 pulled it together in the Akeyless console's Logs view. Every operation from the session was there: MVG discovery and reads from both Vault clusters in Chapters 3 and 4, the write to backend Vault in 5a, the write to payments Vault detected in 5b, all the HVP vault CLI calls from Chapter 6, the AWS and Kubernetes reads from Chapter 7, and every denial from Chapter 8 — all attributed, all timestamped, all in one view. A CISO asking "who accessed what across which backend, when, from where" gets a single answer from a single log, regardless of how many Vault instances or cloud secret stores are connected.

## Next Steps

If your organization is running Vault today and the governance gaps are real — fragmented audit logs, per-namespace RBAC with no cross-team visibility, no single source of truth for access history — you can close those gaps without a migration project. If that same organization also has AWS Secrets Manager, Azure Key Vault, GCP Secret Manager, or Kubernetes Secrets in the picture, the exact same MVG approach extends there too. The Akeyless free tier is available at console.akeyless.io. MVG and HVP work with the secrets and workflows you already have.

For documentation, the Akeyless overview is at docs.akeyless.io/docs/what-is-akeyless. The current MVG documentation is still published under USC naming, including the full requirements and configuration steps for the Vault Target and connector, at docs.akeyless.io/docs/hc-vault-universal-secrets-connector. The HVP documentation, including the full list of supported operations, authentication formats, and dynamic secret producers, is at docs.akeyless.io/docs/hashicorp-vault-proxy. The demo repository linked in this post contains the setup scripts and command reference to reproduce everything shown in the video.

If you are running Vault today and want to layer governance on top of it without disruption — start here.

## Frequently Asked Questions

**Does MVG move my secrets out of Vault or cloud secret stores?**

No. MVG, currently surfaced in the product as USC, does not copy or replicate secrets into Akeyless storage for the backends shown in this demo. Akeyless reads and writes directly to the governed backend via the Gateway and target configuration. Your secrets remain physically in Vault, AWS Secrets Manager, or Kubernetes. Akeyless governs the access; the backend still holds the data.

**Can I use HVP if I'm on Vault Enterprise with namespaces?**

HVP supports Vault OSS API compatibility. Support for Vault Enterprise namespace-scoped paths varies — check the current HVP documentation at docs.akeyless.io/docs/hashicorp-vault-proxy for the latest details on namespace support.

**What permissions does MVG require?**

It depends on the backend. For Vault, the token used by MVG currently follows the USC implementation requirements: `create`, `delete`, `update`, `read`, and `list` capabilities on the KV paths you want to govern. KV version 2 is required; KV v1 is not supported. AWS and Kubernetes use their own target credentials and backend-specific permission scopes.

**Can I use the vault CLI with HVP against dynamic secrets?**

Yes. HVP supports dynamic secrets through Akeyless dynamic secret producers. Over 20 producers are available, covering AWS, Azure, GCP, database engines, Kubernetes, and more. Teams currently using Vault dynamic secrets engines can have equivalent Akeyless dynamic credentials delivered through the same HVP endpoint their tooling already targets.

**Does Akeyless RBAC replace or complement Vault ACLs?**

Akeyless RBAC operates as an overlay governance layer. Your existing Vault ACL policies remain intact and continue to be enforced. For a request to succeed through MVG or HVP, it must satisfy both the Vault ACL policies on the target path and the Akeyless access policies for the requesting identity. Neither system's policies are removed or bypassed — this is defense-in-depth, not policy replacement.

**What happens if Akeyless is unavailable?**

MVG and HVP operations route through the Akeyless control plane. If the control plane is unavailable, MVG and HVP requests will not be processed. Teams accessing Vault directly — bypassing HVP — are unaffected by Akeyless availability. This is a relevant consideration for organizations that route all Vault access through HVP as the sole access path. Refer to the Akeyless Gateway documentation for local caching and availability options.
