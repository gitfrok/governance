# policies

Policy-as-code (OPA/Rego) — the PDP bundle source (ADR-0006, SPEC-0002). Approval, security, and
access policies live here and are enforced **deny-by-default**.

This directory is not *a* place authorization is decided; it is the only one. Invariant 2 forbids
inline permission logic anywhere in the system, so a rule that is not here does not exist. Adding a
grant is a reviewed diff in this repo — which is the property ADR-0006 was chosen for.

## Layout

This directory **is** the OPA bundle. Its root is `policies/`, so paths matter:

```
policies/
  .manifest                        bundle revision + roots
  gitsaas/authz/authz.rego         the deny-by-default authorization policy
  gitsaas/authz/authz_test.rego    its behavioural suite (governance CI runs it)
```

Packages must live under a root declared in `.manifest`, and `opa build` refuses the bundle
otherwise — roots are what stop one bundle silently overwriting another's data when both are
loaded, so a manifest that lies about them is a real defect and not a formality.

## The revision is load-bearing

`.manifest`'s `revision` is returned in every decision (`DecideResponse.policy_revision`) and is
what a PEP keys its decision cache on. A cached decision is only valid for the policy that produced
it, so **bump the revision in the same PR as any change under `gitsaas/`**. Forgetting to means
every PEP keeps serving decisions computed under the old rules until its TTL happens to expire —
a policy change that does not take effect is worse than one that fails loudly.

## Consumers

The backend's PDP adapter loads this directory as a bundle and evaluates
`data.gitsaas.authz.decision`, a total document (both members have defaults) so that no caller ever
has to interpret an undefined result. The wire shape is
`contracts/proto/policy/v1/policy.proto`; the two are the same document and change together.

`_test.rego` files are excluded when the adapter loads the bundle — they are governance's tests of
the policy's content, not part of what ships.

## Testing

`scripts/check-policies.sh` is the gate (required in CI). It builds the bundle, compiles under
`--strict`, runs `opa test`, and — separately from the suite — asserts that every package defining
`allow` evaluates to `false`, not *undefined*, for an empty input. Undefined is not a denial: `not
allow` succeeds for an undefined rule, so a policy that lost its default looks safe under negation
while handing the adapter an absent answer to interpret.

Run it locally with `opa` on PATH:

```
./scripts/check-policies.sh
```

Write the deny cases. An allow-only suite passes just as happily against a policy that allows
everything — and the role matrix in `authz_test.rego` exists because a mutation that granted
`reader` full admin left an earlier version of this suite entirely green.

## Scope today

T-0005 ships the skeleton: the repository action vocabulary the PDP needs to be real. **T-0013**
(identity), **T-0016** (merge requests + protected branches), **T-0018** (import), LFS (SPEC-0023),
**T-0022** (findings ingest/read, SPEC-0025), **T-0028** (code search query/read/index-status,
SPEC-0034/0035), **T-0023** (findings triage + dashboard summary, SPEC-0026/0027 — triage is a
control action withheld from reader, and a summary can never be wider than the findings.read it
aggregates) and **T-0024** (findings on merge requests, SPEC-0028 — no new action: `findings.read`
becomes askable about a `merge_request` resource, with repository, head revision and attribution
status arriving as server-derived context) and **T-0025** (security & approval policy, SPEC-0029/
0030 — a `merge_request.merge` security gate that denies on an attributed-findings severity
threshold, exempts ACCEPT/FALSE_POSITIVE triage while recording the relied-upon triage IDs on the
`decision`, and fails closed when the findings facts a rule requires are missing; plus the
owner-only `policy.dryrun` and `policy.decision.read` vocabulary) and **T-0026** (evidence pack
export, SPEC-0031/0032 — the owner-only `evidence.pack.generate` action asked about the tenant,
and `evidence.pack.read` asked about the `evidence_pack` resource kind; generation is the
compliance owner's act (PR-17), and read is what T-0027's SPEC-0033 auditor grants will later
gate) and **T-0027** (scoped auditor access, SPEC-0033 — the owner-only `auditor.grant.manage`
action asked about the tenant, and the same `evidence.pack.read` action extended to auditor
principals under a valid grant: grant ID, state, tenant, expiry, range bounds and named packs
arrive as decision-time context facts the PEP supplies fresh on every request, so a revoked or
expired grant fails the very next decision — immediacy is structural, not an invalidation race;
the auditor role grants nothing else, so every write path and every repository read stays denied
by construction) and **T-0030** (agent enrolment, SPEC-0038 — the owner-only
`agent.enrolment_token.issue`/`agent.enrolment_token.revoke` actions asked about the
`enrolment_token` resource kind and `agent.dataplane.revoke`/`agent.dataplane.read` asked about
`data_plane`; token issuance and revocation are control-plane acts on machine identity
(SPEC-0038 AC5), and the dataplane read is the operator visibility behind AC8, withheld from
member and reader because registry records are control-plane inventory, not repository content)
own extending it. A resource kind with no entry is
denied, which is the correct state for a feature that does not exist yet.
