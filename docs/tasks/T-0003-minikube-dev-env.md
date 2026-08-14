# T-0003: Minikube dev environment

- **Status:** Done — **AC1–AC4 verified**; AC4 closed 2026-08-09 by a real macOS run, with its one
  residual (cluster bring-up on a Mac) named below
- **Phase / Epic:** 0 / EP-1
- **Repo(s):** super-repo (`Makefile`, `deploy/dev/`, `scripts/`)
- **Spec:** chore — acceptance criteria below
- **ADRs:** 0023, 0024
- **Owner:** unassigned

## Goal

One-command local cluster matching the production topology, with real TLS.

## Acceptance criteria

| AC | Verdict |
|---|---|
| AC1 — `make dev-up` starts Minikube with `ingress` + `ingress-dns` | **Verified 2026-08-08** — the *create* path ran to completion for the first time against a deleted and recreated `gitfrok` profile; re-running against the live cluster exits 0 and changes nothing, so the converge branch still converges |
| AC2 — every service comes up from these manifests on `versions.env` tags | **Verified** — all deployments Available, and `smoke-dev.sh` confirms the images *actually running* come from `versions.env` |
| AC3 — reachable at `*.gitsaas.test` over HTTPS via a mkcert wildcard secret | **Verified over the real ingress path, rootless, with no `port-forward` and never `curl -k`** — `ssl_verify_result=0` against the mkcert CA. Host DNS is wired on the verified host, so `dev-smoke` passes every host by name |
| AC4 — no OrbStack, no Docker Compose; macOS and Linux | **Verified on both 2026-08-09** — bash 3.2.57 on `arm64-apple-darwin25` against Darwin's own BSD userland, not a container standing in for it |

## What the acceptance criteria cost

**Nothing here was found by reading.** Eleven defects were found by running the path — seven in the
manifests, three in `dev-up.sh`'s create branch, one in `mkcert -install` under `set -e` — and all were
invisible to review and to the static image gate, because nothing had executed. The ledger, with the
failure mode and the fix for each, is the super-repo's `deploy/dev/README.md`.

Two things in that ledger are worth stating here, because both had been **recorded as host limits when
they were defects**:

- **AC1** was blocked by `fs.inotify.max_user_instances` at a distro default of 128 (PID 1 in the node
  gets none and exits) **and** by `dev-up.sh` never passing `--container-runtime`, so minikube 1.35's
  docker default tried to start `dockerd` inside the node. `deploy/dev/README.md` had documented
  `containerd` since the first bring-up; the script disagreed with its own README, and the disagreement
  survived because the create branch had never once run to completion.
- **AC3** was called *"needs a rootful driver or KVM"*. What it needed was the node's 80/443 published
  to the host (`--ports`, plus `net.ipv4.ip_unprivileged_port_start=0` to bind them rootless) and then
  a resolver whose setup instructions the script had been printing **incorrectly** — a DNS *forwarder*
  aimed at an address with no nameserver on it, so following them broke `.test` resolution rather than
  wiring it. The snippet had been in the tree since the first bring-up and had never been run.

The second is the general lesson: **printed operator instructions are untested code.**

## AC4: what is verified about macOS, and what is not

AC4 needs an old **shell** (bash 3.2.57) and a BSD **userland** proven, not grepped for. The audit that
grepped for bash-4 syntax was necessary and not sufficient — the userland is where the bugs were.

| Claim | Status |
|---|---|
| no OrbStack, no Docker Compose anywhere | verified — every mention in the tree is a prohibition |
| no bash-4 syntax or behaviour in the gates | verified — a `macos-latest` lane in all five repos runs them under real bash 3.2.57 |
| no GNU-only tool flags | **two real defects found and fixed** (below) |
| `seq`, `sort -z` | fine — Darwin ships both; two earlier hedges in this record were unfounded |
| `date +%N` in `bench-git-workload.sh` | known and self-guarded — exits with a clear message without GNU `date`. macOS-*parseable* is not macOS-*runnable* |
| **the dev cluster comes up on a Mac** | **not verified** — needs a hypervisor no hosted runner has |

The two defects:

1. **`check-docs.sh` used `find -printf`**, a GNU extension no BSD `find` implements, so this repo's
   entire docs gate would have aborted on macOS. Replaced with a portable `sed`. The duplicate-ADR-number
   assertion was re-confirmed by a negative control — a portability fix that silently disabled the check
   would be worse than the bug.
2. **`bench-storage.sh` used `stat -f -c %T` with its failure swallowed** by `2>/dev/null || echo
   unknown`, so on macOS its RAM-disk guard was **silently inert** — the only check between T-0007's
   benchmark and a flattering tmpfs number, on the platform nobody had run it on. T-0007's verdict fed
   ADR-0033, so this was not cosmetic.

The audit is now a standing gate — `check-shell-portability.sh` (SPEC-0014) — rather than something
someone remembers to run. The reason it had to become one: an audit that lists the flags it searched for
is only as good as the search, and the first version of this record claimed `stat -c` while a live
`stat -c` sat in the super-repo.

## Residuals

- **Host DNS stays a manual root step by design** — `dev-up.sh` prints the per-OS snippet and does not
  apply it, because pointing `*.test` at a cluster is a system-wide change a bootstrap script should not
  make. Wired and `dev-smoke`-green by name on the verified host.
- **The cluster lane** is this task's open follow-up and Phase 1's two recorded limits depend on it: a
  second *physical* node running SPEC-0018's production coordinator with an attached volume rather than a
  local partition (T-0012/T-0018's durability quorum and failover demonstration), and a node offering a
  **gVisor RuntimeClass**, which no rootless-podman driver provides (T-0017's CI dispatch).
  Phase 2 delegated its carried demonstrations here too: **T-0024 AC4 measured findings freshness**,
  **T-0028 AC4 measured index freshness**, **CI-dispatched scans** on an MR, and the **exit-scenario
  live-cluster walk** the dev host could not host. Ordering note from T-0024's corrected exit record:
  the `CIJobFinished`→ingest wiring is unbuilt at the pinned backend (scan ingest is RPC-only, no
  `CIJobFinished` subscriber exists), so it is part of what this lane must first deliver — distinct
  from the scan-dispatch host limit.
  Phase 3 delegated its cluster-bound proofs here as well: the **whole BYO path — install →
  self-register → upgrade → meter — proven once end to end on a real customer-shaped cluster**
  (the conformance matrix `deploy/conformance/byo-dataplane.md` exists, 14 rows, all marked
  real-cluster "not run"), **SPEC-0039 AC8's forward/backward migration proof on real state**, and
  the **clock-skew runbook entry** (SPEC-0038's non-functional) that belongs with the first
  real-cluster run.
- **The ADR-0051 FUSE mount does not propagate on this driver**, so the cluster runs the S3 adapter
  ADR-0050 decision 6 keeps for that case. Measured, with the evidence in `deploy/dev/README.md`.
- Smaller, all in `deploy/dev/README.md`: no CI wires the Minikube flow itself (an ADR-0024 intent),
  first-party images pinned by tag rather than digest (ADR-0035 decision 4), `namespace: default`
  hardcoded so two stacks cannot coexist, Valkey without `maxmemory`, and per-OS driver docs.

## Tests

`make dev-smoke` (`scripts/smoke-dev.sh`) is the integration test: every deployment has an available
replica (AC2), every running image comes from `versions.env` (AC2), `secret/gitsaas-tls` exists and is a
TLS secret, `GET https://hello.gitsaas.test/` returns 200, the certificate validates against the mkcert
root CA, and the body is the hello fixture rather than another backend answering (AC3). Failures are
classified — unresolvable host, untrusted certificate, connection refused, wrong backend, non-200 —
because they have different fixes. `hello.yaml` exists so a red result can distinguish "TLS is broken"
from "a real service failed to boot".

## Definition of Done

See `../process/definition-of-done.md`.
