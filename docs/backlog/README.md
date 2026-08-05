# Backlog — epics

Epics are grouped by roadmap phase and link down to executable tasks in `../tasks/`.
**Definition of Done** for every task: `../process/definition-of-done.md`.

## Phase 0 — Foundations
- **EP-0 Scaffolding & process** *(closed)*: T-0001 (repo layout, **Done**), T-0002 (boundary/arch
  CI, **Done**), T-0008 (in-process bus + module `api` convention, **Done**), T-0009
  (extraction-readiness fitness functions, **Done**). T-0008 and T-0009 carry
  `Phase / Epic: 0 / EP-0` in their task files and were missing from this list.
  **Epic status: CLOSED 2026-08-04.** All four tasks **Done**. T-0002 AC5 was the last item — the
  gates now *block* rather than only run: **ADR-0031** split `main` enforcement into two rulesets
  (`main-integrity` with no bypass actors, `main-review` admin-bypassable until the org has a second
  member), applied to all five repos by the super-repo's `scripts/apply-rulesets.sh`, with legacy
  branch protection deleted. Verified empirically: a direct admin push to `main` is
  `[remote rejected]`, and `gh pr merge --admin` is refused on a red required check. Every criterion
  in this epic is met and machine-enforced.
  Carried out of the epic as three ADR-0031 follow-ups, none of them blocking; two have since
  **closed 2026-08-05**: four-eyes review (a second org member joined, so `main-review`'s bypass is
  empty everywhere) and the `webfrontend` gate (it gained a CI workflow, and
  `build + typecheck + test + arch gates` is now a required check in its `main-integrity`).
  **Still open:** the two rulesets are five per-repo copies, because org-level rulesets need GitHub
  Team — kept honest by `make rulesets-check`.
- **EP-9 Contract gates**: T-0020 (`buf lint` + `buf breaking` on `contracts/`, codegen-freshness
  checks in the three consumers). New epic rather than a reopened EP-0: that epic closed 2026-08-04
  with its criteria verified, and this gate was never one of them — `../process/ci-gates.md` marks
  "contract schema" required in four repos but attributes no task to it, and `buf` runs in no CI
  anywhere. Phase 0 all the same: its exit criteria require CI green on *contract* tests.
  **Blocked on ADR-0032 (Proposed)**, which decides whether the 13 `ENUM_VALUE_PREFIX` violations in
  `proto/agent/v1/agent.proto` are renamed before the breaking baseline is set or grandfathered.
- **EP-1 Platform up**: T-0003 (Minikube dev env).
- **EP-2 Tenancy & governance base**: T-0004 (tenancy+RLS), T-0005 (PDP), T-0006 (audit log).
- **EP-3 Storage decision**: T-0007 (SeaweedFS-FUSE vs block-volume benchmark).

## Phase 1 — MVP
- **EP-4 Git plane**: T-0010 (Git-RPC), T-0011 (smart-HTTP+SSH), T-0012 (sync-replica+failover).
- **EP-5 Identity**: T-0013 (Zitadel + PATs, tenant scoping).
- **EP-6 Code UX**: T-0014 (repo read APIs + BFF), T-0015 (web browser/diff/palette).
- **EP-7 Review & CI**: T-0016 (MR + protected branches + approval policy), T-0017 (CI v0 gVisor+KEDA).
- **EP-8 Migration**: T-0018 (repository + review-history import — refs/tags/LFS *and* MR history
  with attested provenance, one unit of work). Scoped in by PRD PR-12; **ADR-0029 Accepted**,
  **SPEC-0011 Approved** — ready to start. T-0019 was folded into T-0018 at spec review.

## Phase 2 — Ultimate wedge  *(to be expanded)*
Scanner integration; unified security dashboard; security/approval policies-as-code; audit
UI + evidence export; Zoekt search.

## Phase 3 — BYO  *(to be expanded)*
Agent impl (`contracts/proto/agent/v1`); Operator + Helm + per-cloud drivers; metering → billing.

## Parked — needs a human decision first
- Force-promote tenant self-service? (ADR-0018) · SPIFFE/SPIRE + proxy fallback (ADR-0017)
- Unit-economics model per tier (ADR-0008) · event catalog (ADR-0022; the boundary linter shipped
  in T-0002/T-0009)
*(Two items left this list recently: extraction-trigger budgets on 2026-08-03, ADR-0030 Accepted; and
"a second GitHub org member" on 2026-08-05 — `webenable-asia` joined, so `main-review`'s admin bypass
was removed and four-eyes review on `main` is now binding on owners too. It never blocked EP-0 in the
end: ADR-0031 bound the check gate without it.)*
