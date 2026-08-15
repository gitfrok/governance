# ADR-0065: One tenant may run many data planes — the operator ships as a signed image and trust distributes over the channel that already exists

- **Status:** Accepted (2026-08-15)
- **Deciders:** product/architecture (proposed by AGDD Phase 3.1 planning)
- **Supersedes / superseded by:** —
- **Related:** ADR-0013 (Helm + Operator), ADR-0011 (outbound-only), ADR-0044 (signing custody —
  extended, not replaced), ADR-0035 (first-party images), ADR-0060, ADR-0061 (metering authority —
  unchanged), SPEC-0038, SPEC-0039, T-0031, T-0032, `deploy/conformance/byo-dataplane.md`

## Context

Three facts sit beside each other and none of them settles multi-plane tenants.

The Operator seam exists — ADR-0013 fixes Helm plus Operator as the packaging — but the operator
binary is not shipped as an image: the conformance matrix records that the chart mounts its release
trust root while the image is a required install value, not yet shipped here. The versioned
public-key trust bundle (ADR-0044) was designed around a single cluster consuming one release
stream. And every real-cluster column in the conformance matrix reads "not run" — the phase's fifth
exit criterion is carried to T-0003's cluster lane, not met.

Meanwhile SPEC-0038's open questions already said it: *one data plane per tenant per cluster;
multiple data planes for one tenant is not refused by anything here, but nothing depends on it
either.* A tenant that wants a second cluster — another region within the declared cloud, a
dedicated plane for burst CI — has no answer that is written down.

## Decision

**The operator becomes a shipped, signed first-party image; the versioned trust bundle distributes
and rotates across N data planes over the existing outbound-only channel; the registry keys planes
by `data_plane_id`; and every plane of a tenant is the same product.**

1. **The operator ships as a vendor-signed container image, digest-pinned in the signed release
   manifest.** This extends ADR-0044 and ADR-0035 with one more first-party image under the
   existing cosign custody, release manifest and verification tests — **no new signing model, no
   new trust root**. The install stops depending on a customer-supplied operator image.
2. **The versioned trust bundle distributes and rotates across N data planes over the
   outbound-only agent channel.** The bundle travels as desired state on the stream the agent
   already holds (SPEC-0039's reconcile path); rotation is the staged dual-validate overlap
   ADR-0044 already defines, applied per fleet rather than per cluster. No new endpoint, no
   inbound path — the matrix's no-inbound tripwires stay at zero.
3. **The registry supports multiple concurrent data planes per tenant, keyed by `data_plane_id`.**
   The certificate already names tenant and data plane (ADR-0060 decision 3), so identity — not
   uniqueness — is what disambiguates planes; liveness, staleness and rollout status remain
   per-plane states, exactly as SPEC-0038 AC8 and SPEC-0039 AC7 render them today.
4. **Posture parity is reaffirmed as a rule, not a preference:** any capability difference between
   the planes of one tenant is a **defect, not a tier**. A plane may differ in cloud, region and
   load; it may not differ in what the product does, enforces, or evidences.
5. **Metering aggregates per tenant across planes, and the control plane remains the sole metering
   authority** (ADR-0061, unchanged). Envelopes are computed on the tenant's aggregate; no plane
   can under-report itself into a smaller envelope, and a silent plane's gap renders as a gap, not
   as zero (ADR-0061 decisions 2–3, now per-plane inputs into one tenant number).

**Rejected: customers distributing operator config by hand.** Keeps us from shipping anything new,
and violates the outbound-only vendor operation ADR-0011 fixes — hand-carried config is unsigned,
unverifiable, and un-upgradable by reconcile, which is the invariant-9 shape applied to the install
itself.

**Rejected: a hard single-plane-per-tenant limit.** Enforceable in one line, and with no
governance basis: PR-22 constrains *where* a tenant's work runs, not *how many* planes run it, and
SPEC-0038 declined to refuse it. A product constraint invented to avoid testing concurrency is a
limit we would later remove.

## Consequences

- Real-cluster conformance proof becomes executable scope: the shipped operator image and
  multi-plane trust distribution are what the cluster lane runs against — **SPEC-0045, to be
  filed**, depending on T-0003's cluster lane, where the phase's carried fifth exit criterion
  already lives.
- No inbound paths are introduced; every new behaviour rides the channel and the release machinery
  that already exist.
- The evidence pack's residency section gains multiple observed placements per tenant to cite —
  the per-plane placement records it already renders, now more than one of them.
- The registry, rollout and metering surfaces must render per-plane truth under one tenant without
  implying per-plane product differences (decision 4's defect rule), which is the honest burden
  this decision accepts.
