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
T-0003 (**open on its macOS criterion only**, as of 2026-08-08 — the `*.gitsaas.test` half of this
line is verified).

**Where Phase 0 actually stands.** Nine of ten tasks are Done. T-0003 is the exception, and as of
2026-08-08 one acceptance criterion of it remains:

| AC | State |
|---|---|
| AC1 — cluster create | **Verified.** Needed `fs.inotify.max_user_instances` raised (one `sysctl`, root) and three defects fixed in `dev-up.sh`'s create branch |
| AC2 — services from pinned manifests | **Verified.** Six deployments Available on pins from `versions.env` |
| AC3 — `*.gitsaas.test` from the host | **Verified.** Every host the ingress declares resolves by name and answers over TLS, on rootless podman, with no rootful driver and no KVM |
| AC4 — macOS half | **Open.** No macOS. Anyone can close it by running the scripts on a Mac |

The two rows this table used to carry as blockers were both retired by evidence rather than by a
different machine, and each had been recorded as a host limit when it was a defect. AC1 wanted a
sysctl *and* a `--container-runtime` flag `dev-up.sh` had never passed. AC3 was called "needs a
rootful driver or KVM"; what it actually needed was the node's 80/443 published, and then a
resolver that the script's own printed instructions had been describing incorrectly — they gave a
DNS *forwarder* aimed at an address with no nameserver on it. Both are written up in
`../tasks/T-0003-minikube-dev-env.md`.

The plan's recorded risk — *"version availability … verify at setup"* — is what the 2026-08-06 run
spent itself on; the 2026-08-08 create-path attempt fired a risk this plan never recorded, **host
configuration**, which is worth adding to the register for Phase 1: a limit low enough on a
mainstream distro to stop the one-command bring-up, invisible to every static check, and findable
only by running the path on a machine nobody had run it on. The AC3 story adds a second entry for
that register — **printed operator instructions are untested code**. The DNS snippet had been in the
tree since the first bring-up, was quoted in three documents as the thing left to do, and had never
once been run.

The item T-0005 added to T-0003 — the missing policy bundle — is **done as of 2026-08-08**, though
not as described. Its premise was wrong: it said a bring-up would "start a plane that immediately
exits" for want of `GITFROK_POLICY_BUNDLE_DIR`, but `deploy/dev` has no dataplane manifest and
`backend/` has no Dockerfile, so there was no pod to exit. The bundle genuinely was missing, so the
conclusion held for the wrong reason. `dev-up` now generates it as a ConfigMap from
`governance/policies` — read from the submodule rather than committed, so governance stays its only
author (invariants 13, 21) — verified by mounting it and evaluating the real policy to `allow: true`.
Nothing consumes it yet, and cannot until a dataplane image exists.

**That last point is the one Phase-0 gap nobody had filed — now T-0021, in Phase 1.** Neither plane
has a container image or a Dockerfile, so "a tenant-scoped, policy-checked, audited request runs
end-to-end in Minikube" is not reachable by any amount of work on T-0003, whose acceptance criteria
are about infrastructure and TLS. It is filed as **T-0021 under EP-10**, phased into 1 by direction.

**Which leaves this plan's exit criterion depending on a Phase-1 task, and that is not resolved.**
The criterion below is written in terms of an end-to-end request; T-0021 is what makes one possible;
T-0021 is Phase 1. So Phase 0 as specified cannot close on Phase-0 work alone — an inversion of the
rule in `../roadmap/README.md` that each phase meets an exit criterion before the next begins.

The three ways out are enumerated in `../tasks/T-0021-container-images.md` (amend this plan's exit
criterion to what Phase 0 actually built; or move T-0021 into Phase 0; or accept the inversion in
writing). Amending an exit criterion is a reviewed change rather than something a task file absorbs,
so nothing here is amended yet — this paragraph exists so the gap cannot be mistaken for closed.
T-0021's own blocker is gone: its AC0 is met by **ADR-0035 (Accepted 2026-08-08)**, so the task is
ready to start. That does not close this gap — the conflict is about which *phase* owns the
end-to-end assertion, and no amount of progress on T-0021 answers it.
