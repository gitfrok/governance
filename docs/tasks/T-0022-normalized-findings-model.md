# T-0022: Normalized findings model + scanner ingestion

- **Status:** Done (2026-08-14) — contracts governance@8b4dac2; backend@acebf68 on the Phase-2 stack; live identity proof green against real Semgrep + gitleaks
- **Phase / Epic:** 2 / EP-11 Findings plane
- **Repo(s):** governance (contracts) + backend
- **Spec:** docs/specs/SPEC-0024-normalized-findings-model.md; docs/specs/SPEC-0025-findings-ingestion-contract.md — both **Approved 2026-08-14**; RED may start (AGDD)
- **ADRs:** 0015, 0006, 0007, 0022, 0025
- **Owner:** unassigned

## Goal
Normalize the output of every scanner class — SAST, dependency, secrets, container, DAST — into one
findings model with **stable finding identity across scans** (PR-13). This is the phase's foundation:
triage state that survives a re-scan (T-0023), placement on the merge request that introduced a
finding (T-0024), and the scan-gate records an evidence pack cites (T-0026) all rest on the identity
rule this task fixes.

Scanners sit behind an ingestion contract. Which scanners ship first is an implementation choice, not
a commitment of this task (PRD §12.4).

## Acceptance criteria (test-first)
- [x] AC1: a findings contract exists in `governance/contracts` covering all five scanner classes —
      SAST, dependency, secrets, container, DAST — with one normalized finding shape, additive-only
      within v1 (ADR-0032, T-0020 gates).
- [x] AC2: finding identity is stable across scans: re-scanning an unchanged repository at a later
      commit yields the same identity for the same underlying defect, and identity does not change
      when unrelated lines move.
- [x] AC3: two different scanners reporting the same defect class on the same location do not collide
      into one finding, and neither is silently dropped.
- [x] AC4: ingestion is tenant-scoped — a finding is readable only within its tenant (SPEC-0001), and
      a cross-tenant read is impossible.
- [x] AC5: ingestion is authorized by the PDP; an unauthorized ingest is denied and the denial is
      audited (ADR-0006, ADR-0007).
- [x] AC6: no scanner-specific field leaks into the normalized model; scanner-native payloads are
      carried as opaque provenance, not as first-class schema.
- [x] AC7: identity stability is proven against **real scanner output on a real repository across at
      least two scans**, not against fixtures.

## Tests to write first
- contract: findings schema against `governance/contracts`; `buf lint` + `buf breaking`.
- unit (backend): identity derivation — line drift, file rename, unrelated edit, same defect from two
  scanners.
- integration: ingest real scanner output twice over a seeded repository; assert identity equality.
- policy/isolation: cross-tenant read denied; unauthorized ingest denied and audited.

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions
Scanner selection is an implementation choice (PRD §12.4) — keep the choice reversible behind the
ingestion contract. Scans ride CI v0, so scan **dispatch** in the dev cluster may hit the same host
limit T-0017 recorded (no gVisor RuntimeClass under rootless podman); that is a cluster-lane limit
(T-0003), not an unmet criterion. Cross-repo changes land governance-first under ADR-0027.

## Exit record (2026-08-14)
Phase-2 exit (this phase's exit task, #23): AC7's live proof (`modules/security/live_identity_proof_test.go`)
re-ran green at the exit pin with the host's real Semgrep and gitleaks binaries — two scans over a
seeded repository with an unrelated intermediate commit, identities equal. AC1–AC6 hold in the
full backend suite with `TEST_DATABASE_URL` (Postgres, RLS). Scan *dispatch* through CI v0 remains
the recorded host limit against T-0003's cluster lane (planning-time record above, unchanged).
Shipped scanners: Semgrep (SAST) + gitleaks (secrets) behind the one ingestion contract.
