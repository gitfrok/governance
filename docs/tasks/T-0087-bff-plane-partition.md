# T-0087: The BFF's plane partition

- **Status:** Todo — **blocked-by SPEC-0070 approval**, which is itself blocked on one owner
  decision: the control plane exposes no PDP door, so a control-plane BFF cannot satisfy both its
  startup contract and ADR-0094 decision 7. Not lane-blocked.
- **Phase / Epic:** ADR-0094 carry. **No epic** — filing one is part of scheduling this.
- **Repo(s):** **bff** (the plane input and both refusals), **backend** (`CheckNoDataPlaneDial`'s
  walk, AC8), **super-repo** (`deploy/k8s/controlplane` and its gate, AC10), **governance** (this
  spec's status and the premise pointers). **Four repos, four commits, never fewer** (ADR-0027,
  invariant 23). If open question 1 resolves to shape (a), `backend` also gains a PDP door — which is
  a separate task, not this one.
- **Spec:** docs/specs/SPEC-0070-bff-plane-partition.md (**Draft**)
- **ADRs:** 0094 (decisions 3–7), 0093, 0011, 0006, 0096/0099
- **Owner:** unassigned

## Goal

Make the code do what ADR-0094 decision 5 already decided: one codebase, deployed twice, with a
refusal in each direction. A control-plane BFF must refuse to start **with** a `RepositoryReader`
address; a data-plane BFF must refuse **without** one. Today the binary requires it unconditionally,
which is why the control-plane installer renders a workload that cannot start.

## Acceptance criteria (test-first)

SPEC-0070's ten, carried. Build order:

- [ ] AC9 the refusal tests first — both directions, asserting the exit and the message
- [ ] AC1 `GITFROK_PLANE` accepts `control` or `data`, and nothing else, with no default
- [ ] AC2 control + reader configured → refuse (the refusal that does not exist today)
- [ ] AC3 control without a reader → starts, where today it exits
- [ ] AC4 data without a reader → refuse, preserving current behaviour
- [ ] AC5 a control-plane deployment serves no repository route, coarse 404
- [ ] AC6 a data-plane deployment serves no metadata route
- [ ] AC7 cross-plane links are URLs from the enrolment record; no outbound request; a tenant with no
      door renders as itself
- [ ] AC8 `CheckNoDataPlaneDial` covers `bff`, proven by a fixture that fails
- [ ] AC10 the installer sets `GITFROK_PLANE=control` and no reader, and the gate asserts both

## Tests to write first

1. **The two refusals** (AC9, AC2–AC4). A refusal no test exercises is a comment, and these two are
   the entire enforcement mechanism ADR-0094 decision 5 relies on.
2. **AC8's fixture** before extending the gate's walk: prove the new assertion fails on a
   control-plane-configured BFF that dials a data plane. `CheckNoDataPlaneDial` currently holds over
   `bff/` only because that repo sits outside its walk — true by layout, not by assertion, which
   ADR-0094's own register row says in those words.
3. **Route-set assertions** (AC5, AC6) parsed from the router rather than probed by string match.
4. **AC10 last**, in the super-repo, because it depends on the binary's contract existing.

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony. Gate matrix: `bff` and `backend` suites with
`-race`; super-repo `make verify` including `check-controlplane-kustomize.sh` with its new
assertions; governance `check-docs.sh`.

## Notes / open questions

**The blocker is a missing door, not a missing line.** `main.go` refuses without
`GITFROK_PDP_ADDR` — correctly, since it "must not serve requests it cannot check" — and the only
PDP is `dataplane:9090`. The control plane opens 9091 agent, 9092 usage, 9093 residency, 9094
enrolment, and no PDP. So AC1–AC4 would produce a control-plane BFF that still does not start, and
fixing the reader alone would move the failure one line down. SPEC-0070 open question 1 holds the
three shapes; the likely one is that `controlplane-app` opens a PDP door on the policy bundle it
already mounts, which would be its own task.

**A bug this task inherits.** `deploy/k8s/controlplane/base/bff.yaml` takes the reader address from a
ConfigMap the installer does not create, with a long comment explaining that no valid control-plane
value exists. Under AC2 that configuration becomes a **boot refusal** rather than a missing input, so
the manifest must drop it entirely. The comment was right about the problem and wrong about the
remedy — recorded because it is the kind of thing a reader trusts.

**Four repos.** The one-commit-per-repo rule is not ceremony here: the binary's contract, the arch
gate, the manifest and the spec status each land in a different tree, and ADR-0027 invariant 23
forbids one commit spanning two.
