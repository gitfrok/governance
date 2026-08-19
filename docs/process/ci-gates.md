# CI gates (required checks)

The docs row is easy to read as cosmetic and is not. `check-docs.sh` resolves every relative link,
asserts every ADR, spec and task appears in its index, and since 2026-08-19 asserts that a status
means the same thing in a document as in the index that lists it — and that a spec whose every task
is Done has left `Approved`. Agents read this repo before they write code and follow its links; a
document whose status is behind the work is a decision they will act on wrongly.

Each repo's CI must pass these before merge; the super-repo gate protects the composition.
`✓` = required, `–` = not applicable.

| Check | governance | backend | bff | webfrontend | super-repo |
|---|:--:|:--:|:--:|:--:|:--:|
| lint / format | ✓ | ✓ | ✓ | ✓ | ✓ |
| ADR/spec present (AGDD) | ✓ | ✓ | ✓ | ✓ | ✓ |
| governance docs — links, indexes and **statuses** (`check-docs.sh`) | ✓ | – | – | – | – |
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

**Gate toolchains are pinned to an exact version.** `buf` 1.72.0, OPA 1.19.0, `shellcheck` v0.11.0,
and the codegen plugins. A linter that changes its mind between runs is a gate whose verdict depends
on the day, and the failure is worse than noisy: it is a gate a developer cannot reproduce locally,
which is a gate they learn to push and see rather than run. This is not hypothetical — `shellcheck`
was the one gate left unpinned, and during T-0005 it went red in the super-repo on a finding the
runner's older copy reports and a newer local one does not. Pin first, then decide whether the
finding is worth acting on; the two questions are separate and only one of them is urgent.

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
by grep. The backend and bff cells in that row became real in the same task: each runs an
`inline-permission-check` fitness function (SPEC-0002 AC4) alongside its PDP adapter and PEP tests.
Every ✓ in the policy row now corresponds to a check that runs.

**One gate exists that this table has no row for**, because it belongs to no single repo:
`scripts/check-policy-composition.sh` in the super-repo runs the real authorization path — bff PEP →
gRPC → backend PDP → `governance/policies` — and asserts each verdict, that both verdicts occur,
that the bundle revision survives every hop, and that no denied request reached the data. It is the
policy analogue of the generated-code row: each repo is green in isolation while none of them can
see the other two, and each generates its own copy of `contracts/proto/policy/v1`. The composition
is the only place that can be checked honestly rather than skipped.
