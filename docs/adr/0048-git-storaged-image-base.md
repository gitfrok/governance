# ADR-0048: `git-storaged` ships on a minimal base with git, not `scratch`

- **Status:** Proposed
- **Date:** 2026-08-10
- **Deciders:** platform
- **Governs:** G9 least-privilege footprint, G4 change governance
- **Refines:** ADR-0035 (first-party image base), ADR-0034 (third-party pin form)
- **Relates to:** ADR-0004 (Git-RPC storage transport), ADR-0025 (one binary per plane), ADR-0033
  (block volumes for live repositories)
- **Invariants:** 9 (signed releases only), 19 (one binary per plane)
- **Tasks:** T-0003 (the dev cluster has no Git transport without this), T-0011, T-0017

## Context

ADR-0035 decision 2 says Go images build `FROM scratch`: statically linked, binary plus CA bundle,
`USER 65532:65532`, no base image at all. It states its own exception in decision 3 — the Node SSR
image cannot come from `scratch`, and two runtimes legitimately get two bases.

`git-storaged` is a third case that neither decision covers, and the difference is not stylistic.
It is a Go binary, so it satisfies decision 2's premise; but its entire purpose is to execute
`git-upload-pack`, `git-receive-pack`, `git for-each-ref`, `git update-ref`, `git rev-parse`,
`git show-ref`, `git ls-tree`, `git show` and `git diff` as subprocesses (ADR-0004, SPEC-0015). It
also invokes a POSIX `sh` hook on the receive path, because refusing a direct push to a protected
ref happens in `pre-receive` (SPEC-0019 AC3) — a hook git runs, in an environment git provides.

None of that exists on `scratch`. The image would build, pass its digest and signature checks, start
cleanly, serve health, and then fail every single Git operation with `exec: "git": executable file
not found`. The failure is invisible to every gate we have: the binary is correct, the image is
correct by ADR-0035's rules, and nothing in the build asserts that the thing the binary shells out
to is present.

The consequence today is concrete: `deploy/dev/` has no `git-storaged` workload, so the dev cluster
runs a data plane with no Git transport, and the Phase-1 exit scenario — clone, durable push, MR,
merge — has nothing to clone from.

Three options were considered.

**Vendor git into a `scratch` image.** Statically link git and copy the binary in. This keeps the
letter of ADR-0035, and it is what "no base image" would demand. It also means we own building and
patching git ourselves, in a form upstream does not ship, for a CVE surface we would then have to
track by hand — and git is not one dependency but a family of them (`git-upload-pack` and
`git-receive-pack` are separate executables, and git expects its exec-path, templates, and a shell).
ADR-0039 forbids vendoring third-party code for reasons that apply here with force.

**Reimplement the Git wire protocol in Go.** Removes the subprocess entirely and would allow
`scratch`. It also replaces the most battle-tested piece of the system with our own, on the path
that holds customer source. ADR-0004 already rejected owning the protocol; nothing has changed.

**Use a minimal base that provides git.** Accepts a base image, pinned and patch-tagged like every
other third-party image, in exchange for using upstream's git and upstream's patching.

## Decision

We will build `git-storaged` `FROM docker.io/library/alpine:<major>.<minor>.<patch>` with `git`
installed from the distribution, pinned and patch-tagged per ADR-0034 rules 1–3, and recorded in
`deploy/dev/versions.env` like any other third-party pin.

1. **This is an exception to ADR-0035 decision 2, stated as one.** ADR-0035 already carries an
   exception for a runtime that cannot come from `scratch`; this is the same argument for a
   different reason — not a runtime, but a required subprocess. ADR-0035 is otherwise unchanged, and
   the two plane binaries stay on `scratch`.

2. **Everything else in ADR-0035 applies unchanged.** The image is referenced by digest, signed with
   cosign, published by the same workflow, and runs as `USER 65532:65532` with a read-only root
   filesystem and no service-account token. The base is the only difference.

3. **The image declares exactly what it needs and the build proves it.** `git` and a POSIX `sh`, and
   nothing else installed on top. The build asserts at image-build time that `git --version`,
   `git-upload-pack --help` and `git-receive-pack --help` succeed inside the final image, so the
   failure mode described above — a correct binary in an image that cannot run it — fails the build
   rather than the first clone.

4. **The base pin is a version floor of record.** It goes in `versions.env` and is asserted by
   `check-dev-images.sh`, so it cannot drift and cannot become `:latest` (ADR-0034).

5. **The exception does not generalize.** Any other first-party image that wants a base must argue
   its own case in its own ADR. "git-storaged has one" is not a precedent for a second, and this
   decision names the property that earned it: the binary's core function is to execute a program
   the image must therefore contain.

## Consequences

**Positive.** The dev cluster and every environment after it can actually serve Git, which the
Phase-1 exit scenario requires. Git is patched by the distribution rather than by us. The hook path
protecting refs has the shell it needs. The build catches a missing git rather than the first user.

**Negative / costs.** `git-storaged` carries a base image and therefore a base CVE surface the two
plane images do not, and it needs the base pin kept current — the cost ADR-0035 was written to
avoid, accepted here deliberately and in one place. Its image is larger, and unlike the `scratch`
images it contains a shell, so `kubectl exec` into it is possible; that is a real reduction in
least-privilege footprint, and the mitigations are the ones already required — read-only root, no
service-account token, non-root user, and no shell-bearing base anywhere else.

**Neutral.** Two base strategies become three. ADR-0035 already accepted two and said so plainly;
the honest framing is that base choice follows what the binary must execute, not the language it is
written in.

## Open questions

- Whether the CI runner image (T-0017) takes the same base or its own. It has the same shape — a
  sandbox that must contain the tools a job runs — but a different threat model, since it executes
  tenant-controlled content. It is deliberately left to its own decision.
