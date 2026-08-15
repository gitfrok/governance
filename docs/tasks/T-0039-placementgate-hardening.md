# T-0039: PlacementGate hardening and placement-facts contradiction visibility

- **Status:** Done
- **Phase / Epic:** 3.1 / EP-20 (residency Declare and placement hardening)
- **Repo(s):** backend
- **Spec:** docs/specs/SPEC-0043-residency-declare-surface.md (Approved 2026-08-15, amended 2026-08-15 — RED may begin)
- **ADRs:** 0063, 0062, 0006, 0009, 0011, 0060
- **Owner:** unassigned

## Goal

Harden the enforcement and evidence half of PR-22 now that declarations have a wire surface and a
durable store: contradictions between the declaration and witnessed placement render in the pack and
as health findings with the existing vocabulary, placement silence renders as a named gap, and the
PlacementGate refuses undeclared or unavailable targets without spending the token.

## Acceptance criteria (test-first)

SPEC-0043 AC2, AC3, AC4 (AC1 and AC5 are T-0038's):
- [x] AC2: a declaration-versus-witnessed-placement contradiction is visible in the pack's residency
      section and as a health finding, using the existing `ResidencyFactKind` vocabulary —
      `PLACEMENT_CONTRADICTION` within the configured detection window (SPEC-0040 AC3); no parallel
      error channel; `RESIDENCY_FACT_KIND_PINNING` stays a control-plane act and
      `PLACEMENT`/`PLACEMENT_REFUSED`/`PLACEMENT_CONTRADICTION` stay control-plane observations.
- [x] AC3: placement silence beyond the detection window renders as `GAP_REASON_PLACEMENT_SILENT`
      gaps — never as inferred placement; absence of contradiction is not evidence of pinning
      (SPEC-0040 AC5's rule).
- [x] AC4: the PlacementGate refuses enrolment for an undeclared or unavailable target with the same
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

## Exit record (2026-08-15)

Merged to backend main at **f182761** (the Wave 3a commit beside T-0038's backend half). Every
proof ran under `-race` against the real-Postgres harness with zero durability skips; the gate
matrix (gofmt/vet/build, `internal/arch` fitness verbose, policy + tenant-isolation) was green at
push.

**SPEC-0043 AC2 — contradiction visible in pack and health findings, existing vocabulary:**
`TestMatrixDeclaredContradicts` (`PLACEMENT_CONTRADICTION` within the detection window),
`TestResidencySectionRendersContradictionAndRefusalAsFindings` and
`TestResidencySectionRendersContradictionAsControlObservation` (a contradiction renders as a
denied control observation — no parallel error channel; `RESIDENCY_FACT_KIND_PINNING` stays a
control-plane act, `PLACEMENT`/`PLACEMENT_REFUSED`/`PLACEMENT_CONTRADICTION` stay control-plane
observations), and the golden over the whole matrix fed by the new Declare surface,
`TestResidencyEvidencePackMatrixFedByDeclareSurface` (effective-dated change rendering included).

**SPEC-0043 AC3 — silence is a named gap, never inferred placement:**
`TestMatrixPlacementSilentWithinWindow` and `TestMatrixPlacementSilentBeyondWindow`,
`TestResidencySectionSilenceIsGapNotCompliance` (`GAP_REASON_PLACEMENT_SILENT`; absence of
contradiction is not evidence of pinning), backed by the gap suite
(`TestSilenceGapsDeclaredButNeverReported`, `TestSilenceGapsOfflineIntervalIsAGap`,
`TestSilenceGapsCoveredRangeIsComplete`, `TestSilenceGapsWindowOpensAtDeclaration`,
`TestSilenceGapsUndeclaredIsNoGap`, `TestSilenceGapsZeroWindowFailsSafe`,
`TestSilenceGapsPerPlaneAreDeterministic`).

**SPEC-0043 AC4 — PlacementGate refuses without spending the token, audited:**
`TestEnrolPlacementRefusedLeavesTokenUnspent` (coarse refusal shape, unspent token),
`TestResidencyCompositionRefusesAndWitnesses` (the composition drives a FAILING declaration store
through the gate — an unavailable store refuses, never admits, SPEC-0043 AC4 — and the witness
path names the declared and the attempted placement), `TestEnrolGateErrorFailsClosed` and
`TestEnrolGateSeesTenantScopedPlacement`, with the refusal audited
(`TestAdmissionRefusalsAreAudited`).
