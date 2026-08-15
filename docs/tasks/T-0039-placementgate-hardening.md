# T-0039: PlacementGate hardening and placement-facts contradiction visibility

- **Status:** Todo
- **Phase / Epic:** 3.1 / EP-20 (residency Declare and placement hardening)
- **Repo(s):** backend
- **Spec:** docs/specs/SPEC-0043-residency-declare-surface.md (Approved 2026-08-15 — RED may begin)
- **ADRs:** 0063, 0062, 0006, 0009, 0011, 0060
- **Owner:** unassigned

## Goal

Harden the enforcement and evidence half of PR-22 now that declarations have a wire surface and a
durable store: contradictions between the declaration and witnessed placement render in the pack and
as health findings with the existing vocabulary, placement silence renders as a named gap, and the
PlacementGate refuses undeclared or unavailable targets without spending the token.

## Acceptance criteria (test-first)

SPEC-0043 AC2, AC3, AC4 (AC1 and AC5 are T-0038's):
- [ ] AC2: a declaration-versus-witnessed-placement contradiction is visible in the pack's residency
      section and as a health finding, using the existing `ResidencyFactKind` vocabulary —
      `PLACEMENT_CONTRADICTION` within the configured detection window (SPEC-0040 AC3); no parallel
      error channel; `RESIDENCY_FACT_KIND_PINNING` stays a control-plane act and
      `PLACEMENT`/`PLACEMENT_REFUSED`/`PLACEMENT_CONTRADICTION` stay control-plane observations.
- [ ] AC3: placement silence beyond the detection window renders as `GAP_REASON_PLACEMENT_SILENT`
      gaps — never as inferred placement; absence of contradiction is not evidence of pinning
      (SPEC-0040 AC5's rule).
- [ ] AC4: the PlacementGate refuses enrolment for an undeclared or unavailable target with the same
      coarse refusal shape as shipped, does not spend the token, and leaves an audit trail naming the
      declared and the attempted placement (SPEC-0040 AC2).

## Tests to write first

Per SPEC-0043 § Test plan:
- contradiction/gap matrix domain tests — declared-matches, declared-contradicts,
  placement-silent-within-window, placement-silent-beyond-window — each rendering pinned to its pack
  section and health-finding vocabulary (AC2, AC3).
- evidence-pack golden tests over the matrix, including the effective-dated change rendering
  (SPEC-0040 AC6) fed by the new surface (AC2).
- enrolment-refusal integration: coarse shape, unspent token, audited with both placements named
  (AC4).

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony — evidence and tenancy.

Gate matrix (per repo):
- backend: `gofmt` / `go build` / `go vet`, `internal/` boundary + architecture fitness, policy +
  tenant-isolation, `go test -race`.

## Notes / open questions

Depends on T-0038: the matrix tests are driven by declarations the surface now sets, and the golden
packs exercise the effective-dated replace path. The detection window stays per-environment
configuration, never a compiled-in constant (SPEC-0040 AC3); enrolment-refusal semantics stay exactly
as shipped in Phase 3 (SPEC-0043's out-of-scope).
