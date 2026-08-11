# ADR-0052: The BFF may open exactly one datastore — its own session store — behind a declared waiver

- **Status:** Accepted
- **Date:** 2026-08-12 (proposed and accepted the same day)
- **Deciders:** platform
- **Governs:** G1 tenant isolation, G2 least privilege
- **Refines:** ADR-0049 (the opaque server-side browser session — this decides *how the BFF is
  permitted to hold it*, which ADR-0049 assumed rather than settled)
- **Relates to:** ADR-0022 (high cohesion, low coupling), ADR-0023 (Valkey), ADR-0025, ADR-0026
- **Invariants:** 15 (no cross-context database access), 18 (BFF has no business logic) · **Tasks:**
  T-0013, T-0015, T-0016

## Context

ADR-0049 decision 5 states that the browser session store **is Valkey**, keyed by the opaque session
identifier, and decision 3 states that **the BFF** resolves a session against it on every request.

The BFF's own boundary fitness function forbids exactly that. `RuleDirectDataStore`
(`bff/internal/arch/boundary.go`, landed by T-0002 and widened by T-0009) fails the build on any
import matching a SQL driver, a cache client — `valkey-io/valkey-go`, `redis/go-redis`,
`gomodule/redigo` — or a message client, anywhere in the BFF tree. Its recorded reasoning is not
stylistic: the BFF has no data of its own, a query from there would run outside RLS and without a PDP
decision, and *"reading another context's state out of Valkey or consuming its topic directly is the
same coupling wearing a different protocol."* There is no waiver mechanism, unlike the inline-authz
rule's `//arch:allow-inline-authz`.

So an Accepted decision and an enforced invariant contradicted each other, and the contradiction was
load-bearing: while it stood, the only implementation of the store was in-process memory, so sessions
died with a BFF restart and could not be shared across replicas.

Three shapes were considered.

**Leave the store in memory and defer.** Costs nothing today and leaves the BFF unable to run more
than one replica without logging users out at random, which the web surface needs before it can scale
at all. It also leaves an Accepted ADR unimplemented, which is the state this repo exists to prevent.

**Move the store behind Identity&Access.** Backend owns a Valkey adapter and the BFF calls
`CreateSession` / `ResolveSession` / `DeleteSession` over gRPC. The fitness rule stays absolute and
the BFF stays stateless. It costs an additive contracts change, a second store implementation, and an
extra network hop on **every** browser request — including the ones that then make no other backend
call. It also contradicts ADR-0049's framing that the session is the BFF's to own: the tenant, actor
and roles would round-trip through a service whose only role is to hold them.

**Permit one datastore in the BFF, narrowly and visibly.** The rule keeps its teeth for every other
import and every other path; a session store is admitted as the single exception, declared in the
source and checked by the same gate.

The distinction that decides it: **a session is the BFF's own state, not a projection of another
context's data.** Invariant 15 forbids reaching into another context's schema. A session record holds
what the BFF minted at the OIDC callback and nothing else — no repository, no merge request, no audit
entry, nothing another context owns. Resolving it is not a cross-context read, and no PDP decision or
RLS predicate applies to it, because the session *is* the identity those checks later consume.

## Decision

The BFF may open **exactly one** datastore: the session store ADR-0049 decides, and nothing else.

1. **`RuleDirectDataStore` gains a path-scoped, declared waiver.** A datastore import is permitted
   only in a file under `internal/session/` that carries the marker comment
   `//arch:allow-session-store <reason>`. Both conditions are required: the path alone is not enough,
   so a future file cannot inherit the exemption by location, and the marker alone is not enough, so
   it cannot be pasted into a handler.

2. **The waiver covers session storage only.** Any read of another context's state through that
   client is a violation of invariant 15 that this ADR does not license, whatever the file it sits
   in. The session record holds the tenant, actor, roles, expiry and nothing else — no field that
   another context owns.

3. **The client is a Valkey/Redis-protocol client** (ADR-0023: Valkey is a drop-in replacement, so a
   Redis-protocol client is the sanctioned way to reach it). The BFF gets its address from
   per-environment configuration and never a compiled-in one (invariant 13).

4. **The store is selected by configuration, and an unavailable configured store is fatal at
   startup.** `GITFROK_SESSION_STORE=valkey` requires the address to be set and reachable; the
   process refuses to start otherwise rather than silently falling back to memory. A BFF that
   quietly served memory sessions while an operator believed Valkey was in use would look healthy
   while logging users out on every rollout.

5. **The in-memory store stays, for dev and for tests.** It is the explicit
   `GITFROK_SESSION_STORE=memory` posture, and it remains the default so a developer with no Valkey
   still gets a working login.

6. **Sessions carry a server-side absolute expiry, enforced by the store.** Valkey key expiry is the
   mechanism; the BFF sets it at creation and never extends it in place, so the ADR-0049 expiry bound
   holds without a sweeper.

## Consequences

**Positive.** ADR-0049 becomes implementable as written. The BFF can run more than one replica, and a
rollout stops logging every user out. Revocation stays a deletion, now durable across restarts. The
exception is visible in the source, checked by the gate, and impossible to widen silently.

**Negative / costs.** The BFF acquires operational state and its first non-transport dependency, and
Valkey moves onto the critical path for the web surface — which ADR-0049 already recorded. The
absolute rule "the BFF opens no datastore" becomes a rule with one named exception, which is a weaker
statement to reason about and needs the gate to keep it honest.

**Neutral.** A programmatic caller still uses a PAT; nothing here gives the session store a second
consumer.

## Alternatives

Rejected above: deferring on memory, and moving the store behind Identity&Access. A third was
rejected without much weight — writing a minimal RESP client in-repo so that no listed import matches.
It satisfies the letter of the fitness rule while defeating its purpose, which is worse than an
honest, declared exception.

## Open questions

- Whether the same waiver shape should be offered for any other BFF-owned state that may appear
  later. Deliberately not generalized here: one exception is auditable, a policy for exceptions is not.
