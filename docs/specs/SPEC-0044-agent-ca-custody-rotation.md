# SPEC-0044: Agent-CA custody and rotation operations

- **Status:** Approved (2026-08-15; **amended 2026-08-15 after the Phase 3.1 plan review** — ADR-0066's custody service gains an owner here: AC5 deploys it, AC4 covers unseal and seal-outage; **amended again 2026-08-15** — the staged CA trust bundle gains its additive `agent/v1` field: `DesiredState.ca_trust_bundle` (`CATrustBundle`: bundle revision, dual-validate trusted roots, issuance root), named apart from SPEC-0045's release trust bundle)
- **Owner:** platform
- **Context(s):** Control plane (CA signs through custody, OpenBao deployed beside it) · Agent (validates staged CA trust bundles) — ADR-0022
- **ADRs:** 0064 (decides custody and rotation), 0066 (decides the provider, its deployment, unseal and availability contract), 0034/0035 (image pin form for the custody image), 0060 (enrolment and loss recovery — unchanged), 0056 (AISVS L3, C9.4.1), 0044 (cosign custody — the overlap shape, not the model), 0057 (decision 5 — inference credentials only, untouched)
- **Task(s):** T-0040 (AC1–AC5)

## Problem / context

PR-20's enrolment CA signs in-process with a dev key — T-0030's exit record says so plainly, and
ADR-0060's consequences carried CA key custody as an open platform-secrets question. The identity
chain is only as strong as its root: today the root is a development secret exercising continuously
in whatever process holds it.

ADR-0064 (Accepted) decides the posture: production signing keys live in a platform-secrets/KMS
integration, control-plane side only; the CA signs through a narrow custody interface and holds a key
reference, never key material; rotation is a staged CA trust bundle with a dual-validate window that
requires no fleet re-enrolment; and the dev CA stays test-only, unreachable from the production
composition root. This spec makes those fitness-asserted and operationally real for Phase 3.1 epic
**EP-21** (PR-20). It also owns the runbook entry ADR-0064's consequences name: the rotation
procedure, alongside the clock-skew symptom entry owed since T-0030.

## In scope

- The custody interface and the production composition-root wiring behind it.
- Fitness assertions: no raw key on disk or in the environment; dev CA unreachable in production.
- CA rotation as a staged **CA trust bundle** with a dual-validate window, over the existing channel.
  (The *release* trust bundle of ADR-0044/ADR-0065 is a different artifact and belongs to SPEC-0045.)
- **Deploying the custody service itself** — OpenBao per ADR-0066: control-plane-side, three-node
  Raft, Kubernetes auth, Shamir unseal, image pinned per ADR-0034.
- The operator runbook: rotation procedure, quorum unseal, seal outage, and the clock-skew symptom
  cross-reference.

## Out of scope

- Choosing a concrete KMS provider — **settled by ADR-0066 (OpenBao, transit engine)**, so it is no
  longer open. What stays out of scope is *widening* the custody interface beyond ADR-0064
  decision 2's narrow sign-through seam, and delegating issuance to OpenBao's PKI engine (rejected by
  ADR-0066 decision 1 — revocation and serial ownership stay control-plane acts).
- General platform-wide tenant-secret custody — ADR-0057 decision 5 and its anticipated general ADR
  remain open on their own track; this spec decides the agent CA alone.
- Any change to ADR-0060 enrolment or loss-recovery semantics (Phase 3.1 non-goal: no revisiting
  ADR-0060/0061 or ADR-0057's scope).
- An HSM inside the customer's cluster, or encrypted on-disk keys (both rejected by ADR-0064).
- Inbound paths of any kind (Phase 3.1 non-goal).

## Contracts touched

`contracts/proto/agent/v1` — **additive** (ADR-0027): the staged CA bundle needs a field the
channel did not carry, so it rides the reconcile path (SPEC-0039) as desired state —
`DesiredState.ca_trust_bundle` (field 3), a `CATrustBundle` carrying a monotonic bundle
revision, the trusted roots (`CATrustRoot`, `repeated` for the dual-validate overlap) and the
`issuance_root_id` new certificates chain to. It is NOT the field SPEC-0045's release trust
bundle would need, and is named apart from it (SPEC-0045's two-bundles note).

## Data owned

The control plane owns the CA role, the key references and the staged CA-trust-bundle state. The
customer's cluster owns nothing but the certificates it was issued and the trust it is told, as
desired state, to hold.

## Acceptance criteria (each becomes a test)

- [ ] AC1: In a production posture the CA issues and rotates agent certificates through
  custody-held keys: the CA service calls the sign-through-KMS custody interface and holds a key
  reference, never private key material. The private key never exists on disk or in the environment —
  asserted by a fitness test that the production composition root cannot construct a CA from a file
  path or an env var, the same way SPEC-0038 AC2 made token secrecy testable rather than advisory.
- [ ] AC2: CA rotation is a staged CA trust bundle with a dual-validate window. A new CA key is brought
  in beside the old; agents' trust accepts old and new during an explicit overlap; new certificates
  chain to the new key; the old trust root is removed only after every issued certificate predates
  its removal. **No fleet re-enrolment is required** — ADR-0060's bootstrap and loss-recovery
  semantics are unchanged, and a data plane that cannot present a valid certificate still recovers
  only by re-enrolment.
- [ ] AC3: The dev CA is test-only and unreachable from the production composition root —
  fitness-asserted, so the in-process signer used by the suites cannot silently become the
  production signer.
- [ ] AC4: The runbook covers the rotation procedure — stage, overlap, remove, with the removal
  precondition named — and cross-references the clock-skew symptom entry (a skewed customer cluster
  presents as a network fault; T-0030's recorded limit). It also covers what ADR-0066 added to this
  spec's runbook scope: **quorum unseal after a cold restart** (who holds the Shamir shares, how they
  are distributed out of band, and the order of operations), **seal or custody outage** (issuance and
  rotation stop; certificates already issued remain valid until expiry, which is the blast radius),
  and what an operator does about an enrolment whose signature failed mid-flight (SPEC-0042 AC6's
  chosen behaviour, named here so the two documents cannot disagree).
- [ ] AC5: The custody service is deployed, pinned and provable — not assumed. OpenBao runs
  control-plane-side only, never in a data plane or customer cluster; HA via integrated storage
  (Raft) with a minimum of three nodes; the control-plane CA service authenticates by Kubernetes auth
  (its service-account token exchanged for a short-lived token) with **no static credential persisted
  anywhere**, which is the only shape consistent with AC1's env/disk rule; the image is pinned per
  ADR-0034 (fully-qualified, resolvable, patch-level; digest where no patch tag is published). A
  deployment check asserts the node count, the absence of a static credential in chart values or
  environment, and that no data-plane chart references the custody service at all. Recovery-key
  custody is operator-held and out of band (ADR-0066 decision 4) — it is human-held, distinct from
  the CA private-key posture AC1 fixes, and does not weaken it.

## Test plan

- KMS-fake integration tests: the custody interface exercised against a fake provider in CI, never
  the production one; the CA's issuance path proven to hold references, not material (AC1).
- Dual-validate window rotation tests: stage → overlap (old and new both validate) → new issuance →
  old-root removal ordering, including mid-window restart and a certificate that outlives a premature
  removal attempt (AC2).
- Fitness tests for both posture assertions: production root cannot build a CA from disk/env (AC1)
  and cannot reach the dev CA (AC3).
- Runbook: existence and cross-links checked by the docs gate once authored under the implementing
  task; the rotation steps, the unseal and seal-outage procedures and the clock-skew entry must all
  resolve (AC4).
- Deployment assertions for AC5: node count and control-plane-side placement from the rendered
  manifests, image pin conformance (the same check ADR-0034's other pins pass), no static credential
  in values or environment, and a data-plane chart render proving the custody service is absent from
  it.
- Custody-unavailable test: with the signer refusing, issuance fails as an availability event —
  already-issued certificates still validate, and enrolment behaves as SPEC-0042 AC6 specifies
  (shared test surface with that spec; neither may prove it alone).

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G3 Supply-chain security | the identity chain's root is a custody-held platform secret, no longer a dev secret (AC1) — AISVS C9.4.1 answered — and the custody service itself enters the tree pinned like every other first-party or third-party image (AC5) |
| G5 Auditability | rotation is a staged, ordered procedure with a named removal precondition, not an ad-hoc event (AC2, AC4) |
| G9 Least-privilege footprint | key material never leaves the control plane's custody boundary; the customer's cluster is never a signing authority (AC1) |

## Non-functional

- Rotation cadence and overlap length are per-environment configuration, not compiled in.
- The custody interface stays narrow enough that a future general platform-secrets ADR can absorb it
  without reopening this posture (ADR-0064 decision 2).

## Open questions / assumptions

- ~~Assumed: the CA-trust-bundle staging rides the existing reconcile path without a new agent/v1
  field; if not, the additive contract change happens first under its own PR (see Contracts
  touched).~~ **Resolved 2026-08-15:** the staging needs what the channel did not carry, so the
  additive `agent/v1` field landed first under its own governance commit — see Contracts touched.
- Assumed: loss of custody access is an availability event, not an integrity event — certificates
  already issued remain valid until expiry, which bounds the blast radius the runbook must describe.
  **The one place that assumption does not hold on its own is first issuance**, where a durable token
  spend meets a remote signer: SPEC-0042 AC6 owns that behaviour and this spec's AC4 documents it.
- Open: OpenBao maintains only its latest major, so the pin-and-upgrade cadence is an operational
  obligation with no end date (2.7 moves several built-in seals to plugins). This spec pins and
  deploys a version; keeping it current is an ADR-0066 follow-up, not a Phase 3.1 acceptance
  criterion.
