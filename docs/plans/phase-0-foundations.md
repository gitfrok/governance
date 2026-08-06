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
unit + policy/isolation → T-0004/T-0005/T-0006 (**done 2026-08-06** — T-0005 closed the policy half
with `opa test` + a deny-by-default assertion in governance, the PDP adapter and AC4 fitness
function in backend, the PEP in bff, and a composition gate in the super-repo); `make dev-up` →
T-0003 (**open**, and the only thing standing between Phase 0 and its exit).

**Where Phase 0 actually stands.** Nine of ten tasks are Done. T-0003 is the exception, and what
remains of it is not code: AC1's cluster-create path and AC3's `*.gitsaas.test` routing need a host
with a rootful container driver or KVM, and AC4's macOS half needs a macOS. Its AC2 and AC4-on-Linux
are verified. The plan's own recorded risk — *"version availability … verify at setup"* — is what
that task spent itself on.

One item was added to T-0003 by T-0005 and is worth naming here so it is not lost: the data plane
now requires `GITFROK_POLICY_BUNDLE_DIR` and exits without it, and nothing in `deploy/dev` mounts
the bundle yet. A bring-up on the manifests as they stand would start a plane that immediately
exits. That is a manifest change, not a host problem, and it is the one part of T-0003 that can be
finished anywhere.
