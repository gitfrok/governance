# ADR-0057: AI-assisted review of merge requests, commits and pipelines via a tenant-configured OpenAI-compatible endpoint

- **Status:** Accepted
- **Date:** 2026-08-14
- **Governs:** G1 isolation, G2 least privilege, G3 supply chain, G4 change governance,
  G5 auditability, G6 compliance
- **Relates to:** **ADR-0056** (AISVS — this ADR is the trigger that fired it) · ADR-0006 (PDP) ·
  ADR-0007 (audit) · ADR-0015 (unified surface) · ADR-0029 §4 (an unwitnessed approval never gates) ·
  ADR-0009/0010/0011 (BYO, portability, outbound-only agent) · ADR-0025/0026 (modular monolith,
  extraction) · SPEC-0019 (merge requests) · SPEC-0024/0025 (findings model and contract) ·
  SPEC-0029/0030 (policy, decision provenance) · SPEC-0031/0032 (evidence)

## Context

The platform will offer **AI-assisted review** of merge requests, commits, review threads and
pipelines, backed by an **OpenAI-compatible** inference endpoint.

This is the event ADR-0056 anticipated. That ADR's applicability table was written "as it stands
today", when nothing in the product called a model; **the trigger has now fired**, and most of AISVS
C1–C12 becomes live for this capability rather than N/A.

Four things were decided when this capability was requested, and they are recorded as the decision
below: the subject is the **product** (tenants' repositories, not only our own SDLC); the endpoint is
**tenant-configured**; an AI review **may block a merge through a deterministic policy rule**; and the
binding verification level is **AISVS L3**.

That combination is the most demanding one available, and three of its consequences are conflicts
with things this tree has already decided or already lacks. They are named in *Open conflicts* below,
because an ADR that records the ambition without the bill is not a decision record.

**"OpenAI-compatible" is a protocol choice, not a provider choice** — the same shape as scanner
selection in PRD §12.4. No provider is named or committed by this ADR; the wire format is what makes
the tenant's own choice possible.

## Decision

### 1. Subject — a product capability

AI-assisted review applies to **tenant repositories**: merge requests, commits, review threads and
pipeline results. It is not merely internal SDLC tooling. Consequently the product becomes an
**AI-enabled system** and AISVS applies to it, not only to the agentic SDLC of ADR-0028.

This capability has **no PR-#** and is not in Phase 2's scope (PR-13…PR-19). A **PRD revision** adding
it — next free `PR-24` — plus a roadmap placement and a fair-use dimension for inference volume are
required follow-ups. This ADR does not perform them.

### 2. Trust boundary — the tenant configures the endpoint

Each tenant supplies the **base URL and credential** of an OpenAI-compatible endpoint they control or
have contracted for. The platform names no provider, ships no model weights, and makes no egress
decision on a tenant's behalf: **the egress decision, the data-processing agreement and the residency
answer are the tenant's** (PR-22).

Consequences that are part of this decision rather than optional hardening:

- **Outbound calls to a tenant-supplied URL are an SSRF surface.** Requests to a tenant endpoint must
  leave through an egress control that refuses link-local, loopback, cluster-internal and metadata
  addresses, and that resolves and pins the destination rather than trusting a name at call time.
- **No AI-assisted review runs for a tenant that has not configured an endpoint.** There is no
  platform default and no silent fallback.
- **BYO (ADR-0009/0011) is unaffected in principle** — a BYO customer points at an endpoint in their
  own environment — but the data plane now makes an outbound call it did not before, which the
  outbound-only posture permits and the operator must be told about.

### 3. Gating — the model never decides, a reviewed policy may

An AI review produces **findings**, not decisions. A finding may feed a **deterministic PDP rule**
(SPEC-0029/0030) that blocks a merge; the model itself never authorizes, approves, or gates
(AISVS C9.5.3).

Unconditional invariants, whichever way the open conflicts are resolved:

- **An AI review never satisfies an approval requirement.** Only first-party human approvals gate a
  merge — the same rule ADR-0029 §4 applies to imported approvals, for the same reason: an
  unwitnessed assertion is not evidence of human judgement.
- **An AI review adds to the deterministic gate and never replaces it** (AISVS C9.2.6). Removing a
  policy check because a model reviewed the change is forbidden.
- **Everything the model reads is attacker-controlled.** Diffs, commit messages, review text, and
  imported history (T-0018) are untrusted input, so indirect prompt injection is the primary threat
  (C10.4.2, C9.3.5, C9.2.7). The reviewer is **tool-less** — text in, schema-validated text out — so
  a successful injection cannot invoke a tool, move a ref, or reach another tenant.
- **Model output is schema-validated before it is stored or rendered** (C9.3.2), and any field that
  reaches a policy rule is treated as untrusted input, never as an assertion of severity.
- **Provenance on every review**: the endpoint identity, model identity and version, prompt version,
  and input digest are recorded on the output and audited (ADR-0007), in the shape SPEC-0030 already
  requires of policy decisions.
- **The tenant's credential never enters a model context, a prompt, a log, or an event payload**
  (C9.5.4).

### 4. Level — AISVS L3, and ADR-0056 is answered

This capability binds to **AISVS Level 3** (high assurance). ADR-0056's open axes are answered by
this ADR: subject = both (product **and** the agentic SDLC), level = L3, and the standard is enforced
as **CI fitness functions** in the T-0009 style rather than a periodic manual assessment, because a
standard nothing checks is the failure ADR-0037 was written about.

L3 obligations that do not exist today and become work: cryptographic identity for each reviewing
agent instance (C9.4.1), approvals cryptographically bound to action parameters with a single-use
nonce (C9.2.8), credential material isolated from the runtime (C9.2.9), an out-of-band kill switch
(C9.6.3), integrity-protected agent state (C9.4.4), and re-evaluation of authorization on every
privileged action in a long-running session (C9.5.6).

### 5. Credential custody — decided here, scoped to inference credentials

Nothing in this tree stores a credential the platform must later *present*: Identity hashes PATs one
way. This ADR therefore decides custody, **scoped to inference credentials only**:

- A tenant's endpoint credential is stored **envelope-encrypted**, under a data key that is itself
  wrapped by a key the platform controls, and it is decryptable only on the call path that presents
  it.
- It is **write-only from the tenant's side**: it can be replaced and revoked, never read back, and no
  API, UI, log, event, error, or evidence record returns it.
- It is **rotatable without downtime**, and a rotation is an audited action naming the actor.
- It is **never present in a model context, a prompt, a tool parameter, or a trace** (C9.5.4), and it
  is redacted at the boundary rather than at the sink.
- An operator with database access learns the ciphertext, not the credential. Key custody is stated in
  the implementing spec, not left to deployment.

This is deliberately **narrower than a platform secret-management facility.** Webhooks, registry
credentials and mirror tokens will each need one; when the second consumer arrives, the general design
is its own ADR and this decision is expected to be **superseded** by it rather than extended sideways.
Recorded so the retrofit is a known cost, not a surprise.

## Conflicts — resolved 2026-08-14

The three conflicts this ADR was blocked on are settled. They are kept here with their resolutions,
because each is a constraint on the implementing specs.

1. **L3's sender-constrained credentials versus a bearer-token endpoint — residual accepted.** AISVS
   asks for credentials that cannot be replayed by whoever holds them (C10.3.5's mTLS/DPoP shape;
   C9.2.9's isolation). An OpenAI-compatible API is, in practice, a bearer token, and mandating mTLS
   would exclude most endpoints a tenant would actually configure. **L3 is therefore claimed with one
   named exception: sender-constrained credentials are NOT MET for the inference call, because the
   tenant's endpoint is bearer-only.** In their place the platform binds itself to what it can hold:
   envelope-encrypted custody and rotation (decision 5), egress pinning (decision 2), no exposure in
   any context, log or event, and a per-call audit record. **Any AISVS verification report this
   platform publishes must carry that exception verbatim**; a report claiming unqualified L3 would be
   false.
2. **A blocking gate fed by non-deterministic output versus SPEC-0024's identity rule — separated.**
   AI review output is **its own resource**, not a sixth scanner class. SPEC-0024 AC1's five classes
   and AC2's identity rule are **untouched**, and both specs stay Approved as written. The AI review
   resource carries its own identity, lifecycle and provenance, defined in its own spec, and sits
   explicitly **outside** the cross-scan identity guarantee — a re-review may legitimately differ, and
   the resource states that rather than pretending otherwise.
   A policy rule may read this resource to gate a merge (decision 3). It may **not** appear in an
   evidence pack's scan-gate control section until a later spec states how a non-deterministic
   producer's output can be cited as control evidence; until then SPEC-0031/0032 are unaffected.
3. **Tenant-secret custody — decided in decision 5 above**, scoped to inference credentials, with the
   generalisation recorded as a known future ADR rather than deferred silently.

## Consequences

**Positive:** review quality improves where a human reviewer is scarce, and it lands on the surface
ADR-0015 already fixes rather than in another tab. Because the endpoint is the tenant's, the platform
neither becomes a data processor for model inference nor takes on a residency answer it cannot keep
(PR-22). The invariants above mean the worst case of a hostile diff is a wrong comment, not a moved
ref or a bypassed gate.

**Negative:** the product acquires an AI attack surface, an SSRF surface, a credential-custody
obligation, and an L3 programme of six controls that do not exist today — minus the one exception
recorded above, which is a permanent qualifier on every L3 claim this platform makes. Per-tenant endpoints mean
per-tenant failure modes — latency, outage, quota, model change under a stable name — none of which
the platform controls, all of which its users will attribute to it. Non-deterministic output sitting
anywhere near a merge gate is a durable source of "it passed yesterday" reports.

**On the roadmap:** this is not Phase 2. It needs PR-24 in the PRD, a roadmap placement, an epic and
tasks, and its own specs before any RED. Phase 2's seven tasks are unaffected.

## Alternatives considered

- **Self-hosted in-cluster inference.** No egress, simplest residency and BYO story, and the only
  option where the platform can honestly constrain the credential path end to end. Rejected in favour
  of tenant choice; recorded here because it remains the fallback if conflict 1 proves unacceptable.
- **A platform-chosen external provider.** Cheapest to operate, best models, but it makes the platform
  a processor of tenant source code, requires a DPA and a residency answer, and breaks the BYO promise
  that a customer's code stays in their cluster. Rejected.
- **Advisory-only review.** Removes conflict 2 entirely and most of the injection risk's blast radius,
  at the cost of the enforcement the capability is wanted for. Rejected as the primary mode; it
  remains the safe configuration a tenant may choose.
- **AISVS L1 or L2.** Reachable without cryptographic agent identity, out-of-band kill switches, or a
  sender-constrained-credential exception. Rejected in favour of L3-with-one-exception; the bill is in
  *Conflicts* 1.
- **Requiring mTLS-capable endpoints.** Would meet L3 unqualified and remove conflict 1 entirely, but
  excludes most managed OpenAI-compatible services and would make the tenant-configured decision
  hollow. Rejected; it remains the upgrade path if the exception proves unacceptable to a customer.
- **AI review as a sixth scanner class.** Would inherit the dashboard, triage and evidence path for
  free, at the cost of amending two Approved specs and defining identity for a non-deterministic
  producer. Rejected in favour of a separate resource.
- **A platform-wide secret-custody ADR first.** Correct in the long run and expected to supersede
  decision 5; rejected as a blocker now because one consumer does not yet establish the general
  design.
