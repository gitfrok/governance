# T-0003: Minikube dev environment

- **Status:** In progress — **AC2 and AC4-on-Linux verified**; AC1 blocked on one host `sysctl`, AC3 on a rootless-podman routing limit, AC4's macOS half on a macOS (see the record)
- **Phase / Epic:** 0 / EP-1
- **Repo(s):** super-repo (`Makefile`, `deploy/dev/`)
- **Spec:** chore — acceptance criteria below
- **ADRs:** 0024, 0023
- **Owner:** unassigned

## Goal
One-command local cluster matching prod topology, with real TLS.

## Acceptance criteria (test-first)
- [~] AC1: `make dev-up` starts Minikube with `ingress` + `ingress-dns` addons. **Addon half
  verified** — `dev-up.sh` ran end to end and enabled both (they were `disabled` first). The
  *cluster-create* path was **attempted for real on 2026-08-08** and failed on a host limit, after
  exposing two defects in the script itself (see the 2026-08-08 record). It is still unverified, but
  the blocker is now named and one `sysctl` wide rather than "needs a different host":
  `fs.inotify.max_user_instances=512`. Raising it needs root, which this environment does not have
  without a password.
- [x] AC2: PostgreSQL 18, Valkey 9.1, Redpanda, Zitadel, SeaweedFS 4.40 come up from
  manifests using image tags in `deploy/dev/versions.env`. **Verified** — six deployments Available,
  six running images all from `versions.env`. Took **seven manifest fixes**; as written, three of the
  five services could not start. Redpanda is now `docker.redpanda.com/redpandadata/redpanda:v26.2.1`
  — `v26.1` was never a published tag (the series is patch-tagged only), and 26.2 still satisfies
  ADR-0023's 26.1 floor.
- [~] AC3: Services are reachable at `*.gitsaas.test` over HTTPS via a mkcert wildcard secret.
  **Verified in substance, not by the specified path.** Ingress serves the mkcert wildcard and returns
  the fixture — `http_code=200`, `ssl_verify_result=0` (validated against the mkcert CA, never
  `curl -k`) — but reached via `kubectl port-forward`, because under **rootless** podman the node IP
  is unroutable from the host (`ping` 100% loss; `smoke-dev.sh`'s `--resolve` fallback times out at
  `rc=28`). No host-DNS or `/etc/hosts` entry fixes that. Needs a rootful driver or KVM.
- [x] AC4: No OrbStack and no Docker Compose anywhere; works on macOS and Linux. **Verified for
  Linux** — it ran. No compose files exist and every OrbStack/Compose mention in the tree is a
  prohibition.

  **The macOS half was upgraded from grep to execution on 2026-08-08, and it found a real breakage.**
  The previous record rested on grepping for bash-4 features (`declare -A`, `mapfile`, `readarray`,
  `${var,,}`) — necessary but not sufficient, because it tested the *shell* and ignored the
  *userland*. macOS ships bash **3.2.57** and a **BSD** userland, and the second is where the bug was.

  What was actually done:
  1. **All 15 shell scripts across the four repos parse under bash 3.2.57** (`bash -n` in a
     `docker.io/library/bash:3.2` container — the same 3.2.57 macOS ships).
  2. **Five fitness scripts were *executed* under bash 3.2.57 and pass**: `check-dep-direction.sh`,
     `check-version-floors.sh`, `check-dev-images.sh`, webfrontend's `check-boundaries.sh`, and this
     repo's `check-docs.sh`. Parsing proves no bash-4 syntax; running proves no bash-4 *behaviour*.
  3. **Audited for GNU-only tool flags**, which no prior check looked for: `grep -P`, `readlink -f`,
     `find -printf`, `date -d`, `stat -c`, `base64 -w`, `xargs -d`, `tac`, `sha256sum`, `sed -i`
     without an argument, `sort -z`.

  **Found and fixed: `check-docs.sh` used `find -printf`, a GNU extension BSD find does not have.**
  This repo's entire docs gate would have aborted on macOS with `find: -printf: unknown primary or
  operator`. Replaced with a portable `sed 's|.*/||'`. Verified both directions in the container: the
  fixed gate reports `docs: OK (98 files checked)` under bash 3.2 with a non-GNU `find`, and the old
  line still fails there. The duplicate-ADR-number detection it implements was re-confirmed by a
  negative control (a deliberately duplicated ADR number is still reported).

  **`sort -z` in the super-repo's `dev-up.sh` is flagged but not confirmed as a defect** — it is a GNU
  extension, yet FreeBSD-derived `sort` (and busybox) accept it, so whether macOS's does cannot be
  established from here. It is being removed regardless, because it is cosmetic there and removing it
  costs nothing. Recorded as *unverified*, not as a bug, to avoid the overclaim.

  **Still untested: the scripts running on an actual Mac.** What changed is that the two things
  reachable without one — bash-version and userland-portability — are now tested rather than asserted,
  and the audit turned up one genuine macOS-fatal defect that grep could never have found.

## Tests to write first
- integration: a smoke test hits an ingress host over TLS and gets 200 from a hello service.

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions
Follow the Agentic SDLC loop; stop-and-ask if a decision/spec is missing.

## Implementation record

| Repo | Merged | What |
|---|---|---|
| super-repo | `b605b26` (#18) | manifests, `dev-up.sh`, `smoke-dev.sh` — written, never executed |
| super-repo | `41e2f45` (#32) | first real cluster run: seven manifest defects fixed, `mkcert -install` no longer aborts the bring-up, `smoke-dev.sh` distinguishes a missing context from a dead cluster |
| super-repo | *pending* | first real cluster-**create** attempt: stale-volume convergence + inotify preflight, and the policy bundle published as a generated ConfigMap |

### What the first run found (2026-08-06)

`deploy/dev/README.md` called every AC *"implemented, unverified"* and was right to. Three of the five
services could not have started:

1. **postgres** mounted its PVC at `/var/lib/postgresql/data`; pg18 keeps data in major-version
   subdirectories and **exits** rather than ignore that mount, so it never silently drops data.
2. **`redpandadata/redpanda:v26.1` was never published.** The series exists (v26.1.2…v26.1.14) but
   Redpanda tags patch releases only, so no floating minor tag exists to pin. This is the phase-0
   plan's own recorded risk — *"version availability … verify at setup"* — landing exactly as written.
3. **seaweedfs** passed `all` as a subcommand; there is no such subcommand.
4. **zitadel** passed `--tls-mode`; the flag is `--tlsMode`.
5. **seaweedfs readiness** probed `/status`, which 404s on the master, so the pod never became Ready
   and the rollout blocked forever.
6. **zitadel could not parse its own `Port`.** Kubernetes injects `<SVC>_PORT=tcp://<ip>:<port>` for
   every Service; the Service is named `zitadel` and Zitadel consumes `ZITADEL_`-prefixed env vars, so
   it received a URL where it wanted a `uint16`. A name collision, not a typo — and invisible until
   #4 was fixed, because the unknown-flag error killed it before config parsing.
7. **Four deployments mounted ReadWriteOnce PVCs under the default `RollingUpdate`**, which deadlocks:
   the replacement cannot start while the old pod holds the volume, and the old will not terminate
   until the new is Ready. Redpanda's *first* rollout squeaked through, which hides the bug rather
   than exposing it.

**What is left, and it is mostly not more code.** AC1's cluster-create path and AC3's
`*.gitsaas.test` path both need a host with a rootful container driver or KVM; macOS needs a macOS.
The environment used here — rootless podman, no `/dev/kvm`, no passwordless sudo — can verify
everything else, and now has.

### Added by T-0005 (2026-08-06): the manifests do not mount the policy bundle

One part *is* code, and it arrived after the run above. The data plane now requires
`GITFROK_POLICY_BUNDLE_DIR` and **exits** without a loadable OPA bundle (ADR-0006, invariant 2) —
deliberately, because a plane that came up without one would deny every request in the system and
reach an operator as an unexplained total outage. Nothing in `deploy/dev/` mounts
`governance/policies` or sets that variable yet, so a bring-up on the manifests as they stand would
start a data plane that immediately exits.

This one can be finished on any host — it is a manifest change, not a driver problem — and it is
worth doing before the next cluster run, since otherwise that run will spend its first cycle
rediscovering it. Note the bundle must be *mounted*, not baked into an image: the backend does not
embed it precisely so that governance stays its only author (invariants 13 and 21).

> **Corrected 2026-08-08 — the last paragraph's premise was wrong, and the item is now done.**
> There is no data plane in `deploy/dev/` to exit: the directory deploys the five infrastructure
> services and the hello fixture, and `backend/` contains **no Dockerfile**, so no image exists to
> run one from. "A bring-up on the manifests as they stand would start a data plane that immediately
> exits" describes a pod that was never there. The conclusion it drew was still the right one for
> the wrong reason — the bundle genuinely was missing — so what shipped is the bundle without a
> consumer, plus the mount contract written down for whoever lands the image. Details in
> `deploy/dev/README.md` ("Policy bundle"); the mount-vs-bake reasoning above holds exactly as
> written and is why the ConfigMap is generated from the submodule rather than committed.

### The 2026-08-08 create-path attempt: two defects in `dev-up.sh`

The first run tested the *converge* branch. Nothing had ever tested the *create* branch, and both of
these lived there — neither is in the manifests, so the seven-fix sweep above could not have found
them.

1. **`dev-up.sh` did not converge a failed create.** Its header promises re-running is "the normal
   way to repair a half-up cluster"; that held for a running cluster and not for a half-created one.
   minikube's in-run retry deletes the failed *container* but leaves the podman *volume*, so attempt
   two died on `volume with name gitfrok already exists` and left the profile registered but
   unusable (`STATUS` blank, runtime `docker` not `containerd`) — after which every run would take
   the create branch and fail the same way. The stale-volume error was also the one that reached the
   operator, naming nothing about the actual cause. Fixed: delete a non-running profile before
   creating, which clears container and volume together.
2. **The actual cause was `fs.inotify.max_user_instances`.** Fedora ships 128 and a GUI login had
   ~114 in use; the node's systemd (PID 1) needs its own and got none — *"Failed to create control
   group inotify object: Too many open files"*, then `Exiting PID 1`. This is not an exotic
   misconfiguration: any Fedora desktop hits it. Fixed as a preflight on the create path, which
   prints the `sysctl` and stops **before** pulling images instead of after. Printed rather than
   applied, matching how the script already treats host DNS and `mkcert -install`.

Worth recording for the plan's risk register: the phase-0 risk that fired here was not "version
availability" but **host configuration** — a limit low enough on a mainstream distro to stop the
one-command bring-up, invisible to every static check, and discoverable only by running the create
path on a machine nobody had run it on.

Also found: `make` is not installed on this host, so `make dev-up` cannot run at all here and the
script must be invoked directly. Not a defect in this task — but AC1 is written in terms of
`make dev-up`, so the acceptance criterion is not literally satisfiable on a host without `make`.
