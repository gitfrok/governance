# Authorization policy — deny-by-default (ADR-0006, SPEC-0002, invariant 2).
#
# This is the whole of the system's authorization logic. Not "the central part of it": invariant 2
# says no service performs an inline permission check, so a rule that is not here does not exist.
# Adding a grant is a reviewed change to this file, which is the property ADR-0006 was chosen for —
# engineers cannot silently loosen rules, because loosening one is a diff in the governance repo.
#
# SHAPE OF THE INPUT — see contracts/proto/policy/v1/policy.proto, which is the same document on the
# wire:
#
#   {
#     "tenant_id": "acme",
#     "subject":   {"id": "u-1", "roles": ["reader"], "tenant_id": "acme"},
#     "action":    "repo.read",
#     "resource":  {"type": "repository", "id": "repo-1"},
#     "context":   {}
#   }
#
# The subject's roles arrive *in the input* rather than being looked up here. That keeps a decision
# a pure function of its request, which is what makes it cacheable at all (SPEC-0002 AC3) and what
# keeps this policy free of any dependency on a running directory service.
package gitsaas.authz

# The invariant, stated once. Every path that does not explicitly grant ends here.
default allow := false

# role_actions maps a role to the actions it grants, as data rather than as rules.
#
# Deliberately a table: adding a role or a grant should be a one-line diff a reviewer can read as a
# sentence, not a new rule body whose interaction with the existing ones has to be reasoned about.
# It is also why there is no "admin implies everything" shortcut — an implicit grant is exactly the
# kind of rule that turns out, years later, to have granted something nobody intended.
#
# T-0005 ships the skeleton vocabulary. T-0013 (identity) extended it with
# personal_access_token actions; T-0016 (merge requests) adds merge_request.* and
# branch-protection actions below; T-0018 (import) adds repository.import.*;
# T-0022 (findings, SPEC-0025) adds findings.ingest and findings.read;
# T-0028 (code search, SPEC-0034/0035) adds search.query, search.read and
# search.index.status.read; T-0023 (security dashboard + triage, SPEC-0026/0027)
# adds findings.triage and findings.summary.read; T-0024 (findings on merge
# requests, SPEC-0028) extends findings.read to the merge_request resource
# kind — no new action, because reading an MR's findings is reading findings.
#
# The search actions are granted to every role that reads a repository —
# owner, member and reader — because a search result is repository text: the
# index never serves what repo.read does not already serve, and per-repository
# readability is re-derived server-side at query time (the searchable scope is
# a server fact, never a caller claim; SPEC-0035 AC2). Withholding search from
# a reader would withhold nothing a clone does not give. Index status likewise
# reveals only the freshness of repositories the caller may already read
# (SPEC-0035 AC6).
#
# findings.ingest is granted to owner and member and withheld from reader on
# the same reasoning as LFS: a tenant that grants reading a repository's text
# has not granted feeding scanner output into its findings plane, and a scan
# adapter ingests with the roles of the principal it runs for.
#
# findings.triage is granted to owner and member and withheld from reader
# (SPEC-0026): triage is a control action — an accepted risk is a claim an
# auditor may later read (PR-17) — and a role that may not even read findings
# cannot record decisions on them.
#
# findings.summary.read is granted exactly as widely as findings.read — to
# owner and member, not reader — and that equality is the decision. A count
# or a facet is an aggregate over findings, and a summary the caller could
# read while the findings themselves stayed unreadable would be the
# aggregate leakage SPEC-0026 AC6 forbids: a number that changes with an
# unreadable repository's findings leaks existence just as a list does
# (SPEC-0027 AC4). A summary can never be wider than the list it summarizes.
#
# The import actions are owner-only, and that is the decision, not an omission.
# An import writes history the platform did not witness, and mapping a foreign
# handle to a platform identity is the one act that can make imported history
# read as ours (SPEC-0011 AC10). Both belong to whoever is accountable for the
# tenant, not to everyone who can push.
#
# The policy actions are owner-only too (T-0025, SPEC-0029/0030). policy.dryrun
# evaluates a candidate bundle against history before it binds, and
# policy.decision.read retrieves a recorded decision with its provenance; both
# are governance/accountability operations on the policy surface, and neither is
# implied by reading or writing repository text. Withholding them from member and
# reader is the least-privilege default: a role that merges code has not thereby
# been granted the surface that dry-runs or audits the rules gating the merge.
role_actions := {
	"owner": {
		"repo.read", "repo.write", "repo.admin",
		"identity.pat.issue", "identity.pat.list", "identity.pat.revoke",
		"ci.run", "ci.cancel",
		"merge_request.open", "merge_request.review", "merge_request.merge",
		"repository.branch_protection.manage",
		"repository.import", "repository.import.read", "repository.import.revoke",
		"repository.import.map_actor",
		"repo.lfs.read", "repo.lfs.write",
		"findings.ingest", "findings.read",
		"findings.triage", "findings.summary.read",
		"search.query", "search.read", "search.index.status.read",
		"policy.dryrun", "policy.decision.read",
	},
	"member": {
		"repo.read", "repo.write", "ci.run", "ci.cancel",
		"merge_request.open", "merge_request.review", "merge_request.merge",
		# A member may read imported history — it is repository content — but may
		# neither start an import, revoke one, nor assert who a foreign handle is.
		"repository.import.read",
		# Large objects are their own permission (SPEC-0023 AC3): a large-file read
		# is bulk egress and a large-file write is bulk storage, and a tenant must be
		# able to grant repository access without granting either.
		"repo.lfs.read", "repo.lfs.write",
		"findings.ingest", "findings.read",
		"findings.triage", "findings.summary.read",
		"search.query", "search.read", "search.index.status.read",
	},
	# A reader reads the repository. LFS is deliberately not included: pulling every
	# large object in a repository is a different cost from reading its text, and a
	# tenant that wants to grant one without the other has to be able to.
	# Search is included: it surfaces nothing repo.read does not (SPEC-0034/0035).
	"reader": {"repo.read", "search.query", "search.read", "search.index.status.read"},
}

# action_resource pins each action to the resource kind(s) it may be asked about.
#
# Without this, the action vocabulary is the only thing separating a repository grant from every
# future resource that reuses a verb — "read" on a repository and "read" on an audit trail are not
# the same permission, and a table keyed only by verb would eventually conflate them.
#
# Every entry is the SET of resource kinds the action may be asked about — a singleton for most
# actions. The one exception is findings.read (SPEC-0025, SPEC-0028): listing is asked about the
# repository, reading one finding is asked about the finding itself, and reading a merge request's
# introduced findings is asked about the merge request — and the same PDP decision shape serves
# all three, with the repository and head revision carried as server-derived context (SPEC-0028).
# A set with one member reads exactly as the old pinning did.
#
# search.query is asked about the tenant (SPEC-0035): the query is tenant-scoped and the
# searchable repository set is server-derived, so no repository is named in the question.
# search.read and search.index.status.read are asked about a repository — the per-repository
# re-check that binds a revocation to the next query (SPEC-0034 AC6, SPEC-0035 AC5).
#
# findings.triage is asked about the finding the record is keyed to (SPEC-0027): triage is a
# resource of its own, and the question is about its key, not about the repository it sits in.
# findings.summary.read is asked about a repository, exactly as SPEC-0027's table pins it; an
# org-wide summary decomposes into per-repository decisions server-side, so no tenant-kind
# question exists for it.
#
# policy.dryrun is asked about the tenant (SPEC-0030): the dry-run is tenant-scoped, and its
# candidate bundle reference and range bounds travel as server-derived context, so no other
# resource kind is named in the question. policy.decision.read is asked about the decision
# record itself — a decision is a resource of its own, and the question is about its ID, not
# about the tenant or the action it recorded.
action_resource := {
	"repo.read": {"repository"},
	"repo.write": {"repository"},
	"repo.admin": {"repository"},
	"identity.pat.issue": {"personal_access_token"},
	"identity.pat.list": {"personal_access_token"},
	"identity.pat.revoke": {"personal_access_token"},
	"ci.run": {"repository"},
	"ci.cancel": {"ci_job"},
	"merge_request.open": {"repository"},
	"merge_request.review": {"merge_request"},
	"merge_request.merge": {"merge_request"},
	"repository.branch_protection.manage": {"repository"},
	"repository.import": {"repository"},
	"repository.import.read": {"import"},
	"repository.import.revoke": {"import"},
	"repository.import.map_actor": {"import"},
	"repo.lfs.read": {"repository"},
	"repo.lfs.write": {"repository"},
	"findings.ingest": {"repository"},
	"findings.read": {"repository", "finding", "merge_request"},
	"findings.triage": {"finding"},
	"findings.summary.read": {"repository"},
	"search.query": {"tenant"},
	"search.read": {"repository"},
	"search.index.status.read": {"repository"},
	"policy.dryrun": {"tenant"},
	"policy.decision.read": {"decision"},
}

# The single grant rule. Every condition is a conjunct, so removing any one of them widens the
# policy — which is what makes this readable as a security statement rather than as code.
allow if {
	# A decision is always tenant-scoped (invariant 1). An unscoped request is not evaluated
	# against some global rule set; it is denied.
	input.tenant_id != ""

	# Holding a role in one tenant is not holding it in another. This is the conjunct that makes
	# the roles-in-the-input design safe: the PEP supplies the roles, but it cannot supply them
	# for a tenant other than the one it is asking about.
	input.subject.tenant_id == input.tenant_id

	# The action must be one this policy knows, asked about a kind of thing it applies to.
	input.resource.type in action_resource[input.action]

	# And some role the subject holds must grant it.
	some role in input.subject.roles
	role_actions[role][input.action]

	# Two server-derived denials the role table alone cannot express (SPEC-0019):
	# a protected branch rejects direct pushes, and a merge needs enough valid
	# approvals. The caller cannot lift either by holding a stronger role.
	not deny
}

# Deny direct pushes to protected branches (SPEC-0019 AC2). Even a tenant owner
# cannot bypass this in-band; force-promotion is a separate platform-operator path
# (ADR-0046). The Git transport PEP supplies context.operation and context.protected.
deny if {
	input.action == "repo.write"
	input.context.operation == "direct_push"
	input.context.protected == "true"
}

# Deny a merge that lacks the required number of valid approvals (SPEC-0019 AC5).
# valid_approvals and required_approvals are server-derived from the review log and
# the protection rule respectively; the caller cannot assert its own counts.
#
# An imported approval never satisfies this requirement (ADR-0029 §4, SPEC-0029
# AC6): valid_approvals counts FIRST-PARTY approvals only. An imported review is
# ATTESTED_IMPORT — history the platform did not witness — and is never folded
# into the first-party approval count, so a merge whose only approval is imported
# presents valid_approvals=0 and is denied here. This is structural: there is no
# fact a caller can supply that makes an imported approval count.
deny if {
	input.action == "merge_request.merge"
	not sufficient_approvals
}

sufficient_approvals if {
	to_number(input.context.valid_approvals) >= to_number(input.context.required_approvals)
}

# --- T-0025 / SPEC-0029 / SPEC-0030: the security merge gate on attributed findings ---
#
# A security rule may block a merge on the findings SPEC-0028 attributes to it.
# The block is a PDP decision over server-derived findings context — never UI
# logic, a caller assertion, or a BFF check (SPEC-0029 AC3). The facts arrive on
# context exactly the way valid_approvals does: assembled by the calling context
# from its own state (ADR-0022), so a fact that cannot be assembled fails closed
# rather than being replaced by a fail-open default or a synchronous cross-context
# read (SPEC-0029 AC9, SPEC-0030 AC4).
#
# The facts this gate consumes (SPEC-0030):
#   findings_gate              "true" when a security rule requires findings facts
#                              for this merge; absent otherwise. Its absence leaves
#                              the SPEC-0019 approval gate unchanged.
#   findings_highest_severity  highest severity among the merge's attributed
#                              findings that no ACCEPT/FALSE_POSITIVE triage
#                              exempts: NONE / LOW / MEDIUM / HIGH / CRITICAL.
#   findings_low|medium|high|critical  attributed counts by severity.
#   relied_upon_triage_ids     the ACCEPT/FALSE_POSITIVE triage record IDs the
#                              exemption relied on (recorded on the decision).

# The severity threshold a merge's attributed findings must stay below
# (SPEC-0029 AC3). Authored in reviewed policy; a tenant-specific threshold is a
# governance PR under reading A. "HIGH" denies a merge whose highest attributed
# severity is HIGH or CRITICAL.
security_severity_threshold := "HIGH"

# severity_rank orders the FindingSeverity vocabulary (contracts/proto/security/v1
# FindingSeverity), plus NONE for "no attributed finding". Numeric so a threshold
# comparison is a single >= rather than a case table.
severity_rank := {
	"NONE": 0,
	"LOW": 1,
	"MEDIUM": 2,
	"HIGH": 3,
	"CRITICAL": 4,
}

# Deny a merge whose attributed findings breach the severity threshold
# (SPEC-0029 AC3). findings_highest_severity is server-derived; the caller cannot
# assert it. The breach stands unless an ACCEPT/FALSE_POSITIVE triage exempts it.
deny if {
	input.action == "merge_request.merge"
	input.context.findings_gate == "true"
	security_findings_breach
}

security_findings_breach if {
	findings_facts_present
	severity_rank[input.context.findings_highest_severity] >= severity_rank[security_severity_threshold]
	not security_triage_exempt
}

# An ACCEPT or FALSE_POSITIVE triage exempts the breach it covers (SPEC-0029 AC4).
# relied_upon_triage_ids is a server-derived fact (SPEC-0026/0028): the context
# provider populates it with the IDs of the ACCEPT/FALSE_POSITIVE triage records
# covering the findings that breach the threshold, and only when they fully cover
# the breach. Its presence is therefore both the exemption and the record of what
# the decision relied on — the PDP surfaces those IDs via relied_upon_triage so
# the decision (and its audit record) names the triage that exempted it.
security_triage_exempt if {
	input.context.relied_upon_triage_ids != ""
}

# Fail CLOSED when the findings gate is engaged but its facts did not assemble
# (SPEC-0029 AC9). A missing or malformed findings_highest_severity — absent, or
# not in the severity vocabulary — is a denial, never a fail-open default and
# never a synchronous cross-context table read to recover it.
deny if {
	input.action == "merge_request.merge"
	input.context.findings_gate == "true"
	not findings_facts_present
}

findings_facts_present if {
	_ = severity_rank[input.context.findings_highest_severity]
}

# relied_upon_triage is the list of ACCEPT/FALSE_POSITIVE triage record IDs the
# security gate relied on (SPEC-0029 AC4). Convention: the PDP adapter records
# this on the decision's audit detail, so an auditor can see which triage record
# exempted a blocking finding. Empty when no exemption was applied.
default relied_upon_triage := []

relied_upon_triage := split(input.context.relied_upon_triage_ids, ",") if {
	input.action == "merge_request.merge"
	input.context.relied_upon_triage_ids != ""
}

# reason explains the outcome in terms that are safe to return to the caller.
#
# There is exactly one denial reason, and that is a security property rather than laziness. A reason
# that distinguished "you hold no such role" from "that repository is in another tenant" would make
# this service an oracle: probe it enough and it enumerates the tenants and roles that RLS and
# deny-by-default exist to hide. The specific cause belongs in the audit trail (SPEC-0003), which is
# read by investigators rather than by the subject who was denied.
default reason := "denied: no policy grants this action"

reason := "allowed: subject holds a role granting this action" if allow

# decision is what the PDP queries — one total document rather than two rules read separately.
#
# Totality is the point. Every member has a default, so `decision` is defined for every conceivable
# input including an empty one, and the Go adapter never has to decide what an undefined result
# means. The only safe answer to that question is "deny", and a policy that can always answer for
# itself is better than an adapter that has to guess correctly forever.
decision := {
	"allow": allow,
	"reason": reason,
	"relied_upon_triage": relied_upon_triage,
}
