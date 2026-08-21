# ADR-0086: Notifications are a context, fed by the bus, read in the app — email and webhooks wait

- **Status:** Accepted (2026-08-21, accepted as written by the deciding owner)
- **Date:** 2026-08-21
- **Deciders:** platform
- **Related:** ADR-0022 (bounded contexts; this adds one), ADR-0025 (module layout),
  platform/bus (the event spine every producer already publishes to), ADR-0003/0062 (tenancy,
  RLS, durable stores), ADR-0071/0080 (the adapter-shape precedent)
- **Governs:** the Notifications context. No change to any existing context's contract or store.

## Context

Nothing in the product tells anyone anything happened. A review is requested in silence, a merge
lands in silence, findings arrive on a merge request that nobody has looked at since morning. The
events all exist — `MergeRequestOpened`, `ReviewSubmitted`, `MergeRequestMerged`,
`FindingsIngested` and the rest publish on the in-process bus — but the only subscribers are
in-process projections. There is no user-facing surface whose job is "tell the actor something
they did not see".

Every producer already does its part. What is missing is a consumer whose aggregate is *a thing
a person has not read yet*.

## Decision

**1. Notifications are their own bounded context**, `modules/notifications`, with the standard
three levels: an `api/` surface, a composition root, internal app/adapters. It subscribes to the
existing bus events and writes one row per (recipient, event) worth telling someone about. It
owns its schema (`notifications`), RLS-forced like every other, module-owned migration.

**2. The first channel is the product itself: an in-app list with an unread count.** BFF routes
(list, unread count, mark-read) and a bell in the app shell. Delivery semantics are
at-least-once from the bus with idempotent writes keyed on the event ID — a replayed event makes
one notification, not two.

**3. Recipients are derived server-side from the event and the store it concerns** — the MR's
author and reviewers, the actor to exclude. No recipient field arrives on the wire from a caller;
the notification service reads the aggregate it is notifying about, exactly as attribution reads
the diff.

**4. Email, webhooks and per-user preferences are out of scope until they have an owner.**
Outbound email is a new infrastructure dependency (a mailer, deliverability, PII in subject
lines); webhooks are an outbound-integration surface with signing and retry semantics of their
own. Both are named follow-ups, not silent gaps — this ADR exists so the first channel ships
without pretending the others were decided.

## Consequences

**Good.** The cheapest possible channel ships first, on rails that already exist: no new wire
producers, no polling of other contexts' tables, and the durability posture (durable rows behind
RLS) is the one every post-ADR-0062 store follows.

**Bad.** In-app-only means the notification exists only for someone who opens the product — which
is circular for the "your merge failed" case. That is the honest cost of deferring email, named
here rather than discovered later.

**The risk this ADR is most likely to be wrong about.** Recipient derivation. Every new event
type must say who should hear about it, and a forgotten case is a silent non-notification —
invisible by construction. The subscriber's coverage table is the test surface that keeps this
honest.

## Alternatives considered

**Notifications inside Code Review.** The majority of early events are MR-shaped, and putting the
bell inside the review module would couple a delivery concern to one producer — then Findings and
CI events would either duplicate it or reach across modules. Refused; the bus already made this
decision once (ADR-0022).

**Email first.** Highest perceived value, highest cost: a mailer dependency, deliverability and
PII decisions nobody has taken. Refused as a first channel, kept as a named follow-up.
