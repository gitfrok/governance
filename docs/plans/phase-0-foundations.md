# Plan — Phase 0: Foundations

## Objective
A wired skeleton where a tenant-scoped, policy-checked, audited request runs end-to-end in
Minikube, with boundaries enforced in CI and the storage question settled.

## Workstreams & sequence
1. **Scaffolding** (T-0001) → unblocks everything.
2. **Boundary enforcement in CI** (T-0002) → depends on T-0001; keeps HCLC honest from commit 1.
3. **Dev environment** (T-0003) → parallel with 1–2; needed to run anything.
4. **Tenancy + RLS** (T-0004) → depends on T-0003 (DB up); foundational for all data.
5. **PDP skeleton** (T-0005) → depends on T-0001; consumed by all request paths.
6. **Audit log** (T-0006) → depends on T-0001; sink for all sensitive actions.
7. **Storage benchmark** (T-0007) → parallelizable; **gates** the Phase-1 git-storage design
   (may amend ADR-0016).
8. **In-process bus + module `api` convention** (T-0008) → depends on T-0001; the modular-monolith seam (ADR-0025).
9. **Architecture fitness functions** (T-0009) → depends on T-0002; proves extraction-readiness (ADR-0026).

## Critical path
T-0001 → T-0003 → T-0004; T-0007 runs alongside and must finish before Phase-1 storage tasks.

## Risks
- Version availability (ADR-0023 floors near knowledge boundary) — verify at setup.
- Benchmark result could force a storage redesign — that's why it's in Phase 0, not later.

## Exit criteria
All Phase-0 tasks Done; CI runs unit + contract + boundary + policy/isolation + fitness-function tests green;
`make dev-up` brings the stack up on `*.gitsaas.test`.
