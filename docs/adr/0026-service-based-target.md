# ADR-0026: Target architecture — service-based (not microservices)

- **Status:** Accepted
- **Date:** 2026-07-21
- **Relates to:** ADR-0025 (start point), ADR-0022 (boundaries), ADR-0003 (DB), ADR-0009 (BYO), ADR-0008 (cost)

## Context
We start as a modular monolith (ADR-0025). We define the **target** so evolution is a governed
decision, not folklore, and so we don't drift into microservice sprawl.

## Decision
The target is **service-based architecture (SBA)**: a **small number (~4–12) of coarse-grained**,
independently deployable domain services per plane, integrated over `contracts/` (gRPC + Redpanda
events). **Explicitly not microservices.**

- **Hardened SBA variant:** keep the shared PostgreSQL **cluster** (ADR-0003, cheap ops) but
  **schema-per-context** (ADR-0022) — avoiding classic SBA's shared-schema coupling.
- **Extraction is trigger-driven** (architecture fitness functions), never scheduled. Promote a
  module to a service when **any** trigger fires:
  1. distinct **scaling profile** (e.g. code search, CI control, scan ingestion);
  2. **isolation / blast-radius / compliance** need (e.g. audit, policy/PDP);
  3. divergent **SLO, deploy cadence, or team ownership**;
  4. the monolith binary's **build/test/deploy time** crosses an agreed budget.
- **BYO cost gate (G8):** each extraction adds a pod to the customer's cluster, so it must justify
  the added footprint.

## Consequences
**Positive:** footprint stays small until scale demands otherwise; `contracts/` + module `api`/bus
make extraction mechanical; shared cluster keeps ops simple; avoids microservice sprawl.
**Negative:** a coarse service can still grow too large — revisit boundaries per ADR-0022 if one
accretes responsibilities.

## Alternatives considered
- **Microservices** — rejected: fine-grained ops cost, DB-per-service, distributed transactions; worse under BYO.
- **Monolith forever** — rejected: scaling/isolation ceilings.
- **Classic shared-DB SBA** — rejected: schema coupling; we use schema-per-context.
