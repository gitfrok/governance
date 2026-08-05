# ADR-0034: Image pins are fully-qualified, resolvable, patch-level tags

- **Status:** Proposed
- **Date:** 2026-08-06
- **Deciders:** platform
- **Governs:** G7 process integrity (a pin that cannot be pulled is not a pin)
- **Relates to:** ADR-0023 (stack + version floors — **refined, not superseded**), ADR-0024 (dev env) ·
  **Invariants:** 13 (reproducible builds/pins) · **Tasks:** T-0003 (found this), T-0007 ·
  **Closes:** the ADR-0023 "CI job asserting installed versions meet the floors" follow-up, image half

## Context

ADR-0023 records the stack as **version floors** — "PostgreSQL 18 • Valkey 9.1 • Redpanda 26.1 •
SeaweedFS 4.40" — and `deploy/dev/versions.env` turns those floors into container image tags. Nothing
said how. T-0003's first real cluster run showed the gap, and it was not academic:

**`redpandadata/redpanda:v26.1` was never a published tag.** The pod stayed in `ErrImagePull` with
*"failed to resolve reference … not found"*. The v26.1 **series** exists — v26.1.2 through v26.1.14 —
but Redpanda publishes patch-level tags only. A floor written as a bare minor had been transcribed
into a pin that no registry could ever serve. It survived review, `check-dev-images.sh` (which
compares manifest text to `versions.env` — both were equally wrong), and a merged PR, because nothing
had tried to pull it.

Two further facts from the same run:

- **`ZITADEL_IMAGE=ghcr.io/zitadel/zitadel:latest`** is still floating. `check-dev-images.sh` has
  warned about it since T-0003 was written, and the warning has been carried rather than acted on. The
  cluster resolved it to **v4.16.2** (`sha256:4b68a210…`), so today's "latest" is knowable — which is
  exactly the point: the value is knowable *after* the fact and unpinnable before it.
- **Registries differ in what they guarantee.** `docker.redpanda.com/redpandadata/redpanda:v26.2.1`
  is Redpanda's own distribution point; `redpandadata/redpanda` on Docker Hub is a mirror subject to
  Docker Hub's rate limits and retention. Naming the registry is part of naming the artifact.

The general defect: a *floor* answers "not older than", while a *pin* must answer "exactly this, and it
resolves". Conflating them produced an unpullable manifest that looked correct in every text-level
check we had.

## Decision

We will require every container image reference in this project to be a **fully-qualified, resolvable,
patch-level tag**, and we will check that it resolves.

1. **Fully qualified.** Registry host included — `docker.redpanda.com/redpandadata/redpanda:v26.2.1`,
   not `redpandadata/redpanda:v26.2.1`. Implicit `docker.io` is a default, not a decision.
2. **Patch level.** No bare major or minor tags, even where upstream publishes them: a floating tag
   makes the running bytes a function of *when* you pulled.
3. **No `:latest`, ever**, including for services we do not yet configure. `ZITADEL_IMAGE` becomes
   `ghcr.io/zitadel/zitadel:v4.16.2` — the version the cluster resolved on 2026-08-06 — so the pin
   records what was actually exercised rather than what a registry offers next week.
4. **Resolvability is checked, not assumed.** `check-dev-images.sh` gains a manifest-existence probe
   against each pinned reference. This is the cheap half of ADR-0023's floors follow-up: the Redpanda
   defect cost a cluster run to find and a registry HEAD request to prevent.
5. **Floors stay floors.** ADR-0023 is **not** superseded and needs no amendment. Its floors remain the
   minimum; this ADR governs the *form* a pin takes when a floor is realised. `v26.2.1` satisfies the
   26.1 floor, and moving inside or above a floor stays an ordinary change.

## Consequences

**Positive:** a pin that cannot be pulled now fails in CI in seconds instead of in a cluster after a
merge. The running artifact becomes reproducible in the sense ADR-0023 already claimed — same tag,
same bytes, named registry. Digest pinning (`@sha256:…`) becomes a possible later tightening rather
than a rewrite, because references are already fully qualified.

**Negative / costs:** patch pins need deliberate bumps, and someone must do that work; a floating tag
picked up fixes for free, which is the same property that makes it unreproducible. Upstreams
occasionally delete or retag patch releases, so a pin can rot — the resolvability check turns that from
a silent 404 at deploy time into a red build. Fully-qualified names are longer and slightly noisier to
read.

**Follow-ups:**
- Pin `ZITADEL_IMAGE` to `v4.16.2` and add the resolvability probe to `check-dev-images.sh`
  (super-repo, after this ADR is Accepted).
- The *toolchain* half of ADR-0023's follow-up — asserting installed `go`/`node`/`tsc` meet their
  floors in CI — is untouched here and remains open.
- Digest pinning is deliberately **not** decided. It defeats registry-side security rebuilds of the
  same tag, and that trade deserves its own ADR rather than being smuggled in here.

## Alternatives considered

- **Keep bare minor tags and treat the Redpanda case as a typo** — rejected: it was not a typo but a
  category error, floor written where a pin was needed, and nothing in the repo could have caught it.
  The same mistake is available for every other service.
- **Pin by digest immediately** (`@sha256:…`) — rejected as scope, not on merit. It is strictly more
  reproducible, and it also freezes out patched rebuilds published under the same tag; that trade is a
  separate decision.
- **Allow `:latest` in the dev environment only** — rejected: the dev cluster is where ADR-0024 says
  the prod topology is rehearsed, and a floating tag there means two developers debug different
  software. It is also how `ZITADEL_IMAGE` stayed unpinned across three tasks: a warning nobody must
  act on is a warning nobody acts on.
- **Have `check-dev-images.sh` pull each image** instead of probing the manifest — rejected: pulling
  gigabytes to answer "does this reference exist" makes the gate slow enough that people skip it.
