# ADR-0101: A schema belongs to the plane whose modules use it, and three belong to both

- **Status:** Proposed
- **Date:** 2026-09-22
- **Deciders:** platform (requested by the deciding owner after T-0088 stopped)
- **Related:** ADR-0100 (the door partition this completes — its module finding stands, its "only
  registration is missing" claim did not), ADR-0094 (the surface partition), ADR-0093 (the component
  partition and the runbook's migration seam), ADR-0092/0099 (two clusters, two Postgres instances),
  ADR-0004/SPEC-0001 (tenancy and RLS — every schema here is tenant-scoped), ADR-0025 (modular
  monolith per plane), ADR-0011 (no control-plane dial to a data plane), SPEC-0070 (blocked on this
  by way of T-0088)
- **Governs:** G1 isolation, G6 compliance, operability

## Context

T-0088 set out to register four services on the control plane and stopped: ADR-0100 decision 1 said
"each module is already wired and in-process there; only the registration is missing", and the
composition root shows none of the four services' **stores** exist control-plane-side. Worse, the data
plane builds auditor grants as `identity.NewAuditorGrantsPostgres(dbPool, …)`, which read as the
stores needing to migrate — the very thing ADR-0100 claimed it had dissolved.

**Measured rather than reasoned about this time**, the picture is different again, and better.

**There is one database today, and that is why none of this has surfaced.** Both dev planes carry the
same `GITFROK_DATABASE_URL` — `postgres://gitfrok_app:gitfrok_app@postgres:5432/gitfrok` — and
`scripts/dev-provision.sh` applies **twelve migrations to that one database**. Every schema exists in
one place, reachable by both planes, so the question of who owns what has had no way to come up.
ADR-0093 said `deploy/dev`'s single namespace made the component partition invisible; its single
database does the same for the stores.

**Production is already decided to be two.** ADR-0092 decision 2 gives each plane its own cluster and
ADR-0099 gives each its own CloudNativePG `Cluster`. So every schema must resolve to a plane, or be
present in both — and nothing states which.

**Eleven schemas, and the module wiring already answers most of it.** Reading the composition roots
for which binary wires which module, against each module's own Postgres adapter:

| Schema | Module | `dataplane-app` | `controlplane-app` |
|---|---|---|---|
| `agent` | agent | | ✓ |
| `residency` | residency | | ✓ |
| `ci` | ci | ✓ | |
| `codereview` | codereview | ✓ | |
| `notifications` | notifications | ✓ | |
| `release` | release | ✓ | |
| `repo` | repository | ✓ | |
| `security` | security | ✓ | |
| **`audit`** | audit | ✓ | ✓ |
| **`identity`** | identity | ✓ | ✓ |
| **`policy`** | policy | ✓ | ✓ |

Three modules have no Postgres adapter at all — `codesearch` (SPEC-0034's recorded in-memory index),
`metering` and `rollout` — and this ADR does not change that.

**The three bi-planar schemas are exactly where T-0088's missing stores live.** Decision records are
`policy`; evidence is `audit`; auditor grants are `identity`. So the stores the control plane needs
are in schemas it is already entitled to — and **no data has to move**. What T-0088 actually needs is
for the control plane to construct its own instances of three stores, against its own database.

## Decision

**1. A schema belongs to the plane whose modules use it.** Eight resolve to one plane by the table
above: `agent` and `residency` to the control plane, `ci`, `codereview`, `notifications`, `release`,
`repo` and `security` to the data plane. A plane's database carries only its own schemas, so a
schema's absence is as informative as its presence.

**2. `audit`, `identity` and `policy` exist in BOTH databases, holding disjoint rows.** This is
ADR-0100 decision 4's bi-planar modules followed through to their storage. It is **not replication**
and nothing synchronises them: two instances of one shape, holding different facts. A control-plane
audit record is about a control-plane action; a control-plane auditor grant grants access to
control-plane metadata; a control-plane decision record records a control-plane authorization.

**3. Therefore no data migrates, and T-0088 is unblocked by three constructors rather than a
migration.** The control plane runs the `audit`, `identity` and `policy` migrations against its own
database and builds its own decision-records, evidence and grants stores. ADR-0100's conclusion was
right and its reasoning was wrong: it is not a migration, but not because only registration was
missing.

**4. Production migrations are applied per plane, with that plane's subset.** `dev-provision.sh`
applies all twelve to one database and is dev-only by ADR-0024. **There is no production migration
mechanism at all** — ADR-0093 decision 4 named schema migrations as the first of the runbook's three
manual seams, written against Minikube. This ADR does not build that mechanism; it fixes what it must
produce: control plane gets tenancy baseline + `agent`, `residency`, `audit`, `identity`, `policy`;
data plane gets tenancy baseline + `ci`, `codereview`, `notifications`, `release`, `repo`, `security`,
`audit`, `identity`, `policy`.

**5. A bi-planar schema's two instances are never joined by a query, and never reached across the
plane boundary.** ADR-0011 forbids the control plane dialling the data plane, and a cross-database
join would be that with extra steps. Anything needing both — an auditor asking what happened
everywhere — reads both and merges outside the database, which is an interface nothing currently
offers.

**6. Tenancy and RLS are unchanged and non-negotiable in both instances.** Every schema here is
tenant-scoped under ADR-0004/SPEC-0001 with RLS forced; splitting a schema across two databases
changes nothing about that, and a second instance is not an exemption. The `internal/arch` migration
gate applies to both subsets.

## Consequences

**Positive:**
- T-0088 unblocks without moving a byte: three store constructions and an OIDC configuration.
- Every schema has a named owner, so a production migration mechanism has something to implement
  against rather than a judgement to make per table.
- Decision 2 turns ADR-0100's "two audit trails" cost from a surprise into a stated property, and
  generalises it correctly to the two schemas that share its shape.
- Decision 1's corollary is useful: a data-plane database that contains an `agent` schema is
  misconfigured, and that is now checkable.
- Decision 5 keeps ADR-0011 intact where a cross-database join would have quietly broken it.

**Negative / costs:**
- **Three facts are now split, and nothing joins them.** An auditor grant issued on one plane does
  not exist on the other; an audit trail answers only about its own plane; a decision record records
  only local authorizations. For audit this is ADR-0100's accepted cost; this ADR extends it to
  grants and decision records, which is a real reduction in what a single query can answer.
- **An auditor's question spans two databases** and no interface offers that. Under ADR-0055's
  retention rules both halves must be kept, and an evidence pack assembled on one plane is
  structurally incomplete about the other — which matters, because ADR-0029's packs are control
  evidence.
- **The production migration mechanism still does not exist** (decision 4). This ADR makes its
  required output unambiguous and builds nothing, so the gap is now precise rather than vague —
  which is an improvement and not a fix.
- **Two instances of three schemas is more to operate**: two sets of migrations to keep in step, and
  a drift between them would be invisible until a query failed on one plane only.
- `codesearch`, `metering` and `rollout` remain without durable stores, and this ADR deliberately
  does not address them — SPEC-0034's in-memory index limit in particular is unchanged.

**Follow-ups:**
- **Amend T-0088** to decision 3's actual shape: construct three stores and an OIDC config, not
  registration alone.
- **The production migration mechanism** (decision 4), and which component runs it — ADR-0093's
  runbook seam, now with a defined per-plane subset.
- **A gate asserting schema ownership**: a plane's migration subset contains no schema decision 1
  gives the other plane.
- **Whether an auditor needs a joined read** across the two `audit` instances, per the second cost.
  ADR-0100 already carries this row; decision 2 makes it larger.
- **Whether OIDCLogin belongs control-plane-side at all**, given it needs a verifier configuration
  the control plane has never had and `identity`'s credential store is bi-planar. ADR-0100 decision 1
  assigned it; the store measurement did not contradict that, but the configuration gap is real.

## Alternatives considered

- **One shared database for both planes**, as dev has. Every schema resolves trivially, nothing
  splits, and an auditor's query answers everything. Rejected: it is a datastore reachable from both
  planes, which makes a customer's data plane depend on the vendor's database and hands any
  data-plane compromise the control plane's rows. ADR-0092 decision 2's two clusters exist to prevent
  exactly that, and ADR-0011 would be a comment.
- **Move `audit`, `identity` and `policy` to the control plane only**, and have the data plane call
  across for authorization and audit. Removes the duplication and the split facts. Rejected: it puts
  a cross-plane call in the hot path of every authorization and every audited action, which ADR-0011
  forbids in one direction and which would make a customer's data plane unavailable whenever the
  vendor's control plane is — the opposite of what BYO is for.
- **Move them to the data plane only.** The mirror, and worse: the control plane could not authorize
  its own doors without dialling a customer's cluster.
- **Migrate the stores T-0088 needs to the control plane** — read ADR-0100's gap as a real migration
  and move `identity.auditor_grants` and the evidence tables. Rejected because the measurement says
  it is unnecessary: those tables are in bi-planar schemas, so the control plane may simply have its
  own. Recorded because it is what T-0088's stopping note suspected, and the suspicion was reasonable
  before the schemas were mapped.
- **Replicate the three bi-planar schemas between planes** so both see all rows. Rejected: it is a
  cross-plane data path by another name, with a lag, and it would make the data plane's contents
  partly the vendor's problem.
