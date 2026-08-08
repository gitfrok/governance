# Definition of Done (DoD)

A task/PR is Done only when **all** hold:

- [ ] The PR declares its **ceremony tier**, or declares nothing and is therefore `full` (SPEC-0012).
      `quick` and `bugfix` waive the item below and nothing else; neither is available to a change
      touching authorization, tenant scoping, RLS, audit, the agent wire, secrets, `policies/`,
      `contracts/` or CI config.
- [ ] An **approved spec** exists (or the task is a chore with acceptance criteria stated).
      *Waived by `quick`; waived by `bugfix`, where the failing test is the specification.*
- [ ] Tests were written **first** and now pass: unit, contract, integration as applicable.
- [ ] **Boundary/arch tests** pass (invariants 14–18) — no cross-context imports, `domain`
      free of infra.
- [ ] **Policy + tenant-isolation tests** pass where relevant (invariants 1–4).
- [ ] No invariant in `../agents/invariants.md` is violated.
- [ ] Contract changes are additive within v1 (`contracts/README.md`).
- [ ] An **ADR was added** if a new significant decision was made (status `Proposed`/`Accepted`).
- [ ] Version floors respected (ADR-0023); `.tool-versions` / image tags unchanged unless intended.
- [ ] PR satisfies `.github/pull_request_template.md`; commits are conventional; diff is focused.
- [ ] **CI gates** green for this repo per `ci-gates.md`.
- [ ] **Task file status** and the **backlog** are updated.
