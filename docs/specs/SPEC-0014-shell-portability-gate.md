# SPEC-0014: Shell portability gate (macOS lane)

- **Status:** Proposed
- **Owner:** platform
- **Context(s):** process (CI + super-repo tooling — no runtime code)
- **ADRs:** 0024 (Minikube local dev — "one cross-platform tool (macOS/Linux/Windows), no macOS
  lock-in"), 0037 (agent-surface generation), 0027 (repo topology), 0028 (AGDD), 0001 (ADR SoT)
- **Task(s):** T-0003 (AC4)

## Problem / context

T-0003 AC4 is *"No OrbStack and no Docker Compose anywhere; works on macOS and Linux."* Its Linux
half ran. **Its macOS half has never been executed on macOS**, and the record has twice declined to
close it for that reason.

What stands in for macOS today is two proxies:

1. **A `bash:3.2` container** — the version macOS ships. It is Alpine + busybox: an independent
   minimal reimplementation with no lineage to Darwin's tools. It proves the scripts avoid *GNU*
   extensions; it is not evidence about *BSD*.
2. **A hand-run grep for GNU-only tool flags** (`grep -P`, `readlink -f`, `find -printf`, `date -d`,
   `stat -c`, `base64 -w`, `xargs -d`, `tac`, `sha256sum`, `sort -z`, bare `sed -i`).

**The proxies work, which is the argument for promoting them rather than for keeping them.** That
grep found two genuinely macOS-fatal defects: `check-docs.sh` used `find -printf`, so this repo's
entire docs gate would have aborted on macOS; and `bench-storage.sh` used `stat -c` with its failure
swallowed by `2>/dev/null || echo unknown`, leaving T-0007's RAM-disk guard **silently inert** on the
platform nobody had run it on — and T-0007's verdict fed ADR-0033.

Two properties of the current arrangement are the actual problem:

- **It is a person, not a gate.** It runs when someone remembers. Between 2026-07 and 2026-08 the
  tree gained eleven shell scripts the standing audit had never seen, and nothing reported that.
- **It cannot see BSD.** The one finding it had to hedge — `sort -z`, a GNU extension that
  FreeBSD-derived `sort` happens to accept — stayed *unverified* rather than resolved, because
  nothing reachable from this host could answer it.

Both repositories are **public**, so GitHub's `macos-latest` runner is free. The evidence AC4 has
been waiting for is one CI job away, and turning the audit into that job also stops it going stale.

**Why a spec and not an ADR.** Cross-platform dev support is not a new decision — ADR-0024 already
made it, and AC4 already promises it. This spec adds the behaviour that verifies a decision the tree
has held since ADR-0024 superseded the macOS-only ADR-0021. Nothing here changes what the project
supports; it changes whether the claim is checked.

## In scope

- A **`check-shell-portability.sh`** fitness function, generated into all five repos from
  `canonical/agent-surfaces/shared/` by the ADR-0037 pipeline, which:
  - **parses** every tracked `*.sh` in its repo under the *system* `bash`;
  - **audits** them against a single codified list of GNU-only tool flags;
  - **asserts its own environment** — the bash it used and the userland it ran against — and fails
    rather than passes when it cannot establish them.
- A **`macos-latest` CI job** in each of the five repos that runs that gate and then that repo's
  existing shell gates against a real BSD userland.
- The same gate on the existing Linux lane, so the flag audit binds for contributors without a Mac.
- An **explicit declaration of what does not run on macOS**, with the reason, so "not run" is
  visible in the log rather than absent from it.
- Closing T-0003 AC4 on the resulting run — or leaving it open, naming what failed.

## Out of scope

- **macOS as a deployment or production target.** This is about the developer and CI environment
  (ADR-0024) only. Nothing here implies a supported runtime.
- **Windows.** ADR-0024 names it as a Minikube platform; no contributor uses it and no evidence is
  being manufactured for it here. If that changes it earns its own lane.
- **Running `dev-up.sh`, `smoke-dev.sh`, or Minikube on macOS CI.** Those need a cluster and a
  hypervisor; a hosted runner would be testing the runner. This gate covers portability of the
  scripts, not the dev environment they build — the distinction the record already draws between
  macOS-*parseable* and macOS-*runnable*.
- **A self-hosted Mac.** Free hosted runners are sufficient for everything in scope.
- Weakening any existing gate to make it pass on macOS. A gate that fails on Darwin is the finding.

## Contracts touched

None.

## Data owned

None. The gate reads the tree and the environment, and writes only to its own output.

## Design sketch

**The gate has three parts, and the third is the one that makes the other two trustworthy.**

**1. Parse.** Every tracked `*.sh`, under the system bash — `/bin/bash` by absolute path, never
whatever `bash` resolves to. Hosted macOS runners ship Homebrew, and a Homebrew bash 5 on `PATH`
would turn this half into a check of nothing.

**2. Flag audit.** One list of GNU-only constructs, in one place, applied to every script. Today's
list lives in prose inside T-0003's record and is re-typed each time it is run; adding a flag should
be a one-line edit to a gate, not an edit to a paragraph nobody executes.

**3. Environment assertion — the part that must fail loudly.** The gate refuses to report success
unless it can establish what it actually tested:

- the bash it parsed with reports **3.2.x**; and
- `find`, `stat`, `sed`, `readlink` and `date` on `PATH` resolve to the **BSD** implementations, not
  to Homebrew's GNU replacements.

**Both are hard failures, not skips, and the second is the load-bearing one.** A runner image that
starts putting GNU coreutils ahead of `/usr/bin` would otherwise quietly convert this gate into a
second Linux lane that reports "macOS: OK" forever. That is precisely the failure this task keeps
recording — a check that silently consults something other than what it appears to. The bash-version
assertion has the same shape pointed at the shell: if Apple ever ships something other than 3.2, the
gate must break and be re-reasoned rather than drift.

**Not-runnable is declared, not omitted.** `bench-git-workload.sh` requires GNU `date`'s `%N` and
exits with a clear message without it. It is macOS-parseable and not macOS-runnable, and the gate
records exactly that. Excluded from execution; **never** excluded from parsing.

**Where the executing half lives.** The shared gate does parse, audit and assertion — uniform across
repos. Which *gates* then run on macOS differs per repo and is already expressed in that repo's CI,
so the macOS job runs them there rather than duplicating the list into a manifest the generator
would have to keep in sync.

## Acceptance criteria (each becomes a test)

- [ ] **AC1:** On a `macos-latest` runner, every tracked `*.sh` in the repo parses under the system
      bash, and the run prints the bash path and version it used.
- [ ] **AC2:** The gate **fails** — not skips, not warns — if that bash does not report `3.2`.
      Verified by a negative control that forces a different bash and observes a non-zero exit.
- [ ] **AC3:** The gate **fails** if `find`, `stat`, `sed`, `readlink` or `date` on `PATH` is the GNU
      implementation. Verified by a negative control that puts a GNU tool ahead of `/usr/bin`.
- [ ] **AC4:** The GNU-only flag audit reads one codified list; adding a flag to that list is the
      only edit required to extend it.
- [ ] **AC5:** A script containing `find -printf` fails the gate. Confirmed **failing against the
      unfixed gate before the fix is trusted** — SPEC-0013's twenty tests all passed while a live
      defect made them meaningless, and no fixture here is believed until it has been seen to fail.
- [ ] **AC6:** Each repo's existing shell gates execute on the macOS lane and pass, against the BSD
      userland rather than a container's.
- [ ] **AC7:** Scripts that cannot run on macOS are declared **with their reason** and are excluded
      from execution only. Every one of them is still parsed.
- [ ] **AC8:** The same gate runs on the Linux lane and passes, so the flag audit binds for
      contributors with no Mac.
- [ ] **AC9:** `sort -z` is resolved: either macOS `sort` accepts it or it does not, recorded as a
      fact rather than as the open hedge the record currently carries.
- [ ] **AC10:** T-0003 AC4 cites the green run. If the lane is red, AC4 stays open and names what
      failed — a red lane is a finding, not a reason to soften the criterion.

## Open questions

1. **Does the macOS lane block merges, or report?** Blocking is the honest reading of AC4 — an
   unenforced gate is the arrangement this spec exists to replace. The cost is that a runner-image
   change can block five repos at once, and the environment assertions in part 3 are deliberately
   brittle. Recommendation: **blocking**, on the grounds that a portability gate nobody must satisfy
   restates the current situation with more YAML.
2. **All five repos, or the super-repo only?** Per-repo catches the defect in the PR that introduces
   it; super-repo-only catches it later, at the pin bump, in someone else's change.
   Recommendation: **all five**, matching SPEC-0012 and SPEC-0013.
3. **Does `check-agent-surfaces-fresh.sh` belong on the macOS lane?** It needs all five repos checked
   out, which only the super-repo lane has. Probably super-repo-only; the implementation should
   confirm rather than assume.

## Implementation

Not started. Blocked on approval of this spec (`docs/process/spec-driven-development.md`: Approved
before RED).
