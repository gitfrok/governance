# Phase 4 — the full product surface

**Intent.** Close the distance between what the platform can do and what a person can reach. Three
inventories describe the web surface today and they disagree: the BFF serves eighteen routes, ten of
which have a UI; the PRD requires twenty-three `PR-#` rows, several of which no surface renders; and
the `./UI` prototype shows a product larger than either.

**Decided by** [ADR-0070](../adr/0070-full-product-surface.md) (**Accepted 2026-08-18**) — the
tiering, the route-before-pixel ordering law, and the nine PRD requirements PR-24…PR-32, which the
PRD's Phase 4 table now carries.

**Design system.** Everything here rides [ADR-0069](../adr/0069-cvd-first-design-system.md) and the
gates [SPEC-0047](../specs/SPEC-0047-cvd-first-design-system.md) left behind. Phase 4 widens what is
built and relaxes nothing about how.

## The ordering law, restated

No UI before the BFF route it reads. No BFF route before the backend port it shapes. A surface whose
backend does not exist is not blocked UI work — it is backend work that has not started, and it is
tasked that way. For every nav destination there must be a route that returns its data; a
destination without one is dead nav.

## Wave 1 — Tier A: the routes that exist and have no UI

`webfrontend` only. No contract change, no backend work. Each of these is a spec and a task, not a
decision — the PRD already requires them and the BFF already serves them. **Wave 1 does not wait on
ADR-0070's acceptance.**

| # | Surface | Routes it consumes | PRD | Spec / task |
|---|---|---|---|---|
| 1 | Merge-request actions — open, review, merge | `POST …/merge_requests`, `…/review`, `…/merge` | PR-9, PR-10 | SPEC-0048 / T-0049 |
| 2 | Code search | `POST /api/v1/search/query`, `GET /api/v1/search/status` | PR-19 | SPEC-0049 / T-0050 |
| 3 | Evidence packs | `POST /api/v1/audit/evidence-packs`, `…/{id}/status`, `…/{id}` | PR-17 | SPEC-0050 / T-0051 |
| 4 | Auditor grants | `POST\|GET /api/v1/audit/auditor-grants`, `DELETE …/{id}` | PR-18 | SPEC-0051 / T-0052 |

Wave 1 leads with merge-request actions because it is the only one of the four that breaks a loop
rather than adding a surface: PR-9's read half shipped in T-0016 and its write half has been
reachable by `curl` and by nothing else ever since.

Two traps this wave must not fall into, both discovered while scoping it:

- **The MR writes are form-encoded**, unlike every other write the frontend performs. A JSON body
  reaches `r.ParseForm()` as no fields and is refused with the same coarse 404 as a dead session.
- **`CommandPalette.tsx` is navigation, not search.** Its three commands change the browser route
  for the current repository. Nothing in the frontend has ever called the search API, so wave 1 item
  2 is a new surface rather than a rewiring.

## Wave 2 — Tier B: the PRD requires it, no route serves it

Each item is three commits in ADR-0027 order — `backend`, then `bff`, then `webfrontend` — and each
needs its own spec. None may start before its backend port exists.

| # | Surface | Why it is blocked | PRD |
|---|---|---|---|
| 1 | Repository list | Worse than "no route": the Repository context has **no durable store at all**. Its only adapter is `memstore`, whose own header says the Postgres adapter was owed with T-0004 and T-0010 — both Done, neither delivered it. See **ADR-0071**. | PR-24 |
| 2 | Blame and history | PR-8 names both; neither has a BFF route. | PR-25 (proposed), PR-8 |
| 3 | Pipelines and job logs | `modules/ci` exists; no browser-facing route does. | PR-26 (proposed), PR-11 |
| 4 | Policy authoring | PR-16 requires author/version/dry-run/enforce; the policies are real, the authoring surface is not. | PR-27 (proposed), PR-16 |

The repository list is the phase's most load-bearing item and the least visible: without it there is
no honest landing page, and its refusal semantics are the whole of G1 — a repository the caller may
not see must be indistinguishable from one that does not exist.

**It also grew a subtask that nobody had recorded.** Scoping it found that the Repository context's
registry is a `map` — `memstore` is its only adapter, and there is no `repositories` table in any
migration. That survived because every existing surface asks about one repository by ID, so an empty
registry looks like a not-found, which SPEC-0001 wants anyway. A **list** is different: one that
omits a repository asserts it does not exist, to a caller who may be looking at its clone URL. The
durable store is therefore its own piece of work, in EP-26's ordering, decided by **ADR-0071** —
the same move ADR-0062 made for the agent and residency stores.

## Wave 3 — Tier C: adopted from the prototype, and a context each

**Unblocked 2026-08-18:** ADR-0070 is Accepted and the PRD carries PR-28…PR-32. The second gate
still stands and is the harder one — **each of issues, releases, repository settings and the admin
area needs its own Proposed ADR before a spec**, because each is a bounded context under ADR-0022
with its own storage, events, permissions and audit obligations. ADR-0070 sets that as its own
follow-up, and it is not a formality: adopting a context adopts its maintenance permanently.

Issues (PR-28), releases (PR-29), repository settings (PR-30), the admin area with its audit-log
browser and runners view (PR-31), and the marketing landing page (PR-32).

**The five context ADRs were written 2026-08-19 and none of them adopts its surface.** Each fixes
the boundaries most likely to be crossed under delivery pressure and records what adoption would
cost. Read together they say something the tier's framing did not: **Tier C is not four screens and
a page, it is four contexts and a deployment**, and two of the five ADRs recommend a smaller
alternative over the thing PR-28…PR-32 describe.

| ADR | Surface | What it fixes | What it recommends |
|---|---|---|---|
| 0074 | Issues | Own context; issue text never enters a control section; attachments out of scope | **Consider linking an external tracker instead** |
| 0075 | Releases | Unsigned artifacts are named as unverified; tenant signing does not reuse the release trust bundle | **Tags + notes, no artifacts, as the first increment** |
| 0076 | Settings | No setting may change an authorization or policy outcome (PR-10); visibility and deletion deferred | Name, description and archival only |
| 0077 | Admin | Audit reached through a grant, not a role; `admin` is not a new primitive; runner state is a dated report | Possibly no audit panel — point at the evidence pack |
| 0078 | Marketing | Separate surface, separate origin, never receives a session | Possibly not this repository at all |

PR-32 is the odd one and the cheapest: a landing page has no context behind it, and ADR-0070's open
follow-up asks whether it belongs in `webfrontend` at all or in a surface that never holds a session
cookie.

## Exit criteria

1. Every BFF route has a UI, or a recorded reason it does not.
2. No nav destination lacks a route (the ordering law's mechanical test).
3. PR-9's loop — open, review, comment, approve, merge — is executable end to end by a person in a
   browser, not only by the north-star script.
4. Every surface added in this phase passes the ADR-0069 gates: zero hex literals, every status in
   `src/lib/status.ts` with a glyph and a word, grayscale and deuteranopia captures reviewed.
5. `usage-regression-pins` and `readonly-cause` are unmodified across the whole phase.
6. Each Tier B item either ships all three commits or records an honest "not started" against its
   backend port — a half-built Tier B item with a UI is the failure this phase's ordering law exists
   to prevent.

## Risks

- **Tier C is adopted from a mockup, not a customer.** ADR-0070 says so in its own consequences.
  The mitigation is procedural: Tier C cannot start until someone defends PR-28…PR-32 on their
  merits at ADR acceptance.
- **Phase 4 is the first phase to touch all four repositories in anger since Phase 3.** The
  one-commit-per-submodule rule (ADR-0027, invariant 25) is easiest to break on Tier B items, where
  a single feature genuinely spans backend, bff and webfrontend.
- **Scope is large enough that partial completion is likely.** Waves are ordered so that stopping
  after wave 1 leaves a coherent product: every feature that exists has a UI. Stopping mid-wave-2
  does not, unless the ordering law is obeyed.
