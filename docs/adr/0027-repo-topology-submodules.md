# ADR-0027: Multi-repo source topology via git submodules (governance-centered)

- **Status:** Accepted
- **Date:** 2026-07-21
- **Refines (physical layout of):** ADR-0022, ADR-0025 (runtime unchanged)
- **Relates to:** ADR-0002 (governance-driven), ADR-0028 (AGDD)

## Context
We deliver with the **AI-Agent Governance-Driven Development (AGDD)** framework (ADR-0028), in
which governance is the control surface for autonomous agents. We want the codebase physically
separated into independent repositories with clear ownership and a single, authoritative place
for governance and the shared contract surface.

## Decision
A **super-repo** composes four **git submodules**; governance is the center everything depends on:

| Repo (submodule) | Owns | Depends on |
|---|---|---|
| **governance** | ADRs (SoT), specs, roadmap/backlog/plans/tasks, process, invariants, **`contracts/`** (proto+events), **`policies/`** (OPA/Rego), agent rules | nothing |
| **backend** | Go modular monolith (`modules/`, `cmd/{dataplane,controlplane}-app`, `platform/`, git-storaged, agent, operator) | governance |
| **bff** | Go BFF (aggregation only) | governance, backend (gRPC) |
| **webfrontend** | Astro + React SSR | governance (generated TS types), bff (HTTP) |

**Dependency direction (strict):** `webfrontend → bff → backend → governance(contracts)`;
**governance depends on nothing**. No repo imports another's internals; the only shared surface
is governance's `contracts/`.

**Why contracts live in governance:** they are the cross-repo boundary; keeping them with the
decisions (ADRs) makes them additive-only, reviewed, and the single source consumers pin.

**Submodule workflow (enforced — see invariants 21–25):**
- Clone/pull with `--recurse-submodules`; the super-repo stores only **pinned commits**.
- Each submodule is changed in **its own repo via its own PR** (the governance gate applies).
- Cross-repo change order: (1) PR the contract/policy in **governance**; (2) bump the governance
  submodule pointer in each consumer and implement there; (3) bump submodule pointers in the super-repo.
- Never edit submodule files "in place" from the super-repo without committing in the submodule's repo.

## Consequences
**Positive:** clean ownership; governance is an auditable control plane; independent versioning
and CI per repo; small blast radius.
**Negative (accepted, mitigated):** submodules add friction — detached HEADs, pointer-bump PRs,
and cross-cutting changes span repos. Mitigations: additive-only contracts (ADR-0022), the
ordered workflow above, a bootstrap script, and CI that fails a super-repo PR whose submodule
pointers reference unmerged commits.

## Alternatives considered
- **Monorepo** — simplest atomic changes, but weaker ownership/isolation for the AGDD control model.
- **Polyrepo without submodules** (package registries) — looser coupling but no single pinned
  composition; rejected for reproducibility.
- **Contracts as a 5th repo** — folded into governance to keep "4 repos" and co-locate with ADRs.
