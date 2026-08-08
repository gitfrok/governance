# governance

The AGDD control surface (ADR-0028): ADRs (SoT), specs, `contracts/`, `policies/`, roadmap/
backlog/plans/tasks, process, invariants, and agent rules. **Depends on nothing.** Start: `AGENTS.md`.

## Licence

This repository is licensed under the **Apache License, Version 2.0** — see [`LICENSE`](LICENSE) and
**ADR-0040**, which licenses every repo in the tree the same way. It replaces the GPL v2 this repo
briefly carried; that grant is not withdrawn for commits already published under it, but this version
onward is Apache-2.0.

Apache-2.0 is compatible with the dependencies ADR-0006 (OPA) and ADR-0014 (Zoekt) mandate — the
constraint that ruled out GPL v2 — and its express patent grant matters for binaries ADR-0009 and
ADR-0013 hand to BYO customers. It is permissive: a customer may fork and redistribute without
contributing back. ADR-0040 decision 4 records that as a deliberate trade.

**No third-party code is vendored in this repo** (ADR-0039 decision 2). Everything here, including
`scripts/gen-agent-surfaces.sh`, is ours.
