# SPEC-0063: The Notifications context

- **Status:** Approved (2026-08-21) — Accepted ADR-0086. Implementation not started.
- **Owner:** platform
- **Context(s):** Notifications (new). Producers unchanged; BFF and webfrontend gain routes and
  a bell.
- **ADRs:** 0086 (decides this), 0022, 0025, 0003, 0062
- **Task(s):** T-0080 (backend + bff + webfrontend)

## Problem / context

Every event the product emits has in-process subscribers only. Nothing tells an actor something
happened that they did not see.

## In scope

- `modules/notifications` on the standard three levels; schema `notifications`, RLS forced,
  module-owned migration.
- Bus subscription to the first event set: merge request opened / ready / merged, review
  submitted, findings ingested onto a merge request. Recipients derived server-side (author,
  reviewers at head, the acting actor excluded).
- One row per (recipient, event), idempotent on the event ID — at-least-once delivery, exactly-
  once rows.
- BFF list / unread-count / mark-read routes; bell with unread count in the app shell; list page
  with read state.

## Out of scope

- Email, webhooks, per-user preferences, digests — ADR-0086's named follow-ups, each needing its
  own decision (a mailer dependency; outbound signing and retry).
- Any change to a producer's contract or store.

## Acceptance criteria (test-first)

- [ ] **AC1** A merge request opened for review produces one notification for the target's
      reviewers-to-be (protection rule holders) minus the actor; durable across a restart.
- [ ] **AC2** A review submitted notifies the author (never the reviewer); a merge notifies the
      author and every reviewer whose approval counted at the gate.
- [ ] **AC3** Findings ingested onto a merge request notify its author once per ingest batch,
      not once per finding.
- [ ] **AC4** Replaying any event makes no second row (idempotency keyed on the event ID),
      proven against real Postgres with `-race` and zero skips.
- [ ] **AC5** Another tenant's notifications are absent, not forbidden; RLS forced; the
      migration passes T-0004's boundary linter.
- [ ] **AC6** Unread count and mark-read are exact: marking one marks one; the count never
      counts another tenant's rows.
- [ ] **AC7** The bell renders the count honestly — zero is zero, not "no badge"; the list says
      what happened, where, and when, and links to the thing.

## Governance mapping

| Objective | How |
|---|---|
| G5 auditability | Notifications are derived from the same events the audit trail records; nothing is notified that did not happen. |
| G1 tenant isolation | Recipient rows are tenant-scoped and RLS-forced like every store. |

## Open questions / assumptions

1. Retention: read notifications accumulate. Same data-lifecycle class as ADR-0080's
   `applied_requests` follow-up; named, not solved here.
2. Recipient coverage is the risk ADR-0086 names; the subscriber keeps a coverage table asserted
   by test so a new event type cannot silently notify nobody.
