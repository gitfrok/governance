# T-0085: The BYO data-plane installer becomes Kustomize

- **Status:** Todo — **blocked-by SPEC-0068 approval**, which waits on two owner decisions, not on a
  lane: whether ADR-0096 decision 6 requires a newly signed rendered-manifest payload (SPEC-0068 open
  question 1), and what happens to the CRD's upgrade semantics (open question 4). Both are decisions
  about a customer-facing artifact and neither is the implementer's to take.
- **Phase / Epic:** 3.1 carry / EP-22 adjacency — this touches the BYO installer EP-22 is still
  In progress on. **Filing the epic is part of scheduling this**, since ADR-0096 has none.
- **Repo(s):** **super-repo** (`deploy/k8s/dataplane/`, `scripts/check-byo-kustomize.sh`, the removal
  of `deploy/helm/gitfrok-dataplane/` and `scripts/check-byo-chart.sh`, and the conformance matrix)
  **and governance** (the SPEC-0039 AC1 amendment, AC12). **Two repos, two commits, never one**
  (ADR-0027, invariant 23). No `backend` change is in scope; if AC13's refusal path or AC8's CRD
  answer needs one, that is a separate task.
- **Spec:** docs/specs/SPEC-0068-dataplane-kustomize-conversion.md (**Draft** — not yet Approved)
- **ADRs:** 0096 (Accepted — decision 3 requires this, decision 6 sets the distribution answer),
  0013 (the Operator survives; its packaging half is amended), 0044/0047 (signing and registry
  trust), 0011 (no inbound), 0017/0060, 0034/0035
- **Owner:** unassigned

## Goal

Convert the customer-facing data-plane installer from Helm to Kustomize without weakening a single
property the chart's gate asserts, and without recording a green row this task did not run.

**The distinction that governs this task:** the control-plane conversion (T-0084) had no evidence to
preserve because its chart was never built. This one has eight gate assertion sections and two
conformance rows that went green on 2026-08-21 — and a customer on the other end of the artifact.
Every property is therefore re-proven against `kubectl kustomize`, not carried across on the strength
of having once been true of Helm.

## Acceptance criteria (test-first)

All fourteen are SPEC-0068's, carried rather than paraphrased:

- [ ] AC1 both install modes render, deterministically
- [ ] AC2 **no inbound path in either render** — mutation-tested (ADR-0011)
- [ ] AC3 no authored `Secret`, no `secretGenerator` — mutation-tested
- [ ] AC4 the enrolment token only by `secretKeyRef`; the token sentinel never reaches output
- [ ] AC5 the `DataPlane` CR is reference-only, its status credential-free
- [ ] AC6 images digest-pinned; the operator's digest equals its signed `.release` digest
- [ ] AC7 the reconcile contract stays named, including the `operator.image.tag` retirement tripwire
- [ ] AC8 the CRD's upgrade semantics stated and tested — no destroyed or orphaned stored `DataPlane`
- [ ] AC9 `check-byo-kustomize.sh` reproduces sections 0–7 and is **failable** per assertion
- [ ] AC10 the chart and `check-byo-chart.sh` are gone; no `helm` left in `scripts/`
- [ ] AC11 matrix rows 11 and 14 read "not run" with ADR-0096 as cause, then carry **re-earned**
      `kubectl kustomize` evidence — never the 2026-08-21 helm evidence
- [ ] AC12 SPEC-0039 AC1 amended in a **governance** commit
- [ ] AC13 required inputs still refuse to be missing — gate, plus the existing startup `require()`
- [ ] AC14 `NOTES.txt`'s post-install guidance lands somewhere a customer reads, not in the bin

## Tests to write first

The gate comes first, because AC9 is what makes the other thirteen worth anything — and because this
is the one task in the set where a silently weakened assertion reaches a customer.

1. **`scripts/check-byo-kustomize.sh` with one negative fixture per assertion**, under
   `scripts/testdata/`: a base with a `Service` (AC2), one with a `secretGenerator` (AC3), one with a
   literal token (AC4), one with a tag-pinned image (AC6), one with an operator digest that does not
   match its `.release` (AC6), one with the `operator.image.tag` tripwire removed (AC7), one with an
   empty required env (AC13). Each exits non-zero; the shipped tree exits zero. **Write these against
   the existing `check-byo-chart.sh` first** and confirm the old gate catches its own equivalents, so
   the port is proven to lose nothing rather than asserted to.
2. **Render assertions parsed as YAML, not grepped** (AC1–AC7), so a comment can neither satisfy nor
   break an assertion.
3. **Determinism** — two renders at one revision, byte-identical.
4. **AC8's CRD proof**, once open question 4 is decided: apply the prior CRD, create a `DataPlane`,
   apply the new one, and assert the stored object survives with its fields intact. This is the one
   criterion that is about a customer's data rather than about a file.
5. **AC10 and AC12** as path, content and status assertions.

Follow `../process/agentic-sdlc.md`; shell work obeys `check-shell-portability.sh` (SPEC-0014, the
macOS lane).

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony.

Gate matrix:
- **super-repo:** `make verify`, `check-shell-portability.sh`, `check-signed-releases.sh` green and
  **unmodified** unless open question 1 resolves to (a), and `check-byo-kustomize.sh` green with all
  its fixtures. `check-controlplane-kustomize.sh` (T-0084's) unaffected.
- **governance:** `check-docs.sh` green for the SPEC-0039 amendment and this spec's status
  transition.

## Notes / open questions

**Blocked on two decisions, and they are the owner's:**

- **Open question 1 — does decision 6 mean a newly signed payload?** The tree signs `oci_ref@digest`
  per component; verified in `scripts/check-signed-releases.sh`, whose signature covers exactly that
  string, and whose section 3 requires only that the chart *pin* the digest a signed manifest records.
  **The chart has never been a signed artifact.** So ADR-0096 decision 6's "signed and distributed on
  ADR-0044's existing terms" is, read strictly, an **addition** to the trust chain rather than a
  restatement — a new payload type plus a `.release` field the gate does not read. It is a real
  improvement, because it closes the window where a template could alter what is applied after the
  signature was checked; it is also materially more work than a conversion. The three readings are in
  SPEC-0068 open question 1 and the answer changes this task's size.
- **Open question 4 — the CRD.** Helm installs `crds/` once and never upgrades or deletes it;
  Kustomize has no special case, so the CRD becomes an ordinary applied resource. That is a decision
  about whether a customer's stored `DataPlane` objects survive an upgrade, and it should not be made
  by whoever writes the first `kustomization.yaml`.

**What this task must not do.** It must not record rows 11 and 14 as green by carrying the 2026-08-21
helm evidence across — that evidence names a tool the tree will no longer have, and the matrix's rule
is that a blurred row is a failed row. It must not touch `backend`. It must not fold in the
control-plane installer (T-0084). And it must not delete `NOTES.txt`'s guidance without rehoming it
(AC14) — the chart told a customer what to do after installing, and Kustomize has nowhere to say it.

**Adjacent open row, possibly answerable together.** ADR-0094's register row — the data-plane door
has no published contract — is adjacent to SPEC-0068 open question 2, which asks what replaces
`values.yaml` as the customer's documented input surface. Both are "what may a customer set, and where
is it written down". Answering them separately risks two half-contracts.

**T-0042 inherits what AC11 leaves.** This task re-earns the harness halves of rows 11 and 14; the
real-cluster halves remain T-0042's, still blocked by T-0003's lane. T-0042's task file needs the
scope note when this one is scheduled.
