# Architecture Decision Records (ADRs) — Source of Truth

This directory is the **single Source of Truth (SOT)** for the architecture of the
Git SaaS platform. Every architecturally-significant decision lives here as an ADR.
**If any diagram, wiki, slide, design doc, or comment disagrees with an Accepted ADR, the ADR wins.**

Narrative context lives in `docs/architecture/`; the shared contracts in `contracts/`; the *decisions* live here.

## Format
ADRs use the Nygard/MADR style: *Status, Context, Decision, Consequences, Alternatives*.
One decision per file. See [`0000-template.md`](0000-template.md).

## Statuses
`Proposed` → `Accepted` → (`Superseded by ADR-XXXX` | `Deprecated`)

## Process (our decision governance — see ADR-0001 & ADR-0002)
1. Copy `0000-template.md` to `NNNN-title.md` (next number).
2. Open a pull request — **the PR review is the decision-approval gate** (see the repo PR template).
3. On merge, set status to `Accepted`. ADRs are immutable once Accepted.
4. To change a decision, add a **new** ADR that supersedes the old one (mark the old one
   `Superseded by ADR-XXXX`). Never rewrite history.

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
| [ADR-0031](0031-merge-enforcement-split-rulesets.md) | Split merge enforcement — bind admins to checks, keep review bypassable | Accepted |
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
| [ADR-0046](0046-platform-operator-force-promote-authz.md) | Platform-operator principals authorize replica force-promotion | Accepted |
| [ADR-0043](0043-credential-verifier-lookup.md) | Resolve opaque credential verifiers through a narrow RLS gateway | Accepted |
| [ADR-0044](0044-cosign-signing-key-custody.md) | Cosign signing-key custody and rotation for first-party images | Accepted |
| [ADR-0045](0045-zitadel-tenant-principal-mapping.md) | Zitadel verified claims map to tenant-scoped principals | Accepted |
| [ADR-0047](0047-first-party-image-distribution.md) | First-party release images are publicly pullable; trust is verified offline | Accepted |
| [ADR-0048](0048-git-storaged-image-base.md) | `git-storaged` ships on a minimal base with git, not `scratch` | Accepted |
| [ADR-0049](0049-bff-browser-session.md) | The browser session is an opaque server-side cookie the BFF owns | Proposed |
| [ADR-0050](0050-large-objects-over-seaweedfs-fuse.md) | Large objects (LFS, CI artifacts, container images) are served from a SeaweedFS FUSE mount | Proposed |

## Open follow-ups (tracked *inside* ADRs; promote to new ADRs when decided)
- ~~Licence for `backend`, `bff`, `webfrontend`, and the super-repo — ADR-0039 (was ADR-0038)~~
  **Closed — ADR-0040 (Proposed 2026-08-08): Apache-2.0 across the whole tree**, including
  relicensing `governance` off GPL v2. Apache-2.0 is compatible with the dependencies ADR-0006 (OPA)
  and ADR-0014 (Zoekt) mandate, which is the constraint that ruled out GPL v2, and its express patent
  grant matters for the binaries ADR-0009 and ADR-0013 hand to BYO customers. Still open inside
  ADR-0040: whether the distributed artifacts need a `NOTICE` or an SBOM of third-party licences.
- **No gate asserts an ADR's status matches what merging it meant.** Proposed on `main` is legitimate
  — `AGENTS.md` tells an agent to draft a Proposed ADR and stop, and that ADR merges while it waits.
  The defect is narrower: an ADR whose PR review *was* the approval should merge `Accepted`, and
  nothing in the file distinguishes that from propose-and-stop. It is a question about intent, so it
  lives in `.github/pull_request_template.md` rather than in `check-docs.sh`. Has caught out
  ADR-0038, ADR-0039 and ADR-0040 so far.
- CI job asserting installed versions meet the floors — ADR-0023. **Split by T-0003's cluster run.**
  The *image* half is now **ADR-0034 (Accepted 2026-08-06)**: `redpandadata/redpanda:v26.1` was never a published
  tag, because a floor written as a bare minor is not a pullable pin. Still open here: the *toolchain*
  half — asserting installed `go`/`node`/`tsc` meet their floors in CI.
- `make dev-up` Minikube bootstrap + per-OS driver docs — ADR-0024
- Event catalog/naming — ADR-0022. The boundary-enforcement linter shipped in T-0002/T-0009; event
  names are the protobuf full names of `contracts/events` (T-0008), but no catalog documents them.
- Event catalog naming remains open (above). Service-extraction triggers are **closed**: measured
  by T-0009, budgeted by ADR-0030 (Accepted), gated on every backend CI run.
- Super-repo CI: fail on submodule pointers referencing unmerged commits — ADR-0027
- Per-repo scaffolding + generated-type publishing (contracts → TS) — ADR-0027/0028
- Contract schema gate — **ADR-0032 Accepted**, **T-0020 Done 2026-08-06**. `buf lint` and
  `buf breaking` (baseline: tip of `main`, category `FILE`) are required in governance CI, and the
  super-repo requires generated code to match its pinned contracts. Still open, and now the only
  part: **per-consumer** codegen gating, which needs the generated-type publishing follow-up above —
  a consumer's `buf.gen.yaml` reads `../governance/contracts`, which exists only in the composition.
- ~~Repo backing: SeaweedFS-FUSE vs block volumes — benchmark, may amend ADR-0016 — ADR-0020/0023~~
  **Closed — benchmarked (T-0007) → ADR-0033 Accepted 2026-08-06**: block volumes confirmed; ADR-0016 needs
  no amendment. SeaweedFS-FUSE fails `rename()` atomicity, which git requires for every ref update —
  36 of 428 concurrent ref reads missed a ref that always existed, with zero rename errors. Evidence:
  `../bench/T-0007/README.md`.
- Replica promotion fencing and operator-only force-promote — **ADR-0042 Accepted**; T-0012 may enter contract work.
- Platform-operator tenant bindings for `replica.force_promote` — **ADR-0046 Accepted** (2026-08-10); review required before T-0012 contract or policy implementation.
- Cert issuance/rotation (SPIFFE/SPIRE) + HTTP-2 proxy fallback — ADR-0017
- Unit-economics model per pricing tier — ADR-0008
- Merge enforcement — ADR-0031. Two follow-ups are **closed** (both 2026-08-05): the
  second-org-member one (`main-review` bypass emptied, four-eyes review binding on owners) and the
  `webfrontend` one (it now has a CI workflow, required in its `main-integrity` as
  `build + typecheck + test + arch gates`, so every repo has a check to fail on). Still open: the two
  rulesets are five per-repo copies because org-level rulesets need GitHub Team — `make
  rulesets-check` in the super-repo is what catches drift.
