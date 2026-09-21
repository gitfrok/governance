# T-0088: Register the control plane's four service doors

- **Status:** Todo — **RED may begin.** ADR-0100 Accepted 2026-09-22; no spec of its own is required
  because nothing about the services' behaviour changes, only where they are served. Acceptance
  criteria are below.
- **Phase / Epic:** ADR-0094/0100 carry. No epic.
- **Repo(s):** **backend** only (`cmd/controlplane-app`). One commit.
- **Spec:** chore — acceptance criteria below (the four services' contracts are unchanged; ADR-0100
  decision 1 is the whole specification)
- **ADRs:** 0100 (decision 1), 0094 (decision 4 — the surfaces this makes servable), 0041 (one
  listener per plane, not one per capability), 0006/SPEC-0002 (the PDP)
- **Owner:** unassigned

## Goal

Register four services on `controlplane-app`'s existing listener set so a control-plane BFF has
something to call: `PolicyDecisionPoint`, `EvidenceService`, `AuditorGrantService`, `OIDCLogin`.

Each module is already wired into that binary and already constructed in-process — the decision
point at `main.go:121`, the audit trail at 176–180, the identity authenticator at 365–369 — so this
is registration, not new capability. That is why ADR-0100 could shrink what looked like a migration
of nine contexts to four calls.

## Acceptance criteria (test-first)

- [ ] **AC1** `controlplane-app` registers `PolicyDecisionPoint` on its existing listener, backed by
      the OPA decision point it already constructs from its mounted bundle. No second bundle, no
      second decision path.
- [ ] **AC2** It registers `EvidenceService`, backed by the audit trail it already constructs.
- [ ] **AC3** It registers `AuditorGrantService`, backed by the identity authenticator it already
      constructs.
- [ ] **AC4** It registers `OIDCLogin`.
- [ ] **AC5** **No new listener.** ADR-0041's reasoning applied to this plane: one door per plane,
      not one per capability. The four join an existing port.
- [ ] **AC6** Each new door authorizes through the PDP exactly as the data plane's equivalents do. A
      door that skips the decision point would widen the control plane's surface without widening its
      checks — and this plane's application door is what agents reach.
- [ ] **AC7** `dataplane-app`'s registrations are **unchanged**. ADR-0100 decision 4 makes bi-planar
      `audit`, `identity` and `policy` the design; this task adds a second instance's doors and
      removes nothing.
- [ ] **AC8** The arch gate still passes: no new import edge from the control plane toward a
      data-plane module, and `CheckNoControlPlaneDialsDataPlane` stays at zero violations.

## Tests to write first

1. **A door-set assertion** over `cmd/controlplane-app`: exactly the prior five services plus these
   four, on the same listener. Asserting the *set* rather than each addition is what catches a fifth
   service arriving unnoticed later.
2. **An authorization test per new door** (AC6), asserting a denied decision refuses the call — the
   property that makes four new doors safe rather than merely present.
3. **AC7** as a `dataplane-app` door-set assertion, so a future consolidation of the bi-planar
   modules fails here rather than silently removing a data-plane door.

## Definition of Done

See `../process/definition-of-done.md`. Backend suite with `-race`; `internal/arch` green.

## Notes / open questions

**Why this has no spec of its own.** The four services' request and response shapes are unchanged and
their behaviour is unchanged; ADR-0100 decision 1 names them exhaustively and the criteria above are
mechanical. A spec would restate the ADR.

**It does not unblock a working control-plane BFF by itself.** SPEC-0070's recorded gap stands: a
data-plane BFF has no session store, and AC7 of that spec waits on ADR-0094's enrolment-record row.
This task removes one of three obstacles.
