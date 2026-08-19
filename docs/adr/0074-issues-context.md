# ADR-0074: Issues is a bounded context, and the largest permanent widening this product has proposed

- **Status:** Accepted
- **Date:** 2026-08-19 (Proposed and Accepted the same day, by the deciding owner)
- **Deciders:** platform (required by ADR-0070's follow-up before any PR-28 spec)
- **Related:** ADR-0070 (Tier C, and the requirement for this ADR), ADR-0022 (bounded contexts),
  ADR-0029 (provenance and what may enter the audit record), ADR-0007 (audit), ADR-0009/0010
  (residency), ADR-0050 (object storage), ADR-0014 (code search), ADR-0006
- **Governs:** PR-28

## Context

The `./UI` prototype shows an issue tracker: `Issue #247`, open and closed states, labels,
milestones, assignees, participants, and a `Closes issue` link to a merge request. ADR-0070 adopted
it as PR-28 and required this ADR before a spec.

The screens are the smallest part of it. **Issues is a bounded context** under ADR-0022 — its own
aggregate, storage, events, permissions and retention — and it is the first context this product
would add whose primary content is **free-form user text**. Every other context stores facts the
system produced: commits, scans, decisions, runs, packs. An issue stores what a person wrote.

That difference is what makes this the largest permanent widening the product has proposed, and it
is easy to miss because an issue tracker looks like a table with a status column.

## What has to be decided, and is not decided here

**1. Whether issue content enters the evidence pack.** ADR-0029 admits control records — approvals,
policy decisions, scan gates, access changes. An issue is none of those. But an issue *linked to* a
merge request that satisfied a policy is arguably part of the walkthrough an auditor wants. If
issues never enter, the pack is honest and thinner than a customer expects; if they do, the pack
starts carrying unstructured user text, and SPEC-0032 AC2's "no attested content in a control
section" becomes a much harder line to hold.

**2. Attachments.** The prototype does not show them and every issue tracker grows them. User
uploads mean object storage (ADR-0050), size and retention as fair-use dimensions (PRD §6),
malware scanning, and content that is tenant data under residency (ADR-0009/0010). Attachments are a
larger decision than issues.

**3. Cross-context linking.** `Closes issue` is a reference between Issues and Code Review. Under
ADR-0022 that is an identifier and an event, never a foreign key or a cross-context read. Deciding
it as a join is the single easiest way to collapse two contexts into one.

**4. Mentions and notification.** Naming a person in issue text is an identity read across contexts
and, if it notifies, an egress path the product does not currently have.

**5. Search.** The code-search index is code. Issues being searchable is a second index with
different permissions, and carried limit 12 already says that index is in-process and lost on
restart.

## Decision

**This ADR does not adopt issues. It records what adopting them costs and fixes three boundaries so
the eventual design starts in the right place.**

**1. Issues is its own context, with its own storage and its own module.** Not a table beside
merge requests, and not a field on one. The moment issue state is readable from the Code Review
context's storage, both stop being contexts.

**2. Issue content never enters an audit record or an evidence pack control section.** Whatever is
later decided about an *appendix*, the control sections stay what ADR-0029 and SPEC-0032 AC2 make
them: system-produced records with no free-form user content. An issue may be *referenced* by
identifier from a control record; its text may not travel into one.

**3. Attachments are out of scope for PR-28 and need their own decision.** An issue tracker without
attachments is a coherent product. An issue tracker with attachments is a content platform, and the
difference is storage, scanning, retention, residency and metering.

## Accepted scope (2026-08-19)

**The owner accepted this ADR together with its recommended alternative: link to an external tracker.
This product does not build an issue tracker.** The first increment is specified as SPEC-0059, and it
is one decision rather than a context — *how a merge request references an issue that lives somewhere
else.*

That decision, in full:

**1. The reference is an identifier and a link, and nothing else.** A merge request may carry external
issue references, each a tracker label, an issue key and an absolute `https` URL. There is no title,
no state, no assignee, no labels and no body — **because the platform never asks the tracker
anything.** Nothing here fetches, polls, authenticates against, or receives a webhook from a customer's
tracker. A field for the issue's title would be a field the product could only fill by becoming a
client of somebody else's system, and every such field is a promise about freshness nobody can keep.
Check 18 asserts that absence against the compiled descriptor.

**2. "Closes issue" is refused as automation and kept as prose.** The prototype's link implies the
platform closes the issue on merge. It does not: closing an issue happens in the tracker, by whoever
manages it. A reference is **inert** — merging a merge request performs no outbound act and infers no
issue state. This is the assumption a reader will make first, so the surface says so rather than
letting the absence be discovered.

**3. Decision 2 above stands unchanged and is now cheap to keep.** With no issue text in the product
at all, "issue content never enters an audit record or an evidence pack control section" is satisfied
by there being no content. The audit record for a link names the identifier; the identifier is the
only thing there is.

**4. The reference lives on the Code Review side, as decision 1's shape required.** It is a field on
the merge request aggregate — an identifier held by the context that owns the merge request — not a
foreign key, not a join, and not a read into another context. There is no Issues context to collapse
into, which is the cheapest possible way to satisfy that decision.

**5. A link is a `merge_request.external_issue.link` decision**, a new action granted to `owner` and
`member` and denied to `reader`. It is not folded into `merge_request.open`: a write authorized as
something it is not is a lie in the vocabulary, and the role table is the one place this product's
authorization is legible.

**What this increment must not grow into without returning here:** a tracker client, a webhook
receiver, a cached issue title or state, or a merge that closes something. The first two make this
product a client of a system it does not control; the third is a freshness claim; the fourth is an
outbound act on a customer's data.

**What the original PR-28 asked for is not being built, and the PRD says so.** "Open, assign, label,
discuss and close issues" is not partially delivered — it is replaced. The requirement keeps its
number and is re-scoped to the reference, dated and citing this ADR.

**One honest limitation, recorded rather than hidden.** The Code Review context's store is
`NewMemoryStore` — merge requests are not durable today, which was survivable while a merge request
was a short-lived object and is the same gap ADR-0071 closed for the repository registry. An external
issue reference is exactly as durable as the merge request carrying it, which is to say: not, until
that store has an ADR of its own. This increment does not fix it, does not pretend to, and does not
quietly add a table to one context's adapter while the aggregate it belongs to has none.

## Consequences

**Good.** The boundaries most likely to be crossed under delivery pressure are named before anyone
writes a schema. Decision 2 in particular is the one that would be crossed silently — by an appendix
that "just includes the linked issue for context".

**Bad.** PR-28 is not delivered by this ADR and is not close to delivered. Issues is the largest
single piece of work in Tier C and probably in the phase: a context, a schema, an event stream, a
permission model, a UI, and a search story.

**The risk this ADR is most likely to be wrong about.** That issues are worth building at all.
ADR-0070 already records that Tier C's evidence is a mockup rather than a user, and issues are the
clearest case: every customer already has an issue tracker, the switching cost is enormous, and a
worse one bundled with a forge has repeatedly failed to move anyone. The honest reading is that
PR-28 may be parity work that nobody will use, and this ADR's cost section is the argument against
it as much as the plan for it.

## Alternatives considered

**Link to an external tracker instead.** Cheaper by an order of magnitude, honest about where issues
actually live, and probably what most customers want. It needs one decision — how a merge request
references an external issue — rather than a context. **Recommended for consideration before PR-28.**

**Issues as a thin table on Code Review.** Refused by decision 1: it collapses two contexts, and the
collapse is irreversible in practice.

## Follow-ups

- Whether to build issues at all, or to link to an external tracker (the alternative above).
- Attachments, if issues proceed.
- Whether an issue may appear in an evidence pack appendix, and under what provenance class.
