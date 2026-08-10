# T-0012: Sync-replica write path + failover

- **Status:** Done (2026-08-10) — backend
- **Phase / Epic:** 1 / EP-4
- **Repo(s):** backend (git-storaged)
- **Spec:** docs/specs/SPEC-0005-durable-writes-failover.md
- **ADRs:** 0016, 0018, 0042, 0046
- **Owner:** unassigned

## Goal
Make pushes durable and survive node loss per the failover policy.

## Acceptance criteria (test-first)
- [ ] AC1: a push is acked **only after primary + 1 sync replica** are durable (invariant 6).
- [ ] AC2: on primary loss, only an in-sync replica auto-promotes.
- [ ] AC3: dual loss → **read-only** (no stale auto-promote); operator override is audited (ADR-0018).

## Tests to write first
- integration: kill-node scenarios; unit: ack/quorum logic; contract: coordination messages.
- audit: override path emits an immutable audit event.

## Definition of Done
See `../process/definition-of-done.md`.

## Implementation record

| Repo | Commit | What |
|---|---|---|
| governance | `bcd42e1` (#102) | Additive replica coordination contract: `contracts/proto/replica/v1/replica.proto`. |
| governance | `39e3e6e` (#79) | SPEC-0018 Approved. |
| governance | `7a30c96` (#80) | ADR-0042 Accepted — fencing term before write authority. |
| governance | `b352465` (#85) | SPEC-0005 Approved + replica coordination contract. |
| governance | `d6646d9` (#??) | ADR-0046 Accepted — dual loss / force-promote policy. |
| backend | `8d14e57` (T-0012) | `modules/repository/internal/replica/` in-process coordinator; `api.Coordinator` port; `platform/audit/forcepromote.go`; git-storaged write-path integration (`acquireWriteLease`, `requireQuorum`); single-node auto-seed via `NewInMemoryCoordinator`. |

- **AC1** — `TestQuorumRequiresPrimaryAndSyncAck` proves primary-only ack withholds quorum; async-only replica cannot satisfy it; sync ack completes the quorum. `TestReceivePackQuorumWithholdsAckWhenSyncUnreachable` at the write path confirms a push without quorum is not acknowledged and no RefUpdated event is published. The quorum rule is keyed off the same fencing term used for BindWrite, so a stale term cannot satisfy it (`TestTermChangeMidPushWithholdsAck`).
- **AC2** — `TestStaleTermAndStalePrimaryAreDeniedWithoutChangingRecord` proves stale-term BindLease and stale-primary AckDurable are refused without mutation. `TestUnknownShardDenied` covers unknown shards.
- **AC3** — `TestDualLossFailsReadOnly` confirms a degraded shard enters read-only, BindLease is denied, and auto-promotion is refused. `TestForcePromoteFromDegradedReadOnlyAudited` proves force-promote from read-only requires operator input, allocates a higher term, and emits exactly one `replica.force_promote` audit event.
- **AC4** — `TestAutoPromoteCASAndFence` proves promotion is a CAS from healthy to the in-sync replica only; the old primary's lease/ack is stale; the new primary cannot write until `AcknowledgeFence`.

## Notes / open questions
SPEC-0005, SPEC-0018, and ADR-0042 were Approved/Accepted before RED. The single-process coordinator is the dev adapter; production uses a shared durable substrate behind the same `api.Coordinator` port (SPEC-0018 §Open questions). Cross-repo changes followed ADR-0027 order (governance first).
