# Architecture Decision Records (ADRs) — Source of Truth

Every architecturally-significant decision lives here as an ADR. **If any diagram, wiki, slide, design
doc, or comment disagrees with an Accepted ADR, the ADR wins.** Narrative context is in
`../architecture/`, the shared surface in `contracts/`; the *decisions* are here.

## Process (ADR-0001, ADR-0002)

Nygard/MADR style — *Status, Context, Decision, Consequences, Alternatives* — one decision per file;
see [`0000-template.md`](0000-template.md). Statuses run
`Proposed` → `Accepted` → (`Superseded by ADR-XXXX` | `Deprecated`).

1. Copy the template to `NNNN-title.md`, taking the next number.
2. Open a PR — **the PR review is the decision-approval gate.**
3. On merge, set the status to `Accepted`. **Accepted ADRs are immutable.**
4. To change a decision, add a **new** ADR that supersedes the old one and mark the old one
   `Superseded by ADR-XXXX`. Never rewrite history.

## Index

| ADR | Decision | Status |
|-----|----------|--------|
| [ADR-0001](0001-adrs-as-source-of-truth.md) | ADRs are the Source of Truth | Accepted |
| [ADR-0002](0002-governance-driven-design.md) | Adopt Governance-Driven design | Accepted |
| [ADR-0003](0003-multitenancy-shared-db-rls-cells.md) | Multi-tenancy: shared DB + RLS + cells | Accepted |
| [ADR-0004](0004-git-storage-tier.md) | Git storage via Git-RPC over sharded nodes | Accepted |
| [ADR-0005](0005-ci-ephemeral-sandbox-isolation.md) | CI: ephemeral per-job sandbox isolation | Accepted |
| [ADR-0006](0006-policy-as-code-opa.md) | Policy-as-code with OPA (PEP/PDP) | Accepted |
| [ADR-0007](0007-append-only-audit-log.md) | Append-only, tamper-evident audit log | Accepted |
| [ADR-0008](0008-flat-rate-fair-use-cost-governance.md) | Flat-rate + fair-use cost governance | Accepted |
| [ADR-0009](0009-byo-infrastructure-cp-dp-split.md) | BYO infra: control/data-plane split (BYOC) | Accepted |
| [ADR-0010](0010-target-gke-eks-aks-portability.md) | Target GKE/EKS/AKS via portability layer | Accepted |
| [ADR-0011](0011-outbound-only-agent.md) | Outbound-only agent for CP↔DP | Accepted |
| [ADR-0012](0012-gvisor-default-ci-isolation-byo.md) | gVisor default CI isolation on BYO | Accepted |
| [ADR-0013](0013-helm-plus-operator-packaging.md) | Package via Helm + Operator | Accepted |
| [ADR-0014](0014-dedicated-code-search-index.md) | Dedicated code-search index (Zoekt-style) | Accepted |
| [ADR-0015](0015-uiux-github-clean-unified-security.md) | UI/UX: GitHub-clean + unified security surface | Accepted |
| [ADR-0016](0016-git-failover-sync-one-replica.md) | Git failover: sync 1 replica + async fan-out | Accepted |
| [ADR-0017](0017-agent-grpc-mtls-protocol.md) | Agent protocol: gRPC streaming over mTLS | Accepted |
| [ADR-0018](0018-dual-loss-failover-policy.md) | Dual-loss failover: fail-safe (halt + audited override) | Accepted |
| [ADR-0019](0019-technology-stack.md) | Technology stack (v1) | Superseded by ADR-0020 |
| [ADR-0020](0020-technology-stack-rev2.md) | Technology stack rev.2 (Astro SSR, Redpanda, SeaweedFS) | Superseded by ADR-0023 |
| [ADR-0021](0021-local-dev-orbstack.md) | Local/dev: OrbStack + *.orb.local | Superseded by ADR-0024 |
| [ADR-0022](0022-high-cohesion-low-coupling.md) | Modular architecture: high cohesion, low coupling | Accepted |
| [ADR-0023](0023-technology-stack-rev3.md) | Technology stack rev.3 (version floors + Valkey) | Accepted |
| [ADR-0024](0024-local-dev-minikube.md) | Local/dev: Minikube only + *.gitsaas.test | Accepted |
| [ADR-0025](0025-modular-monolith.md) | Modular monolith (one app binary per plane) | Accepted |
| [ADR-0026](0026-service-based-target.md) | Target architecture: service-based (coarse services) | Accepted |
| [ADR-0027](0027-repo-topology-submodules.md) | Multi-repo source topology via git submodules | Accepted |
| [ADR-0028](0028-agdd-framework.md) | AGDD — AI-Agent Governance-Driven Development framework | Accepted |
| [ADR-0029](0029-imported-history-attested-provenance.md) | Imported history is attested, not audited — two-class provenance | Accepted |
| [ADR-0030](0030-extraction-trigger-budgets.md) | Extraction-trigger budgets for the modular monolith | Accepted |
| [ADR-0031](0031-merge-enforcement-split-rulesets.md) | Split merge enforcement — bind admins to checks, keep review bypassable | Superseded by ADR-0053 |
| [ADR-0032](0032-contract-schema-gates.md) | Gate the contract schema — lint + breaking checks on `contracts/` | Accepted |
| [ADR-0033](0033-git-storage-backing-block-volumes.md) | Live bare repos stay on block volumes — SeaweedFS-FUSE fails git's rename contract | Accepted |
| [ADR-0034](0034-image-pins-are-resolvable-patch-tags.md) | Image pins are fully-qualified, resolvable, patch-level tags | Accepted |
| [ADR-0035](0035-first-party-images-scratch-digest-signed.md) | First-party images: `scratch` base, digest-referenced, cosign-signed | Accepted |
| [ADR-0036](0036-resolvability-over-vendor-registry.md) | When a vendor registry cannot be verified, prefer the one that can | Accepted |
| [ADR-0037](0037-rdf-agent-surface-generation.md) | Agent surfaces are generated from governance (RDF canonical-first), not hand-maintained | Accepted |
| [ADR-0038](0038-governance-gplv2-vendor-rdf.md) | `governance` is GPL v2 and vendors RDF; the code repos' licence stays open | Superseded by ADR-0039 |
| [ADR-0039](0039-no-vendored-third-party-code.md) | Vendor no third-party code; the surface pipeline is ours and `governance` keeps GPL v2 by choice | Accepted |
| [ADR-0040](0040-apache-2-across-the-tree.md) | Apache-2.0 across the whole tree | Accepted |
| [ADR-0041](0041-git-http-ssh-front-doors.md) | Git HTTP and SSH front doors terminate in the data plane | Accepted |
| [ADR-0042](0042-replica-promotion-fencing.md) | Replica promotion uses monotonic fencing terms | Accepted |
| [ADR-0043](0043-credential-verifier-lookup.md) | Resolve opaque credential verifiers through a narrow RLS gateway | Accepted |
| [ADR-0044](0044-cosign-signing-key-custody.md) | Cosign signing-key custody and rotation for first-party images | Accepted |
| [ADR-0045](0045-zitadel-tenant-principal-mapping.md) | Zitadel verified claims map to tenant-scoped principals | Accepted |
| [ADR-0046](0046-platform-operator-force-promote-authz.md) | Platform-operator principals authorize replica force-promotion | Accepted |
| [ADR-0047](0047-first-party-image-distribution.md) | First-party release images are publicly pullable; trust is verified offline | Accepted |
| [ADR-0048](0048-git-storaged-image-base.md) | `git-storaged` ships on a minimal base with git, not `scratch` | Accepted |
| [ADR-0049](0049-bff-browser-session.md) | The browser session is an opaque server-side cookie the BFF owns | Accepted |
| [ADR-0050](0050-large-objects-over-seaweedfs-fuse.md) | Large objects (LFS, CI artifacts, container images) are served from a SeaweedFS FUSE mount | Accepted |
| [ADR-0051](0051-seaweedfs-mount-produced-by-node-daemonset.md) | The SeaweedFS FUSE mount is produced by one privileged node DaemonSet, not by a sidecar in each pod | Accepted |
| [ADR-0052](0052-bff-owns-its-session-store.md) | The BFF may open exactly one datastore — its own session store — behind a declared waiver | Accepted |
| [ADR-0053](0053-direct-to-main-ci-is-the-gate.md) | Work lands directly on `main`; CI on push is the only gate | Superseded by ADR-0054 |
| [ADR-0054](0054-main-guard-only.md) | `main` is guarded against rewrite and deletion, and against nothing else | Accepted |
| [ADR-0055](0055-audit-retention-attested-imported-records.md) | Audit retention: the chain never removes; attested history expires; a pack is a snapshot | Accepted |
| [ADR-0056](0056-owasp-aisvs-adoption.md) | OWASP AISVS — bound to the agentic SDLC and to AI-enabled features, at L3 with one named exception | Accepted |
| [ADR-0057](0057-ai-assisted-review-openai-compatible.md) | AI-assisted review via a tenant-configured OpenAI-compatible endpoint; AISVS L3 minus sender-constrained credentials | Accepted |
| [ADR-0058](0058-woodpecker-pipeline-format.md) | Adopt Woodpecker's pipeline format — the syntax, not the engine | Accepted |
| [ADR-0059](0059-ci-scan-results-to-findings.md) | How a CI scan's results reach the findings plane — the runner persists, a subscriber ingests | Accepted |
| [ADR-0060](0060-agent-enrolment-identity.md) | Agent identity: one-time enrolment token, control-plane-issued short-lived certificates | Accepted |
| [ADR-0061](0061-metering-authority.md) | The control plane is the authority for fair-use metering | Accepted |
| [ADR-0062](0062-durable-agent-residency-stores.md) | Durable Postgres stores for agent enrolment, registry and residency behind the existing ports | Accepted |
| [ADR-0063](0063-residency-declare-wire-surface.md) | Residency Declare is a control-plane admin gRPC surface; the agent channel never declares | Accepted |
| [ADR-0064](0064-agent-ca-key-custody.md) | Agent-CA keys in platform-secrets custody; rotation by staged trust bundle, no re-enrolment | Accepted |
| [ADR-0065](0065-multi-cluster-byo-readiness.md) | Multi-cluster BYO: signed operator image, N data planes per tenant, aggregate metering | Accepted |
| [ADR-0066](0066-openbao-control-plane-custody-service.md) | OpenBao as the control-plane custody service (agent-CA first consumer, transit signing, Shamir unseal) | Accepted |
| [ADR-0067](0067-platform-operator-residency-declaration.md) | A tenant-scoped platform operator may set a tenant's residency declaration (extends ADR-0046's role by one action) | Accepted |
| [ADR-0068](0068-redpanda-durable-issuance-retry.md) | Redpanda-backed durable issuance retry — a custody outage never interrupts enrolment (Phase 3.2 candidate; would supersede SPEC-0042 AC6's interim release-the-claim posture) | Proposed |
| [ADR-0069](0069-cvd-first-design-system.md) | The product design system is CVD-first, token-only and light by default — discharges ADR-0015's design-system follow-up; diffs become blue/orange with gutter markers | Accepted |
| [ADR-0070](0070-full-product-surface.md) | The prototype's six absent surfaces become product, gated by a route-before-pixel law — supersedes SPEC-0047's scope record; PR-24…PR-32 now in the PRD | Accepted |
| [ADR-0071](0071-repository-registry-durability.md) | The repository registry is durable and is the product's truth for existence — the Postgres adapter owed since T-0004; a repo on disk with no row is absent by consequence, not by defect | Accepted |
| [ADR-0072](0072-ci-job-history-and-logs.md) | CI keeps a durable job history; job logs are a separate decision it does not make — PR-26 is delivered in half, deliberately | Accepted |
| [ADR-0073](0073-tenant-policy-authoring.md) | Policy authoring needs a per-tenant policy source governance does not have; a tenant policy may only ever narrow | Accepted |

## Open follow-ups

Tracked *inside* the named ADR; promote to a new ADR when decided. Closed items are not kept here —
the deciding ADR is the record.

| Follow-up | ADR |
|---|---|
| The staleness bound for roles captured at login — the ADR fixes where roles live, not how often they are re-fetched | 0049 |
| The CSRF mechanism for browser-initiated writes. `SameSite=Lax` mitigates but does not close it, and the MR write surface must carry a defence | 0049 |
| Whether distributed artifacts need a `NOTICE` or an SBOM of third-party licences | 0040 |
| **No gate asserts an ADR's status matches what merging it meant.** Proposed on `main` is legitimate — an agent drafts a Proposed ADR and stops, and that ADR merges while it waits. The narrow defect: an ADR whose PR review *was* the approval should merge `Accepted`, and nothing distinguishes that from propose-and-stop. It is a question about intent, so it belongs in `.github/pull_request_template.md`, not in `check-docs.sh`. Has caught out ADR-0038, ADR-0039 and ADR-0040 | 0001 |
| The *toolchain* half of the version-floor gate — assert installed `go`/`node`/`tsc` meet their floors in CI. The *image* half closed as ADR-0034 | 0023 |
| Per-OS Minikube driver docs, and CI that exercises the dev-cluster flow itself | 0024 |
| Event catalog and naming — names exist as the protobuf full names of `contracts/events`, but nothing documents them | 0022 |
| Super-repo CI: fail on submodule pointers referencing unmerged commits | 0027 |
| Per-repo scaffolding + generated-type publishing (contracts → TS). Blocks **per-consumer** codegen gating: a consumer's `buf.gen.yaml` reads `../governance/contracts`, which exists only in the composition, so freshness is gated at the super-repo pin instead | 0027, 0028, 0032 |
| Meter audit-store and evidence-pack growth against the PRD §6 fair-use dimensions — retention is now unbounded by decision, and nothing measures it; ADR-0062 joined the agent and residency store tables to the same follow-up | 0055 |
| Whether an expired attested store leaves a marker distinguishable from "never imported" | 0055 |
| PRD revision adding AI-assisted review as **PR-24**, a roadmap placement, and an inference-volume fair-use dimension — the capability is Accepted with no requirement behind it | 0057 |
| Platform-wide tenant secret custody, expected to **supersede** ADR-0057 decision 5 once a second consumer (webhooks, registry, mirrors) exists — ADR-0066 records OpenBao as its presumptive home but authorizes no second consumer | 0057, 0066 |
| OpenBao pin-and-upgrade cadence: upstream maintains only its latest major, and 2.7 moves several built-in seals to plugins — a packaging change to track before it lands. An operational obligation with no end date, deliberately not a Phase 3.1 acceptance criterion | 0066 |
| Hardware-backed signing for the agent CA — OpenBao's External Keys RFC (transit/PKI keys backed by KMS/HSM) is Accepted upstream but not landed. A future compliance bar demanding it is a new decision on the same custody seam, not a change to ADR-0064's posture | 0066, 0064 |
| What the tenant-scoped `platform_operator` role may and may not accumulate — ADR-0046 confined it to one action, ADR-0067 added a second; the general rule is worth writing before a third arrives | 0046, 0067 |
| Door authentication and a server-derived tenant-pinning interceptor for the Phase-2 dataplane door — SPEC-0002's recorded limit (d). SPEC-0043 AC6 gives the new `residency/v1` surface a verified caller; whether that seam generalizes to the older doors is undecided | 0045, 0006 |
| How a non-deterministic producer's output may be cited as control evidence — until decided, AI review stays out of an evidence pack's scan-gate sections | 0057 |
| AISVS L3 obligations that do not exist yet: nonce-bound approvals (C9.2.8), per-execution budgets (C9.1.2), tool-definition snapshot with re-approval (C10.4.8), indirect-prompt-injection screening (C10.4.2), out-of-band kill switch (C9.6.3) — agent cryptographic identity (C9.4.1) closed by ADR-0060 + ADR-0064 | 0056, 0057 |
| Amend SPEC-0010 and SPEC-0020 (both Approved) for the pipeline format, publish the supported-construct subset, and file the implementing task | 0058 |
| Retention and fair-use metering of stored scan reports — SPEC-0037 bounds size and age, but nothing meters growth, and ADR-0055's retention rules do not cover a report (it is not an audit record) | 0059 |
| Whether to adopt Woodpecker's **engine** later — headless executor or Go library inside `modules/ci`. Not foreclosed by adopting the format | 0058 |
| HTTP/2 proxy fallback for a customer whose egress permits only a proxy — the remaining half of ADR-0017's follow-up; cert issuance closed by 0060 | 0017 |
| Unit-economics model per pricing tier — dimensions and derivation now fixed by 0061, prices still open | 0008 |
| Which PRD §6 dimensions are centrally derivable (storage and index size are sizes, not events) — SPEC-0041 states coverage; the rest is deferred and must not read as metered | 0061 |
| Teach `check-ceremony-tier.sh` to read the tier from a pushed commit, so SPEC-0012's declaration is checked rather than only written | 0053 |
| Whether a red `main` should notify anything beyond whoever pushed it | 0053 |
| First-party images are pinned by tag, not digest, in `deploy/dev` | 0035 |
