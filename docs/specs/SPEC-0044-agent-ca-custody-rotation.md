# SPEC-0044: Agent-CA custody and rotation operations

- **Status:** Approved (2026-08-15)
- **Owner:** platform
- **Context(s):** Control plane (CA signs through custody) · Agent (validates staged trust bundles) — ADR-0022
- **ADRs:** 0064 (decides custody and rotation), 0060 (enrolment and loss recovery — unchanged), 0056 (AISVS L3, C9.4.1), 0044 (cosign custody — the overlap shape, not the model), 0057 (decision 5 — inference credentials only, untouched)
- **Task(s):** — (Phase 3.1, epic EP-21; task to be filed)

## Problem / context

PR-20's enrolment CA signs in-process with a dev key — T-0030's exit record says so plainly, and
ADR-0060's consequences carried CA key custody as an open platform-secrets question. The identity
chain is only as strong as its root: today the root is a development secret exercising continuously
in whatever process holds it.

ADR-0064 (Accepted) decides the posture: production signing keys live in a platform-secrets/KMS
integration, control-plane side only; the CA signs through a narrow custody interface and holds a key
reference, never key material; rotation is a staged trust bundle with a dual-validate window that
requires no fleet re-enrolment; and the dev CA stays test-only, unreachable from the production
composition root. This spec makes those fitness-asserted and operationally real for Phase 3.1 epic
**EP-21** (PR-20). It also owns the runbook entry ADR-0064's consequences name: the rotation
procedure, alongside the clock-skew symptom entry owed since T-0030.

## In scope

- The custody interface and the production composition-root wiring behind it.
- Fitness assertions: no raw key on disk or in the environment; dev CA unreachable in production.
- CA rotation as a staged trust bundle with a dual-validate window, over the existing channel.
- The operator runbook: rotation procedure and the clock-skew symptom cross-reference.

## Out of scope

- Choosing a concrete KMS provider — a deployment concern within the posture ADR-0064 fixes (the
  same way ADR-0044 kept provider selection out of its custody model).
- General platform-wide tenant-secret custody — ADR-0057 decision 5 and its anticipated general ADR
  remain open on their own track; this spec decides the agent CA alone.
- Any change to ADR-0060 enrolment or loss-recovery semantics (Phase 3.1 non-goal: no revisiting
  ADR-0060/0061 or ADR-0057's scope).
- An HSM inside the customer's cluster, or encrypted on-disk keys (both rejected by ADR-0064).
- Inbound paths of any kind (Phase 3.1 non-goal).

## Contracts touched

None by default — rotation rides the agent channel's existing desired-state/reconcile path
(SPEC-0039). If the staged bundle needs a field the channel does not carry, that is an additive
`agent/v1` change under its own governance PR first.

## Data owned

The control plane owns the CA role, the key references and the staged trust-bundle state. The
customer's cluster owns nothing but the certificates it was issued and the trust it is told, as
desired state, to hold.

## Acceptance criteria (each becomes a test)

- [ ] AC1: In a production posture the CA issues and rotates agent certificates through
  custody-held keys: the CA service calls the sign-through-KMS custody interface and holds a key
  reference, never private key material. The private key never exists on disk or in the environment —
  asserted by a fitness test that the production composition root cannot construct a CA from a file
  path or an env var, the same way SPEC-0038 AC2 made token secrecy testable rather than advisory.
- [ ] AC2: CA rotation is a staged trust bundle with a dual-validate window. A new CA key is brought
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
  presents as a network fault; T-0030's recorded limit).

## Test plan

- KMS-fake integration tests: the custody interface exercised against a fake provider in CI, never
  the production one; the CA's issuance path proven to hold references, not material (AC1).
- Dual-validate window rotation tests: stage → overlap (old and new both validate) → new issuance →
  old-root removal ordering, including mid-window restart and a certificate that outlives a premature
  removal attempt (AC2).
- Fitness tests for both posture assertions: production root cannot build a CA from disk/env (AC1)
  and cannot reach the dev CA (AC3).
- Runbook: existence and cross-links checked by the docs gate once authored under the implementing
  task; the rotation steps and the clock-skew entry must both resolve (AC4).

## Governance mapping (G1–G9)

| Objective | How this spec satisfies it |
|---|---|
| G3 Supply-chain security | the identity chain's root is a custody-held platform secret, no longer a dev secret (AC1) — AISVS C9.4.1 answered |
| G5 Auditability | rotation is a staged, ordered procedure with a named removal precondition, not an ad-hoc event (AC2, AC4) |
| G9 Least-privilege footprint | key material never leaves the control plane's custody boundary; the customer's cluster is never a signing authority (AC1) |

## Non-functional

- Rotation cadence and overlap length are per-environment configuration, not compiled in.
- The custody interface stays narrow enough that a future general platform-secrets ADR can absorb it
  without reopening this posture (ADR-0064 decision 2).

## Open questions / assumptions

- Assumed: the trust-bundle staging rides the existing reconcile path without a new agent/v1 field;
  if not, the additive contract change happens first under its own PR (see Contracts touched).
- Assumed: loss of custody access is an availability event, not an integrity event — certificates
  already issued remain valid until expiry, which bounds the blast radius the runbook must describe.
