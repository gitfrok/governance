{{include:banner}}
# AGENTS.md — webfrontend (Astro + React SSR)

Depends on **bff** (HTTP) and **governance** (generated TS types from `contracts/`). Read
`{{GOV}}/AGENTS.md` and `{{GOV}}/docs/` first; obey invariants 1–25.

## Strict
- **Calls only the `bff`** — never `backend` directly (invariant 22).
- Node ≥ 26, TypeScript ≥ 7 (ADR-0023). SSR is a thin proxy; keep logic in the BFF/backend.
- UI follows ADR-0015 (GitHub-clean + unified security/governance surface).
- **TDD**: Vitest for units, a few Playwright E2E on critical paths (see `{{GOV}}/docs/process/tdd.md`).
