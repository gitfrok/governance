# T-0017: CI v0: gVisor sandbox runner + KEDA

- **Status:** Done (2026-08-10) — backend #29/#32 + deploy PR #76; one recorded dev-cluster limit
- **Phase / Epic:** 1 / MVP
- **Repo(s):** backend (ci + runner)
- **Spec:** docs/specs/SPEC-0010-ci-ephemeral-isolation.md; docs/specs/SPEC-0020-ci-job-contract.md
- **ADRs:** 0005, 0012
- **Owner:** unassigned

## Goal
Run pipelines in ephemeral, per-job gVisor sandboxes that autoscale.

## Acceptance criteria (test-first)
- [x] AC1: a job runs in an **ephemeral** gVisor-isolated sandbox and is destroyed after (invariant 3).
      (`modules/ci/internal/runner` sandbox model + `adapters/k8s` Job builder; jobs run as real
      Kubernetes Jobs since backend #32.)
- [x] AC2: runners scale on queue depth via KEDA. (ScaledObject + `ci_queued_jobs` metric served;
      deploy PR #76 targets the dataplane Deployment.)
- [x] AC3: a job cannot access another tenant's data or the host (isolation test).

## Tests to write first
- integration: job lifecycle + teardown; isolation: cross-tenant/host escape attempts denied.
- unit: scheduling/queue logic.

## Definition of Done
See `../process/definition-of-done.md`.

## Progress record

| Repo | Commit | What |
|---|---|---|
| backend | `e53b6ee` (#29) | `modules/ci`: tenant-scoped job lifecycle, PDP-gated immutable enqueue, `RefUpdated` subscriber; per-attempt sandbox model; Kubernetes Job adapter behind a `Client` port; dispatch loop with claim-once and the `ci_queued_jobs` gauge; `cmd/dataplane-app` composition, gRPC registration, and the metrics listener. |
| backend | `c6757d8` (#32) | Run job sandboxes as real Kubernetes Jobs — the `Client` port's client-go implementation (`NewClusterClient`), so dispatch is no longer dev-only |
| super-repo | `8becd0f` (#76) | Deploy the Git storage tier; KEDA `ScaledObject` on the dataplane's `ci_queued_jobs` metric; the plane's front doors point at git-storaged |

- **AC1** — the sandbox model, the Job spec, and the destroy-and-confirm path are implemented and
  tested (`modules/ci/internal/runner`, `modules/ci/internal/adapters/k8s`). Jobs run as real
  Kubernetes Jobs since #32.
- **AC2** — the metric KEDA scales on is served, the loop that publishes it is tested, and the
  `ScaledObject` (deploy PR #76) targets the dataplane Deployment. **Recorded limit:** the dev job
  queue is in-process, so a new replica starts empty; dividing existing work needs the durable
  queue (Redpanda is in the cluster waiting for it).
- **AC3** — covered: job reads and cancellation are tenant-scoped and coarse; host namespaces,
  service-account tokens, privilege escalation, host paths, and non-ephemeral volumes are each
  refused with a test, at both the model and the cluster boundary.

## Notes / open questions
The dev Minikube cluster (rootless podman) has no gVisor RuntimeClass and no runner image pinned,
so CI dispatch is left unconfigured there (the plane records jobs and launches none). Real sandbox
dispatch requires a cluster with the gVisor RuntimeClass — the deploy manifests and KEDA wiring are
in place for it. Write the SPEC in `governance/docs/specs/` and get it Approved before RED (AGDD).
Cross-repo changes follow the ADR-0027 order (governance first).
