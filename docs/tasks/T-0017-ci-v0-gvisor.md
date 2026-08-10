# T-0017: CI v0: gVisor sandbox runner + KEDA

- **Status:** In progress — backend #29
- **Phase / Epic:** 1 / MVP
- **Repo(s):** backend (ci + runner)
- **Spec:** docs/specs/SPEC-0010-ci-ephemeral-isolation.md
- **ADRs:** 0005, 0012
- **Owner:** unassigned

## Goal
Run pipelines in ephemeral, per-job gVisor sandboxes that autoscale.

## Acceptance criteria (test-first)
- [ ] AC1: a job runs in an **ephemeral** gVisor-isolated sandbox and is destroyed after (invariant 3).
- [ ] AC2: runners scale on queue depth via KEDA.
- [ ] AC3: a job cannot access another tenant's data or the host (isolation test).

## Tests to write first
- integration: job lifecycle + teardown; isolation: cross-tenant/host escape attempts denied.
- unit: scheduling/queue logic.

## Definition of Done
See `../process/definition-of-done.md`.

## Progress record

| Repo | Commit | What |
|---|---|---|
| backend | `e53b6ee` (#29) | `modules/ci`: tenant-scoped job lifecycle, PDP-gated immutable enqueue, `RefUpdated` subscriber; per-attempt sandbox model; Kubernetes Job adapter behind a `Client` port; dispatch loop with claim-once and the `ci_queued_jobs` gauge; `cmd/dataplane-app` composition, gRPC registration, and the metrics listener. |

- **AC1** — the sandbox model, the Job spec, and the destroy-and-confirm path are implemented and
  tested (`modules/ci/internal/runner`, `modules/ci/internal/adapters/k8s`). **Not yet proven in a
  cluster:** the `Client` port has no client-go implementation, so the plane wires the dev launcher.
- **AC2** — the metric KEDA scales on is served and the loop that publishes it is tested. **The
  `ScaledObject` is still missing**, and cannot be written honestly until `deploy/dev/` has a plane
  Deployment for it to target.
- **AC3** — covered: job reads and cancellation are tenant-scoped and coarse; host namespaces,
  service-account tokens, privilege escalation, host paths, and non-ephemeral volumes are each
  refused with a test, at both the model and the cluster boundary.

## Notes / open questions
Write the SPEC in `governance/docs/specs/` and get it Approved before RED (AGDD).
Cross-repo changes follow the ADR-0027 order (governance first).
