# ADR-0036: When a vendor registry cannot be verified, prefer the one that can

- **Status:** Proposed
- **Date:** 2026-08-08
- **Deciders:** platform
- **Governs:** G7 process integrity — a pin whose existence cannot be checked is the defect ADR-0034
  set out to remove
- **Relates to:** **ADR-0034** (image pins are fully-qualified, resolvable, patch-level tags —
  **refined, not superseded**) · ADR-0023 (version floors) · ADR-0024 (dev env) ·
  **Invariants:** 13 · **Tasks:** T-0003 (AC2, found this)

## Context

ADR-0034 requires every image reference to be a fully-qualified, resolvable, patch-level tag, and — rule
4 — that **resolvability is checked, not assumed**. Its Context also made a specific sub-choice, using
Redpanda as the worked example:

> `docker.redpanda.com/redpandadata/redpanda:v26.2.1` is Redpanda's own distribution point;
> `redpandadata/redpanda` on Docker Hub is a mirror subject to Docker Hub's rate limits and retention.
> Naming the registry is part of naming the artifact.

That reasoning is sound in general. **For this image it does not hold**, and the way it fails happens to
break ADR-0034's own rule 4.

`docker.redpanda.com` is not an independent distribution channel. It fronts Docker Hub:

```
$ dig +short docker.redpanda.com
vectorized.docker.scarf.sh.                     # a Docker-Hub-fronting proxy

$ curl -sSI https://docker.redpanda.com/v2/redpandadata/redpanda/manifests/v26.2.1
www-authenticate: Bearer realm="https://auth.docker.io/token",service="registry.docker.io",…
```

It delegates authentication to Docker Hub's own registry, so a pull through it *is* a Docker Hub pull
with an extra hop — and it inherits the unauthenticated rate limit that choosing it was meant to avoid:

```
$ skopeo inspect docker://docker.redpanda.com/redpandadata/redpanda:v26.2.1
toomanyrequests: You have reached your unauthenticated pull rate limit.
```

The operational consequence is the part that matters. `check-dev-images.sh`'s manifest probe — the
mechanism ADR-0034 introduced to satisfy its own rule 4 — reported `?? inconclusive` for this reference
on **every run since it was introduced, including in the PR that introduced it**. The same tag on
`docker.io` reports `ok resolves`. So the preferred registry was the one whose pin could never be
verified, and the check quietly degraded to a no-op for exactly one of six images. A gate that reports
"inconclusive" indefinitely is the same failure ADR-0034 was written about — `redpanda:v26.1` survived
review because nothing had tried to pull it.

Rate limits are also not the only thing being traded. Mirror **retention** is a real risk and this ADR
does not pretend otherwise; the difference is that a resolvability probe turns a deleted or retagged
upstream into a red build, whereas an unverifiable reference turns it into a deploy-time 404.

## Decision

We will **prefer the registry whose references can be verified** when a vendor's own distribution point
cannot satisfy ADR-0034 rule 4.

1. **Resolvability wins.** If a reference cannot be resolved by `check-dev-images.sh` on an ordinary
   developer or CI host, it is not an acceptable pin, regardless of which party publishes it. All of
   ADR-0034's rules 1–3 continue to apply: fully qualified, patch level, never `:latest`.
2. **`REDPANDA_IMAGE` becomes `docker.io/redpandadata/redpanda:v26.2.1`.** Same version, same digest
   content, the registry that answers. This reverses ADR-0034's Context sub-choice for this one image
   and nothing else.
3. **A vendor registry is still the default preference** where it resolves. This is a tie-breaker for
   the conflict case, not a general demotion of vendor endpoints — nothing about `ghcr.io/zitadel` or
   `docker.redpanda.com` for some future image changes on the strength of this.
4. **"Inconclusive" is a state to act on, not carry.** A reference that reports inconclusive on every
   run is a finding: either authenticate the probe, or move the reference to a registry that answers.
   Carrying it indefinitely is how the `:latest` warning on `ZITADEL_IMAGE` survived three tasks
   (ADR-0034 recorded that pattern and this is the same shape).
5. **ADR-0034 is refined, not superseded.** Its five decision rules stand unchanged and this ADR adds
   no rule that contradicts them. What changes is one illustrative choice in its Context, and this ADR
   exists because that choice is not editable — ADR-0034 is Accepted, and ADR-0001 makes Accepted ADRs
   immutable.

## Consequences

**Positive.** Every image pin in `deploy/dev/` now resolves under `CHECK_IMAGE_RESOLVE=1`; the probe is
a real gate for six of six rather than five of six. The rule that decides future conflicts is written
down instead of being re-argued per image. And the reasoning is recorded where ADR-0001 says decisions
live, rather than as a note in a `deploy/dev/README.md` that would silently disagree with an Accepted
ADR.

**Negative / costs.** We take on Docker Hub's retention and rate-limit exposure for this image
deliberately; a Hub outage or a deleted tag now affects the dev bring-up, mitigated only by the probe
turning it into a fast red build. Anyone reading ADR-0034 alone will find its Redpanda example
contradicts the tree, which is the ordinary cost of superseding-by-refinement and why this ADR names the
example explicitly. There is also a mild inconsistency of appearance: one image on Docker Hub while
others use vendor or vendor-adjacent registries.

**Follow-ups.**
- Authenticating the manifest probe (a token would raise Hub's limit and might make
  `docker.redpanda.com` resolvable again) is not decided here. If it happens, revisit rule 2 — the
  reason for the move is the limit, not the vendor.
- `ZITADEL_IMAGE`'s digest-vs-tag question stays where ADR-0034 left it.
- Nothing here touches first-party images, which ADR-0035 governs and which are digest-referenced.

## Alternatives considered

- **Keep `docker.redpanda.com` and accept a permanently inconclusive probe** — rejected. That is rule 4
  in name only, and ADR-0034 exists because an unverifiable pin already cost a cluster run.
- **Keep the vendor registry and authenticate the probe** — rejected as scope, not on merit, and left as
  a follow-up. It requires a registry credential in CI and on every developer machine to fix one
  reference, and it does not help the *pull*, which is rate-limited by the same account.
- **Pin Redpanda by digest instead** — rejected: it would make the reference exact but no more
  *resolvable* through a rate-limited endpoint, so it does not address the actual failure. First-party
  digest pinning is ADR-0035's business; third-party digest pinning remains ADR-0034's open question.
- **Mirror the image into our own registry** — rejected for the dev environment as disproportionate.
  Worth revisiting for air-gapped installs, where ADR-0013 already requires mirrored images.
- **Amend ADR-0034 in place** — not available. ADR-0001 makes Accepted ADRs immutable; supersede or
  refine by a new ADR. Recording the change only in `deploy/dev/README.md` was the path first taken and
  was wrong for the same reason: ADR-0001 says the ADR wins over any other document, so a README that
  disagrees with it is a defect rather than an amendment.
