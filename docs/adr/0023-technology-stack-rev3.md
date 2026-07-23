# ADR-0023: Technology stack (rev. 3) — version floors + Valkey

- **Status:** Accepted
- **Date:** 2026-07-19
- **Supersedes:** ADR-0020
- **Governs:** operability, security, developer experience
- **Relates to:** ADR-0022 (modules), ADR-0024 (dev env)

## Context
We want to run on current releases and remove Redis (licensing/community concerns). This
ADR pins minimum-supported versions and swaps the cache/session store.

## Decision
Unchanged from rev.2 (ADR-0020): request path `browser → Astro+React SSR (Node thin proxy)
→ Go BFF → gRPC → Go services`; Go backend; Zitadel; Redpanda; PostgreSQL + RLS; SeaweedFS
(S3 for blobs); OPA/Rego; Zoekt; gVisor CI sandboxes.

**Changes:**
1. **Replace Redis with Valkey** (Linux Foundation fork; open governance) for cache/sessions.
2. **Pin minimum versions (floors), targeting latest:**

| Component | Min version | Runs as |
|---|---|---|
| Go | **1.26** | host toolchain (`go.mod: go 1.26`) |
| Node.js | **26** | host + SSR runtime (`package.json engines`) |
| TypeScript (tsc) | **7** | build — native compiler |
| PostgreSQL | **18** | service (image) |
| Valkey | **9.1** | service (image) — *replaces Redis* |
| Redpanda | **26.1** | service (image) |
| SeaweedFS | **4.40** | service (image) |
| git | **2.x** | host toolchain |

**Materialization (single sources of truth):**
- Host tools → `.tool-versions` (asdf/mise).
- Service image tags → `deploy/dev/versions.env`.
- `go.mod` (`go 1.26`) and `package.json` `engines` mirror the floors.

## Consequences
**Positive:** modern, supported runtimes; Valkey removes the Redis licensing concern and is
protocol-compatible (existing clients such as go-redis work unchanged); TypeScript 7's native
compiler gives much faster type-checking/builds.
**Negative / watch-outs:**
- **TS 7 native compiler**: verify type-checking plugins / `ts-node`-style tooling compat.
- **Valkey**: confirm no reliance on Redis-module features that differ; validate client libs.
- Several floors are **recent/at or just past the Jan-2026 knowledge boundary** — recorded as
  specified; **pin exact patch releases and confirm availability at build time.**
**Follow-ups:** add a CI job asserting installed versions meet the floors.

## Alternatives considered
- **Keep Redis** — rejected (licensing/community direction; Valkey is the drop-in successor).
- **Looser/older floors** — rejected; goal is to run current releases.
