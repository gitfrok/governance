# T-0005: PDP skeleton (OPA)

- **Status:** Done — 2026-08-06. All three ACs, plus SPEC-0002 AC4, verified across all four repos
- **Phase / Epic:** 0 / EP-2
- **Repo(s):** governance (`policies/`) → backend (PDP adapter) → bff (PEP call, AC3)
- **Spec:** docs/specs/SPEC-0002-policy-decision-point.md
- **ADRs:** 0006, 0022
- **Owner:** unassigned

## Goal
Deny-by-default policy decision point consulted by the BFF/services.

## Acceptance criteria (test-first)
- [x] AC1: A request with no matching allow policy is denied. **Verified end to end.**
  `policies/gitsaas/authz` defaults to deny; `scripts/check-policies.sh` asserts every package
  defining `allow` evaluates to `false` — not *undefined* — for an empty input; the backend adapter
  returns the zero `Decision` on every failure path, so a caller that ignores the error still
  denies; and the composed run denies an anonymous subject, a subject with no roles, an unknown
  role, and a reader from another tenant.
- [x] AC2: Policies live in a versioned policy dir and load as OPA bundles. **Verified** —
  `policies/` is the bundle root with a `.manifest` carrying revision `0.1.0`; `opa build -b`
  validates it in CI, including that the declared roots cover every package present. The revision
  reaches the PEP intact, which is what makes cache invalidation work.
- [x] AC3: The BFF calls the PDP for a sample protected action; decision is cached. **Verified** —
  the action is **`repo.read`**, chosen because the existing `repository` module and Phase-1 T-0014
  will actually ask about it, so the policy outlives the skeleton. The BFF's PEP caches by request
  and invalidates by bundle revision.

SPEC-0002 carries a fourth criterion this task's own list did not:

- [x] AC4 (SPEC-0002): No service performs an inline permission check that bypasses the PDP.
  An `inline-permission-check` fitness function in **both** backend and bff, each with fixtures
  proving it can fail and that it does not fire on correct code. It is a **tripwire, not a proof**,
  and is documented as one — see the note below.

## Tests to write first
- policy: unit tests over Rego (allow/deny cases).
- contract/integration: BFF↔PDP decision path.
NOTE: write SPEC first (behavioral) before RED — see SDD.

## Definition of Done
See `../process/definition-of-done.md`.

## Notes / open questions
Follow the Agentic SDLC loop; stop-and-ask if a decision/spec is missing.

## Implementation record

| Repo | Merged | What |
|---|---|---|
| governance | `29362e7` (#30) | `policies/` bundle + Rego suite, `contracts/proto/policy/v1`, `scripts/check-policies.sh` wired into CI |
| backend | `57ff7c1` (#9) | `modules/policy` (OPA evaluator, denial auditing, gRPC server), `platform/audit.PolicyDecisionDenied`, the AC4 fitness function, PDP injected into the plane |
| bff | `dec4424` (#6) | `internal/pep` (PEP + revision-invalidated cache), `internal/aggregate` (the guarded `repo.read`), the AC4 fitness function |
| super-repo | *(pin bump)* | pins + `scripts/check-policy-composition.sh` |

### Decisions taken during implementation (no new ADR needed)

Both follow from Accepted ADRs rather than deciding anything new, which is why this task did not
stop for a Proposed ADR (invariant 12):

1. **The PDP is embedded in the plane binary, not an OPA sidecar.** ADR-0025 enumerates the only
   separate app processes — `git-storaged`, CI runners, the agent, the operator — and a PDP is not
   among them. So it is a backend module reached through its `api/` package in-process, and over
   `contracts/proto/policy/v1` from the BFF.
2. **The bundle reaches the backend as configuration, not as embedded source.** `go:embed`-ing
   `policies/` into the backend would place a second copy of the rules in a repo that does not own
   them (invariant 21) and would make a policy change a backend release. Per-environment config
   (invariant 13) keeps governance the only author.

### Cache invalidation: by revision, not by clock

SPEC-0002 left the caching strategy open. `DecideResponse.policy_revision` carries the bundle
revision that produced the decision, so a PEP keys its cache on it and a policy change invalidates
every entry by construction — no flush to remember, and no window during which a tightened rule is
not yet in force. A TTL still bounds staleness of the *inputs* (a subject's roles can change without
the policy changing), which is a separate concern and belongs where the PEP lives.

### What the mutation testing found

The Rego suite was written before the policy and went green at 16 tests — and still passed when the
role table was widened to grant `reader` full `repo.admin`. Every test asserted what a role *can*
do, and the single negative case happened to name the one action that stayed denied. The role matrix
(`denied_pairs` / `granted_pairs`) was added for that reason; five mutations of the policy's
conjuncts are now each caught.

### AC4 is a tripwire, not a proof — stated so it is not misread later

Every other boundary rule in `backend/internal/arch` is founded on an import edge, which is a fact:
either the edge exists or it does not. Authorization logic has no such signature —
`user.Role == "owner"` imports nothing and looks like ordinary code. The rule catches the two shapes
an inline check overwhelmingly takes (a function named for an authorization question, a comparison
against a role literal) and **cannot** catch a sufficiently indirect one.

That limit is written into the source rather than left for someone to discover, because a heuristic
advertised as complete is worse than no gate: the green tick starts being read as an assurance
nobody actually made. What the rule buys is that the obvious form cannot be written by accident, and
the deliberate form needs a `//arch:allow-inline-authz <reason>` waiver a reviewer has to accept.

The waiver requires a reason and covers **one line**. A heuristic with no escape hatch is deleted
the first time it misfires — an audited exception is strictly better than an unenforced rule — and a
waiver covering a whole function is where the second exception drifts in unnoticed.

The bff's copy is **stricter** than the backend's: the backend exempts `modules/policy`, because that
is where the decision belongs, and the bff exempts nothing, because there is nowhere in the BFF
where deciding access is correct (invariant 18).

### What the composition check found, and why it exists

Each repo was green in isolation before the composed path had ever run. `governance` tests its Rego,
`backend` tests its evaluator against fixtures, `bff` tests its PEP against a stub — and every one of
those is honest, but none can see the other two, and each generates its **own** copy of
`contracts/proto/policy/v1`.

`scripts/check-policy-composition.sh` in the super-repo runs the real path: bff PEP → gRPC → backend
PDP → `governance/policies`. It asserts each verdict rather than merely that a response arrived,
requires both verdicts to occur (a PDP stuck open and one stuck shut would each satisfy half a
one-sided suite), checks the bundle revision survives all four hops, and checks that no denied
request reached the backing store. Mutation-tested: removing the policy's cross-tenant conjunct is
caught by two of its assertions.

It lives in the super-repo for the same reason `check-codegen-fresh.sh` does — the composition is the
only place it can be honest rather than skipped (ADR-0032's precedent, T-0020).

### Known limits, recorded rather than left to be discovered

1. **Cache staleness between a policy change and the first miss.** Invalidation is by revision, so
   the cache is flushed when a response reports a new one — which means entries serve the old rules
   until *some* request reaches the PDP. The TTL is what guarantees that happens. Bounded, not zero.
2. **The TTL is how long a revoked role keeps working.** A subject's roles can change while the
   policy does not, and nothing in a response reveals it. 30s in the BFF today.
3. **No mTLS between BFF and PDP yet.** `cmd/bff` dials with insecure credentials; that is T-0013's,
   and the line naming it says so rather than deferring silently.
4. **`deploy/dev` does not yet mount the bundle.** The plane now requires
   `GITFROK_POLICY_BUNDLE_DIR`, so a Minikube bring-up would start a data plane that exits. T-0003
   owns the manifests and is still open on a host question; this is one more item for it.
5. **The role vocabulary is a skeleton.** `owner`/`member`/`reader` over `repo.*`. T-0013 (identity)
   and T-0016 (merge requests) own extending it; a resource kind with no entry is denied, which is
   the correct state for a feature that does not exist.
