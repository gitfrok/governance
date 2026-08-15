# T-0044: PR-7 durability read-only vs envelope-throttle state distinction in UI/API

- **Status:** Todo
- **Phase / Epic:** 3.1 / EP-23 (usage-view truth and the PR-7 distinction)
- **Repo(s):** backend (cause contract), webfrontend (rendering) — one commit per repo
- **Spec:** docs/specs/SPEC-0046-usage-view-pr7-distinction.md (Approved 2026-08-15 — RED may begin)
- **ADRs:** 0061, 0018, 0008
- **Owner:** unassigned

## Goal

Every read-only state names its cause: the PR-7 durability mode (ADR-0018 — dual loss, audited
override) or an envelope-throttle effect — never a bare "read-only". Commercial states never render
as read-only; the prohibition SPEC-0041 AC8 has held since T-0034 gains the in-product distinction
the phase carried. This discharges the carry recorded in T-0034's exit ("AC8's product distinction
defers to PR-7", enforced per ADR-0061).

## Acceptance criteria (test-first)

SPEC-0046 AC4, plus AC5's pins on the surfaces this task touches:
- [ ] AC4: any read-only state in the UI or API identifies its cause — the PR-7 durability mode
      (ADR-0018) or an envelope-throttle effect; commercial states never render read-only
      (SPEC-0041 AC8's prohibition, now with the distinction).
- [ ] AC5 (on these surfaces): "not metered" never renders as zero, and git is never blocked in any
      envelope state — the regression pins cover the states this task labels.

## Tests to write first

Per SPEC-0046 § Test plan:
- backend: cause-carried read-only state — the API identifies the cause so every consumer renders
  the same distinction (cause labels are contract vocabulary, not UI copy).
- webfrontend vitest: state-cause rendering for every read-only surface — durability vs throttle vs
  never (AC4); "not metered" rendering.
- regression pins wired to fail the build (AC5).

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony.

Gate matrix (per repo):
- backend: `gofmt` / `go build` / `go vet`, `internal/` boundary + architecture fitness, policy +
  tenant-isolation, `go test -race`.
- webfrontend: vitest suite plus build/typecheck.

## Notes / open questions

Sequenced last in M4 so the distinction renders against live envelope states, but it shares only the
epic with T-0043 — the API cause contract can land independently if needed. The PR-7 durability mode
itself is SPEC-0005/ADR-0018's; if PR-7's mode has no product state yet, AC4's durability branch
tests the API cause contract and the UI branch lands with PR-7's own work (SPEC-0046's assumption).
PR-7's own product work is not part of this task or this phase.
