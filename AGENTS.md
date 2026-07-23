# AGENTS.md — governance repo (canonical engineering rules)

`governance` is the **control surface** for AGDD (ADR-0028): ADRs (SoT), specs, `contracts/`,
`policies/`, process, invariants, and these rules. **Everything depends on this repo; it depends
on nothing.** (Super-repo overview: `../AGENTS.md`.)

## Read order
1. This file.
2. `docs/agents/context.md` — condensed architecture + G1–G9.
3. `docs/agents/invariants.md` — hard rules **1–25** (never violate).
4. `docs/process/agdd.md`, `agentic-sdlc.md`, `spec-driven-development.md`, `tdd.md`.
5. `docs/architecture/04-repository-topology.md` — the submodule split + workflow.
6. Pick work: `docs/roadmap/` → `docs/backlog/` → `docs/tasks/T-####.md`; then its **spec**
   (`docs/specs/`), the **ADRs** it cites (`docs/adr/`), and `docs/process/definition-of-done.md`.

## Source of Truth
`docs/adr/` is SoT (ADR-0001). Accepted ADRs are immutable — supersede, don't edit. The only
shared cross-repo surface is `contracts/`. New significant decision no ADR covers → draft a
**Proposed ADR and STOP**. New behavior no spec covers → write the **spec first**.

## Working agreements
- **TDD always**; **spec-first**; small PRs; every PR meets `.github/pull_request_template.md`
  + `docs/process/definition-of-done.md`.
- Contracts & policies change **only here**, additive-only within v1 (`contracts/README.md`).
- Where you implement code you'll be in `backend/`, `bff/`, or `webfrontend/` — read that repo's
  `AGENTS.md` too; **governance stays SoT** and the dependency direction (invariant 22) holds.

## Architecture quick reference
- Runtime: **modular monolith, one binary per plane** (ADR-0025) — `backend/cmd/{dataplane,controlplane}-app`;
  modules interact via each other's `api/` package or the in-process bus; everything else under
  `internal/` (Go-unimportable). Target: coarse **services** on a trigger (ADR-0026).
- Path: `browser → Astro/React SSR (webfrontend) → Go BFF (bff) → gRPC → Go modules (backend)`.
- Stack (ADR-0023): Go 1.26 • Node 26 • tsc 7 • PostgreSQL 18 + RLS • Valkey 9.1 • Redpanda 26.1 •
  SeaweedFS 4.40 (S3 for blobs; **FUSE not for live repos**) • OPA/Rego • Zoekt • gVisor CI • git ≥2.
- Dev: **Minikube only**, `*.gitsaas.test`, mkcert TLS (ADR-0024).

## What NOT to do
- Don't edit Accepted ADRs (supersede). Don't skip the spec or the tests.
- Don't change `contracts/`/`policies/` anywhere but here; keep them additive within v1.
- Don't import another module's `internal/*` — cross-module via `api/`/bus; cross-process via `contracts/`.
- Don't read another module's DB tables; don't put business logic in the BFF; don't put infra in `domain`.
- Don't cross a submodule boundary in one commit; don't let `webfrontend` call `backend` directly.
- Don't bypass the PDP; don't write un-tenant-scoped queries; don't put code/secrets on the
  agent↔CP stream; don't mutate/delete audit events; don't split a module into a service without an ADR-0026 trigger.
