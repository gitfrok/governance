# T-0059: Durable CI job history and the runs list

- **Status:** Done (2026-08-19) — backend@94a55c1; SPEC-0054 AC1–AC6 proven
- **Phase / Epic:** 4 / EP-26 (Tier B)
- **Repo(s):** backend
- **Spec:** ../specs/SPEC-0054-*.md (AC1–AC6)
- **ADRs:** 0072, 0073, 0070, 0069, 0006
- **Owner:** unassigned

## Goal

See the spec. This task is one repository's share of it, split along the ADR-0027 boundary.

## Acceptance criteria (test-first)

- [x] SPEC-0054 AC1–AC6 — as written in the spec; the spec is the authority and this file does not restate it.

## Tests to write first

- As the spec's *Acceptance criteria* section requires, RED before implementation.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- ADR-0072 defers job logs and ADR-0073 defers policy authoring. Neither absence is a gap to fill
  opportunistically here: both are decisions with their own follow-ups.

## Exit record (2026-08-19)

**AC1–AC6 green, and AC6 by evidence.** backend **94a55c1**. Seven integration proofs against the
dev Postgres, **0 skips** — the count, not the green summary, is what AC6 asks for.

Third instance of ADR-0062's move. The idempotency rule moved from a mutex to the database:
`CreateOrGet` was atomic under a lock in the memory adapter, and `UNIQUE (tenant_id,
idempotency_key)` is the same invariant where more than one process can enqueue.

**The table has no column for job output**, and that is the point rather than an omission.
ADR-0072 defers log retention to its own decision; adding a column here is that decision, not a
migration.

Paging walks `(queued_at DESC, job_id DESC)`, so two jobs queued in the same microsecond cannot
repeat or skip across a page boundary — the cursor is a position in a total order rather than an
offset into an answer.
