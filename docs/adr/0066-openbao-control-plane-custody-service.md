# ADR-0066: OpenBao is the control-plane custody service; the agent CA is its first consumer

- **Status:** Proposed (2026-08-15)
- **Deciders:** platform (proposed by AGDD Phase 3.1 planning)
- **Supersedes / superseded by:** —
- **Related:** ADR-0064 (the custody posture this names a provider inside), ADR-0060 (the CA role
  this serves), ADR-0057 (decision 5 — the second-consumer supersession this anticipates but does not
  start), ADR-0044 (the cloud-KMS portability precedent), ADR-0034/0035 (image pin form for a
  third-party control-plane dependency), SPEC-0044, T-0040

## Context

ADR-0064 accepted the custody posture for the agent CA — sign through a narrow custody interface,
hold a key reference and never material, keep the private key off disk and out of the environment,
rotate by staged trust bundle — and its consequences then stopped deliberately: *"Choosing a concrete
KMS provider is deliberately not decided here; the custody interface keeps that a deployment concern
within the posture this ADR fixes."* SPEC-0044 repeats the line in its out-of-scope list.

That deferral was right at the posture layer, but the provider in question is not a library choice,
and inheriting it silently into deploy config would be wrong. Adding a stateful, sealed, HA secrets
service to the control plane fixes facts this repo owns: a **topology** (new nodes inside the
control-plane blast domain), an **unseal procedure** (a new operational authority — whoever can
reconstitute the barrier), an **availability coupling** (issuance and rotation now wait on a quorum),
and **lifecycle obligations** (version pinning, upgrades, plugin packaging changes). Those are
architecture facts, not deployment details. A sweep of `governance/` and `deploy/` on 2026-08-15
confirms the gap is real: no secrets platform is named anywhere in either tree.

Research (2026-08-15): **OpenBao** — the Vault fork under Linux Foundation/OpenSSF stewardship that
exists because of HashiCorp's BUSL relicence — is MPL-2.0 and actively released (2.6.x as of
2026-07). Its **transit engine** does exactly what ADR-0064 decision 2 drew the seam for:
non-exportable-by-default ECDSA P-256 sign/verify (`POST /transit/sign/:name`), with the key
generated inside and never leaving the encrypted barrier, never returned by any API. The seam itself
already exists — the dev CA sits behind `CertificateIssuer`
(`backend/modules/agent/internal/adapters/pki/ca.go`), so a custody-backed issuer is a
composition-root swap, not an issuance-logic change; that is the shape SPEC-0044 AC1 tests.

## Decision

**The control-plane custody service is OpenBao; the agent CA is its first consumer, signing through a
transit-held, non-exportable ECDSA P-256 key it references and never holds.**

1. **Provider: OpenBao, transit engine.** The CA's production signing key is an ECDSA P-256 key
   generated inside OpenBao's transit engine, non-exportable by default; the CA service calls
   `POST /transit/sign/:name` and holds a key reference — the sign-through-KMS interface ADR-0064
   decision 2 fixed, nothing wider. **PKI-engine delegation is rejected**: handing issuance to
   OpenBao's PKI engine would move issuance authority, serial ownership and revocation into the
   secrets platform — widening the governance surface and reopening ADR-0060/SPEC-0044 territory,
   when revocation is a control-plane act (ADR-0060 decision 5). Rotation orchestration — the staged
   trust bundle, the dual-validate window, the removal precondition — stays in the CA service per
   ADR-0064 decision 4; transit merely signs under old-then-new keys during the overlap. No
   `agent/v1` contract change.
2. **Reconciled with ADR-0064's rejection of "encrypted on-disk keys" — recorded, not waved
   through.** ADR-0064 rejected encrypted on-disk keys because the key is decryptable on every start
   and lives wherever the disk lives. A transit key is different in kind, not degree: software key
   material inside OpenBao's encrypted barrier, in a hardened dedicated service whose only interface
   refuses export — the private key is never returned, by construction rather than by policy. This
   ADR records that reconciliation explicitly because it is the one place this decision touches an
   ADR-0064 rejection. Hardware backing is an **upgrade path, not current scope**: OpenBao's External
   Keys RFC (transit/PKI keys backed by KMS/HSM) is Accepted upstream but not landed, and the KMIP
   seal exists for HSM-adjacent unseal. A future compliance bar demanding hardware-backed signing is
   a new decision on this same seam.
3. **Scope: the custody service and its first consumer — not the general platform-secrets
   facility.** This ADR decides that the control plane *has* a custody service (OpenBao) and wires
   its first consumer (the agent CA). It does not decide the general platform-secrets facility:
   ADR-0057 decision 5's tenant-secret track keeps its own clock. It does record OpenBao as the
   presumptive home when the second consumer arrives (e.g. the inference-credential KEK ADR-0057
   decision 5 implies), at which point the anticipated general platform-secrets ADR is written and
   supersedes ADR-0057 decision 5, exactly as that text expects. Until then the custody interface
   stays as narrow as ADR-0064 decision 2 drew it.
4. **Unseal: Shamir recovery keys; cloud-KMS auto-unseal rejected.** Auto-unseal via
   awskms/gcpckms/azurekeyvault recreates the per-cloud coupling ADR-0044 rejected for cosign keys —
   at the seal layer, where it is harder to see — and cuts against ADR-0010's portability layer.
   Shamir recovery keys (quorum, operator custody, out-of-band distribution) keep the control plane
   provider-portable, at the cost of a quorum unseal procedure on cold restart — an accepted
   operational cost, runbooked under decision 6. One boundary stated plainly: recovery-key custody is
   operator-held and out-of-band; it is distinct from the CA private-key posture ADR-0064 fixes and
   does not violate the env/disk fitness rule, which governs the CA service's composition, not
   human-held recovery shares. Revisit only if the External Keys/HSM story or an operational pain
   bar demands it — a new decision then.
5. **Service authentication: Kubernetes auth.** The control-plane CA service authenticates to OpenBao
   via Kubernetes auth — its service-account token exchanged for a short-lived OpenBao token; no
   static credential is persisted anywhere, which is the only answer consistent with ADR-0064
   decision 3's posture. AppRole rejected: delivering the `secret_id` to the workload without
   violating the env/disk fitness rule reintroduces exactly the problem custody exists to solve. TLS
   certificate auth is the documented fallback if the control plane ever runs off-cluster.
6. **Availability contract.** OpenBao deploys control-plane-side only, HA via integrated storage
   (Raft), minimum three nodes; writes — transit sign included — serialize through the active node.
   Custody or seal outage is an **availability event, not an integrity event**, consistent with
   SPEC-0044's recorded assumption: certificates already issued remain valid until expiry, which
   bounds the blast radius. The runbook must cover seal-outage and quorum-unseal procedures — this
   widens SPEC-0044 AC4's runbook scope at implementation time. OpenBao is never deployed in a data
   plane or customer cluster, reinforcing ADR-0064's rejection of customer-cluster key custody.
7. **Lifecycle obligations.** OpenBao maintains only its latest major, so pin-and-upgrade cadence is
   an operational obligation rather than a choice: 2.7 moves several built-in seals to plugins, a
   packaging change to track before it lands. The image enters the tree as any other third-party
   control-plane dependency — pinned per ADR-0034 (fully-qualified, resolvable, patch-level; digest
   only where upstream publishes no patch tag, ADR-0035 decision 5's refinement).

**Rejected: HashiCorp Vault.** The incumbent, but BUSL-licensed — inconsistent with the stack's
open-source posture; OpenBao is the MPL-2.0 fork that exists because of exactly that relicence.

**Rejected: per-cloud KMS (AWS/GCP/Azure) as the signing provider.** The portability coupling
ADR-0044 rejected for cosign keys at publish time — worse here, exercised continuously in the running
control plane across three provider APIs.

**Rejected: cloud-KMS auto-unseal.** The same coupling at the seal layer (decision 4).

**Rejected: PKI-engine delegation.** Moves issuance authority, serial ownership and revocation into
the secrets platform (decision 1).

**Rejected: an HSM in the customer cluster; a dev-style in-process CA in production.** Both already
rejected by ADR-0064; restated here only so this ADR's alternatives list is complete.

## Consequences

- The provider question ADR-0064 left open is closed **inside** the posture it fixed: nothing in
  ADR-0064 or SPEC-0044 changes, and the spec's out-of-scope line remains true for the spec — the
  choice is now made at the architecture layer, where the topology, unseal and availability facts
  live. SPEC-0044's ACs test the interface and the posture, not the provider.
- New operational obligations, all runbook-shaped: quorum unseal after cold restart, the
  pin-and-upgrade cadence tracking OpenBao's latest-major-only maintenance (2.7's seal-to-plugin move
  lands as packaging work), and seal-outage/quorum-unseal procedures joining SPEC-0044 AC4's runbook
  scope at implementation time.
- T-0040's implementation notes should reference this ADR — a wiring follow-up at acceptance time;
  the task doc is deliberately not edited now.
- The general platform-secrets clock is **recorded but not started**: OpenBao is the presumptive home
  for the second consumer, and when it arrives the general platform-secrets ADR supersedes ADR-0057
  decision 5 as its own text expects. Until then this ADR authorizes no second consumer.
- A new control-plane dependency enters the tree: three OpenBao nodes (Raft) inside the
  control-plane blast domain, image pinned per ADR-0034.
