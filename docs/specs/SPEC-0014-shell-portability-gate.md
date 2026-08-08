# SPEC-0014: Shell portability gate (macOS lane)

- **Status:** Approved
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

Unticked boxes below are the ones that **need a Mac to answer**, and they stay unticked until a
green `macOS portability` run exists. That is the whole point of the spec; ticking them from a Linux
run would be the fabrication AC4 has twice refused.

- [ ] **AC1:** On a `macos-latest` runner, every tracked `*.sh` in the repo parses under the system
      bash, and the run prints the bash path and version it used. *Needs the run.*
- [x] **AC2:** The gate **fails** — not skips, not warns — if that bash does not report `3.2`.
      Verified by a negative control that forces a different bash and observes a non-zero exit, and
      by its mirror: a stub reporting 3.2.57 makes the bash complaint disappear while the userland
      one remains, so the assertion is not a blanket refusal.
- [x] **AC3:** The gate **fails** if `find`, `stat`, `sed`, `readlink` or `date` on `PATH` is the GNU
      implementation. `PORTABILITY_STRICT=1` on Linux is that control and reports all five.
- [x] **AC4:** The GNU-only flag audit reads one codified list — `portability-flags.tsv`, 17
      patterns; adding a flag to that list is the only edit required to extend it.
- [x] **AC5:** A script containing `find -printf` fails the gate. Confirmed by deleting that row
      from the list and observing the same fixture exit 0 — the detection is the pattern's doing and
      not the fixture's.
- [ ] **AC6:** Each repo's existing shell gates execute on the macOS lane and pass, against the BSD
      userland rather than a container's. *Needs the run.*
- [x] **AC7:** Scripts that cannot run on macOS are declared **with their reason** and are excluded
      from execution only. Every one of them is still parsed.
- [x] **AC8:** The same gate runs on the Linux lane and passes, so the flag audit binds for
      contributors with no Mac. Green in all five repos: 18, 19, 5, 5 and 6 scripts respectively.
- [ ] **AC9:** `sort -z` is resolved: either macOS `sort` accepts it or it does not, recorded as a
      fact rather than as the open hedge the record currently carries. *Needs the run.* The
      construct itself is already gone from `dev-up.sh`; what is unresolved is the claim about
      Darwin, and only Darwin can settle it.
- [ ] **AC10:** T-0003 AC4 cites the green run. If the lane is red, AC4 stays open and names what
      failed — a red lane is a finding, not a reason to soften the criterion.

## Resolutions

**Approved 2026-08-09.** All three were answered by instruction; the record keeps the distinction
because it changes what a later reader may assume was reviewed.

1. **Blocking, not reporting.** A portability gate nobody must satisfy restates the current
   situation with more YAML. The accepted cost is that the part-3 assertions are deliberately
   brittle, so a runner-image change can block five repos at once — which is the intended behaviour,
   not a regrettable side effect: the alternative is a lane that goes quietly meaningless.

   **This has a prerequisite the spec did not anticipate, and it is not automatic.** The macOS lane
   is a separate job, so it is a separate required-status-check context, and contexts are registered
   by the super-repo's `scripts/apply-rulesets.sh` against each repo's `main-integrity` ruleset
   (ADR-0031). Until `make rulesets-apply` is run with an admin token, **every macOS lane reports
   and does not block.** That gap is named in each workflow file rather than left to be discovered.

2. **All five repos**, matching SPEC-0012 and SPEC-0013. Per-repo catches the defect in the PR that
   introduces it; super-repo-only would catch it later, at the pin bump, inside someone else's
   change.

3. **`check-agent-surfaces-fresh.sh` runs on both lanes, and means different things on each.** In
   governance it checks that repo's own surfaces and runs standalone, so it is on the macOS lane
   there. In the composition it needs all five repos checked out, so the super-repo's macOS lane runs
   it over all of them. Confirmed by running it rather than assumed.

## Implementation

| File | Where | What |
|---|---|---|
| `check-shell-portability.sh` | all five repos | the gate: parse, audit, environment assertion |
| `portability-flags.tsv` | all five repos | the codified list — 17 patterns |
| `test-shell-portability.sh` | governance only | 19 cases, alongside the other three suites |
| `.github/workflows/ci.yml` | all five repos | `macOS portability` job, plus the audit on the Linux lane |
| `scripts/apply-rulesets.sh` | super-repo only | multiple required contexts per repo |

Generated from `canonical/agent-surfaces/shared/` by the ADR-0037 pipeline. The surfaces gate goes
from 72 files to 82.

## What the implementation found

**1. The gate's first real run condemned the fix that the audit it replaces had produced.**
`bench-storage.sh` detects filesystem type by *probing* `stat -f -c %T` inside a conditional and
falling through to a `df`+`mount` pair when it fails — which is portable, and is that shape precisely
because the 2026-08 audit made it so. A flat "mentions a GNU flag" rule marks it a violation.

That is a false positive with a real lesson in it: **the pattern list is a proxy**, and the proxy is
wrong for a GNU construct guarded by a portable fallback. The answer is a waiver marker
(`# portability-ok: <reason>`) that binds to one line or the line above it, requires a reason, and is
**printed on every run and counted in the summary**. A waiver you cannot see in the log is an
exemption; one you cannot avoid reading is a declaration.

**2. The pattern list cannot live inside the gate.** A heredoc of these patterns would be scanned by
the gate that contains it, and every entry would report itself. SPEC-0013 shipped that defect one
level down — a `Scope:` parser that enforced the example inside its own PR body. Here the cheaper fix
exists: a `.tsv` is not a `*.sh`, so nothing self-matches and the gate audits its own source honestly
rather than by exemption.

**3. A test asserted a syntax error that was not one.** The first draft's parse-half fixture was
`if [ -z "$x" ; then …`, which *looks* broken and is not: `[` is a command, so a missing `]` is a
runtime failure `bash -n` correctly says nothing about. The case passed the gate and was caught by
running it, not by reading it — the same shape as SPEC-0013's finding that a fixture which cannot
distinguish the mechanism from the outcome is not testing the mechanism. Every detection case here
was afterwards re-run with its pattern removed from the list and confirmed to stop firing.

**4. One control cannot exist on Linux, and was not faked.** The *passing* side of the part-3
assertion needs a real BSD userland at `/usr/bin`; a stub anywhere else is rejected by the same path
check it would be trying to satisfy. Making that test pass would have meant weakening the assertion.
The macOS lane is that control, and the suite says so where the missing case would have been.
