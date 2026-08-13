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
| Meter audit-store and evidence-pack growth against the PRD §6 fair-use dimensions — retention is now unbounded by decision, and nothing measures it | 0055 |
| Whether an expired attested store leaves a marker distinguishable from "never imported" | 0055 |
| Cert issuance and rotation (SPIFFE/SPIRE) + HTTP/2 proxy fallback | 0017 |
| Unit-economics model per pricing tier | 0008 |
| Teach `check-ceremony-tier.sh` to read the tier from a pushed commit, so SPEC-0012's declaration is checked rather than only written | 0053 |
| Whether a red `main` should notify anything beyond whoever pushed it | 0053 |
| First-party images are pinned by tag, not digest, in `deploy/dev` | 0035 |
