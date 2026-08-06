# CI gates (required checks)

Each repo's CI must pass these before merge; the super-repo gate protects the composition.
`✓` = required, `–` = not applicable.

| Check | governance | backend | bff | webfrontend | super-repo |
|---|:--:|:--:|:--:|:--:|:--:|
| lint / format | ✓ | ✓ | ✓ | ✓ | ✓ |
| ADR/spec present (AGDD) | ✓ | ✓ | ✓ | ✓ | ✓ |
| contract schema — lint + breaking (ADR-0032) | ✓ | – | – | – | – |
| generated code matches the pinned contracts | – | – | – | – | ✓ |
| unit (domain) | – | ✓ | ✓ | ✓ | – |
| integration | – | ✓ | ✓ | ✓ (E2E) | – |
| boundary / arch (invariants 14–20) | – | ✓ | ✓ | ✓ | – |
| policy + tenant-isolation (invariants 1–4) | ✓ (Rego) | ✓ | ✓ | – | – |
| fitness fns (invariants 19–22; ADR-0026) | – | ✓ | ✓ | ✓ | ✓ (dep direction) |
| version floors (ADR-0023) | – | ✓ | ✓ | ✓ | ✓ |
| submodule pins reference **merged** commits (invariant 25) | – | – | – | – | ✓ |

Wired by tasks T-0002 (boundary/arch), T-0009 (fitness), T-0004/T-0005 (policy/isolation),
T-0001 (version floors + super-repo dep-direction), T-0020 (contract schema + generated code).
See `definition-of-done.md`.

**The contract rows moved in T-0020, and the previous shape was wrong.** They used to read
`✓ | ✓ | ✓ | ✓ (TS gen) | –` — a check required in four repos that existed in none, for a reason no
amount of effort inside those repos could fix: each consumer's `buf.gen.yaml` reads
`../governance/contracts`, a sibling checkout that exists only in the super-repo composition, so a
standalone consumer CI run has nothing to generate from. `buf lint`/`buf breaking` therefore belong
where the contracts live (governance), and *generated code matches its pin* belongs where the repos
are composed (super-repo). Per-consumer generation would need the generated-type publishing
follow-up in ADR-0027/0028; until that is decided, the rows above are what is actually enforceable,
and every ✓ in this table now corresponds to a check that runs.

**The governance Rego cell became real in T-0005.** `✓ (Rego)` had been in this table since it was
written, against an empty `policies/` directory — the same shape of problem as the contract rows
above, a required check with nothing behind it. `scripts/check-policies.sh` now builds the bundle,
compiles under `--strict`, runs `opa test`, and asserts deny-by-default by *evaluation* rather than
by grep. The backend and bff cells in that row are still aspirational: they are satisfied by
T-0005's remaining halves (the PDP adapter and the PEP call, plus the AC4 fitness function that
fails a build containing an inline permission check).
