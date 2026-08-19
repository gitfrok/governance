# SPEC-0018: Replica coordination and fencing contract

- **Status:** Implemented (2026-08-10) — every acceptance criterion is proven by its task(s)
- **Owner:** platform
- **Context(s):** Repository/Git, Policy, Audit
- **ADRs:** 0006, 0007, 0016, 0018, 0042
- **Task(s):** T-0012

## Problem / context

ADR-0016 makes an acknowledged push dependent on durability at the primary and its recorded
in-sync replica. ADR-0018 makes a correlated loss fail read-only, and ADR-0042 requires an
increasing fencing term before any replacement primary writes. The storage process needs one
additive, implementation-independent coordination surface so a router cannot mistake a lease,
an async acknowledgement, or a stale primary for authority to accept a push.

## In scope

- An additive `contracts/proto/replica/v1/replica.proto` coordination service with opaque shard,
  node and operation identifiers.
- A read-only shard record containing primary node, in-sync replica, membership version, state,
  and unsigned monotonic fencing term.
- A write-route lease that binds one receive-pack operation to the record's primary and term;
  storage nodes reject writes and acknowledgements with a lower term or another primary.
- Durable-primary and durable-sync acknowledgement messages for one opaque operation ID; a router
  acknowledges its caller only after both are confirmed under the same term.
- Compare-and-swap auto-promotion from `healthy` only to the recorded in-sync replica. The change
  allocates a higher term, requires fence acknowledgement, and exposes write-ready only afterward.
- A force-promotion request for an operator-selected async replica only from
  `degraded_read_only`, with previous term, estimated RPO window, actor, policy decision ID, and
  resulting term available to the Audit emitter. It carries no caller-provided allow assertion.
- Bounded audit detail vocabulary for `replica.force_promote` using the existing generic audit
  event: shard ID, previous/new term, selected node, estimated RPO window, actor and decision ID.

## Out of scope

- Git object/pack transport, source code, filesystem locations, credentials, agent-stream data,
  cross-region DR, lease-only primary election, tenant self-service force-promotion, and an
  automatic promotion of an async replica.

## Contracts touched

- `contracts/proto/replica/v1/replica.proto` (additive), generated for backend consumers.
- Existing `events/audit/v1/AuditEvent` action `replica.force_promote`; no event schema change.

## Data owned

Repository/Git owns per-shard membership, fencing terms, durable operation acknowledgements and
read-only state. Policy owns the force-promotion decision. Audit owns immutable persistence of the
force-promotion outcome. No context reads another context's tables.

## Acceptance criteria (each becomes a test)

- [ ] AC1: A receive-pack acknowledgement is impossible until the same operation and term have
  durable acknowledgements from both recorded primary and recorded in-sync replica.
- [ ] AC2: A stale term, stale primary, async-only acknowledgement, malformed operation, or
  mismatched shard/term is denied without changing the shard record.
- [ ] AC3: Automatic promotion is a CAS from `healthy` to only the recorded in-sync replica; it
  increments the term and stays non-write-ready until the old term is fenced.
- [ ] AC4: Confirmed primary-plus-sync loss enters `degraded_read_only`; no automatic async
  promotion or write route is available.
- [ ] AC5: Force promotion requires a PDP allow for `replica.force_promote`, a successful CAS and
  fence, then one immutable audit event containing all required bounded detail keys.
- [ ] AC6: Contract lint proves no filesystem path, credential, Git payload, agent-stream field,
  or authorization assertion can be represented by a coordination message.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 isolation | Shard records and operation routes are tenant-scoped; stale writers cannot cross a fence. |
| G2 least privilege | Force promotion is PDP-gated operator action; missing policy decision denies. |
| G5 auditability | Every accepted RPO trade-off emits immutable bounded evidence. |
| G9 least-privilege footprint | Coordination carries opaque IDs/terms, never source, secrets or storage paths. |

## Non-functional

- Terms are unsigned 64-bit, strictly increasing per shard, and comparison is constant-time.
- A failed coordinator CAS, fence or replica acknowledgement leaves writes unavailable; it never
  retries by accepting a lower term or falling back to a lease.
- The receive-pack hot path adds one sync durability acknowledgement only; async fan-out cannot
  delay or satisfy the acknowledgement rule.

## Open questions / assumptions

- The coordinator persistence implementation (Postgres advisory/CAS, etcd, or another durable
  substrate) is an adapter choice after this contract and does not alter the term semantics.
- Operator authentication reaches the force-promotion PEP through the established control-plane
  path; this contract receives its identity and policy decision ID as audit context, not an allow
  flag.
