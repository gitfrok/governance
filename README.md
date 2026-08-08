# governance

The AGDD control surface (ADR-0028): ADRs (SoT), specs, `contracts/`, `policies/`, roadmap/
backlog/plans/tasks, process, invariants, and agent rules. **Depends on nothing.** Start: `AGENTS.md`.

## Licence

This repository is licensed under the **GNU General Public License v2.0** — see [`LICENSE`](LICENSE)
and **ADR-0039**, which explains why this repo and only this repo carries it. Nothing obliges the
choice; it costs nothing here, because this repo links no libraries, produces no binary, and ships to
no customer.

`backend`, `bff`, `webfrontend`, and the super-repo are **not** covered and **must not** simply
inherit it. Their licence is an open decision (ADR-0039 decision 5): GPL v2 without "or later" is
incompatible with Apache-2.0, and ADR-0006 (OPA) and ADR-0014 (Zoekt) mandate Apache-2.0 dependencies
inside the binaries ADR-0009 distributes to BYO customers.

**No third-party code is vendored in this repo** (ADR-0039 decision 2). Everything here, including
`scripts/gen-agent-surfaces.sh`, is ours.
