# Implementation Tracker

## Goal

Expand the webinar demo and follow-on blog post from a Vault-only story into an MVG story centered on:

- HashiCorp Vault as the primary use case
- AWS Secrets Manager as the cloud secrets manager example
- Kubernetes Secrets as the second non-Vault example
- MVG terminology in narrative copy, with USC retained where the current product, CLI, and docs still use it

## Workstreams

### 1. Tracking and scope control

- [x] Create tracking document
- [ ] Keep tracker updated during implementation

### 2. Demo implementation

- [x] Review current demo setup and commands
- [x] Extend setup for AWS demo resources
- [x] Extend setup for Kubernetes demo resources
- [x] Extend demo commands for AWS and Kubernetes chapters
- [x] Update demo walkthrough and prerequisites

### 3. Webinar materials

- [x] Update webinar title and positioning in the video script
- [x] Update agenda and chapter structure
- [x] Update architecture and narration to include Vault plus cloud secrets managers
- [x] Keep Vault as the main story, with AWS and Kubernetes as the breadth proof

### 4. Blog post

- [x] Reframe blog around MVG across Vault and cloud secrets managers
- [x] Preserve Vault Enterprise replication context and isolated-cluster target use case
- [x] Add AWS and Kubernetes to architecture and walkthrough
- [x] Keep MVG terminology consistent, with USC called out as the current product surface

### 5. Consistency and validation

- [x] Update repo README if needed
- [x] Run consistency checks across chapter references and terminology
- [x] Document remaining manual prerequisites or risks

## Progress Log

### 2026-03-09

- Created tracker.
- Inspected existing demo scripts, setup, and docs to identify the minimum viable implementation path for Vault + AWS + Kubernetes.
- Added `demo/setup-cloud-and-k8s-demo.sh` to seed AWS and Kubernetes demo resources and output required env vars.
- Extended `demo/akeyless-setup.sh` to optionally create AWS and Kubernetes targets, USCs, and RBAC coverage.
- Extended `demo/demo-commands.sh` with AWS and Kubernetes demo chapters plus cross-backend RBAC and audit steps.
- Updated `demo/README.md`, `README.md`, `video-script.md`, and `blog-post.md` to match the new webinar title, mixed-backend scope, and Vault-led MVG story.
- Ran shell syntax validation for the updated demo scripts.
- Ran consistency checks across titles, chapter references, and terminology.

## Remaining Manual Prerequisites / Risks

- The AWS extension requires valid AWS credentials in the shell used for setup.
- The Kubernetes extension requires a working `kubectl` context with permission to create a namespace, secret, service account, role, and role binding.
- The live demo still depends on a reachable Akeyless Gateway and a valid Akeyless account.
- The AWS and Kubernetes target creation paths are based on the current local Akeyless CLI surface; the actual webinar environment should be dry-run once end to end before recording or going live.
