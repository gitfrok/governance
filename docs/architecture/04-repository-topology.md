# Repository topology (ADR-0027) & the AGDD control model (ADR-0028)

The platform is a **super-repo** composing four **git submodules**. Governance sits at the
center; everything depends on it, it depends on nothing.

```
git-saas/                      super-repo — pinned submodule commits + dev orchestration
├── governance/   [submodule]  AGDD control surface: ADRs, specs, contracts/, policies/, process, agent rules
├── backend/      [submodule]  Go modular monolith (modules, cmd/{dataplane,controlplane}-app, platform, git-storaged, agent, operator)
├── bff/          [submodule]  Go BFF (aggregation only)
└── webfrontend/  [submodule]  Astro + React SSR
```

## Dependency direction (strict)
```
webfrontend ──HTTP──▶ bff ──gRPC──▶ backend ──imports──▶ governance/contracts
     └──────────────── generated TS types ◀──────────────┘   (governance depends on NOTHING)
```
- No repo imports another repo's internals. The only shared surface is `governance/contracts/`.
- `webfrontend` never calls `backend` directly — always through `bff`.
- `bff` has no business logic (aggregation/shaping only).

## Submodule workflow (do this exactly — invariants 21–25)
1. `git clone --recurse-submodules <super-repo>` (or `git submodule update --init --recursive`).
2. Change code **inside a submodule's own repo** on a branch → PR there (governance gate applies).
3. For a cross-repo change: **governance PR first** (add contract/policy, additive-only) → merge
   → in each consumer bump the `governance` pointer + implement → PR each → finally bump submodule
   pointers in the **super-repo** referencing the merged commits.
4. The super-repo only ever stores **pinned commits**. Never commit in-place edits to a submodule
   path from the super-repo.

## Why this shape for AGDD
Governance is the agents' "policy brain": ADRs (SoT), specs, invariants, `contracts/`, and
`policies/` are all here and versioned. Code repos are "actuators." Agents read governance first,
and cannot change governance silently — decisions go through Proposed ADRs / spec approval.
