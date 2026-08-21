# T-0078: The Code Review context keeps what it was told

- **Status:** Done (2026-08-21) — backend@06e14da; SPEC-0061 AC1–AC18 proven, 16 real-Postgres
  proofs green with `-race` and **0 skips**
- **Phase / Epic:** 4 / EP-29 (durability debt, after Phase 4)
- **Repo(s):** backend
- **Spec:** ../specs/SPEC-0061-code-review-durable-store.md (AC1–AC18)
- **ADRs:** 0080, 0071, 0062, 0003, 0025, 0084 (Accepted — the write split)
- **Owner:** unassigned

## Goal

SPEC-0061 in one task, in one repository. The spec is the authority.

## Acceptance criteria (test-first)

- [x] SPEC-0061 AC1–AC18 — as written in the spec.

## Tests to write first

- The scoping refusals (AC5, AC6) and the call-site pairing (AC7) before the adapter, because they
  are the properties an adapter is easiest to write without.

## Notes / open questions

- **Stopped at RED 2026-08-21, resumed the same day.** The adversarial review before commit found
  that AC9's guard and the service's version-preserving projection write (the ref-update event
  path) cannot coexist in one `Save`; ADR-0084 decided the split and was accepted as written.
  SPEC-0061 is amended (AC9–AC12 carry the split; AC3 converges; AC7's test shape is restated)
  and RED resumes on the amended spec.
- **What the stopped run already proved** (backend work-in-progress, uncommitted): the migration
  and its text tests, the scoping refusals, the call-site pairing test, and all seventeen
  real-Postgres proofs ran green with `-race` and **zero skips** against the dev cluster's
  Postgres (2026-08-21); the full backend suite passed at the same pins. The review's findings
  were the version guard's event-path shape, the missing `ErrVersionConflict` mapping, `Merge`'s
  move-before-save ordering, and the `CreateOrGet` race — none of them in the proofs above, and
  each now has its criterion.

- **The order that makes this reviewable:** migration and its text test, then the adapter one port
  method at a time against a real Postgres, then the wiring. Eleven methods and five tables in one
  task is the diff shape reviewers trust least, so each step should stand on its own.
- **The version guard changes behaviour**, not just storage: a zero-row update is a conflict.
  The 2026-08-21 review corrected this note's earlier claim — the service maps every `Save`
  error to `ErrDenied` today, and its ref-update path `Save`s without bumping the version on
  purpose. Both findings live in ADR-0084; AC11 is the test that says the wire did not move.
- **The port stays as ADR-0080 left it, plus exactly the one method ADR-0084 decision 1 adds** —
  the version-preserving projection write. ADR-0080's refusal to widen it for tenancy stands, and
  the whole scoping design depends on that refusal holding; the new method carries its tenant
  exactly as every other event-path method does.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Exit record (2026-08-21)

**AC1–AC18 green.** backend **06e14da** — the adapter, migration, service split, wiring and tests
in one commit on `main`. The proofs: **16 real-Postgres tests green with `-race`, 0 skips**
(`TEST_DATABASE_URL` + `TEST_SUPERUSER_DATABASE_URL` against the dev cluster's Postgres,
port-forwarded :15432), plus the migration text tests, the service-edge guard tests over the
memory store with an injected conflict, and the derived call-site pairing test. Full backend suite
(97 packages) and the arch/boundary gates green at the same pin.

**The stop did its job.** The pre-commit adversarial review caught what the green proofs could not:
one `Save` cannot serve both write protocols, because the two disagree about what the version column
means — bumped writers arrive at N+1, the projection arrives at N. `WHERE version = v-1` conflicts
every push; `WHERE version IN (v-1, v)` silently kills AC9 by letting a losing bumped writer match
the winner's just-bumped row. ADR-0084 split the write along the protocol line that already existed,
and the resumed RED landed it: `Save` guards (`WHERE version = mr.Version - 1`, zero rows a
conflict), `SaveProjection` preserves the version and re-reads-and-re-applies when the row moved
under it — proven live by bumping the row between the read and the projection and asserting the
caller's edit survives beside the re-applied revisions.

**The pairing is asserted, not trusted.** The AC7 test parses this package's own source, derives its
event entry points from the `bus.Subscribe*` call sites rather than a name list, qualifies store-call
selectors by receiver type so the ImportService's identically-shaped field does not match, and fails
if the event path can reach `Get`/`PutReview`/`Reviews`/`Seen`.

**Merge now refuses before anything moves, and pays for moving anyway.** The guarded `Save` runs
before `MoveRef` (a conflict leaves the record OPEN and the ref untouched — asserted), and a move
that fails after the save is compensated: a re-open under its own version bump and a named audit
record (`codereview.merge.compensated`, denied outcome, correlated to the policy decision and the
move's refusal reason), after which a fresh request ID merges cleanly. The retry test asserts both
bumps.

**Observed, not opened:** the dev cluster's `codereview` tables exist because the proof harness
self-applies the migration under `TEST_SUPERUSER_DATABASE_URL` — the same posture as the repository,
CI and release stores since T-0053/T-0059/T-0064, whose migrations are likewise not in
`scripts/dev-provision.sh`'s list. A fresh provision wires the durable store against a database
without these tables. That is a provisioning gap shared by all four Phase-4-era stores, pre-existing
this task, and recorded here rather than silently widened into scope.
