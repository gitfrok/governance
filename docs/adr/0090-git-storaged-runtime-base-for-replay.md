# ADR-0090: `git-storaged`'s runtime base moves to Alpine 3.24 so the rebase landing works

- **Status:** Accepted
- **Date:** 2026-08-23
- **Deciders:** platform
- **Refines:** ADR-0048 (the base-with-git exception), ADR-0034 (third-party pin form)
- **Relates to:** ADR-0035 (first-party image base), ADR-0088 (refuse rather than ship unsafe),
  ADR-0089 (the Go builder base), SPEC-0065 AC4 (the rebase landing)
- **Invariants:** 9 (signed releases only)

## Context

SPEC-0065 AC4 says `rebase` replays the source commits onto the target head. `git-storaged`
implements it with `git replay --onto=<current> --ref=<target> --ref-action=print`. The
`--ref-action=print` half is the safety story, and it is deliberate: replay names what it *would*
update and touches nothing, so the only ref move in a landing stays where every other landing's
does — the caller's compare-and-swap, on the quorum path (AC6).

Those two flags are newer than `git replay` itself. Measured against the real thing on 2026-08-23,
running the exact invocation against a real bare repository:

| base | git | the invocation |
|---|---|---|
| `alpine:3.22.5` | 2.49.1 | `error: unrecognized argument: --ref=...`, exit 128 |
| `alpine:3.23.5` | 2.52.0 | `error: unrecognized argument: --ref=...`, exit 128 |
| `alpine:3.24.1` | 2.54.0 | completes; prints `update refs/heads/main <new> <old>` |

`git replay -h` on 2.49.1 offers only `--advance`, `--onto` and `--contained`. On 2.54.0 it offers
`--ref` and `--ref-action` as well. Both spell the command `(EXPERIMENTAL!)`.

`Dockerfile.gitstoraged` ships `FROM docker.io/library/alpine:3.22.2` — git 2.49.1, the first row.
So **every rebase landing and every trunk-mode fallback refuses on the image we publish**, and has
since SPEC-0065 shipped. Until backend `4c57f57` the refusal claimed `merge_conflict`, which is why
nobody saw it; that commit made the refusal honest (`rebase_path_unproven`, probed per process
rather than inferred from a version number). Honest, but still a refusal: AC4 is marked `[x]` in
SPEC-0065 and is unreachable in production.

ADR-0088's "ships unsafe nowhere" is about not landing a wrong result. It is not an argument for
never shipping the feature, and this ADR does not weaken it — the refusal stays exactly as it is
wherever the capability is absent.

Two things about ADR-0048 that this ADR has to deal with rather than assume:

- **Its decision 4 was never implemented.** "The base pin is a version floor of record. It goes in
  `versions.env` and is asserted by `check-dev-images.sh`" — there is no base pin in
  `deploy/dev/versions.env` and nothing in `scripts/check-dev-images.sh` looks for one. The version
  lives in exactly one place, `Dockerfile.gitstoraged:21`, ungated. Moving a pin that has no
  recorded floor and no gate would repeat the drift 0048 meant to prevent.
- **Its decision 3 proves the wrong things now.** The build asserts `git --version`,
  `command -v git-upload-pack`, `command -v git-receive-pack` and an executable `/bin/sh`. Every one
  of those passes on 2.49.1, which cannot do the landing. The assertion set was written against
  "git is absent" and does not cover "git is present and lacks a flag".

## Decision

1. **`git-storaged`'s runtime base becomes `docker.io/library/alpine:3.24.1`**, patch-tagged per
   ADR-0034 rules 1–3. Everything in ADR-0048 stands: a base carrying git, `git` and a POSIX `sh`
   and nothing else, `USER 65532:65532`, read-only root, no service-account token, referenced by
   digest, cosign-signed, published by the same workflow. Only the pin moves, and it moves inside
   ADR-0048's own rules.

2. **ADR-0048 decision 4 gets implemented in the same change.** The base pin is recorded in
   `deploy/dev/versions.env` and asserted, so it cannot drift and cannot become a floating tag. A
   pin with no gate is how this one sat three minor releases behind what the code needed.

3. **ADR-0048 decision 3's assertions gain the capability probe.** The build runs the replay
   invocation's own flags — `git replay --onto=HEAD --ref=refs/heads/gitfrok-replay-probe
   --ref-action=print HEAD..HEAD` — and fails the build if git answers `unrecognized argument`.
   Option parsing happens before git reads an object and `--ref-action=print` moves nothing, so the
   probe is free of side effects. This is the durable half of this ADR: `git replay` is marked
   EXPERIMENTAL by git itself, so its flag surface can move under a future base bump, and the build
   should say so rather than the first tenant's rebase. The runtime probe in `landRebase` stays as
   it is — it is what keeps the refusal honest on any host we did not build.

4. **The builder base is not this ADR's business.** ADR-0089 owns it and it stays at
   `golang:1.27.0-alpine3.23`; the builder compiles a `CGO_ENABLED=0` binary and needs no git at
   all. `Dockerfile.gitstoraged` therefore carries a 3.23 builder and a 3.24.1 runtime, and the
   comment ADR-0089 added at the build stage is rewritten by the implementing change to say why
   each version is what it is.

5. **The exception still does not generalize** (ADR-0048 decision 5). This ADR moves one pin and
   adds one assertion for one image. It is not licence for a second based image.

## Alternatives considered

- **Drop `--ref`/`--ref-action` and use the invocation older git understands.** Measured, not
  assumed: on 2.49.1 `git replay --onto=<base> <base>..<head>` exits 0 and prints **nothing**, so
  there is no landed head to read back. The only old-git ways to get a result are `--advance` and
  `--contained`, both of which move a ref inside replay — which is precisely the property
  `--ref-action=print` exists to avoid, and would put a second ref move in a landing that AC6 says
  has exactly one. So this is not rejected on taste: it is unavailable without giving up the safety
  property.
- **Install a newer git on Alpine 3.22 from `edge`/backports.** Keeps the pin still and breaks what
  ADR-0048 bought — git patched by the distribution rather than by us — by taking a package from a
  branch the base does not track.
- **Vendor or statically link a newer git.** ADR-0048 and ADR-0039 already rejected this; nothing
  has changed.
- **Accept the refusal and leave the base alone.** Defensible after `4c57f57` — the product tells
  the truth. It also means SPEC-0065 AC4 is checked off and cannot happen, and every repository
  that chooses `rebase` or trunk-based landing gets a refusal with no way to satisfy it. If this is
  the choice, AC4 and ADR-0088's strategy table need amending to say that rebase is unavailable on
  the shipped image, because they currently read as though it works.

## Consequences

**Positive.** The rebase landing and the trunk-mode fallback work on the image we publish, so AC4
becomes true where it is claimed. The base pin acquires the floor and the gate ADR-0048 specified
and never got. The build proves the capability rather than the absence of git, which is the failure
this image class keeps producing — a correct binary in an image that cannot run it.

**Negative / costs.** Two Alpine minors move at once (3.22 → 3.24), which is a larger jump than a
patch bump and carries whatever else changed in the base; the mitigation is that the image contains
git and a shell and nothing else installed on top. A newer base means a newer CVE set to track — the
cost ADR-0048 already accepted, not a new one. The capability probe binds the build to a flag
surface git calls experimental; that is the point, but it means a future base bump can fail the
build, deliberately.

**Neutral.** The Dockerfile keeps two Alpine versions. That is now stated in the file rather than
inferred.

## Implementation, if accepted

Per ADR-0027, separate commits:

- **backend** — `Dockerfile.gitstoraged`: runtime stage to `alpine:3.24.1`, the build-time
  assertion block gains the replay-flag probe, and the build-stage comment explains both versions.
- **super-repo** — `deploy/dev/versions.env` records the base pin; `scripts/check-dev-images.sh`
  asserts it; pin bump.

No change to `landRebase`: its probe is per process, and a new image is a new process. The change
has to be republished through the `image-publish` environment's approval gate before any cluster
sees it, and the three landing tests that assert a successful rebase go from environment-dependent
to passing on the shipped base.
