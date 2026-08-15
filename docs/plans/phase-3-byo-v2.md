# Plan — Phase 3.1: North Star (durability, custody, multi-cluster, commercial maturity)

**Status:** **Planned (2026-08-15)** — plan accepted; **SPEC-0042…SPEC-0046 Approved** and
**ADR-0062…ADR-0067 Accepted** (2026-08-15); every epic may go RED.
**Amended 2026-08-15** after the plan review (`phase-3.1-plan-review.md`): ADR-0066 folded in as the
phase's fifth decision, the custody service's deployment given an owner, the Declare surface given a
verified caller, and the two trust bundles named apart. It also surfaced one decision the phase had
been assuming rather than making — who may declare a tenant's residency — settled by **ADR-0067
(Accepted 2026-08-15)**: the owner keeps the grant, a tenant-scoped platform operator gains it, and
SPEC-0043 AC7 carries it.
**Objective:** Phase 3's recorded limits become production posture — durable control-plane stores,
residency's operator handle on a PDP-decided wire surface, agent-CA keys in custody with staged
rotation, the conformance matrix answered on real clusters, honest divergence health gates through to
the browser, and the PR-7 read-only distinction surfaced — with git never blockable, the control
plane the sole metering authority, and no inbound path opened.

## Context — where Phase 3 actually landed

Phase 3 is implementation-complete (2026-08-15): T-0030…T-0034 all Done with exit records in
`../tasks/`, every task-level acceptance criterion proven by named tests at the exit pins. The fifth
exit criterion — the whole path on a real customer-shaped cluster — is carried to T-0003's cluster
lane, recorded as carried proof, not counted as met.

The 2026-08-15 review added one carry with teeth: the envelope throttle is computed centrally,
published as desired state and acked, but **no data-plane consumer applies it** — SPEC-0041 AC5's
behaviour does not happen in a customer's cluster. **T-0035** owns that data-plane half plus the
design decision it needs (claim gate, scaler input, or both). T-0035 was opened on EP-18's books
*before* this phase was planned and is not renumbered into it; it gates T-0043, because an unapplied
throttle cannot be observed being applied.

The carried set this phase picks up (from `../backlog/` §Phase 3): the in-memory agent/residency
stores (Postgres adapters), the residency Declare wire surface, the enrolment CA's production key
custody, the real-cluster conformance proof with SPEC-0039 AC8, and the PR-7 read-only product
distinction. Closed by the review and carried nowhere: the CA trust-ordering fix (backend@e722046)
and the no-inbound fitness scan's derived tree list.

## North Star

A production-ready multi-cluster posture. A tenant's data planes run where the tenant declared, on
identity rooted in custody-held keys, and it is provable: declarations outlive control-plane
restarts, contradictions are visible with the existing vocabulary, and evidence packs assemble from
durable projections only. The operator ships as a vendor-signed, digest-pinned image; the versioned
release trust bundle distributes and rotates across N data planes without re-enrolment or downtime;
and the conformance matrix answers on real GKE, EKS and AKS clusters — "not run" stops being the default.
Usage stays honest per dimension: divergence is shown with both numbers and never smoothed into a
metered figure, the applied throttle is observable end to end, deferred dimensions read "not
metered", and any read-only state names its cause. Git is never blockable in any envelope state; the
control plane remains the sole metering authority (ADR-0061); nothing opens an inbound path
(ADR-0011).

## What is already decided

Like Phase 3, the architecture predates the plan — all five decisions are Accepted:

- **ADR-0062** — Postgres adapters behind the existing module ports, swapped at the composition
  root; additive module-owned migrations; RLS on every new table; effective-dated declarations; pack
  assembly from durable projections only. No new store engine, no snapshot files, no SQLite sidecar.
- **ADR-0063** — Declare is an additive `contracts/proto/residency/v1` control-plane admin surface;
  operators declare, the PDP decides, every act is audited; the agent channel is never a declaration
  path.
- **ADR-0064** — CA keys live in platform-secrets/KMS custody behind a narrow interface holding key
  references, never material; rotation is a staged CA trust bundle with a dual-validate window and no
  fleet re-enrolment; the dev CA is unreachable from the production composition root.
- **ADR-0065** — the operator is a vendor-signed, digest-pinned first-party image; N data planes per
  tenant keyed by `data_plane_id`; metering aggregates per tenant; posture differences between a
  tenant's planes are defects, not tiers.
- **ADR-0066** — the control-plane custody service is **OpenBao**, the agent CA its first consumer:
  a non-exportable transit-held ECDSA P-256 key signed through ADR-0064's interface, PKI-engine
  delegation rejected, Shamir quorum unseal (no cloud-KMS auto-unseal), Kubernetes auth, three-node
  Raft control-plane-side only, image pinned per ADR-0034. It closes the provider question ADR-0064
  left open **inside** that posture; it also brings a deployment, an unseal authority and an
  availability coupling this phase must own rather than inherit silently (EP-21, T-0040).

Two decisions the review found leaning on assumptions rather than decisions, both settled by
**applying** Accepted ADRs rather than opening new ones:

- **The Declare surface authenticates its caller** — ADR-0045 already decides that tenant, actor and
  roles come from one verified identity source and never from caller input, and ADR-0006 leaves the
  PDP deciding about that verified subject. A new surface that *writes* control state does not get to
  inherit the Phase-2 posture where the subject is the caller's assertion (SPEC-0002's recorded
  limit (d)). SPEC-0043 AC6 makes it testable; the limit stays recorded for the doors it still
  describes.
- **Who may declare** — bundle 0.9.0 grants the action to the tenant's owner only, which was an
  unstated product decision rather than a settled one. **ADR-0067** (filed Proposed and Accepted
  2026-08-15) settles it: reuse ADR-0046's tenant-scoped `platform_operator` for exactly one more
  action, owner grant unchanged, no cross-tenant field — the tenant is a property of the verified
  principal, so SPEC-0043 AC6 stands. SPEC-0043 AC7 and T-0038 carry the policy change; the role stays
  at two actions and a third is a third decision.
- **Token spend must not be burnt by a custody outage** — spend is durable (ADR-0062) and issuance is
  now a network call to a quorum-serialized signer (ADR-0066). ADR-0060's rule is that one token
  never mints two identities; nothing says a failed signature must consume the token. SPEC-0042 AC6
  makes the intended behaviour explicit instead of leaving it to the adapter.

## Workstreams

| Epic | Requirement | Tasks | Specs |
|---|---|---|---|
| **EP-19** Durable control-plane stores | PR-20, PR-22 | T-0036, T-0037 | SPEC-0042 |
| **EP-20** Residency Declare & placement hardening (surface authenticates its caller) | PR-22 | T-0038, T-0039 | SPEC-0043 |
| **EP-21** Agent-CA custody & rotation, incl. the OpenBao custody service's deployment | PR-20 | T-0040 | SPEC-0044 |
| **EP-22** Multi-cluster BYO readiness | PR-20, PR-21 | T-0041, T-0042 | SPEC-0045 |
| **EP-23** Usage-view truth & PR-7 distinction | PR-23, PR-7 | T-0043, T-0044 | SPEC-0046 |

## Milestones and the dependency spine

- **M1 — Durability (EP-19):** T-0036 → T-0037.
- **M2 — Residency ∥ custody (EP-20 ∥ EP-21):** T-0038 → T-0039 ∥ T-0040.
- **M3 — Multi-cluster (EP-22):** T-0041 → T-0042 (blocked-by T-0003's cluster lane).
- **M4 — Commercial maturity (EP-23):** T-0043 (blocked-by T-0035) → T-0044.

**Why this spine.** Durability comes first because everything above it grows the registry or cites
the pack: EP-20's wire surface is pointless over a volatile store (SPEC-0043's own assumption), and
EP-22's multi-plane registry leans on the same durable liveness records — T-0036 lands the
adapter/migration pattern once and T-0037 repeats it for declarations and the pack assembly that
reads them. EP-20 and EP-21 then run in parallel because they touch different modules —
residency/audit versus the agent CA — and neither gates the other; within EP-20 the surface (T-0038)
precedes the hardening that consumes its effective-dated changes (T-0039). **Within EP-21 the custody
service is deployed before the CA is wired to it**: T-0040 lands OpenBao (three-node Raft, Kubernetes
auth, pinned image, unseal procedure) and only then swaps the composition root, because a fitness test
that forbids a disk/env key is unshippable while the only other signer is the dev CA. EP-22's harness
half (T-0041) precedes its real-cluster half (T-0042), which no amount of code can unblock — only the
lane. **EP-21 and EP-22 rotate two different artifacts and neither gates the other**: the *CA trust
bundle* (agent identity roots, ADR-0064, SPEC-0044 AC2, T-0040) and the *release trust bundle*
(cosign release-signing keys, ADR-0044/0065, SPEC-0045 AC2, T-0041). Both ride the reconcile path and
both stage with a dual-validate overlap; they are not the same bundle and must not share a test. EP-23 waits on T-0035, because SPEC-0046 AC3 is untestable until the data plane applies the
throttle; the read-only distinction (T-0044) lands last, rendering against live states. Everything is
additive-first per ADR-0027: the one contract change is a new versioned package (`residency/v1`),
and the only other possible contract touch (CA-trust-bundle staging) is conditional and explicitly
under its own governance PR first.

## What this phase must not do

- **No inbound paths beyond the agent channel** — every new behaviour rides the outbound-only
  connection that already exists; the no-inbound tripwire is re-asserted for the multi-plane shape.
- **No custom billing engines and no overage billing** (ADR-0008); prices, tiers and plan names stay
  out. Nothing in this phase bills.
- **No customer-run operator binaries** — the operator is a first-party signed image (ADR-0065
  decision 1), not an install value a customer supplies.
- **No features needing architectural decisions beyond the six Accepted ADRs** (0062–0067). A
  requirement that
  needs a new decision stops the line at a Proposed ADR (ADR-0001) — it does not get designed inside
  a task.
- **No GitLab-breadth chasing.** PRD §7 (non-goals) stands in full; scope here is the carried set
  and nothing adjacent to it.

## Exit criteria

- [ ] All SPEC-0042…0046 acceptance criteria green — including at least one real cluster per cloud,
      or an honestly annotated subset with named causes (the conformance matrix's own rule; never a
      silent "not run").
- [x] Durable-store restart proofs: token spend, registry staleness and residency declarations
      survive a control-plane kill-and-restart against real Postgres, and pack assembly is proven
      unable to reach in-process stores (SPEC-0042 AC1–AC4).
- [x] Custody off-disk proofs: the production composition root cannot construct a CA from disk or
      env, the dev CA is unreachable, and staged rotation is proven with no re-enrolment
      (SPEC-0044 AC1–AC3) — with the custody service itself deployed, pinned and unsealable by the
      documented procedure (SPEC-0044 AC5).
- [x] The Declare surface refuses an unauthenticated or self-asserted caller before the PDP is asked,
      and no request field can choose tenant, actor or roles (SPEC-0043 AC6).
- [x] A signing failure during enrolment behaves as SPEC-0042 AC6 specifies — proven by test with the
      signer down, not reasoned about.
- [x] Divergence gates shipped through webfrontend: both numbers rendered, applied throttle
      observable end to end, never-zero/never-blocked pins failing the build on regression
      (SPEC-0046).
- [ ] Full gate matrix green at the final pin bump — every repo, one commit per submodule, submodule
      pins referencing merged commits only (invariant 25).
- [x] Runbook current: the rotation procedure with its removal precondition, and the clock-skew
      symptom cross-reference (SPEC-0044 AC4).

### Phase-summary evidence — the final gate-matrix run (board #23, 2026-08-16)

Exit criterion 7 above stays deliberately UNTICKED: the gate-matrix run recorded below predates this
record's own commits, so the pin state at the next bump is not the state the run covered — and a tick
must name the state it binds (the criterion's own "at the final pin bump" wording).

The final full gate matrix ran green at the pin state of super-repo **8ba8d77**: backend **0238dee**,
bff **4059a23**, webfrontend **843a195**, governance **a4c0748** — the state T-0043's and T-0044's
exit records cite (`make verify` + `make codegen-check` + `make surfaces-check` green, per-repo gate
matrices green per those records). **Honest correction:** the board task that opened this record cited
super-repo `2162777` and governance `6301d94` for the same run; neither SHA exists in its repository
(verified after fetch), so the run is cited here at the verifiable pin state above and the unverifiable
SHAs are recorded as a board-side error, not papered over.

**Dev-smoke caveat carried with this run:** `make dev-smoke` AC3 requires the `*.gitsaas.test` names
in `/etc/hosts` (sudo) — documented environment prep, not a product defect; its ingress+TLS half
passes without it (probed via `--resolve`). AC2's openbao half — `smoke-dev.sh`'s running-image
assertion missing the `OPENBAO_IMAGE` pin — was the one real drift board #23 found and fixed;
`make dev-smoke` AC2 is green with it.

### Recorded limits carried out of Phase 3.1 (code review, 2026-08-16)

The phase-3.1 code review (super-repo `cfd8898`) confirmed the phase's acceptance criteria and found
no failing gate. Two of the criteria are met in a narrower sense than their wording suggests, and the
distinction is recorded here so a later reader does not take a tick for more than it proves. Neither
is a defect against a decision; both are scope the phase deliberately did not carry.

- **(f) SPEC-0046 AC4 — the read-only cause is contract vocabulary, and nothing produces or renders
  one yet.** The AC reads "any read-only state in the UI or API identifies its cause". What exists is
  the vocabulary and its prohibitions: `backend/modules/repository/api/readonly.go` (a bare
  "read-only" is not constructible; the commercial branch cannot express one) and
  `webfrontend/src/lib/readonlyCause.ts` (durability and throttle render as different distinctions;
  an unknown cause renders nothing). Neither has a non-test caller, and no wire field carries a
  cause. This follows SPEC-0046's own stated assumption — PR-7's durability mode has no product
  state yet — and T-0044's exit record says so; the limit is that the AC's surface half lands with
  PR-7's own work, not in this phase.

- **(g) EP-21 — the release trust bundle is distributed, not applied.** The bundle reaches each data
  plane over the outbound reconcile channel and its applied revision is recorded per plane
  (SPEC-0045 AC2), but the operator loads its verification keys once at startup from a directory the
  chart mounts (`backend/cmd/operator-app/trust.go`); nothing writes a received bundle into that
  directory. `ReconcileDir` is the control-plane-side staging seam. A rotation therefore reaches the
  fleet's registry but does not change what an operator trusts until the ConfigMap is updated and the
  pod restarts — so AC2's "no downtime during overlap" is proven as a control-plane property, not yet
  as a fleet one. First recorded at board #20 as distribution-without-application; carried here at
  phase level because it bounds what the phase's headline proof means.

A third review finding is recorded as a platform-wide follow-up rather than a phase limit: the
durable adapters scope their transactions from the tenant ARGUMENT, so RLS is evaluated for the
tenant asked about and cannot itself refuse a caller asking about another. Residency's adapter now
refuses the one shape a caller must never express — a tenant argument contradicting the tenant on the
context — before any database work; the same pattern in the security and agent adapters is untouched
and is a platform decision, not a residency one.

## Risks

- **The cluster lane bounds M3.** T-0042 is the only task whose blocker is infrastructure, and it is
  the phase's headline proof; if a lane is unavailable, the exit is an honestly annotated subset —
  the plan says so up front rather than discovering it at exit.
- **The custody service is a new operational authority in the control-plane blast domain.** ADR-0066
  closed the provider question (OpenBao) but bought three obligations with it: a quorum unseal after
  any cold restart (whoever holds the Shamir shares is a new operational authority), an availability
  coupling — issuance and rotation now wait on a Raft quorum, and writes serialize through the active
  node — and a pin-and-upgrade cadence against a project that maintains only its latest major (2.7
  moves several built-in seals to plugins). The first two are runbook-shaped and land with T-0040;
  the third outlives this phase and sits on ADR-0066's follow-ups. The interface risk ADR-0064
  decision 2 guards against is unchanged: the custody seam must stay narrow enough for a future
  general platform-secrets ADR to absorb it.
- **A custody outage lands on the enrolment path.** Spend is durable from EP-19 onward and issuance is
  a remote call from EP-21 onward, so the window between them is the one place an availability event
  can consume a customer's token. SPEC-0042 AC6 fixes the behaviour rather than leaving it to
  whichever adapter lands first; if the chosen shape is "spend stands", the runbook — not the code —
  carries the operator recovery.
- **T-0035's mechanism decides AC3's shape.** If the chosen throttle mechanism (claim gate, scaler
  input, or both) reports too little applied-state fact, SPEC-0046 AC3 carries honestly in T-0035's
  exit record rather than being weakened here.
- **Proxy-only egress remains the standing install-blocker** outside this phase's scope (ADR-0017's
  remaining follow-up) — able to block a sale outright and unchanged by anything below.
