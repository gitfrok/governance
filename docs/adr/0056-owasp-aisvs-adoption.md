# ADR-0056: OWASP AISVS — where it applies to this system, and what we bind ourselves to

- **Status:** Accepted
- **Date:** 2026-08-14
- **Governs:** G3 supply chain, G5 auditability, G7 process integrity
- **Relates to:** ADR-0028 (AGDD) · ADR-0037 (agent surface generation) · ADR-0011 (outbound-only
  agent — *not* an AI agent) · ADR-0005/0012 (CI sandbox isolation, gVisor) · ADR-0006 (PDP) ·
  ADR-0034/0035/0036 (image supply chain) · ADR-0053/0054 (main guard, CI on push) ·
  SPEC-0012 (ceremony tiers), SPEC-0013 (dispatch scope boundary), SPEC-0014 (shell portability gate)

## Context

**OWASP AISVS 1.0** is a catalogue of testable security requirements for **AI-enabled systems**,
organised in twelve chapters (C1–C12) at three verification levels, plus an Appendix C on
AI-assisted secure coding. The request that prompted this ADR was to "implement AISVS in the core
system."

**The core system has no AI-enabled surface.** The PRD names no AI or ML capability in any phase
(PR-1…PR-23); the product is a git hosting, review, CI and governance platform. `contracts/proto/agent/v1`
is ADR-0011's **outbound-only data-plane agent** for BYO installs — a deployment component, not an AI
agent — and the name is the only thing about it that reads as AI. No model is trained, served,
fine-tuned or called at runtime; there is no inference path, no embedding store, no vector database,
no prompt handling in any request path.

What *is* AI in this system is **how it is built**. Under ADR-0028 (AGDD) agents implement specs,
run tools, and open changes; ADR-0037 generates their steering surface from governance. That is a
real attack surface with real controls already in the tree — but it is the **SDLC**, not the product.
Adopting a standard against the wrong subject would produce a wall of "N/A" verifications and a false
claim of coverage, which is precisely the failure mode ADR-0029 §4 and SPEC-0011 AC14 exist to
prevent elsewhere.

So the useful question is not *whether to implement AISVS* but **which subject we bind it to, and at
what level**. That is a decision with a cost, and it belongs here rather than in a task.

## The trigger fired — 2026-08-14

This ADR's axis 1(b) anticipated a future AI-enabled product feature. **ADR-0057** is that feature:
AI-assisted review of merge requests, commits and pipelines via a tenant-configured OpenAI-compatible
endpoint. The table below remains an accurate record of the system *before* that capability, and is
kept for that reason; for the reviewing capability itself, most of C1–C12 is live rather than N/A, and
ADR-0057 records the subject, level and enforcement shape this ADR left open.

## Applicability of C1–C12 to this system, as it stands today (pre-ADR-0057)

| Chapter | Applies? |
|---|---|
| **C1** Training Data Integrity & Traceability | **N/A** — nothing is trained. Revisit only if a model is trained on customer code. |
| **C2** Input Validation | **N/A as written** (model input). Ordinary input validation is already covered by the contract specs, not by AISVS. |
| **C3** Model Lifecycle Management & Change Control | **N/A** — no model artifact exists to version, approve or roll back. |
| **C4** Infrastructure, Configuration & Deployment Security | **N/A as written**; the equivalent non-AI controls are ADR-0005/0012 (gVisor sandboxes), ADR-0024 (dev cluster), T-0021 images. |
| **C5** Access Control & Identity for AI Components & Users | **N/A for AI components.** Human/service identity is SPEC-0006 + ADR-0006 and is out of AISVS's remit here. |
| **C6** Supply Chain Security for **Models** | **N/A** — no models. The *image* supply chain is ADR-0034/0035/0036 and is a different subject; do not conflate them. |
| **C7** Model Behavior, Output Control & Safety Assurance | **N/A** — no model output reaches a user. |
| **C8** Memory, Embeddings & Vector Database Security | **N/A** — none exist. Would become live if T-0028's code search ever adopted semantic/embedding retrieval; SPEC-0034 chose a trigram/symbol index (ADR-0014), so it does not. |
| **C9** Orchestration & Agentic Security | **Applies to the SDLC today.** See below. |
| **C10** Model Context Protocol (MCP) Security | **Applies to the SDLC today** wherever an agent is given MCP tools. |
| **C11** Adversarial Robustness | **N/A** — no model to attack. Prompt-injection risk against *build* agents is C9/C10 and Appendix C, not C11. |
| **C12** Monitoring, Logging & Anomaly Detection | **N/A as written** (AI-specific telemetry). ADR-0007's audit chain covers the product. |
| **Appendix C** AI-Assisted Secure Coding (AC.1–AC.14) | **Applies to the SDLC today**, and is the closest fit to AGDD of anything in the standard. |

**Where the tree already meets part of C9/C10 without having named them.** SPEC-0013 gives each unit
of work a declared scope and an isolated worktree, and checks afterwards that what was committed
matches what was declared — that is C9.3-shaped isolation and C9.5-shaped authorization, decided for
different reasons. SPEC-0012's ceremony tiers gate how much process a change must clear. ADR-0053/0054
make CI on push the gate and guard `main` against rewrite and deletion, which is the
non-repudiation half of C9.4 for whatever an agent lands. ADR-0005/0012's gVisor sandboxes are the
tool-isolation control C9.3.1 asks for, applied to CI jobs. Coverage is partial and was never
assessed against the standard; naming the gaps is most of the value on offer.

**Where it plainly does not.** Nothing in the tree issues an agent a cryptographic identity (C9.4.1),
binds an approval to action parameters (C9.2.8), enforces a per-execution budget (C9.1.2), maintains
a tool-definition snapshot with re-approval on change (C10.4.8), or screens tool output for indirect
prompt injection before it enters an agent's context (C10.4.2).

## Decision

Taken 2026-08-14, alongside ADR-0057 which is the capability that fired this ADR's trigger.

1. **Subject — both.** AISVS binds to the **agentic SDLC** (C9, C10, Appendix C against how this
   platform is built) **and** to any AI-enabled product feature, which must verify against AISVS
   before it ships. ADR-0057 is the first such feature.
2. **Level — L3**, with the one named exception ADR-0057 records: sender-constrained credentials are
   not met for a tenant-configured bearer-token inference endpoint. Every AISVS claim this platform
   publishes carries that exception.
3. **Enforcement — CI fitness functions**, in the T-0009 style, not a periodic manual assessment. A
   standard nothing checks is the failure ADR-0037 was written about.
4. **Gap ownership.** The C9/C10 gaps named below are recorded as follow-ups on this ADR. The
   product-side L3 obligations (ADR-0057 §4) become tasks under the epic the PRD revision files; the
   SDLC-side gaps stay follow-ups until a task claims them. None is silently closed.

The axes as they were originally posed, kept because they explain the shape of the answer:

1. **Subject.** Bind AISVS to (a) the **agentic SDLC** — C9, C10 and Appendix C against how this
   platform is built; (b) a **trigger gate** — any future AI-enabled product feature must verify
   against AISVS before it ships, in the measured-trigger style of ADR-0030; or (c) both. Option (b)
   alone costs nothing today and prevents the gap from opening silently; option (a) is real work
   against a real surface.
2. **Level.** L1 (baseline), L2 (production handling sensitive data), or L3 (high assurance). The
   agentic SDLC touches source code and the release path, which argues above L1; L3 requires
   cryptographic agent identity and out-of-band kill switches that nothing here has.
3. **Enforcement shape.** Whether verification is a **fitness function** in CI (the T-0009 pattern,
   which is how every other governance claim in this tree is kept honest) or a periodic manual
   assessment recorded as evidence. A standard nothing checks is the failure ADR-0037 was written
   about.
4. **Ownership of the gaps.** Which of the named C9/C10 gaps become tasks, and which are accepted
   risks recorded here. Accepting a risk is a legitimate answer; leaving it unnamed is not.

**Explicitly out of scope for this ADR:** offering AISVS as a *customer-facing compliance framework*
that the product verifies and evidences. PR-17 names SOC 2 Type II and the PRD deliberately leaves
other frameworks unnamed, because adding one changes the evidence model (PRD §12.3, §12.4). That is a
**PRD revision**, not a decision this ADR may take.

## Consequences

**If subject (a) is chosen:** the platform gains a named external standard against its own build
process, with a published requirement list an auditor or customer can read — a differentiator
adjacent to the Phase-2 wedge. Cost: C9/C10 at L2 implies agent identity, execution budgets,
tool-manifest enforcement and MCP allow-listing that do not exist today, and each is a task competing
with Phase-2 delivery.

**If subject (b) alone is chosen:** cost today is a paragraph and a gate; the risk is that a future AI
feature is specified before anyone reads the gate. Mitigate by writing the trigger into
`docs/process/definition-of-done.md` rather than only here.

**If rejected:** nothing changes, and the record says why — which is worth more than an unstated
"we looked at it once".

**Either way:** the applicability table above stops the recurring question of whether AISVS applies,
and stops `contracts/proto/agent/v1` being mistaken for an AI surface.

## Alternatives considered

- **Implement AISVS against the product now.** Rejected: there is no AI-enabled surface to verify, so
  every chapter but C9/C10 would be recorded N/A, and a verification record consisting of N/A is a
  claim of coverage that does not exist.
- **Adopt AISVS silently as a checklist without an ADR.** Rejected: adopting an external standard
  binds future work and is architecturally significant (ADR-0001, ADR-0002) — the same reasoning that
  made OPA (ADR-0006) and the UI principle (ADR-0015) ADRs rather than conventions.
- **Fold it into ADR-0028 (AGDD).** Rejected: ADR-0028 is Accepted and defines the framework; this is
  an external standard measured *against* that framework, and extending an Accepted ADR by edit is
  forbidden.
- **Wait until an AI feature exists.** Rejected as the sole answer: the agentic SDLC is a live surface
  today, and the trigger in axis 1(b) is exactly what makes waiting safe rather than forgetful.
