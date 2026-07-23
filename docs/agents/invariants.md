# Invariants — hard rules. Violating any of these fails review.

## Security & tenancy
1. **Every query is tenant-scoped** (`tenant_id`), with Postgres RLS as backstop —
   both, always (ADR-0003, G1).
2. **AuthZ goes through the PDP (OPA), deny-by-default.** No inline permission logic
   (ADR-0006, G2).
3. **CI jobs run in one ephemeral isolated sandbox each** (gVisor RuntimeClass on BYO);
   never shared, never reused (ADR-0005/0012).
4. **Search results are permission-filtered** before return (ADR-0014).

## Data integrity
5. **Audit events are append-only** — no update/delete path exists, hash chain preserved
   (ADR-0007, G5).
6. **A push is acked only after primary + 1 sync replica are durable.** Only the in-sync
   replica may auto-promote; dual loss → read-only + audited operator override, never
   auto-promote stale (ADR-0016/0018).
7. **Live bare repos live on fast block volumes, not FUSE/SeaweedFS**, unless the
   benchmark follow-up in ADR-0020 concludes otherwise and ADR-0016 is amended.
   SeaweedFS-S3 is for LFS/artifacts/registry blobs.

## Agent & wire protocol
8. **No source code or secrets ever traverse the agent↔CP stream** (ADR-0011/0017, G9).
9. **The agent applies only signed releases** it verifies (cosign) — CP cannot push
   arbitrary code (ADR-0017).
10. **Proto v1 is additive-only**: never change/reuse field numbers or types; reserve
    removed tags; enums keep `*_UNSPECIFIED = 0` (`contracts/README.md`).

## Process
11. **`docs/adr/` is the SOT.** Accepted ADRs are immutable; change = superseding ADR
    (ADR-0001). ADR-0019 is superseded — follow ADR-0020.
12. **Undecided significant choices → `Proposed` ADR + ask**, don't decide silently.
13. Config (hostnames, OIDC redirect URIs) is **per-environment**, never hard-coded
    (`*.gitsaas.test` dev / real domains prod) (ADR-0024).

## Cohesion, coupling & deployment (ADR-0022, ADR-0025, ADR-0026)
14. **No module imports another module's `internal/*`.** In-process, cross-module access is via
    the target's `api` package or the in-process bus (ADR-0025); cross-process only via
    `contracts/` (gRPC/events) (ADR-0022). Go's `internal/` enforces this.
15. **No cross-context database access** — each context owns its schema; get other contexts'
    data via API or event-fed projections (refines ADR-0003).
16. **`domain` imports no infrastructure** (no pg/redpanda/http/opa/zitadel) — infra sits
    behind ports; dependencies point inward (adapters → app → domain).
17. **Prefer events over synchronous calls** for cross-context reactions; sync only when a
    direct response is required.
18. **BFF has no business logic** (aggregation/shaping only).
19. **One app binary per plane** (`cmd/dataplane-app`, `cmd/controlplane-app`); modules are
    packages, not services. The only separate app processes are `git-storaged`, CI runners,
    the agent, and the operator (ADR-0025).
20. **A module's `api/` exposes no infrastructure types**, and extracting a module into a service
    must not change its callers — extract only on an ADR-0026 trigger.

## Repository topology & submodules (ADR-0027, ADR-0028)
21. **Governance is the only home for decisions & shared surface** — ADRs, specs, invariants,
    `contracts/`, and `policies/` change **only** in the `governance` repo. Never fork them elsewhere.
22. **Dependency direction is one-way:** `webfrontend → bff → backend → governance(contracts)`;
    **governance depends on nothing.** No repo imports another repo's internals; `webfrontend`
    never calls `backend` directly.
23. **Confirm which submodule you are in before editing; one commit never spans two submodules.**
24. **Cross-repo changes are ordered:** governance PR (additive) → consumer bumps governance
    pointer + implements → super-repo bumps submodule pointers to **merged** commits only.
25. **The super-repo stores pinned submodule commits only** — never in-place edits to a submodule path.
