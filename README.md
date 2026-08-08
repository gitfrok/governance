# governance

The AGDD control surface (ADR-0028): ADRs (SoT), specs, `contracts/`, `policies/`, roadmap/
backlog/plans/tasks, process, invariants, and agent rules. **Depends on nothing.** Start: `AGENTS.md`.

## Licence

This repository is licensed under the **GNU General Public License v2.0** — see [`LICENSE`](LICENSE)
and **ADR-0038**, which explains why this repo and only this repo carries it. `backend`, `bff`,
`webfrontend`, and the super-repo are **not** covered; their licence is an open decision (ADR-0038
follow-up), because GPL v2 alone conflicts with the Apache-2.0 dependencies ADR-0006 and ADR-0014
require in shipped binaries.

Nothing under `tools/rdf/` (vendored from [rfxn/rdf](https://github.com/rfxn/rdf), GPL v2) may be
imported or copied into a code repo or a shipped artifact — ADR-0038 decision 5.
