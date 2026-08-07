# T-0003: Minikube dev environment

- **Status:** In progress — **AC1, AC2 and AC4-on-Linux verified**; AC3's ingress half verified and its host-DNS half still unwired (root); AC4's macOS half still needs a macOS (see the record)
- **Phase / Epic:** 0 / EP-1
- **Repo(s):** super-repo (`Makefile`, `deploy/dev/`)
- **Spec:** chore — acceptance criteria below
- **ADRs:** 0024, 0023
- **Owner:** unassigned

## Goal
One-command local cluster matching prod topology, with real TLS.

## Acceptance criteria (test-first)
- [x] AC1: `make dev-up` starts Minikube with `ingress` + `ingress-dns` addons. **Verified** — on
  2026-08-08 the *cluster-create* path ran to completion for the first time, against a deleted and
  recreated `gitfrok` profile: node created, both addons enabled (`disabled` beforehand), wildcard
  installed, policy bundle published, all six deployments Available, `dev-up: OK`. Re-running against
  the live cluster exits 0 and changes nothing, so the converge branch still converges.

  It took three attempts, and each failure was a real defect rather than a host problem:
  `fs.inotify.max_user_instances` at Fedora's default of 128 (raised to 512 and persisted in
  `/etc/sysctl.d/`); a stale podman volume that survived a failed create; and — the one only a create
  that gets *past* inotify can reach — **`dev-up.sh` never passing `--container-runtime`**. minikube
  1.35 defaults to *docker*, so provisioning started `dockerd` inside the node and failed
  (`Job for docker.service failed` → `StartHost failed` → `GUEST_PROVISION`). `deploy/dev/README.md`
  had documented `containerd` since the first bring-up; the script disagreed with its own README, and
  the disagreement survived because the create branch had never once run to completion.
- [x] AC2: PostgreSQL 18, Valkey 9.1, Redpanda, Zitadel, SeaweedFS 4.40 come up from
  manifests using image tags in `deploy/dev/versions.env`. **Verified** — six deployments Available,
  six running images all from `versions.env`. Took **seven manifest fixes**; as written, three of the
  five services could not start. Redpanda is now `docker.io/redpandadata/redpanda:v26.2.1` — `v26.1`
  was never a published tag (the series is patch-tagged only), and 26.2 still satisfies ADR-0023's
  26.1 floor.

  **Re-verified 2026-08-08 after two Redpanda pin changes**, both of which taught something:

  - **The registry moved from `docker.redpanda.com` to `docker.io`.** ADR-0034 preferred the vendor's
    own distribution point over the Docker Hub mirror on rate-limit grounds; for this image that is
    backwards. `docker.redpanda.com` answers an unauthenticated manifest query with
    `toomanyrequests: You have reached your unauthenticated pull rate limit`, so it evidently sits
    behind Docker Hub and inherits the limit. The effect is that ADR-0034's **own rule 4** —
    resolvability is checked, not assumed — could not be met there: the probe reported
    `?? inconclusive` on every run. On `docker.io` the same tag reports `ok resolves`. A pin that can
    be verified beats a pin from a preferred registry that cannot. Rationale recorded in
    `deploy/dev/README.md` ("Why Redpanda is pinned on docker.io").
  - **Redpanda refuses downgrades.** A brief pin to `v26.1.15` crash-looped with
    *"Incompatible downgrade detected! My version 18, feature table 19 indicates that all nodes in
    cluster were previously >= that version"*. It writes a feature-table version into its data
    directory and will not start against data from a newer release, so moving a Redpanda pin **down**
    a minor requires deleting `redpanda-pvc`. Moving **up** is fine — `v26.1.15 → v26.2.1` rolled out
    against the existing volume. Worth knowing before someone reads "26.1 floor" as an invitation to
    pin at the floor.

  All six deployments Available on the current pins, `rpk version: v26.2.1` confirmed in-container,
  and every pinned image resolves with `CHECK_IMAGE_RESOLVE=1`.
- [~] AC3: Services are reachable at `*.gitsaas.test` over HTTPS via a mkcert wildcard secret.
  **Verified over the real ingress path, under rootless podman, with no `port-forward`** —
  `GET https://hello.gitsaas.test/` returns `http_code=200`, `ssl_verify_result=0` (validated against
  the mkcert CA, never `curl -k`) and the hello fixture, hitting `127.0.0.1:443`. Left at `[~]` for
  one reason only: **host DNS is still unwired**, so that request is made with `curl --resolve`.
  Wiring it needs root and touches system DNS, which `dev-up.sh` prints rather than does.

  **The previous entry here was wrong, and the correction is the point.** It said AC3 "needs a rootful
  driver or KVM". The evidence behind that — the node IP being unroutable from the host under rootless
  podman — was measured correctly. The inference drawn from it was not: the node's 80/443 can simply be
  published to the host (`minikube start --ports=80:80,443:443`, supported by the podman driver), and
  then nothing rootful is required. `smoke-dev.sh` had been pinning its `--resolve` fallback to the
  node IP alone, so its `rc=28` looked like confirmation of a limit that was not there.

  Binding 80/443 as a non-root user also needs `net.ipv4.ip_unprivileged_port_start=0`; the create path
  now checks that sysctl and aborts with the fix — a hard stop, unlike the host-DNS instructions above,
  which it only prints. *"The node IP is unroutable"* was an observation; *"so this needs a different
  host"* was an inference, and it entered the record with the same confidence as the measurement.

  **Publishing the ports was necessary but not sufficient.** A second, unrelated defect stood between
  the published ports and a reliable 200, and the record would otherwise credit the whole result to
  port publishing. `ingress-nginx` left nginx's `worker_processes` at the host CPU count (12 here)
  while the controller pod's cgroup capped `pids.max` at 307, so workers died with
  `pthread_create() failed (11: Resource temporarily unavailable)` and nginx logged "worker process
  exited with fatal code 2 and cannot be respawned". The survivors still completed the TCP handshake
  and then never answered, so requests hung until the client gave up: 4 of 6 probes returned `curl`
  exit 28 while the other 2 answered normally. What separated it from a routing fault was that a
  `/dev/tcp` connect to the controller pod succeeded on both 80 and 443 at the same moment `curl` to
  those ports timed out. Pinning `worker-processes=2` in the `ingress-nginx-controller` ConfigMap fixed
  it, and `dev-up.sh` now does that on every run.
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

  **That audit found two defects, not one.** The first version of this record said one, and was wrong —
  it named `stat -c` among the flags it had searched while a live `stat -c` sat in the super-repo:

  1. **`check-docs.sh` used `find -printf`**, a GNU extension BSD find does not have, so this repo's
     entire docs gate would have aborted on macOS with `find: -printf: unknown primary or operator`.
     Replaced with a portable `sed 's|.*/||'`. Verified both directions in the container: the fixed
     gate reports `docs: OK (98 files checked)` with a non-GNU `find`, and the old line still fails
     there. The duplicate-ADR-number detection was re-confirmed by a negative control (a deliberately
     duplicated ADR number is still reported) — a portability fix that silently disabled the assertion
     would be worse than the bug.
  2. **`bench-storage.sh` used `stat -f -c %T` with the failure swallowed** by
     `2>/dev/null || echo unknown`, so on macOS its RAM-disk guard was **silently inert** — the one
     check between T-0007's benchmark and a flattering tmpfs number, on the platform nobody had run it
     on. Fixed in the super-repo with a portable detector that refuses to run rather than guess.
     (T-0007's verdict fed ADR-0033, so this was not a cosmetic risk.)

  **What the bash 3.2 container does and does not prove.** It is Alpine + busybox — an independent
  minimal reimplementation with no lineage to Darwin's tools. That busybox *also* rejects
  `find -printf` corroborates the finding but is not evidence about BSD; the `-printf` conclusion rests
  on it being a documented GNU extension that no BSD-family `find(1)` implements. What the container
  legitimately proves is that the replacements work without GNU extensions. Useful, and a different
  claim from "verified on macOS".

  **`sort -z` in the super-repo's `dev-up.sh` is flagged but not confirmed as a defect** — it is a GNU
  extension, yet FreeBSD-derived `sort` (and busybox) accept it, so whether macOS's does cannot be
  established from here. It is being removed regardless, because it is cosmetic there and removing it
  costs nothing. Recorded as *unverified*, not as a bug, to avoid the overclaim.

  **Still untested: the scripts running on an actual Mac.** What changed is that the two things
  reachable without one — bash-version and userland-portability — are now tested rather than asserted,
  and the audit turned up two genuine macOS-fatal defects that grep could never have found.

  One surviving limit, named rather than buried: `bench-git-workload.sh` requires GNU `date`'s `%N` and
  exits with a clear message without it. It is macOS-*parseable*, not macOS-*runnable* — so "all 15
  scripts parse under bash 3.2" must not be read as "all 15 run on macOS".

  A note on how this record was produced, since it bears on how much to trust it: the "audit found one
  defect" version above was caught by review, not by me. The lesson is the specific one — an audit that
  lists the flags it searched for is only as good as the search, and mine claimed `stat -c` while
  missing a live `stat -c`. Treat the table in `deploy/dev/README.md`
  ("What is verified about macOS, and what is not") as the authoritative split.

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
| super-repo | `a6c3fb2` (#42) | first real cluster-**create** attempt: stale-volume convergence + inotify preflight, and the policy bundle published as a generated ConfigMap |
| super-repo | `b7d1663` (#45) | macOS portability audit: `sort -z` dropped, `bench-storage.sh`'s silently-inert RAM-disk guard fixed |
| governance | `9667a36` (#39) | `check-docs.sh` no longer uses GNU `find -printf`, which aborted this repo's docs gate on macOS |
| super-repo | `a126acd` (#47) | create path completed: `--container-runtime=containerd` pinned, orphaned-volume sweep, ingress ports published so AC3 needs no rootful driver, and `worker-processes=2` pinned on the ingress-nginx ConfigMap so requests stop hanging |

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
