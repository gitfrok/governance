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
# branch-protection actions below; T-0018 (import) adds repository.import.*.
#
# The import actions are owner-only, and that is the decision, not an omission.
# An import writes history the platform did not witness, and mapping a foreign
# handle to a platform identity is the one act that can make imported history
# read as ours (SPEC-0011 AC10). Both belong to whoever is accountable for the
# tenant, not to everyone who can push.
role_actions := {
	"owner": {
		"repo.read", "repo.write", "repo.admin",
		"identity.pat.issue", "identity.pat.list", "identity.pat.revoke",
		"ci.run", "ci.cancel",
		"merge_request.open", "merge_request.review", "merge_request.merge",
		"repository.branch_protection.manage",
		"repository.import", "repository.import.read", "repository.import.revoke",
		"repository.import.map_actor",
	},
	"member": {
		"repo.read", "repo.write", "ci.run", "ci.cancel",
		"merge_request.open", "merge_request.review", "merge_request.merge",
		# A member may read imported history — it is repository content — but may
		# neither start an import, revoke one, nor assert who a foreign handle is.
		"repository.import.read",
	},
	"reader": {"repo.read"},
}

# action_resource pins each action to the one resource kind it may be asked about.
#
# Without this, the action vocabulary is the only thing separating a repository grant from every
# future resource that reuses a verb — "read" on a repository and "read" on an audit trail are not
# the same permission, and a table keyed only by verb would eventually conflate them.
action_resource := {
	"repo.read": "repository",
	"repo.write": "repository",
	"repo.admin": "repository",
	"identity.pat.issue": "personal_access_token",
	"identity.pat.list": "personal_access_token",
	"identity.pat.revoke": "personal_access_token",
	"ci.run": "repository",
	"ci.cancel": "ci_job",
	"merge_request.open": "repository",
	"merge_request.review": "merge_request",
	"merge_request.merge": "merge_request",
	"repository.branch_protection.manage": "repository",
	"repository.import": "repository",
	"repository.import.read": "import",
	"repository.import.revoke": "import",
	"repository.import.map_actor": "import",
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

	# The action must be one this policy knows, asked about the kind of thing it applies to.
	action_resource[input.action] == input.resource.type

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
deny if {
	input.action == "merge_request.merge"
	not sufficient_approvals
}

sufficient_approvals if {
	to_number(input.context.valid_approvals) >= to_number(input.context.required_approvals)
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
# Totality is the point. Both members have defaults, so `decision` is defined for every conceivable
# input including an empty one, and the Go adapter never has to decide what an undefined result
# means. The only safe answer to that question is "deny", and a policy that can always answer for
# itself is better than an adapter that has to guess correctly forever.
decision := {
	"allow": allow,
	"reason": reason,
}
