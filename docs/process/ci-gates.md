# CI gates (required checks)

Each repo's CI must pass these before merge; the super-repo gate protects the composition.
`✓` = required, `–` = not applicable.

| Check | governance | backend | bff | webfrontend | super-repo |
|---|:--:|:--:|:--:|:--:|:--:|
| lint / format | ✓ | ✓ | ✓ | ✓ | ✓ |
| ADR/spec present (AGDD) | ✓ | ✓ | ✓ | ✓ | ✓ |
| contract schema (additive / breaking-check) | ✓ | ✓ | ✓ | ✓ (TS gen) | – |
| unit (domain) | – | ✓ | ✓ | ✓ | – |
| integration | – | ✓ | ✓ | ✓ (E2E) | – |
| boundary / arch (invariants 14–20) | – | ✓ | ✓ | ✓ | – |
| policy + tenant-isolation (invariants 1–4) | ✓ (Rego) | ✓ | ✓ | – | – |
| fitness fns (invariants 19–22; ADR-0026) | – | ✓ | ✓ | ✓ | ✓ (dep direction) |
| version floors (ADR-0023) | – | ✓ | ✓ | ✓ | ✓ |
| submodule pins reference **merged** commits (invariant 25) | – | – | – | – | ✓ |

Wired by tasks T-0002 (boundary/arch), T-0009 (fitness), T-0004/T-0005 (policy/isolation),
T-0001 (version floors + super-repo dep-direction). See `definition-of-done.md`.
