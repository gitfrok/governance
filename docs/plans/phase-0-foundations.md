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
10. **Contract schema gates** (T-0020) → depends on T-0001 (which wired `contracts/` + per-consumer
    codegen); parallel with everything after it. Filed 2026-08-06 under EP-9, after this plan was
    first written — which is why it sits out of dependency order at the end of the list. It is the
    workstream that makes the *contract* half of the exit criteria below real: until it landed,
    `ci-gates.md` required a contract-schema check that existed in no repo (ADR-0032).

Statuses are not repeated here — each task file's own `Status:` field is authoritative
(`../tasks/README.md` indexes them).

## Critical path
T-0001 → T-0003 → T-0004; T-0007 runs alongside and must finish before Phase-1 storage tasks.
T-0020 is off the critical path: nothing in Phase 0 waits on it, but Phase 0 cannot exit without it.

## Risks
- Version availability (ADR-0023 floors near knowledge boundary) — verify at setup.
- Benchmark result could force a storage redesign — that's why it's in Phase 0, not later.

## Exit criteria
All **ten** Phase-0 tasks Done; CI runs unit + contract + boundary + policy/isolation +
fitness-function tests green; `make dev-up` brings the stack up on `*.gitsaas.test`.

Which workstream satisfies which half of that CI line, since "runs green" is easy to assume and was
not true of one of them for a long time: boundary + fitness → T-0002/T-0009 (done); **contract** →
T-0020 (done — `buf lint` + `buf breaking` in governance, generated-code freshness in the super-repo);
unit + policy/isolation → T-0004/T-0005/T-0006 (open); `make dev-up` → T-0003 (open, and never yet
run on a cluster).
