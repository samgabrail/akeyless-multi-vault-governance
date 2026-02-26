# HashiCorp Vault + Akeyless Governance — Content Design

**Date:** 2026-02-25
**Topic:** "HashiCorp Vault + Akeyless: Governance Without Rip-and-Replace"

---

## Goal

Produce three tightly coupled content assets (blog post, video script, demo) that demonstrate how Akeyless governs existing HashiCorp Vault deployments without requiring migration, targeting both security architects and hands-on engineers.

---

## Audience

- **Security architects / decision-makers** — need the business case and governance story (blog post intro + architecture sections)
- **Platform / security engineers** — need hands-on technical proof (demo + video demo chapters)

---

## Content Assets

### 1. Blog Post (`blog-post.md`)

**Length:** ~2,000–2,500 words
**Format:** Executive + technical hybrid — opens with business case, transitions to technical proof

**Structure:**
```
H1: HashiCorp Vault + Akeyless: Governance Without Rip-and-Replace
H2: Video                                        ← embed placeholder at top
[Intro ~200w]                                    ← migration dilemma, rip-and-replace fear
H2: The Reality of Enterprise Secret Management  (~300w)
H2: A Better Path: Govern Without Migrating      (~300w)
H2: Two Integration Models                       (~350w)  ← USC vs HVP
H2: Architecture at a Glance                     (~200w)  ← text diagram
H2: Two-Way Secret Sync                          (~300w)  ← coexistence story
H2: Getting Started                              (~150w)
H2: What We Did in the Demo                      (~300w)  ← near end, explains video
H2: Next Steps                                   (~100w)  ← CTA
```

### 2. Video Script (`video-script.md`)

**Length:** ~10–12 min total
**Format:** Structured sections — intro slides → demo screencast → closing slide
**Delivery:** Pure screencast for both slides and demo

**Structure:**
```
[SLIDES ~3 min]
  Slide 1: Title
  Slide 2: The problem
  Slide 3: USC vs HVP side by side
  Slide 4: Architecture diagram
  Slide 5: Demo agenda

[DEMO SCREENCAST ~9 min]
  Chapter 1: Vault dev mode + seed secrets
  Chapter 2: Akeyless Vault Target setup
  Chapter 3: Create USC, list & read secrets
  Chapter 4a: Create in Akeyless → appears in Vault (two-way sync)
  Chapter 4b: Create in Vault → visible in Akeyless (two-way sync)
  Chapter 5: HVP — vault CLI against Akeyless backend
  Chapter 6: RBAC — deny in action
  Chapter 7: Centralized audit trail

[CLOSING SLIDE ~30 sec]
  Recap + CTA
```

### 3. Demo (`demo/`)

**Environment:**
- Vault: dev mode (local, `vault server -dev`)
- Akeyless Gateway: Helm-deployed on home lab K8s cluster
- Tools required: `vault` CLI, `akeyless` CLI, `kubectl`, `helm`

**Files:**
```
demo/
  README.md              — self-contained step-by-step guide
  setup-vault-dev.sh     — start vault dev, seed sample secrets
  gateway-values.yaml    — Helm values for Akeyless Gateway on K8s
  akeyless-setup.sh      — create Vault Target, USC, RBAC role
  demo-commands.sh       — all demo commands in sequence
```

**Demo flow:**
1. Seed Vault with two sample secrets
2. Create Vault Target + USC in Akeyless
3. List and read Vault secrets via `akeyless usc list/get`
4. Two-way sync: `akeyless usc create` → `vault kv get` confirms it exists
5. Two-way sync: `vault kv put` → `akeyless usc list/get` confirms it's visible
6. HVP: `export VAULT_ADDR=https://hvp.akeyless.io` → `vault kv get` works natively
7. RBAC: create restricted role, show denied read
8. Audit: show all operations logged in Akeyless console

---

## Key Technical Facts (from Akeyless docs)

- USC requires KV v2 engine, supports static secrets only
- Vault Target requires token with create/delete/update/read/list on KV engine
- HVP token format: `<Access Id>..<Access Key>` stored in `~/.vault-token`
- HVP public endpoint: `https://hvp.akeyless.io`
- RBAC uses path-based rules with capabilities: list, read, create, update, delete, deny
- Audit log captures: access_id, action, status, remote_addr, duration, timestamp
- SIEM forwarding: Splunk, Datadog, S3, Elasticsearch, Logstash, Logz.io, Azure, Syslog

---

## Repo Structure (flat)

```
/
  blog-post.md
  video-script.md
  demo/
    README.md
    setup-vault-dev.sh
    gateway-values.yaml
    akeyless-setup.sh
    demo-commands.sh
  docs/
    plans/
      2026-02-25-vault-akeyless-governance-design.md
      2026-02-25-vault-akeyless-governance-plan.md
```
