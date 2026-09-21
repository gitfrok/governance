# T-0088: Register the control plane's four service doors

- **Status:** Done (2026-09-22) at backend@92c8acf — **three of four registered; OIDCLogin deliberately absent.** Unblocked by ADR-0101 (Accepted) and reshaped by it.
  ADR-0101 decision 3 settles that **no data migrates**: the three stores this task needs all live in
  `policy`, `audit` and `identity`, which decision 2 makes bi-planar, so the control plane builds its
  own instances against its own database. The task is three store constructions, an OIDC
  configuration, and one new BFF-facing door — not four `Register` calls, and not a migration.

  *Previously:* **BLOCKED, and this task's own premise was wrong.** Attempted 2026-09-22 and
  stopped: ADR-0100 decision 1 says "each module is already wired and in-process there; only the
  registration is missing", and reading `cmd/controlplane-app` shows that is **false for all four
  services**. Each needs a store or a configuration the control plane does not construct, and one of
  them needs data that lives in the data plane's Postgres. See "What stopped this" below. Two of this
  task's own criteria — AC5's listener claim and the four-Register-calls framing — were written on
  the same mistake and are corrected below rather than left to mislead.
- **Phase / Epic:** ADR-0094/0100 carry. No epic.
- **Repo(s):** **backend** only (`cmd/controlplane-app`). One commit.
- **Spec:** chore — acceptance criteria below (the four services' contracts are unchanged; ADR-0100
  decision 1 is the whole specification)
- **ADRs:** 0100 (decision 1), 0094 (decision 4 — the surfaces this makes servable), 0041 (one
  listener per plane, not one per capability), 0006/SPEC-0002 (the PDP)
- **Owner:** unassigned

## Goal

Give a control-plane BFF four services to call: `PolicyDecisionPoint`, `EvidenceService`,
`AuditorGrantService`, `OIDCLogin`.

## What stopped this (2026-09-22)

**Two factual errors, both mine, both found by reading the composition root instead of trusting the
layer above it. The third time in one thread that the prose promised more than the code holds.**

**1. The control plane does not have one listener; it has five, and the design is deliberate.**
`usage`, `fleet`, `residency`, `enrolment` and the mTLS agent gateway each get their own, and the
fleet door's comment states the principle: *"Its own listener rather than a second service on the
usage door, so a deployment can serve one without the other"* and *"registered here rather than on
the enrolment door because the callers differ."* So ADR-0100 decision 1's "they share the existing
listener set … on ADR-0041's own reasoning applied to this side" applies the **data plane's**
one-door model to a plane that deliberately rejects it. AC5 below is corrected.

**2. The four modules are wired for the control plane's OWN uses, not with these services'
dependencies.** `main.go:121` builds an OPA decision point, 176–180 an audit trail, 365–369 a PAT
authenticator — each for the control plane to authorize its own doors, write its own trail and check
its own callers. None of the four *services* can be constructed from them:

| Service | Constructor the data plane uses | What the control plane has |
|---|---|---|
| `PolicyDecisionPoint` | `policy.NewGRPCServer(pdp, records)` | `pdp` ✓, **no decision-records store** |
| `EvidenceService` | `audit.NewEvidenceGRPCServer(evidence)` | a trail ✓, **no evidence service** |
| `AuditorGrantService` | `identity.NewAuditorGrantGRPCServer(grants)` | **no grants store** |
| `OIDCLogin` | `identitygrpc.NewOIDCServer(...)` with a verifier config | **no OIDC configuration at all** |

The three words `records`, `evidence` and `grants` do appear in `cmd/controlplane-app/main.go` — all
three are **comments**.

**3. The consequence, which is the part that matters.** The data plane builds the grants store as
`identity.NewAuditorGrantsPostgres(dbPool, dp.policy, dp.bus, witness)` — its data is in the data
plane's Postgres. ADR-0100 put `AuditorGrantService` control-plane-side. So either that data moves,
or the control plane gets a **second** grants store, which is worse than the two audit trails
ADR-0100 already accepted.

**ADR-0100 dissolved the migration for the DOORS and not for the STORES.** Its central finding — the
module partition already matches ADR-0094 decision 4 — remains true and useful. Its conclusion that
only registration is missing does not survive contact with the composition root.

## What ADR-0101 settled

Its own instance, for all three — the middle option of the three above. The measurement that decided
it: `policy`, `audit` and `identity` are used by **both** composition roots, so they are bi-planar
schemas (ADR-0101 decision 2), and the control plane is already entitled to them. Decision records,
evidence and auditor grants therefore need no migration; they need constructors.

The cost travels with it and is not this task's to relitigate: a control-plane grant, trail entry or
decision record is invisible on the data plane, and nothing joins them.

## Acceptance criteria (test-first)

- [ ] **AC1** `controlplane-app` registers `PolicyDecisionPoint` on its existing listener, backed by
      the OPA decision point it already constructs from its mounted bundle. No second bundle, no
      second decision path.
- [ ] **AC2** It registers `EvidenceService`, backed by the audit trail it already constructs.
- [ ] **AC3** It registers `AuditorGrantService`, backed by the identity authenticator it already
      constructs.
- [ ] **AC4** It registers `OIDCLogin`.
- [ ] **AC5** **CORRECTED.** The original criterion said "no new listener, ADR-0041's reasoning
      applied to this plane", which is wrong: this plane runs five listeners on purpose, one per
      caller-class, and the fleet door's comment argues for exactly that. The real criterion is that
      the four are grouped by **caller and required-ness**: all four are called by the control-plane
      BFF and all four are required together for it to function at all, unlike `usage` and `fleet`
      which are optional surfaces a deployment may serve without the other. So one new door for the
      four, not four doors and not a fifth service bolted onto `usage`.
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

## Exit record (2026-09-22) — backend@92c8acf

**Registered on a new BFF door** (`GITFROK_BFF_GRPC_ADDR`, optional like `usage` and `fleet`):
`PolicyDecisionPoint`, `EvidenceService`, `AuditorGrantService`. The control-plane door set goes from
five services to eight, asserted as a **set** so a ninth cannot arrive unnoticed.

**No data migrated**, per ADR-0101 decision 3. The three stores are this plane's own instances of
bi-planar schemas: auditor grants from `identity`, evidence from `audit`, decision records from
`policy`.

**A defect fixed on the way, which the task did not ask for and should have.** This plane was calling
`policy.NewOPADecisionPoint` — the **memory** store — with a Postgres pool already constructed above
it, so its decisions could not be evidence of anything across a restart.
`NewOPADecisionPointWithPostgres` existed for precisely this case and says so in its own doc comment.
`EvidenceService` on the new door serves from those records, which is what made it visible: the gap
had been there since the control plane gained a pool.

**`attested` is nil on `EvidenceService`**, and the module blesses it rather than tolerating it:
*"composed only on planes that have the import surface — a plane without it has no imported history,
and an empty appendix is then the truthful answer."* ADR-0029 §4 and T-0018 AC19 already require
control sections to carry zero attested records, so this is the requirement met rather than a
shortcut.

**OIDCLogin is not registered, and a test asserts its absence.** ADR-0100 decision 1 assigned it
here; this plane has never had an OIDC verifier configuration. ADR-0101's register row holds it as
the weakest of the four assignments, and the test sends anyone who wires it back to that row.

**AC5 as originally written was wrong and is corrected above.** This plane runs a listener per
caller-class on purpose; ADR-0100 decision 1 applied ADR-0041's one-door model, which belongs to the
data plane. The three new services share one caller and are required together — unlike `usage` and
`fleet`, which are optional surfaces — so one door, not three, and not a fourth service on the usage
door.

**The AC7 assertion caught an error in ADR-0100's own context table.** It claims the data plane
registers **fourteen** services; it registers **thirteen**. `RegisterGitStorageServer` appears in
`cmd/dataplane-app` only inside `gitfront_test.go` — the git tier ships as its own image — and the
original measurement grepped test files. Recorded in the test itself, because that ADR's entire
argument was that measuring beats reasoning, and this is the third correction to a claim I made
confidently in this chain.

**Gates:** builds and vets clean; `cmd/...`, `internal/arch` and the `policy`, `audit` and `identity`
module suites green with `-race`. No new import edge toward a data-plane module.

**What it does not do.** A control-plane BFF still cannot serve, for two reasons outside this task:
SPEC-0070's `main.go` route partition is unwritten, and a data-plane BFF has no session store
(ADR-0101's register row). This removes one of three obstacles.

## Notes / open questions

**Why this has no spec of its own.** The four services' request and response shapes are unchanged and
their behaviour is unchanged; ADR-0100 decision 1 names them exhaustively and the criteria above are
mechanical. A spec would restate the ADR.

**It does not unblock a working control-plane BFF by itself.** SPEC-0070's recorded gap stands: a
data-plane BFF has no session store, and AC7 of that spec waits on ADR-0094's enrolment-record row.
This task removes one of three obstacles.
