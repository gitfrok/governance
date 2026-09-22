# T-0093: A data-plane BFF logs people in

- **Status:** Done (2026-09-23) — bff@14adef6 + super-repo; SPEC-0073 AC1–AC6
- **Phase / Epic:** EP-32 carry (ADR-0102)
- **Repo(s):** **bff** (the route and the refusal, with their tests), then **super-repo** (the pin,
  and any `deploy/dev` change). Separate commits (invariant 23).
- **Spec:** `../specs/SPEC-0073-data-plane-login.md` (AC1–AC6)
- **ADRs:** 0102, 0094, 0100, 0052, 0011
- **Owner:** unassigned

## Goal

A person can log in to the repository surface a data-plane BFF serves, on the dev cluster.

## Definition of Done

See `../process/definition-of-done.md`. Plus: `go test ./...` green in `bff` with the new tests seen
failing first; `make verify` green in the super-repo; SPEC-0073 AC6 shown on the dev cluster. **No
production step** (owner rule, 2026-09-23).

## Exit record

Tests first, seen failing, then green; mutation-checked; `go test -race ./...` green in `bff`;
`make verify` green in the super-repo. SPEC-0073 AC6 shown on the dev cluster (see the spec's
Evidence section). No production step.

Two findings outside the spec, both recorded rather than absorbed: the seven migrations
`dev-provision.sh` never applied (fixed in the super-repo — the same list was used on production), and
the notifications read path that denies everyone (T-0094).
