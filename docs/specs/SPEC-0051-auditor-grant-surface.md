# SPEC-0051: Auditor grants — issue, list and revoke scoped, time-boxed evidence access

- **Status:** Implemented (2026-08-18) — every acceptance criterion is proven by its task(s); approved (2026-08-18) — no new decision is required; PR-18 already binds, SPEC-0033
  already fixes the behaviour, and the BFF has served all three routes since T-0027. ADR-0070 places
  this in Tier A.
- **Owner:** platform
- **Context(s):** Web frontend (renders) · BFF (shapes and forwards) — ADR-0022. No backend or
  contract change.
- **ADRs:** 0070, 0069, 0015, 0019, 0049, 0006 (the PDP that owns `auditor.grant.manage`)
- **Task(s):** T-0052

## Problem / context

PR-18 requires that an auditor can be granted **scoped, read-only, time-boxed** access to evidence
**without repo read access**. The BFF has served the administration surface since T-0027:

| Route | Shape | Returns |
|---|---|---|
| `POST /api/v1/audit/auditor-grants` | JSON `{auditor_principal_id, range_from, range_to, repository_id?, pack_ids[], expires_at}`, RFC3339 | `AuditorGrantView` |
| `GET /api/v1/audit/auditor-grants?auditor_principal_id=` | — | `{grants: [...]}` |
| `DELETE /api/v1/audit/auditor-grants/{grant_id}` | — | `AuditorGrantView` |

No UI has ever called any of them. Issuing scoped auditor access is currently an engineer's `curl`,
which makes PR-18 true of the platform and false of the product.

**Two properties of this surface shape the whole design.**

**The server may bound what was asked for.** `issueGrant`'s own comment says the backend answers
with "the expiry it recognized — **which may bound the requested one**". A UI that confirms the
grant by echoing the form's expiry would tell an admin their auditor has access until a date the
server never agreed to. The returned grant is the only truth; the request is a proposal.

**A grant's state is a fact read at decision time, not a cached flag.** SPEC-0033 AC5/AC7: revocation
takes effect on the next decision, and the state in a list is the server's rendering of its own
record *at response time*. The UI must therefore never compute a state — not "expired because
`expires_at` is in the past", not "active because it is not revoked". Comparing `expires_at` against
the browser's clock is the specific mistake available here, and it would render a grant as expired
while the server still honours it, or the reverse.

**Revoking cannot be a plain form.** HTML forms speak GET and POST only; there is no DELETE. The
revoke control therefore posts to an SSR route which issues the `DELETE` upstream — the same relay
shape T-0049 used — so the control stays markup and SPEC-0048 AC6's "no affordance is a permission
claim" story holds without client JavaScript.

## In scope

- Issuing a grant: auditor principal, closed range, optional repository scope, named packs, expiry.
- Listing the tenant's grants, optionally narrowed to one auditor principal.
- Revoking a grant.
- The returned-truth and server-state rules above.

## Out of scope

- Any new BFF route, backend RPC or contract change.
- Extending, renewing or editing a grant. `grantIssueBody` has no field for any of them, and
  SPEC-0033 AC8 records that as deliberate: a changed scope is a new grant.
- Rendering anything a grant gives access **to**. This surface administers access; it never shows
  pack contents. That separation is the whole of PR-18's "without repo read access".
- Any client-side computation of grant state, expiry or validity — forbidden above, not merely
  omitted.
- Evidence packs — SPEC-0050, its own surface, reached from the Compliance destination that spec
  establishes.

## Contracts touched

None. `identity/v1` and the BFF's `AuditorGrantView` / `GrantListView` JSON are consumed unchanged.

## Data owned

None.

## Acceptance criteria (each becomes a test)

- [x] **AC1** A grant can be issued: the form posts JSON with RFC3339 timestamps and at least one
      pack ID. An unparseable timestamp, an open or inverted range, a missing auditor or an empty
      pack list is refused before a request is compiled — the BFF's `ValidateGrantIssue` refuses the
      same shapes, and its refusal is the coarse 404 that names nothing.
- [x] **AC2** **The issued grant renders from the response, never from the request.** A test drives
      a response whose `expires_at` is earlier than the one posted and asserts the rendered expiry is
      the returned one. Echoing the submitted value is the failing case.
- [x] **AC3** The tenant's grants list renders scope, state and lifecycle: auditor principal, range,
      repository scope if any, pack IDs, expiry, who granted it, when it was issued, and when it was
      revoked if it was. It renders no pack contents.
- [x] **AC4** **State is never computed here.** The rendered state is the `state` string the server
      sent. A test drives a grant whose `expires_at` is in the past but whose state is `ACTIVE` and
      asserts it renders as active — the server's record is the fact, and the browser's clock has no
      standing (SPEC-0033 AC7).
- [x] **AC5** A grant can be revoked through an SSR relay that issues the upstream `DELETE`; the
      control is a plain form, so it works with no client script. After revocation the page renders
      the returned grant, not an assumed one.
- [x] **AC6** A refusal names no cause. Nonexistent, cross-tenant, revoked, expired, malformed and
      unauthorized are one coarse refusal (SPEC-0033, SPEC-0001), so SPEC-0048 AC4's copy
      enumeration applies verbatim to this surface.
- [x] **AC7** No affordance is a permission claim. Issuing and revoking are owner-only PDP
      decisions this surface is never told; the controls render for every session and nothing is
      hidden or disabled to signal an outcome. A test asserts the controls are present and nothing
      is disabled.
- [x] **AC8** `ACTIVE`, `REVOKED` and `EXPIRED` enter `src/lib/status.ts`. **They form their own
      distinctness set** — they render side by side in the list, so no two share a glyph or a word,
      and the pair `ACTIVE`/`REVOKED` is not the success/danger pair. A test asserts pairwise
      distinctness across the grant states specifically, not merely across the whole vocabulary.
- [x] **AC9** No hex literal is introduced; `npm run check:tokens` stays at zero, and every style
      value carrying a length ships its unit.
- [x] **AC10** `tests/usage-regression-pins.test.ts` and `tests/readonly-cause.test.ts` pass
      **unmodified**; `git diff` over both is empty for the whole task.
- [x] **AC11** The e2e stub BFF serves all three routes, including a **bounded-expiry fixture** (the
      issued grant comes back with an earlier expiry than requested) and a grant whose `expires_at`
      is past while its state is `ACTIVE`, so AC2 and AC4 are exercised end to end. Capture fixtures
      are write-free. CVD captures regenerated per SPEC-0047 AC10 and reviewed in grayscale and
      deuteranopia.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 tenant isolation | A cross-tenant grant is refused as the same 404 as one that does not exist; AC6 keeps the copy from distinguishing them. |
| G2 authorization | `auditor.grant.manage` is owner-only and decided by the PDP. AC7 forbids this surface from predicting or mirroring that. |
| G5 auditability | Each lifecycle action appends an immutable record naming the granting admin and the auditor principal — backend behaviour, unchanged and unaided by this layer. |
| G6 evidence | PR-18's point is scoped access without repo read. The out-of-scope rule against rendering pack contents is what keeps the administration surface from becoming a reading one. |

## Non-functional

- Server-rendered; writes go through SSR relays as in T-0049.
- No timers, no polling, no client-side clock arithmetic anywhere on this surface.

## Open questions / assumptions

1. **Pack IDs are typed, not picked.** No route lists a tenant's packs, so the issue form cannot
   offer a chooser. SPEC-0050's status page shows a pack's ID, which is where an admin gets one. A
   picker needs a list route and its own spec.
2. **The auditor principal is typed too.** No principal-search route exists.
3. **Listing is unpaged.** `ListGrants` returns a slice with no page token; if a tenant's grant count
   grows past what one response should carry, that is a BFF change and its own spec.
