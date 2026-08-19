# SPEC-0059: A merge request references an issue that lives somewhere else

- **Status:** Approved (2026-08-19) — ADR-0074 Accepted with this alternative; RED may begin
- **Owner:** platform
- **Context(s):** Code Review (owns the merge request the reference lives on) · BFF · Web frontend —
  ADR-0022
- **ADRs:** 0074 (decides this, and decides against building a tracker), 0029 (provenance, and what
  may enter a control record), 0022, 0006, 0007, 0069, 0070
- **Task(s):** T-0074 (contract + policy + backend), T-0075 (bff), T-0076 (web)

## Problem / context

PR-28 asked for an issue tracker: open, assign, label, discuss and close. ADR-0074 recorded what that
costs — a bounded context whose primary content is free-form user text, with its own storage, events,
permissions, retention and search — and recommended the alternative this spec builds: **link to the
tracker the customer already has.**

The ADR's argument for the alternative is the one worth restating, because it is the reason this spec
is short. Every customer already has an issue tracker; the switching cost is enormous; a worse one
bundled with a forge has repeatedly failed to move anyone. What a forge is actually asked for is the
*reference* — "this change is for that issue" — and that is one decision, not a context.

**The whole design is that the platform never asks the tracker anything.** No fetch, no poll, no
webhook, no stored credential. That single property is what makes the feature small, keeps it correct
under a tracker outage, and means there is no field here whose value could go stale.

## In scope

- A merge request carrying external issue references: a tracker label, an issue key, and an absolute
  `https` URL.
- Adding and removing a reference, each authorized and audited.
- Rendering them on the merge request, as links that state where they go.

## Out of scope

- **An issue tracker.** No issue aggregate, no issue storage, no issue text anywhere in this product.
- **Any read of the tracker**, by ADR-0074's accepted scope: no title, no state, no assignee, no
  labels, no body, no comment count. Not deferred — refused, because a field the product can only fill
  by becoming a client of somebody else's system is a freshness promise nobody can keep.
- **Closing an issue on merge**, and any other outbound act. A reference is inert.
- **Attachments**, which ADR-0074 decision 3 already put outside PR-28 entirely.
- **A tracker integration, a webhook receiver, or a stored tracker credential.**
- **Making merge requests durable.** See the honest limitation below.

## The reference's shape, and why each field is the one it is

| Field | Why |
|---|---|
| `tracker` | A short label the tenant recognises — "JIRA", "Linear", "GitHub". It is not an enum: a vocabulary of trackers would need a decision every time a customer used a different one. |
| `issue_key` | What a person says out loud: `PLAT-1421`. It is the reference's identity within a tracker, and the only thing the audit record needs. |
| `url` | Absolute, `https` only. It is what makes the reference useful and the only field a reader clicks. |

Nothing else. A `title` would have to be fetched or typed: fetched makes this a tracker client, typed
makes it a copy that silently diverges from the truth.

## Contracts touched

- `contracts/proto/codereview/v1` — **additive**: `repeated ExternalIssue external_issues` on
  `MergeRequest`, plus `LinkExternalIssue` and `UnlinkExternalIssue` on `MergeRequestService`.

`CreateMergeRequestRequest` is deliberately not widened. Opening a merge request and referencing an
issue are separate acts with separate authorization, and a create that could carry references would
make the link path optional — which is how one of two paths stops being tested.

## Policies touched

- `policies/gitsaas/authz` — **additive**: `merge_request.external_issue.link`, granted to `owner` and
  `member`, denied to `reader`, asked about the `merge_request` resource.

It is a new action rather than a reuse of `merge_request.open` because a write authorized as something
it is not is a lie in the vocabulary, and the role table is where this product's authorization is
legible. **The role vocabulary itself is unchanged** — SPEC-0058 AC5's pin still holds: three roles,
one more action.

## Data owned

No new table. The references are a field on the merge request aggregate, held by the context that owns
it.

## Acceptance criteria (each becomes a test)

### The contract, the policy and the backend (T-0074)

- [ ] **AC1** `LinkExternalIssue` adds a reference to a merge request: tracker, issue key and URL,
      recorded with who added it and when. `UnlinkExternalIssue` removes one by tracker and issue key.
- [ ] **AC2** **The same reference twice is one reference.** Linking `(tracker, issue_key)` that is
      already present is accepted and changes nothing — no duplicate, no second audit record, and the
      original instant does not move.
- [ ] **AC3** **The URL must be absolute and `https`.** A `http:`, `javascript:`, `data:` or relative
      URL is refused by the domain, with the field named. This is a link a person will click from
      inside the product, and the product is not going to be the thing that hands them a hostile one.
- [ ] **AC4** Tracker, issue key and URL are each bounded, and the reference count per merge request is
      bounded. A reference list is a reference list, not a document.
- [ ] **AC5** **Both acts are `merge_request.external_issue.link` PDP decisions**, and a refusal is
      coarse: a caller who may not link learns nothing about whether the merge request exists.
- [ ] **AC6** Each accepted act publishes exactly one `MergeRequestUpdated`, the event this context
      already emits for a change to a merge request — no new event, because nothing new happened to
      the world beyond the merge request changing.
- [ ] **AC7** **Nothing in the backend reads the tracker.** There is no HTTP client, no URL fetch and
      no port that could acquire one on this path. A test asserts the reference is stored exactly as
      given and that the service makes no outbound call.
- [ ] **AC8** **Additive:** `buf breaking` passes; `external_issues` is a new field and the two RPCs
      are new.
- [ ] **AC9** **No external-issue message carries tracker content.** A descriptor check asserts no
      field named `title`, `body`, `text`, `summary`, `description`, `status`, `state`, `assignee`,
      `labels`, `comments` or `attachment` on the external-issue shape, with a fixture carrying `title`
      and `status` to prove the check can fail — ADR-0074's accepted scope as a type property.
- [ ] **AC10** **The policy addition is exactly one action.** `role_actions` still has three keys
      (SPEC-0058 AC5's pin), `reader` is denied the new action in the denial matrix, and the action is
      pinned to the `merge_request` resource.

### The BFF (T-0075)

- [ ] **AC11** The BFF shapes and forwards a link and an unlink under the session. The actor comes from
      the session and has no field on the request.
- [ ] **AC12** Every failure is one coarse refusal, except a bad URL, which is a 400 naming the field —
      the caller already knows what it sent.
- [ ] **AC13** The response body carries no tracker content: a test asserts none of the AC9 vocabulary
      appears, so the increment holds at the layer a browser reads.

### The view (T-0076)

- [ ] **AC14** The merge request page lists its external issue references, each showing the tracker,
      the issue key, and **the host the link goes to**. A reader can see where a link leads before
      clicking it.
- [ ] **AC15** **The page says what a reference is and is not**: it is a pointer to an issue in the
      tracker, this product stores no issue and shows no issue state, and merging does not close
      anything. The copy enumeration forbids "closes", "will close", "auto-close", "synced", "coming
      soon" and any phrasing implying the platform reads or writes the tracker.
- [ ] **AC16** Linking and unlinking are plain forms that work with no client script.
- [ ] **AC17** **A hostile URL never becomes a link.** A reference whose URL is not `https` is rendered
      as text, not as an `href`, and a test drives `javascript:`, `data:` and `http:`. External links
      carry `rel="noopener noreferrer"`.
- [ ] **AC18** A merge request with no references says so plainly, and says how one is added.
- [ ] **AC19** No hex literal; the two regression pins unmodified; captures regenerated per SPEC-0047
      AC10 where the surface changed, and reviewed.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G2 authorization | One new action, granted to owner and member, denied to reader; the role vocabulary is unchanged and still pinned. |
| G4 review integrity | A reference is inert: it cannot satisfy a merge policy, change a review outcome, or close anything. The merge gate does not read it. |
| G5 auditability | Each link and unlink is audited by identifier. There is no issue content to keep out of a control record, which is ADR-0074 decision 2 satisfied by absence (ADR-0029). |

## Non-functional

- No outbound network dependency is introduced. A tracker being down changes nothing about this
  product's behaviour, which is the point of storing a reference rather than a mirror.

## Open questions / assumptions

1. **Merge requests are not durable today.** The Code Review context's store is `NewMemoryStore`, so a
   reference is exactly as durable as the merge request carrying it — which is to say, not, across a
   restart. That is the same gap ADR-0071 closed for the repository registry, it needs its own ADR, and
   this spec does not quietly add a table to one context's adapter while the aggregate has none.
   **Recorded as a follow-up rather than fixed here.**
2. **The URL is trusted to be the tenant's own tracker, not validated against an allowlist.** A
   per-tenant allowed tracker origin is a settings decision, and ADR-0076 kept settings narrow. AC14's
   host rendering and AC17's `https`-only rule are what stand in for it: a reader sees where a link
   goes, and a non-`https` URL is never clickable.
3. **`Closes issue` may be what customers actually want.** If so, it is an outbound write to a system
   this product does not control, with credentials, retries and partial-failure semantics — an ADR, not
   a checkbox.
