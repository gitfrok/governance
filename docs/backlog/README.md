# Backlog — epics

Epics are grouped by roadmap phase and link down to executable tasks in `../tasks/`.
**Definition of Done** for every task: `../process/definition-of-done.md`.

## Phase 0 — Foundations
- **EP-0 Scaffolding & process** *(closed)*: T-0001 (repo layout, **Done**), T-0002 (boundary/arch
  CI, **Done**), T-0008 (in-process bus + module `api` convention, **Done**), T-0009
  (extraction-readiness fitness functions, **Done**). T-0008 and T-0009 carry
  `Phase / Epic: 0 / EP-0` in their task files and were missing from this list.
  **Epic status: CLOSED 2026-08-04.** All four tasks **Done**. T-0002 AC5 was the last item — the
  gates now *block* rather than only run: **ADR-0031** split `main` enforcement into two rulesets
  (`main-integrity` with no bypass actors, `main-review` admin-bypassable until the org has a second
  member), applied to all five repos by the super-repo's `scripts/apply-rulesets.sh`, with legacy
  branch protection deleted. Verified empirically: a direct admin push to `main` is
  `[remote rejected]`, and `gh pr merge --admin` is refused on a red required check. Every criterion
  in this epic is met and machine-enforced.
  Carried out of the epic as three ADR-0031 follow-ups, none of them blocking; two have since
  **closed 2026-08-05**: four-eyes review (a second org member joined, so `main-review`'s bypass is
  empty everywhere) and the `webfrontend` gate (it gained a CI workflow, and
  `build + typecheck + test + arch gates` is now a required check in its `main-integrity`).
  **Still open:** the two rulesets are five per-repo copies, because org-level rulesets need GitHub
  Team — kept honest by `make rulesets-check`.
- **EP-9 Contract gates**: T-0020 (`buf lint` + `buf breaking` on `contracts/`, codegen-freshness
  checks in the three consumers). New epic rather than a reopened EP-0: that epic closed 2026-08-04
  with its criteria verified, and this gate was never one of them — `../process/ci-gates.md` marks
  "contract schema" required in four repos but attributes no task to it, and `buf` runs in no CI
  anywhere. Phase 0 all the same: its exit criteria require CI green on *contract* tests.
  **Epic status: CLOSED 2026-08-06.** T-0020 **Done** across all five repos: the 13
  `ENUM_VALUE_PREFIX` violations renamed per ADR-0032 (invariant 10 permits it — a rename keeps the
  number and type), `buf lint` + `buf breaking` required in governance, and generated-code freshness
  required in the super-repo. AC5 was **amended** during implementation: per-consumer codegen gating
  is impossible while each `buf.gen.yaml` reads `../governance/contracts`, so it is gated at the
  composition boundary instead — the per-repo variant stays blocked on the ADR-0027/0028
  generated-type publishing follow-up.
- **EP-1 Platform up** *(closed)*: T-0003 (Minikube dev env) — **Done 2026-08-09; all four ACs,
  including the macOS run, verified.** First real cluster run 2026-08-06 (rootless podman) cost
  **seven manifest fixes** — as
  written, three of the five services could not start, including a Redpanda tag that was never
  published and a Zitadel config poisoned by Kubernetes service-link env vars. **AC1 and AC3 both
  closed on 2026-08-08, on that same rootless host.** The line this entry used to carry — *"need a
  rootful driver or KVM … not more code, a different host"* — was wrong twice over, and in both
  cases a defect had been recorded as an environment limit. AC1 needed a sysctl plus three fixes in
  a `dev-up.sh` branch that had never run to completion. AC3 needed the node's 80/443 published,
  and then a resolver whose setup instructions the script had been printing incorrectly: a DNS
  *forwarder* pointed at an address with no nameserver on it, so following them broke `.test`
  resolution rather than wiring it. Nobody had run them. The macOS lane passed on a real Mac on
  2026-08-09; **Epic status: CLOSED.**
- **EP-2 Tenancy & governance base** *(closed)*: T-0004 (tenancy+RLS, **Done 2026-08-06**),
  T-0005 (PDP, **Done 2026-08-06**), T-0006 (audit log, **Done 2026-08-06**).
  **Epic status: CLOSED 2026-08-06.** T-0005 landed across all four repos in dependency order
  (invariant 24): the `policies/` OPA bundle and `contracts/proto/policy/v1` in governance, the
  embedded PDP module in backend, the PEP with a revision-invalidated decision cache in bff, and the
  pins plus a composition gate in the super-repo. All three task ACs and SPEC-0002's fourth are met.
  This makes the Rego row in `../process/ci-gates.md` real for the first time — it had been marked
  required against an empty `policies/` directory since the table was written.
  Two things are worth carrying forward rather than burying. **SPEC-0002's open question is
  answered:** cache invalidation is by *bundle revision*, not by clock, so a policy change
  invalidates every cached decision by construction. And **AC4's fitness function is a tripwire, not
  a proof** — authorization logic has no import signature the way every other boundary rule does, so
  it catches the obvious shapes and is documented as catching only those. Carried out of the epic,
  not blocking: no mTLS between BFF and PDP yet (T-0013), and `deploy/dev` does not mount the policy
  bundle the plane now requires (one more item for T-0003). T-0004 landed all four SPEC-0001 criteria against a real Postgres with RLS
  enforced, including the guard that makes the suite refuse a SUPERUSER/BYPASSRLS role — without it
  every isolation test would pass against a database enforcing nothing. **T-0006 inherits a decision**:
  the audit event T-0004 emits used a provisional routing key — **resolved by T-0006**, which renamed
  it onto `contracts/events/audit/v1.AuditEvent`. T-0005 then consumed that vocabulary without a
  contracts change — `policy.decision.denied` is a new `action` string, which is the property the
  generic `AuditEvent` was chosen for.
- **EP-3 Storage decision** *(closed)*: T-0007 (SeaweedFS-FUSE vs block-volume benchmark, **Done**).
  **Epic status: CLOSED 2026-08-06.** Benchmarked and decided: **ADR-0033 Accepted** — live bare repos
  stay on block volumes because SeaweedFS-FUSE's `rename()` is not atomic and git renames a `.lock`
  over the ref on every update (36 of 428 concurrent ref reads missed a ref that always existed, 0 of
  229 on block, zero rename errors — so rename works and simply is not atomic; reproduced three times).
  ADR-0016 needed **no** amendment and invariant 7's escape clause is discharged. Performance was not
  the deciding factor (~12% on push/clone, ~2× on gc/status, 2.6× on concurrent push). Evidence:
  `../bench/T-0007/`; harness `make bench-storage` in the super-repo. Carried out of the epic, not
  blocking: the latency *ratios* deserve a re-run on a real cluster once T-0003 is verified — the
  correctness verdict does not, being a property of the FUSE client rather than the hardware.

## Phase 1 — MVP
- **EP-4 Git plane**: T-0010 (Git-RPC, **Done** — backend #20), T-0011 (smart-HTTP+SSH),
  T-0012 (sync-replica+failover).
- **EP-5 Identity**: T-0013 (Zitadel + PATs, tenant scoping).
- **EP-6 Code UX**: T-0014 (repo read APIs + BFF, **Done** — backend #22/#24; bff #18),
  T-0015 (web browser/diff/palette).
- **EP-7 Review & CI**: T-0016 (MR + protected branches + approval policy), T-0017 (CI v0 gVisor+KEDA).
- **EP-8 Migration**: T-0018 (repository + review-history import — refs/tags/LFS *and* MR history
  with attested provenance, one unit of work). Scoped in by PRD PR-12; **ADR-0029 Accepted**,
  **SPEC-0011 Approved** — ready to start. T-0019 was folded into T-0018 at spec review.
- **EP-10 Deployable images**: T-0021 (container images for both planes) — **Todo, unblocked
  2026-08-08: AC0 met by ADR-0035 (Accepted).** A new epic rather than an addition to EP-1 on scope
  grounds: EP-1 is a Phase-0 epic
  scoped to the Minikube dev environment, and this is neither Phase 0 nor dev-env work. (Not the EP-9
  precedent, which was about *not reopening a closed epic* for scope it never owned — EP-1 is still
  open, so that reasoning does not apply here and the scope mismatch has to carry the argument by
  itself.)

  Nothing in the four repos builds an image — no `Dockerfile`, `Containerfile`, `.ko.yaml` or
  goreleaser config, and no image build in any CI workflow. Found while closing out T-0003
  (2026-08-08): the policy bundle that task now publishes as a ConfigMap has no consumer, because
  there is no pod to mount it into.

  **AC0 was the blocker and is now met — ADR-0035, Accepted 2026-08-08.** No Accepted ADR had covered
  how a first-party image is produced: ADR-0013 chose Helm + Operator and *assumes* images exist;
  ADR-0034 governs third-party dev-env tag pinning. ADR-0035 settles base image (`scratch` for Go),
  build tool (multi-stage Dockerfile over `ko`), registry (`ghcr.io/gitfrok`), digest-referencing and
  cosign signing, SBOM via Syft as an OCI attestation, and runtime posture — and adds a **fourth**
  image, the `webfrontend` SSR server, which T-0021's original ACs omitted.

  Worth carrying forward, because it is the kind of thing that gets quoted onward: the ADR was merged
  and *then* found to claim invariant 9 compelled key-based cosign signing. It does not — that phrase
  is a proto comment, and ADR-0017 still lists agent-release signing as open. Key-based-vs-keyless was
  an open choice the ADR makes on ADR-0011 grounds (the outbound-only agent may have no route to a
  transparency log). Corrected while still `Proposed`; the ADR carries the note.

  **Phase-0 boundary resolved 2026-08-09.** Phase 0 completed on its delivered foundation scope.
  The policy-checked end-to-end request is a Phase-1 deployment milestone, proven by this task's
  image and integration acceptance criteria; no Phase-0 exit depends on Phase-1 work.

## Phase 2 — Ultimate wedge  *(to be expanded)*
Scanner integration; unified security dashboard; security/approval policies-as-code; audit
UI + evidence export; Zoekt search.

## Phase 3 — BYO  *(to be expanded)*
Agent impl (`contracts/proto/agent/v1`); Operator + Helm + per-cloud drivers; metering → billing.

## Parked — needs a human decision first
- Force-promote tenant self-service? (ADR-0018) · SPIFFE/SPIRE + proxy fallback (ADR-0017)
- Unit-economics model per tier (ADR-0008) · event catalog (ADR-0022; the boundary linter shipped
  in T-0002/T-0009)
*(Two items left this list recently: extraction-trigger budgets on 2026-08-03, ADR-0030 Accepted; and
"a second GitHub org member" on 2026-08-05 — `webenable-asia` joined, so `main-review`'s admin bypass
was removed and four-eyes review on `main` is now binding on owners too. It never blocked EP-0 in the
end: ADR-0031 bound the check gate without it.)*
