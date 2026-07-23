# ADR-0017: Agent ↔ control-plane protocol — gRPC bidirectional streaming over mTLS

- **Status:** Accepted
- **Date:** 2026-07-19
- **Governs:** G9 least-privilege footprint, security, operability
- **Refines:** ADR-0011

## Context
ADR-0011 established an outbound-only agent but left the wire protocol open. We need an
efficient, secure, schema-evolvable channel that carries control/telemetry but never
source code or secrets.

## Decision
The agent opens a **single outbound gRPC bidirectional stream over mTLS** (HTTP/2) to the
control plane, authenticated with **short-lived, rotated per-cluster client certs**.
- **agent → CP:** registration, heartbeat/health, telemetry, billing metadata, and acks of
  applied desired-state. No source code or secrets.
- **CP → agent:** desired-state deltas (component/version), config, and reconcile commands.
- **Model:** CP owns *desired* state, agent owns *actual* state and **reconciles
  idempotently** (declarative, operator-style). Messages are versioned protobuf.
- **Resilience:** auto-reconnect with backoff; resumable via a last-acked cursor; keepalive
  pings on the long-lived stream.
- **Security:** outbound-only; mTLS + cert rotation; the agent only applies **signed
  release references** it can verify (CP cannot push arbitrary code); published RBAC.

## Consequences
**Positive:** one multiplexed connection; strong typing + schema evolution via protobuf;
mutual auth; server push without inbound ports.
**Negative:** some corporate egress proxies need HTTP/2 support (may need a gRPC-Web
fallback); cert lifecycle to manage; long-lived streams need health/keepalive.
**Follow-ups:** protobuf schema + versioning policy; cert issuance/rotation (e.g. SPIFFE/
SPIRE); proxy/HTTP-2 fallback; supply-chain signing of releases the agent applies.

## Alternatives considered
- **WebSocket over TLS** — works, but weaker typing and you build your own framing/schema.
- **REST polling** — chatty, no efficient server push.
- **MQTT/broker** — extra infrastructure for no gain here.
