# Backlog — epics

Epics group tasks by roadmap phase and link down to `../tasks/`. Each task file's own `Status:` is
authoritative; **Definition of Done** for all of them is `../process/definition-of-done.md`.

## Phase 0 — Foundations · all epics CLOSED

| Epic | Tasks | Closed |
|---|---|---|
| **EP-0** Scaffolding & process | T-0001, T-0002, T-0008, T-0009 | 2026-08-04 |
| **EP-1** Platform up | T-0003 | 2026-08-09 |
| **EP-2** Tenancy & governance base | T-0004, T-0005, T-0006 | 2026-08-06 |
| **EP-3** Storage decision | T-0007 | 2026-08-06 |
| **EP-9** Contract gates | T-0020 | 2026-08-06 |

What is worth carrying forward out of them:

- **EP-0** closed when the gates began to *block* rather than only run: ADR-0031 split `main`
  enforcement into `main-integrity` (no bypass actors) and `main-review`, applied to all five repos by
  the super-repo's `scripts/apply-rulesets.sh`. Verified empirically — a direct admin push to `main` is
  `[remote rejected]` and `gh pr merge --admin` is refused on a red required check. **Still open:** the
  two rulesets are five per-repo copies, because org-level rulesets need GitHub Team; `make
  rulesets-check` catches drift.
- **EP-2**: SPEC-0002's open question is answered — decision-cache invalidation is by *bundle
  revision*, not by clock, so a policy change invalidates every cached decision by construction. And
  **AC4's fitness function is a tripwire, not a proof**: authorization logic has no import signature
  the way every other boundary rule does, so it catches the obvious shapes only, and says so. Carried
  out, not blocking: no mTLS between BFF and PDP yet (T-0013).
- **EP-3**: ADR-0033 Accepted — live bare repos stay on block volumes, because SeaweedFS-FUSE's
  `rename()` is not atomic and git renames a `.lock` over the ref on every update (36 of 428 concurrent
  ref reads missed a ref that always existed; 0 of 229 on block; zero rename errors, reproduced three
  times). Performance was not the deciding factor. ADR-0016 needed no amendment and invariant 7's
  escape clause is discharged. Evidence: `../bench/T-0007/`.
- **EP-9**: T-0020's AC5 was **amended** during implementation — per-consumer codegen gating is
  impossible while each `buf.gen.yaml` reads `../governance/contracts`, so freshness is gated at the
  composition boundary instead. The per-repo variant stays blocked on the ADR-0027/0028 generated-type
  publishing follow-up.

## Phase 1 — MVP · all epics CLOSED

| Epic | Tasks | Landed |
|---|---|---|
| **EP-4** Git plane | T-0010, T-0011, T-0012 | backend #20, #27/#28, #30 |
| **EP-5** Identity | T-0013 | backend #21/#37/#50, bff #22, governance #124 |
| **EP-6** Code UX | T-0014, T-0015 | backend #22/#24, bff #18/#22, webfrontend #20, super-repo #77 |
| **EP-7** Review & CI | T-0016, T-0017 | backend #29/#31/#32/#33/#34/#35, super-repo #76 |
| **EP-8** Migration | T-0018 | governance #110/#114/#116, backend #39/#40/#45/#46, bff #25, webfrontend #23 |
| **EP-10** Deployable images | T-0021 | backend #19/#25, bff #16/#19, webfrontend #16/#18 |

Two limits are recorded against the phase rather than left open (see `../plans/phase-1-mvp.md`): no
gVisor RuntimeClass under rootless podman, so CI dispatch is unconfigured in the dev cluster (T-0017),
and one git node, so the durability quorum and failover cannot be demonstrated there (T-0012/T-0018
prove both in their suites).

**EP-8 owes one criterion forward.** T-0018's **AC19 moved to Phase 2** (decided 2026-08-10): an
evidence pack spanning an import must carry zero attested records in its control sections, with
attested history confined to a labelled appendix carrying its provenance blocks and the admitting
`HistoryImported` event (SPEC-0011 AC14). No evidence-pack surface exists yet to satisfy it. **ADR-0029
§4 binds whoever builds that surface whether or not the criterion is copied into their task.**

## Phase 2 — Ultimate wedge *(to be expanded)*

Scanner integration; unified security dashboard; security/approval policies-as-code; audit UI +
evidence export (inherits AC19 above); Zoekt search.

## Phase 3 — BYO *(to be expanded)*

Agent implementation (`contracts/proto/agent/v1`); Operator + Helm + per-cloud drivers; metering →
billing.

## Parked — needs a human decision first

Force-promote tenant self-service (ADR-0018) · SPIFFE/SPIRE + proxy fallback (ADR-0017) ·
unit-economics model per tier (ADR-0008) · event catalog (ADR-0022 — the boundary linter shipped in
T-0002/T-0009; the names exist as protobuf full names, nothing documents them).
