# SPEC-0070: The BFF's plane partition, and the two refusals that enforce it

- **Status:** Draft
- **Owner:** unassigned
- **Context(s):** BFF, webfrontend
- **ADRs:** 0094 (decisions 3–7 — this is their contract), 0093 (the partition ADR-0094 amends),
  0011 (no control-plane dial to a data plane), 0006/SPEC-0002 (the PDP), 0096/0099 (the installers
  that consume this), 0052 (the session store)
- **Amends by reference, without changing a request or response shape:** SPEC-0021, SPEC-0007,
  SPEC-0008. ADR-0094's register row asked for the repository-surface specs to be amended "for the
  data-plane premise" and stated the reason this spec exists: *"Request and response shapes are
  unchanged; the deployment premise is not."* So those specs gain a premise pointer here rather than
  a rewrite — four Implemented specs re-opened to restate a deployment fact would be churn that
  obscures what actually changed.
- **Task(s):** T-0087

## Problem / context

`bff/cmd/bff/main.go` requires `GITFROK_REPOSITORY_READER_ADDR` unconditionally and exits without it
("without RepositoryReader the browser has no data to show"). That reader is `git-storaged`, which is
data-plane-side. So a control-plane BFF needs an address ADR-0011 forbids it to hold, and omitting it
exits the binary — the blocking gap ADR-0093 surfaced and ADR-0094 settled **in principle** while the
code stayed where it was.

ADR-0094 decision 5 says exactly what the code should do, and it is the inverse of what it does:
*"A control-plane deployment refuses to start with a `RepositoryReader` address configured; a
data-plane deployment requires one. The refusal is the enforcement."*

**A second input has the identical shape and nobody had noticed.** `main.go` also requires
`GITFROK_PDP_ADDR` — refusing, correctly, to "serve requests it cannot check" — and in `deploy/dev`
that address is `dataplane:9090`. **The control plane exposes no PDP door at all**: its manifest opens
9091 agent, 9092 usage, 9093 residency and 9094 enrolment, and nothing else. So three accepted
statements cannot all hold today:

- ADR-0094 decision 4 gives the control plane surfaces that need authorization — billing, usage,
  fleet, grants, audit, notifications, admin;
- ADR-0094 decision 7 requires a control-plane BFF to have **no** data-plane dial;
- `main.go` refuses to start without a PDP, and the only PDP is the data plane's.

This spec's job is to state the partition contract precisely and to make that PDP gap a **blocking
open question** rather than something the implementing task discovers halfway through.

## In scope

- A single explicit plane input for `bff` and `webfrontend`, and the route set each plane serves.
- **Both refusals** of ADR-0094 decision 5, in both directions.
- Cross-plane navigation by URL from the enrolment record's door base URL (decision 6).
- Extending `CheckNoDataPlaneDial` to the `bff` repository (decision 7), which today holds only by
  accident of repository layout.
- The premise pointers into SPEC-0021, SPEC-0007 and SPEC-0008.

## Out of scope

- **Any change to a request or response shape.** ADR-0094 is explicit, and a contract change here
  would need a governance-first additive proto change, which this is not.
- The data-plane door's published route and TLS requirements — ADR-0094 decision 1's own open row.
- `webfrontend`'s route-set implementation beyond the plane input it must read.
- Deciding how the control plane gets a PDP. Open question 1 **blocks** this spec's approval; it does
  not belong to it.

## Contracts touched

None.

## Data owned

None.

## Acceptance criteria (each becomes a test)

- [ ] **AC1** One input, `GITFROK_PLANE`, accepts exactly `control` or `data`. Absent or any other
      value refuses at boot with a message naming the two legal values — not a default, because a
      default here silently picks a route set.
- [ ] **AC2** `GITFROK_PLANE=control` **refuses to start when `GITFROK_REPOSITORY_READER_ADDR` is
      set**, and the message says why: a control-plane deployment must serve no repository content
      (ADR-0094 decisions 4 and 5). This is the refusal that does not exist today and is the whole
      point of the spec.
- [ ] **AC3** `GITFROK_PLANE=control` starts **without** a reader address, where today it exits.
- [ ] **AC4** `GITFROK_PLANE=data` refuses to start **without** a reader address, preserving today's
      behaviour for the plane that genuinely needs it.
- [ ] **AC5** **BLOCKED by open question 2** — a route set cannot be partitioned before its
      backends are. A control-plane deployment serves none of the repository routes — tree, file, diff,
      history, blame, code search, and the merge-request views that render diffs — and returns a
      coarse, non-enumerating 404 for each, never a 500 and never a redirect that leaks the
      data-plane door.
- [ ] **AC6** **BLOCKED by open question 2**, and it is the half that exposes the problem: nine of
      ADR-0094 decision 4's metadata surfaces have their backend on the data plane's door today. A
      data-plane deployment serves those routes and **none** of the metadata routes of
      ADR-0094 decision 4 — identity, billing, usage, fleet, policy authoring, audit, evidence packs,
      grants, notifications, admin.
- [ ] **AC7** A control-plane page linking to repository content renders an absolute URL built from
      the enrolment record's stored door base URL, and the BFF makes **no** outbound request to it
      (decision 6). A tenant with no door recorded renders as itself, not as an error — which is the
      state ADR-0094's own register row already asks for.
- [ ] **AC8** `CheckNoDataPlaneDial` covers the `bff` repository, and a fixture proves it fails: a
      control-plane-configured BFF that dials a data-plane address is caught (decision 7). Until this
      exists the invariant is true by repository layout rather than by assertion.
- [ ] **AC9** Both refusals are proven by tests that assert the **exit** and the message, not merely
      the absence of a route — a refusal that no test exercises is a comment.
- [ ] **AC10** The installers agree with the binary: `deploy/k8s/controlplane` sets
      `GITFROK_PLANE=control` and **configures no reader address**, and
      `check-controlplane-kustomize.sh` asserts both. The current base does the opposite — it takes
      the reader from a ConfigMap — which AC2 would refuse at boot.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 isolation | AC2 and AC8 turn ADR-0011's no-dial rule from a layout accident into a boot refusal plus a gate; AC5's coarse 404 keeps a control-plane deployment from disclosing that a data-plane door exists |
| G4 change governance | AC9 makes both refusals testable rather than asserted; AC10 keeps the manifests and the binary from disagreeing, which is how the current gap arose |
| G6 compliance | Unchanged: the PDP remains the authorization point wherever it lives, and this spec adds no second decision |

## Non-functional

- No contract change, so no consumer regenerates anything.
- The refusals are boot-time, not request-time. A deployment that is wrong should fail where an
  operator sees it, not on the first request from a user.

## Open questions / assumptions

1. ~~The control plane has no PDP door.~~ **Owner chose shape (a) on 2026-09-22:**
   `controlplane-app` opens a PDP door on the policy bundle it already mounts, keeping one PEP model
   and avoiding the second BFF authorization decision SPEC-0021's out-of-scope line rules out. That
   is a backend task of its own and **is not** this spec's.

2. **BLOCKING, AND LARGER THAN QUESTION 1 WAS — `GITFROK_PDP_ADDR` is not the PDP's address, it is
   the data plane's entire gRPC door, and nearly every ADR-0094 decision 4 surface rides it.**
   Measured in `bff/cmd/bff/main.go` on 2026-09-22: **fourteen** service clients are constructed on
   `pdpConn` and **one** on a control-plane connection.

   ADR-0041 put PDP, code review, CI and OIDC on one data-plane listener, and the BFF has since
   added more. On `pdpConn` today: `OIDCLogin`, `AuditorGrantService`, `EvidenceService`,
   `NotificationService`, `PolicyDecisionPoint`, `CIJobService`, `FindingsService`, `SearchService`,
   `RepositoryRegistry`, `RepositorySettings`, `ReleaseService`, `MergeRequestService`,
   `ImportService`. On a control-plane connection: `UsageService`, and nothing else.

   ADR-0094 decision 4 assigns identity and login, billing and usage, policy authoring, audit and
   evidence packs, auditor grants, notifications and admin to the **control plane**. Nine of those
   have their backend on the data plane's door. So shape (a) gives a control-plane BFF a policy
   decision point and still leaves it unable to serve almost any route decision 4 promises it — a
   control-plane deployment could serve the usage view and `/healthz`.

   **This is a plane migration of bounded contexts, not a configuration change**, and it interacts
   with where each context's durable store already lives (T-0053's registry, T-0078's code review,
   T-0064's releases, T-0068's settings are all backend Postgres schemas). It needs its own ADR
   deciding which plane owns each context, and it should not be inferred from decision 4's prose.

   **Consequence for this spec:** AC1–AC4 and AC9 remain correct and implementable — they are
   ADR-0094 decision 5 verbatim and the refusals are worth having regardless. **AC5 and AC6 cannot
   be met** until the contexts' plane ownership is decided, because a route set cannot be partitioned
   before its backends are. Approving this spec whole would hand T-0087 an instruction to improvise
   across fourteen services.
3. **Whether `GITFROK_PLANE` is the right input name and shape** — an enum env var versus two
   separate binaries versus a build tag. ADR-0094 decision 5 says one codebase deployed twice, which
   rules out the binaries; the rest is naming.
4. **`webfrontend`'s half is stated here and specified nowhere.** AC5/AC6 describe route sets, and
   the Astro app has its own routing. Whether that needs its own task depends on how much of the
   partition lives in the BFF's responses.
5. **Nothing here makes a repository browsable.** The data-plane `bff`+`webfrontend` pair still needs
   somewhere to run — ADR-0094 decision 1's customer-exposed door, whose route and TLS requirements
   are that ADR's own open row and block a supported install.
