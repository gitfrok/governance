# T-0008: In-process event bus + module `api` convention

- **Status:** Done (2026-08-03)
- **Phase / Epic:** 0 / EP-0
- **Repo(s):** backend (`platform/bus`, reference modules, `cmd/dataplane-app`); governance only
  if AC3 needs a new `contracts/events` shape (additive)
- **Spec:** chore — acceptance criteria below
- **ADRs:** 0025, 0022
- **Owner:** unassigned

## Goal
Build the modular-monolith seam so modules integrate in-process the way they will over `contracts/`.

## Acceptance criteria (test-first)
- [x] AC1: `platform/bus` provides typed publish/subscribe usable by any module's `app` layer.
- [x] AC2: A reference module exposes only its `api/` package; a second module consumes it via `api` + bus.
- [x] AC3: Event names/shapes mirror `contracts/events/...` so extraction to Redpanda is mechanical.
- [x] AC4: Wiring happens in `cmd/dataplane-app` (concrete impls injected), not inside modules.

## Tests to write first
- unit: bus publish/subscribe + delivery semantics.
- contract: in-process event shapes match the `contracts/events` schema (shared test).
- boundary: the consumer imports only the producer's `api/`, never `internal/*`.

## Definition of Done
See `../process/definition-of-done.md`.

## Implementation record

| Repo | Commit | What |
|---|---|---|
| backend | `6acc1c8` (#3) | `platform/bus`, `platform/ids`, `modules/codesearch`, repository events + composition roots |

- **AC1** — `bus.InProcess`: synchronous, ordered fan-out keyed by event name. Every handler runs
  even when one fails and the errors come back joined, so an independent consumer cannot be
  silently skipped. `SubscribeTyped[T]` gives an app layer the concrete type with no assertion.
- **AC2** — `modules/codesearch` projects `modules/repository`'s events. `RepositoryCreated`
  deliberately carries no repository name, so the projection resolves it through the producer's
  `api/` read port: both legal cross-module routes exercised for real, not just declared.
- **AC3** — a parity test asserts each in-process event's name equals its protobuf full name and
  that the fields correspond in **both** directions. Mutation-checked: an added field, a dropped
  field and a renamed event each fail it.
- **AC4** — composition lives in `cmd/dataplane-app`, proven by a test that creates a repository
  through one context and reads it back from the other.

## Notes / open questions
- **Go's `internal/` rule is stricter than the architecture rule, and AC4 as written is not
  satisfiable without a new convention.** `cmd/` cannot name a type under `modules/<ctx>/internal`,
  so it cannot inject one. Each module now has an exported composition root at
  `modules/<ctx>/module.go` that assembles its internals and returns `api/` interfaces; `cmd/`
  still chooses the adapter and passes the infrastructure. Recorded in backend `AGENTS.md`.
- **The bus requires a tenant on every event** (`bus.ErrTenantRequired`). Invariant 1 is written
  about queries; every message in `contracts/events` carries `tenant_id`, and a consumer that
  cannot scope what it received cannot honour it. Deliberate strengthening, flagged here rather
  than assumed.
- **Delivery is synchronous by design.** It keeps a request's choreography inside that request's
  context and transaction. Anything needing redelivery or replay belongs on Redpanda already, not
  on a goroutine behind this interface.
- `platform/ids` shipped the ULID that T-0001 deferred to this task, checked against the ULID
  spec's own test vector. `event_id` is the consumer's idempotency key, so monotonicity within a
  millisecond is a property and not an accident.
- No `contracts/` change was needed: `RepositoryCreated` and `RefUpdated` already existed. Nothing
  publishes `RefUpdated` yet — the git write path is T-0010 — but the shape and its consumer are
  in place and covered by tests.
