# ADR-0064: Production agent-CA keys live in platform-secrets custody; rotation is a staged trust bundle, not a fleet re-enrolment

- **Status:** Proposed (2026-08-15)
- **Deciders:** product/architecture (proposed by AGDD Phase 3.1 planning)
- **Supersedes / superseded by:** —
- **Related:** ADR-0060 (this closes its CA-custody follow-up), ADR-0057 (decision 5 — inference
  credentials only; not superseded by this ADR), ADR-0056 (AISVS L3, C9.4.1), ADR-0044 (cosign
  custody — a different signing secret at a different time), SPEC-0038, T-0030

## Context

Phase 3's enrolment CA signs in-process with a dev key — T-0030's exit record says so plainly:
*CA key custody is dev custody; production custody is deferred to the ADR-0057-scoped custody
follow-up.* The deferral was recorded, not forgotten: ADR-0060's consequences name the CA's key
custody as a platform-secrets question, and the ADR index carries it as an open follow-up.

Scoping matters here, because it is easy to borrow the wrong decision. ADR-0057 decision 5 decides
custody **for inference credentials only** — tenant secrets the platform stores and later presents
— and explicitly expects a general tenant-secret ADR once a second consumer exists. The agent CA
key is a different class: a **platform signing secret**, exercised continuously by the running
control plane, on behalf of no single tenant. And ADR-0044's cosign keys, though also platform
signing secrets, live in GitHub Actions custody because they sign at publish time in CI; the agent
CA signs at issuance and rotation time, in the running control plane, so that custody model does
not carry over either. This ADR decides the agent CA alone.

## Decision

**Production CA signing keys are held in a platform-secrets/KMS integration, control-plane side
only; the CA signs through a custody interface and never touches raw key material; rotation is a
staged trust bundle with a dual-validate window that requires no re-enrolment.**

1. **Custody is platform-side, control-plane only.** The CA is a control-plane role (ADR-0060
   decision on issuance), and its key material never leaves the control plane's custody boundary —
   never the data plane, never the customer's cluster, never a tenant-visible surface.
2. **Issuance and rotation sign via the custody interface.** The CA service calls a narrow
   sign-through-KMS interface; it holds a key reference, never the private key. The interface is
   the seam a future general platform-secrets ADR can absorb without reopening this decision's
   posture.
3. **The private key is never on disk or in the environment in a production posture — asserted by
   a fitness test,** not by review: the production composition root cannot construct a CA from a
   file path or an env var, the same way SPEC-0038 AC2 made token secrecy testable rather than
   advisory.
4. **Rotation is a staged trust bundle with a dual-validate window.** A new CA key is brought in
   beside the old; the agents' trust accepts old and new during an explicit overlap; new
   certificates chain to the new key; the old trust root is removed only after every issued
   certificate predates its removal. **Rotation requires no fleet re-enrolment** — ADR-0060's
   bootstrap and its loss-recovery semantics are unchanged, and a data plane that cannot present a
   valid certificate still recovers only by re-enrolment. This is ADR-0044's overlap shape,
   applied to agent identity instead of image signature.
5. **The dev CA stays test-only and unreachable from the production composition root** —
   fitness-asserted, so the in-process signer used by the suites cannot silently become the
   production signer.

**Rejected: an HSM inside the customer's cluster.** Strongest boundary on paper, but it exercises
control-plane authority from inside the managed data plane — the exact inversion ADR-0009 exists
to prevent — and it multiplies the portability burden ADR-0010 keeps out of the trust model
across three managed Kubernetes flavours.

**Rejected: encrypted on-disk keys.** Seemingly a small step up from dev custody, but the key is
decryptable on every start, lives wherever the disk lives (backups, snapshots, node images), has
no rotation story that does not become an operational event, and fails the fitness test decision
3 exists to enforce.

## Consequences

- Closes the recorded CA-custody carry: T-0030's recorded limit and ADR-0060's platform-secrets
  follow-up for the agent CA. ADR-0057 decision 5 is untouched — tenant-secret custody and its
  anticipated general ADR remain open on their own track.
- AISVS C9.4.1 (cryptographic identity for agent instances) gains a production-grade answer: the
  identity chain's root is no longer a dev secret.
- Runbook additions become the next spec's scope — **SPEC-0044, to be filed**: the CA rotation
  procedure (stage, overlap, remove), alongside the clock-skew symptom entry already owed since
  2026-08-15 (T-0030's recorded limit; a skewed cluster presents as a network fault).
- Choosing a concrete KMS provider is deliberately not decided here; the custody interface keeps
  that a deployment concern within the posture this ADR fixes, the same way ADR-0044 kept provider
  selection out of the custody model.
