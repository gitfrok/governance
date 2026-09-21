# ADR-0100: Which plane serves which context — the control plane registers doors for modules it already wires

- **Status:** Proposed
- **Date:** 2026-09-22
- **Deciders:** platform (requested by the deciding owner)
- **Amends:** **ADR-0094 decision 4 in one respect** — notifications stay **data-plane-side**. That
  decision listed them among the control plane's surfaces; their events originate in code review and
  CI, which are data-plane contexts, and relaying them would need a cross-plane path that does not
  exist. ADR-0094 is Accepted and is not edited (ADR-0001).
- **Related:** ADR-0093 (the partition ADR-0094 amended), ADR-0094 (decisions 3–7 — this makes
  decision 4 servable), ADR-0011 (no control-plane dial to a data plane), ADR-0041 (one data-plane
  gRPC door), ADR-0006/SPEC-0002 (the PDP), ADR-0086 (notifications), ADR-0025 (modular monolith per
  plane — this is that boundary, read from the composition roots), SPEC-0070 (the BFF's plane
  partition, blocked on this)
- **Governs:** G1 isolation, G4 change governance

## Context

SPEC-0070 set out to make the BFF's reader address conditional, per ADR-0094 decision 5, and stopped
on something larger: `GITFROK_PDP_ADDR` is not the PDP's address but **the data plane's entire gRPC
door** (ADR-0041), and fourteen of the BFF's fifteen service clients are built on it. Nine of
ADR-0094 decision 4's control-plane surfaces appeared to have their backend on the wrong plane, which
read like a migration of bounded contexts.

**Measured in the composition roots, it is not.** The module partition is already close to what
decision 4 describes:

| Wired by | Modules |
|---|---|
| `cmd/dataplane-app` only | `ci`, `codereview`, `codesearch`, `notifications`, `release`, `repository`, `security` |
| `cmd/controlplane-app` only | `agent`, `metering`, `residency` |
| **Both** | `audit`, `identity`, `policy` |

And the control plane does not merely import those three — it **uses them in-process today**:
`policy.NewOPADecisionPoint(bundleDir, b)` at `cmd/controlplane-app/main.go:121`,
`audit.NewPostgresTrail(pool)` at 176–180, and an `identity` authenticator at 365–369 and 406–410.

What is missing is **door registration**, not contexts. The two planes register:

| | Services registered |
|---|---|
| `controlplane-app` | `AgentGateway`, `EnrolmentService`, `FleetReader`, `ResidencyService`, `UsageService` |
| `dataplane-app` | `AuditorGrantService`, `CIJobService`, `CredentialAuthenticator`, `EvidenceService`, `FindingsService`, `GitStorage`, `ImportService`, `MergeRequestService`, `NotificationService`, `PolicyDecisionPoint`, `ReleaseService`, `RepositoryRegistry`, `RepositorySettings`, `SearchService` |

So a control-plane BFF cannot reach a policy decision point, an evidence pack or an auditor grant —
not because those live on the wrong plane, but because **nobody registered them on a door there**.
That is a much smaller decision than a migration, and it is the decision this ADR makes.

One surface is a genuine exception rather than a missing registration, and it is named rather than
bent to fit.

## Decision

**1. The control plane registers the services for the surfaces ADR-0094 decision 4 gives it, from
modules it already wires.** Four additions to `controlplane-app`'s door set:

| Service | Module | Status today | Why the control plane |
|---|---|---|---|
| `PolicyDecisionPoint` | `policy` | **in-process already** (`main.go:121`) | ADR-0094 decision 4 gives it policy authoring and visibility, and its BFF must authorize its own routes. This is the shape the owner chose as (a), and it is the cheapest of the four: the decision point exists, it is simply not served |
| `EvidenceService` | `audit` | trail in-process (`main.go:176`) | decision 4 gives it audit and evidence packs |
| `AuditorGrantService` | `identity` | authenticator in-process (`main.go:365`) | decision 4 gives it auditor grants |
| `OIDCLogin` | `identity` | registered by `modules/identity/module.go`, wired only into the data plane | decision 4 gives it identity and login, and a login flow that must reach the data plane to authenticate is the inverse of ADR-0094's intent |

They share the control plane's existing gRPC listener set rather than opening a fifth door per
service, on ADR-0041's own reasoning applied to this side.

**2. The data plane keeps every context whose subject is a repository.** `repository` (registry,
settings, reader), `codereview`, `codesearch`, `ci`, `release`, `security`, `GitStorage`,
`CredentialAuthenticator`. These are ADR-0094 decision 3's surface and its Git front doors, and their
durable stores are already there (T-0053's registry, T-0064's releases, T-0068's settings, T-0078's
code review).

Note what this settles that ADR-0094 left unstated: **the repository list and repository settings are
data-plane surfaces.** Neither decision 3 nor decision 4 named them. They are metadata *about* a
repository rather than metadata *instead of* one, their store is data-plane-side, and the data plane
needs the registry to serve Git at all — so splitting repository identity across planes would be the
expensive choice.

**3. Notifications stay data-plane-side, amending ADR-0094 decision 4.** Their events originate in
`codereview` and `ci` — ADR-0086 feeds the Notifications context from the bus — and both are
data-plane contexts by decision 2. Placing notifications control-plane-side would require relaying
those events across the plane boundary, and the only channel that crosses it is the ADR-0017 agent
stream, which carries desired state and telemetry rather than product events. Amending the decision
is cheaper and more honest than inventing that relay.

**Consequence, stated because it is a real loss:** a notification about a control-plane event —
billing, a grant, a residency change — has nowhere to live under this decision. None exists today,
so nothing regresses; when one is wanted it needs its own decision, and this ADR does not pretend
otherwise.

**4. `audit`, `identity` and `policy` are deliberately bi-planar, and that is not duplication to be
resolved.** Each plane authorizes its own requests, writes its own audit trail, and authenticates its
own callers. A single shared instance would be a cross-plane dependency in the hot path of every
request, which ADR-0011 forbids in one direction and ADR-0025's per-plane monolith rules out in both.
Two instances of a module are the design, not drift.

**5. The BFF gains a second upstream address rather than a migration.** It keeps the data-plane door
address for the contexts of decision 2 and gains a control-plane door address for decision 1's four.
`GITFROK_PDP_ADDR`'s name becomes actively misleading once it is one of two doors, so it is renamed
to `GITFROK_DATAPLANE_ADDR` — additively, with the old name accepted for one release — because a
name that says "PDP" while carrying fourteen services is how this confusion arose.

**6. What the two BFF deployments may reach is therefore asymmetric, and the refusals enforce it.**
A control-plane deployment configures the control-plane door and **no** data-plane address at all,
which makes ADR-0094 decision 7's assertion mechanical rather than aspirational: there is no address
to dial. A data-plane deployment configures the data-plane door and no control-plane one.

## Consequences

**Positive:**
- SPEC-0070 unblocks, and its AC5/AC6 become writable: a route set can be partitioned once its
  backends can be reached.
- The work is four `Register…Server` calls on an existing listener plus a rename, not a migration of
  nine contexts across a plane boundary with their Postgres schemas.
- Decision 1's PDP registration is the owner's shape (a), and measuring the tree showed it is the
  cheapest of the four rather than a standalone favour: the decision point is already constructed.
- Decision 2 settles the repository list and settings, which ADR-0094 left unassigned and which a
  route partition would otherwise have had to guess.
- Decision 4 writes down that bi-planar modules are intentional, which stops a future reader
  "fixing" them into a shared service and breaking ADR-0011 in the process.
- Decision 6 turns a gate assertion into a structural fact.

**Negative / costs:**
- **A control-plane notification has nowhere to live** (decision 3). Nothing regresses because
  nothing exists, and it is a gap rather than a defect — but it is a gap in the surface ADR-0086
  built.
- **Two audit trails and two policy bundles** to keep consistent in meaning, if not in storage. An
  auditor asking "what happened" must read both, and nothing joins them.
- **The rename touches every BFF deployment and the manifests** (decision 5). It is additive for one
  release, and a compatibility window is a thing to remember to close.
- **Four new registrations widen the control plane's attack surface**, on a plane whose API endpoint
  is private (ADR-0097) but whose application door is reached by agents. Each needs the same
  authorization discipline the data plane's door already has.
- This ADR reads the partition off the composition roots, so it is accurate as of the pinned commit
  and would need re-reading after any module move.

**Follow-ups:**
- **The implementing spec and task** for decision 1's four registrations — `backend`, and it is not
  SPEC-0070's, which is the BFF's side.
- **Amend SPEC-0070's open question 2** to reference this ADR, and un-block AC5/AC6.
- **The `GITFROK_PDP_ADDR` rename** and the release at which the old name stops being accepted.
- **Whether a control-plane notification surface is wanted**, per decision 3's cost.
- **Whether the two audit trails need a joined read** for an auditor, per the second cost.

## Alternatives considered

- **Migrate the contexts to match ADR-0094 decision 4's prose** — move `notifications`, and register
  audit/identity/policy only control-plane-side. Rejected: it reads the decision as a specification
  of where code lives, when its subject was which *surface* a user reaches. It would also move
  durable stores across projects, which is the expensive irreversible half.
- **Leave decision 4 as written and relay notifications over the agent channel.** Keeps the ADR
  unamended. Rejected under decision 3: ADR-0017's stream carries desired state and telemetry, and
  making it carry product events would widen the one channel that crosses the plane boundary — the
  opposite of what ADR-0011 protects.
- **One shared instance of `audit`, `identity` and `policy`.** Removes the duplication decision 4
  accepts. Rejected: it puts a cross-plane call in the hot path of every authorization, which
  ADR-0011 forbids from the control plane and which would make a data plane's availability depend on
  the vendor's.
- **Keep `GITFROK_PDP_ADDR`'s name.** No migration cost. Rejected under decision 5: the name asserts
  one service and carries fourteen, and that is precisely how SPEC-0070's author (correctly) read it
  as the PDP and mis-sized the problem for an afternoon.
- **A fifth control-plane door per new service.** Rejected under decision 1 on ADR-0041's reasoning:
  one listener per plane, not one per capability.
