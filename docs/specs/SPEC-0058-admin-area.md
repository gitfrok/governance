# SPEC-0058: The admin area — a dated fleet report, and a door into the grant flow

- **Status:** Implemented (2026-08-19) — AC1–AC19 green; governance@0d1b79c, backend@688ed6e, bff@1b761f5, webfrontend@1d1d815
- **Owner:** platform
- **Context(s):** Agent (owns the data-plane registry the fleet report reads) · Identity & Access
  (owns the auditor grants the audit door leads to) · BFF · Web frontend — ADR-0022
- **ADRs:** 0077 (decides this and its scope), 0007 (append-only audit), 0060 (agent enrolment and
  identity), 0009/0010 (residency, and why the data plane is outbound-only), 0049 (identity and
  roles), 0006, 0022, 0069, 0070
- **Task(s):** T-0071 (contract + backend), T-0072 (bff), T-0073 (web)

## Problem / context

PR-31 asks that an org administrator can read the org's members, roles, runners and audit log from an
admin area, **without gaining repository read access**. That last clause is the requirement, and it is
already solved in this product for a different reader: SPEC-0033's auditor grants are scoped,
time-boxed, revocable and audited, and the evidence pack is what they read.

ADR-0077 accepted the two panels that can be built honestly today:

- **A fleet report.** The Agent context's `Fleet` already returns each data plane with its derived
  status and the instant it was last seen, and its own comment says *stale reads stale, never
  healthy*. Nothing reads it from a browser: there is no RPC for it, so this spec adds one.
- **A door into the grant flow.** Not a trail browser. The admin area explains that audit access is
  granted and bounded, and links to the surfaces that issue, list and revoke grants.

**Members and roles are deferred, and the reason is a missing port rather than a missing screen.**
Roles come from Zitadel (ADR-0049) and the Identity context has no member-listing port at all. Under
ADR-0070's route-before-pixel law, a members panel is not a UI question yet. It is **absent**, not
present-and-empty: an empty table would assert this org has no members, which is false.

**`Last active` is refused rather than deferred** (ADR-0077's accepted scope). It is presence
telemetry about people, nothing else in this product collects any, and a field that exists gets used.

## In scope

- Listing a tenant's data planes with their derived status and the instant each was last seen, plus
  provisioned-but-never-connected rows, as the Agent context already computes them.
- An admin destination that renders that report and states its age and its limits.
- An audit section that explains grant-bounded access and links into the existing grant and evidence
  surfaces.

## Out of scope

- **A members list and a roles table**, by ADR-0077's accepted scope. Not a field, not an empty table,
  not a disabled control.
- **An audit-log browser.** Decision 1: audit is reached through a grant. There is no route here that
  reads the trail, and none that could — this spec adds no audit RPC.
- **An `admin` role.** Decision 2. The role vocabulary stays `owner`, `member`, `reader`, pinned by a
  rego test.
- **A live runner console, or CI-runner-level state.** The data plane's connection is outbound-only;
  what the control plane holds is what the plane last reported.
- **`Last active`, or any per-person activity.**
- Provisioning, revoking or otherwise acting on a data plane from this surface. Revocation is an
  operator act with its own audited door (SPEC-0038); this surface reads.

## Contracts touched

- `contracts/proto/agent/v1` — **additive**: a new `FleetReader` service with `ListFleet`.

It is a new service rather than an RPC on `EnrolmentService` because the callers are different in
kind. `EnrolmentService` is an operator door authenticated by a PAT, with no tenant or actor field —
both are properties of the verified principal. `ListFleet` is read by an org administrator through the
BFF under a session, so it carries a `FleetContext` the way `usage/v1` does: tenant, actor and roles,
verified server-side. Putting a session-shaped read on a PAT-shaped door would have meant one service
with two authentication stories.

## Data owned

None. This spec adds no table and no column: the fleet report is a read of the Agent context's
existing registry, and the audit door is a link.

## Acceptance criteria (each becomes a test)

### The contract and the backend (T-0071)

- [x] **AC1** `ListFleet` returns one tenant's data planes with, for each: the data-plane ID, cloud,
      region, agent and Kubernetes versions, the derived status, the instant it was last seen, and its
      certificate expiry. Provisioned-but-never-connected rows carry the token ID and no plane.
- [x] **AC2** It is a `agent.dataplane.read` PDP decision — the action the Agent context's `Fleet`
      already asks, granted to `owner` and to nobody else. **This surface adds no action to the
      vocabulary and no role to the model.**
- [x] **AC3** **Additive:** `buf breaking` passes; `FleetReader` is a new service and no existing
      message changes shape.
- [x] **AC4** **No message in `agent/v1` carries an audit-trail read.** A descriptor check asserts
      there is no RPC named for reading the trail (`*AuditLog*`, `*AuditTrail*`, `ListAuditRecords`)
      and no field named `audit_records`, `trail` or `audit_log`, with a fixture carrying one to prove
      the check can fail — ADR-0077 decision 1 as a type property, so a trail browser cannot arrive
      behind this surface.
- [x] **AC5** **`admin` is not a role.** A rego test pins `role_actions` to exactly `owner`, `member`
      and `reader`, and a mutation adding an `admin` key fails it — decision 2 made mechanical in the
      one place the role vocabulary exists.
- [x] **AC6** The response carries **no per-person field**: no member, no user, no `last_active`. A
      test asserts the generated messages carry none.
- [x] **AC7** A refusal is coarse and uniform: unauthorized, unverified and unavailable are the same
      answer, and a tenant with no data planes is a successful empty answer rather than a refusal.
- [x] **AC8** The door is composed on the control plane beside the usage door, and the BFF reaches it
      by configuration — a plane without the door configured serves the admin area without the fleet
      report rather than failing (the usage surface's shape, SPEC-0046).

### The BFF (T-0072)

- [x] **AC9** The BFF shapes and forwards under the session: tenant, actor and roles come from the
      session and have no field on the browser's request.
- [x] **AC10** Every failure is one coarse refusal. An unconfigured fleet door is reported as
      unavailable, which is what it is — not as an empty fleet, which would say this tenant has no
      data planes.
- [x] **AC11** The response body carries no audit-record, member or activity vocabulary. A test
      asserts it, so decision 1's boundary holds at the layer a browser reads.

### The view (T-0073)

- [x] **AC12** The admin destination renders the fleet report: one row per data plane, each with its
      status as a glyph and a word, and **the instant it was last seen, shown as an age**.
- [x] **AC13** **The report says it is a report.** The page states that the control plane shows what
      each plane last reported, and that the data plane's connection is outbound-only — the same
      freshness honesty SPEC-0049 AC7's index reading takes. A stale plane is rendered as stale, never
      as healthy.
- [x] **AC14** **The page says what it cannot show**: the CI runners inside a customer's own cluster
      are not visible from the control plane, and there is no per-person activity here. The copy
      enumeration forbids "last active", "coming soon", "not yet available" and any phrasing implying
      a live console or a members list is pending.
- [x] **AC15** **The audit section is a door, not a browser.** It explains that audit access is issued
      as a scoped, time-boxed, revocable grant and links to the grant and evidence surfaces. A test
      asserts the page renders no audit record, no trail table, and no control that would read one.
- [x] **AC16** There is no members panel and no roles table, and **no disabled control anywhere** — the
      capability does not exist, and a disabled control would tell a reader they lack a permission
      (SPEC-0055 AC7's rule).
- [x] **AC17** An unavailable fleet report says so and describes nothing. A tenant with no data planes
      says that plainly, and the two readings are different sentences.
- [x] **AC18** No hex literal; every status word in `src/lib/status.ts` with a glyph and a word; the
      plane statuses are separable in grayscale and under deuteranopia; the two regression pins
      unmodified.
- [x] **AC19** The stub serves a healthy plane, a stale one and a never-connected row; captures
      regenerated per SPEC-0047 AC10 and reviewed in grayscale and deuteranopia.

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G1 tenant isolation | The fleet read is tenant-scoped by the verified caller; a data plane in another tenant is absent, not refused with a reason. |
| G2 authorization | `agent.dataplane.read`, already owner-only. No new action, no new role — AC5 pins the vocabulary. |
| G5 auditability | Audit access stays grant-bounded and every grant act is audited (SPEC-0033). This surface adds no second path to the trail, which is the whole of ADR-0077 decision 1. |
| G6 policy as code | The role vocabulary is asserted in `policies/`, in the repository ADR-0001 makes the Source of Truth. |

## Non-functional

- The fleet report is a read of a registry a tenant's data planes update on their own cadence. It
  carries no freshness guarantee beyond the instant it renders, which is why that instant is the
  panel's most prominent field.

## Open questions / assumptions

1. **Grant-scoped audit access may not survive an administrator's real job.** ADR-0077 says so in its
   own risk section: an admin investigating an incident at 2am does not want to issue themselves a
   grant. If the answer turns out to be a permanent grant, the model has been preserved in form and
   lost in substance, and that is an ADR, not a UI change.
2. **"Runners" in the prototype means CI runners; this spec reports data planes.** They are the
   closest true thing — a data plane is what runs work in a tenant's cluster — and AC14 states the
   difference rather than letting the panel imply it away.
3. **The fleet door is optional configuration.** A deployment without it renders an admin area with an
   unavailable report, which is honest and keeps the surface from being all-or-nothing.
