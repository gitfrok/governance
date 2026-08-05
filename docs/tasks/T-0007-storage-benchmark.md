# T-0007: Storage benchmark: SeaweedFS-FUSE vs block volumes

- **Status:** Done (2026-08-06) — AC1–AC3; ADR-0033 **Accepted**
- **Phase / Epic:** 0 / EP-3
- **Repo(s):** super-repo (`scripts/`, `deploy/dev/` — bench harness) → governance (result doc +
  Proposed ADR, AC3)
- **Spec:** chore — acceptance criteria below
- **ADRs:** 0020, 0023, 0016
- **Owner:** unassigned

## Goal
Settle the ADR-0020 open knob: is FUSE viable for live bare repos, or block volumes only?

## Acceptance criteria (test-first)
- [x] AC1: Benchmark clone / push / gc / status latency + throughput on (a) SeaweedFS-FUSE
  and (b) fast block volumes, under concurrent load. Harness: super-repo
  `scripts/bench-storage.sh` + `scripts/bench-git-workload.sh` (`make bench-storage`).
- [x] AC2: Include correctness checks (concurrent pushes, fsync/rename semantics). Five probes;
  the decisive one is git's own `update-ref`/`rev-parse` race, which replaced an `mv(1)` proxy that
  could have manufactured the same symptom via `EXDEV` fallback.
- [x] AC3: Result doc `../bench/T-0007/README.md` (+ raw JSON) and **ADR-0033 (Proposed)** —
  confirms the block-volume default; ADR-0016 needs **no** amendment.

## Tests to write first
- integration/bench harness; not unit-tested code but results must be reproducible (scripted).

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions
Follow the Agentic SDLC loop; stop-and-ask if a decision/spec is missing.

**Outcome.** SeaweedFS-FUSE is disqualified for live bare repos on a correctness ground, not a speed
one: `rename()` is not atomic on the FUSE client, and git commits every ref update by renaming a
`.lock` over the ref. 36 of 428 concurrent `git rev-parse --verify` calls failed to resolve a ref that
never stopped existing, with **zero** rename errors from git itself — so rename works, it just is not
atomic. Block: 0 of 229. Reproduced three times across two probe designs.

Performance was not the deciding factor and is recorded for completeness: FUSE costs ~12% on push and
clone, ~2× on `gc` and `status`, 2.6× on concurrent push throughput.

**Done on 2026-08-06**, when ADR-0033 was Accepted — AC3's deliverable is a decision, and ADR-0001
makes the PR review that decision's gate. Invariant 7's escape clause ("unless the benchmark follow-up
in ADR-0020 concludes otherwise") is discharged with it: the benchmark concluded the same way the rule
already read, so the rule stands and the conditional is gone.

**Known limit, deliberately not papered over.** The run is one workstation with a single-node filer,
so the *latency ratios* deserve a re-run on the cluster once T-0003 is verified. The correctness
verdict does not: atomicity of `rename()` is a property of the FUSE client, not of the hardware.
