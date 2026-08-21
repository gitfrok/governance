# T-0080: The Notifications context — bell, list, mark-read

- **Status:** In progress (2026-08-21)
- **Phase / Epic:** EP-31 (notifications)
- **Repo(s):** backend, bff, webfrontend
- **Spec:** ../specs/SPEC-0063-notifications.md (AC1–AC7)
- **ADRs:** 0086, 0022, 0025, 0003, 0062
- **Owner:** unassigned

## Goal

The product tells actors what happened: a durable, tenant-scoped notification per (recipient,
event), read in the app.

## Acceptance criteria (test-first)

- [ ] SPEC-0063 AC1–AC7 — as written in the spec.

## Tests to write first

- The idempotency proof first (AC4): replay the same event twice against real Postgres and count
  rows — at-least-once delivery with exactly-once rows is the property everything else leans on.
- The recipient coverage table test second (ADR-0086's named risk): every subscribed event type
  names its recipients; an unsubscribed-but-known event type fails the test rather than notifying
  nobody silently.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- Order of work follows ADR-0027: migration + adapter (real-Postgres proofs, zero skips), then
  subscriber + service, then BFF routes, then the bell.
- Email/webhooks stay out even if tempting mid-task; they are ADR-0086's named follow-ups with
  decisions of their own.
