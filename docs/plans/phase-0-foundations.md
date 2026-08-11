# Plan — Phase 0: Foundations

**Status:** **Complete (2026-08-09)**
**Objective:** a wired foundation — Minikube with real TLS, tenant-scoping, deny-by-default policy and
append-only-audit seams, boundaries enforced in CI, and the storage question settled.

## Workstreams & sequence

1. **Scaffolding** (T-0001) — unblocks everything.
2. **Boundary enforcement in CI** (T-0002) — keeps HCLC honest from commit 1.
3. **Dev environment** (T-0003) — parallel with 1–2; needed to run anything.
4. **Tenancy + RLS** (T-0004) — depends on the database being up.
5. **PDP skeleton** (T-0005) — consumed by every request path.
6. **Audit log** (T-0006) — sink for all sensitive actions.
7. **Storage benchmark** (T-0007) — parallel; **gated** the Phase-1 git-storage design.
8. **In-process bus + module `api` convention** (T-0008) — the modular-monolith seam (ADR-0025).
9. **Architecture fitness functions** (T-0009) — proves extraction-readiness (ADR-0026).
10. **Contract schema gates** (T-0020) — filed later under EP-9, which is why it sits out of dependency
    order; it made the *contract* half of the exit criteria real, since `ci-gates.md` had required a
    check that existed in no repo (ADR-0032).

**Critical path:** T-0001 → T-0003 → T-0004, with T-0007 alongside and finishing before any Phase-1
storage task. Statuses live in each task file (`../tasks/README.md` indexes them).

## Exit criteria — all met

All ten tasks Done; CI green on unit + contract + boundary + policy/isolation + fitness tests;
`make dev-up` brings the stack up on `*.gitsaas.test`.

Which workstream satisfied which half of that CI line: boundary + fitness → T-0002/T-0009; **contract**
→ T-0020 (`buf lint` + `buf breaking` in governance, generated-code freshness in the super-repo); unit
+ policy/isolation → T-0004/T-0005/T-0006; `make dev-up` → T-0003, whose four acceptance criteria were
all verified on 2026-08-09, including a real macOS run.

The end-to-end policy-checked request needs T-0021's plane images, so it is a **Phase-1** deployment
milestone rather than a Phase-0 exit criterion. Phase 0 closed on the foundation it delivered.

## Risks, and what they cost

The recorded risk — *version availability against ADR-0023's floors* — is what the 2026-08-06 cluster
run spent itself on: seven manifest fixes, including a Redpanda tag that was never published.

Two risks this plan never recorded fired anyway, and both belong in the register for later phases:

- **Host configuration.** `fs.inotify.max_user_instances` at a mainstream distro's default was low
  enough to stop the one-command bring-up, invisible to every static check, and findable only by
  running the create path on a machine nobody had run it on.
- **Printed operator instructions are untested code.** The host-DNS snippet had been in the tree since
  the first bring-up and was quoted in three documents as the thing left to do. It described a DNS
  *forwarder* aimed at an address with no nameserver on it, so following it broke `.test` resolution
  rather than wiring it. Nobody had run it.

Both AC1 and AC3 had been recorded as host limits — "needs a rootful driver or KVM" — when each was a
defect. AC1 needed a sysctl **and** a `--container-runtime` flag `dev-up.sh` had never passed; AC3
needed the node's 80/443 published, plus a resolver whose instructions were wrong. Written up in
`../tasks/T-0003-minikube-dev-env.md`.
