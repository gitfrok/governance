# T-0087: The BFF's plane partition

- **Status:** Done (2026-09-22) at bff@ec3d6c9 — **8 of 10 criteria met.** The PDP gap that blocked
  it is closed by T-0088. **AC7 remains blocked** on ADR-0094's enrolment-record row (there is no
  field to read), and **AC8 is not done**: extending `CheckNoDataPlaneDial`'s walk over `bff/` is a
  backend change and is now less urgent, because ADR-0100 decision 6 made the property structural —
  a control-plane deployment has no data-plane address to dial, and the gate refuses one.
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

## Exit record (2026-09-22) — bff@ec3d6c9

**Met:** AC1 (`GITFROK_PLANE`, no default), AC2 (control + reader → refuse — the refusal that did
not exist), AC3 (control without a reader starts, where it used to exit), AC4 (data without a reader
refuses), AC5/AC6 (the route partition: 11 control-plane registrations, 26 data-plane), AC9 (both
refusals tested by exit and message), AC10 (the manifests assert the binary's contract, with a
failable fixture).

**The shape that made AC5/AC6 tractable.** Three connections replace one address: `dataConn`, nil on
a control-plane deployment; `ctrlConn`, the door T-0088 registered; and `metaConn`, whichever of the
two serves the four services ADR-0100 decision 1 moved control-plane-side. That last one is why the
evidence, grants, policy-visibility and login handlers are *identical* in both deployments —
ADR-0101 decision 2 makes those schemas bi-planar precisely so each plane reads its own instance.

**The login catch-all is control-only, and that is load-bearing.** It is what makes an unmatched
repository path on the control plane a coarse 404 rather than a redirect into a login flow, which
AC5 requires so that a control-plane response cannot disclose that a data-plane door exists.

**AC7 — blocked, not by this spec.** ADR-0094's own register row asks where the data plane's door
URL lives on the enrolment record. There is no field to read, so there is nothing to render.

**AC8 — not done, and less urgent than when it was written.** Extending `CheckNoDataPlaneDial` over
`bff/` is a backend change. ADR-0100 decision 6 has since made the property structural: a
control-plane deployment is given no data-plane address, the binary refuses one, and
`check-controlplane-kustomize.sh` refuses a manifest that sets one. The gate would now assert
something three other mechanisms already enforce.

**Two of my own mistakes, both caught by tests rather than review.** The route-partition test's first
version anchored on `if cfg.IsControl()` and reported "no control-plane routes found" — true of the
wrong block, since that condition appears three times in `main.go` and the first match selects
`metaConn`. And a mid-edit scaffold referenced a `registerDataPlaneRoutes` helper that did not exist;
reverted rather than built around.

**What still stops a data-plane deployment serving anyone:** it has no session store. That is
ADR-0101's register row, unchanged by this work — the routing is correct and the authentication is
absent.

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
