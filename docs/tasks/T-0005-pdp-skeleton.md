# T-0005: PDP skeleton (OPA)

- **Status:** In progress — governance half merged: policy bundle, `Decision` contract, Rego gate
- **Phase / Epic:** 0 / EP-2
- **Repo(s):** governance (`policies/`) → backend (PDP adapter) → bff (PEP call, AC3)
- **Spec:** docs/specs/SPEC-0002-policy-decision-point.md
- **ADRs:** 0006, 0022
- **Owner:** unassigned

## Goal
Deny-by-default policy decision point consulted by the BFF/services.

## Acceptance criteria (test-first)
- [~] AC1: A request with no matching allow policy is denied. **Policy half verified** —
  `policies/gitsaas/authz` defaults to deny, and `scripts/check-policies.sh` asserts every package
  defining `allow` evaluates to `false` (not *undefined*) for an empty input. The PDP service that
  returns that denial to a caller is the backend half, still open.
- [x] AC2: Policies live in a versioned policy dir and load as OPA bundles. **Verified** —
  `policies/` is the bundle root with a `.manifest` carrying revision `0.1.0`; `opa build -b`
  validates it in CI, including that the declared roots cover every package present.
- [ ] AC3: The BFF calls the PDP for a sample protected action; decision is cached. Sample action
  is **`repo.read`** — chosen because it is the one the existing `repository` module and Phase-1
  T-0014 will actually ask about, so the policy outlives the skeleton.

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
| governance | *(this PR)* | `policies/` bundle + Rego suite, `contracts/proto/policy/v1`, `scripts/check-policies.sh` wired into CI |

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
