# ADR-0020: Technology stack (rev. 2)

- **Status:** Superseded by ADR-0023
- **Date:** 2026-07-19
- **Supersedes:** ADR-0019
- **Governs:** all objectives; operability, developer experience
- **Relates to:** ADR-0003/0004/0006/0007/0008/0014/0015/0016/0017

## Context
ADR-0019 set an initial stack. The team has refined the frontend request path, the
streaming layer, and the storage layer. This ADR records the agreed stack and the deltas.

## Decision

**Frontend + edge request path**
`browser → Astro + React (SSR, on Node — thin proxy) → Go BFF → gRPC → Go services`
- **Astro + React (islands), server-side rendered** on Node.
- A **thin Node proxy** hosts SSR and forwards data/API calls to a **Go BFF**.
- The **Go BFF** aggregates **gRPC** calls to Go domain services.

**Backend / platform** — Go (unchanged from 0019), Kubernetes-native.

**Identity** — **Zitadel** (unchanged).

**Streaming / messaging** — **Redpanda** (Kafka-API compatible, single binary, no ZooKeeper/
JVM) for the event bus, CI queue, audit/event streams, and usage metering. *Replaces* the
NATS JetStream choice in ADR-0019.

**Datastores** — **PostgreSQL** (row-level security, ADR-0003) + **Redis** (cache/sessions).

**Object storage & file backing** — **SeaweedFS**:
- **SeaweedFS-S3** for LFS, CI artifacts, and registry blobs (strong fit, self-hostable → good for BYO).
- **SeaweedFS + FUSE/filer** available for POSIX access where needed (see risk below).

Scanners (Trivy/Semgrep/Gitleaks/ZAP/Syft-Grype), policy (OPA), and code search (Zoekt)
are unchanged from the prior ADRs.

## Consequences
**Positive:** Astro SSR → fast first paint + server-rendered pages; clean Node-SSR / Go-BFF
separation; Redpanda gives durable, Kafka-compatible log semantics (well suited to audit and
usage streams) with lighter ops than Kafka; SeaweedFS unifies object + file storage and is
cheap to self-host.

**Negative / risks:**
- **Git on FUSE-mounted SeaweedFS is the main risk.** Git is highly sensitive to filesystem
  latency and POSIX semantics (many small-file ops, locks, atomic renames, fsync). Bare repos
  on a FUSE distributed FS can be slow and risk correctness, and it complicates the sync-replica
  + failover design in **ADR-0016** (which assumed fast local block volumes + Raft).
  **Recommendation:** use **SeaweedFS-S3 for blobs** and keep **live bare git repos on fast
  block volumes** per ADR-0016 — or benchmark the FUSE/filer path under real Git load *before*
  committing, and amend ADR-0016 accordingly.
- Two runtimes at the edge (Node + Go) — slightly more to operate than a single BFF.
- Redpanda is heavier operationally than NATS (though lighter than Kafka).

**Follow-ups:** benchmark Git on SeaweedFS-FUSE vs block volumes and record the outcome
(may amend ADR-0004/0016); confirm Astro islands cover heavily-interactive views (diff,
editor, boards).

## The knob left for you
- **Repo storage backing:** SeaweedFS-FUSE vs fast block volumes. Default recommendation:
  block volumes for live repos, SeaweedFS-S3 for blobs. Decide (and possibly amend ADR-0016)
  once benchmarked.

## Alternatives considered
- **Vite SPA / Next.js** (ADR-0019) — Astro chosen for SSR performance + islands model.
- **NATS JetStream** (ADR-0019) — Redpanda chosen for Kafka compatibility + durable log.
- **Cloud-native object storage only** — SeaweedFS chosen for a unified, self-hostable store.
