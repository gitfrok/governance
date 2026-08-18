# T-0052: Issue, list and revoke auditor grants from the web UI

- **Status:** Done (2026-08-18) — webfrontend@1141bc5; SPEC-0051 AC1–AC11 proven
- **Phase / Epic:** 4 / EP-25 (Tier A — the routes that exist and have no UI)
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0051-auditor-grant-surface.md (AC1–AC11)
- **ADRs:** 0070, 0069, 0015, 0006
- **Owner:** unassigned

## Goal

Make PR-18 reachable. The grant administration surface has been served since T-0027 and called by
nothing, so granting an auditor scoped, time-boxed evidence access is an engineer's `curl` today.
Reached from the Compliance destination T-0051 establishes.

## Acceptance criteria (test-first)

- [x] AC1: issue a grant — RFC3339 JSON, at least one pack ID; malformed shapes refused before a
      request is compiled.
- [x] AC2: the issued grant renders from the RESPONSE, never the request. Driven with a response
      whose `expires_at` is earlier than the posted one.
- [x] AC3: the list renders scope, state and lifecycle; no pack contents.
- [x] AC4: state is never computed here. Driven with a grant whose `expires_at` is past and whose
      state is `ACTIVE` — it renders active.
- [x] AC5: revoke through an SSR relay issuing the upstream DELETE; a plain form, no client script;
      the returned grant is what renders after.
- [x] AC6: refusal names no cause — SPEC-0048 AC4's copy enumeration applies verbatim.
- [x] AC7: no affordance is a permission claim; controls present, nothing disabled.
- [x] AC8: `ACTIVE`/`REVOKED`/`EXPIRED` enter `status.ts` as their own distinctness set; no shared
      glyph or word, and `ACTIVE`/`REVOKED` is not the success/danger pair.
- [x] AC9: `npm run check:tokens` stays at zero; every length value ships its unit.
- [x] AC10: `usage-regression-pins` and `readonly-cause` pass unmodified; `git diff` over both empty.
- [x] AC11: stub BFF serves all three routes with a bounded-expiry fixture and a past-expiry-but-
      ACTIVE fixture; capture fixtures write-free; captures regenerated and reviewed.

## Tests to write first

- vitest: the issue client — validation before a request is compiled; RFC3339 encoding.
- vitest: the returned-truth rule — rendered expiry equals the response's, not the request's.
- vitest: the no-computed-state rule — past `expires_at` with `ACTIVE` renders active.
- vitest: the revoke relay — a POST that issues a DELETE upstream.
- vitest: the copy enumeration.
- vitest: grant-state pairwise distinctness as its own set.
- playwright: issue → list → revoke, plus the bounded-expiry journey.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony. Captures per SPEC-0047 AC10.

## Notes / open questions

- **The server may bound the requested expiry.** `issueGrant`'s comment says so outright. Echoing the
  form's value back as confirmation would tell an admin their auditor has access until a date the
  server never agreed to.
- **Never compare `expires_at` to the browser's clock.** State is read at decision time; a computed
  state renders a grant expired while the server still honours it, or the reverse (SPEC-0033 AC7).
- HTML forms speak GET and POST only — revoke goes through an SSR relay, which also keeps the control
  as markup so AC7 holds without client JavaScript.

## Exit record (2026-08-18)

**All eleven criteria green.** Landed with T-0051 in one webfrontend commit, **1141bc5** — the two
are one surface: they share the Compliance destination, link to each other, and touch the same four
files, so splitting them would have produced a first commit whose tests referenced symbols the
second added. One commit per submodule still holds.

**What now exists.** `src/lib/grants.ts` (copy table, the three lifecycle states),
`src/components/GrantList.astro` and `IssueGrant.astro`,
`src/pages/compliance/auditor-grants/index.astro`, and two SSR relays — issue, and a revoke that
turns a form POST into the upstream DELETE. Tests: `grants-bff`, `grants-render`, `grants-route`,
all three added to `prebuild`.

**Both traps held.** The issue relay deliberately does **not** carry the issued grant through its
redirect: the list re-reads it from the server, because the server may have bounded the expiry and
its record is the only place that value is true. And `src/lib/grants.ts` has **no function that takes
an `expires_at` and returns a state** — the obvious helper is the bug. A grant's validity is read at
decision time (SPEC-0033 AC7), so a browser computing it would render a grant expired while the
server still honours it. The stub carries `grant-past-active`, whose expiry was 2020 and whose state
is `ACTIVE`; it renders as active in the browser and in the capture.

**A deliberate choice worth stating:** a REVOKED or EXPIRED grant still renders its Revoke control.
Revocation is idempotent at the backend, and hiding a control on a state basis is one step from
hiding it on a permission basis — which AC7 forbids outright.

**Carried:** pack IDs and auditor principals are typed, not picked, because no route lists either
(SPEC-0051 open questions 1 and 2). Listing is unpaged — `ListGrants` returns a slice with no page
token (open question 3). All three need a BFF change and their own spec under ADR-0070's ordering
law.
