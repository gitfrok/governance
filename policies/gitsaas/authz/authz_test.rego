# Tests for the deny-by-default authorization policy (SPEC-0002 AC1, T-0005).
#
# These run in governance CI (`scripts/check-policies.sh`) and are the *only* place the policy's
# content is tested. The backend's PDP adapter tests the evaluator against its own fixtures; it
# deliberately does not re-test these rules, because a copy of the policy in another repo would be
# a second source of truth for something invariant 21 says has exactly one.
#
# The deny cases outnumber the allow cases on purpose. Deny-by-default is only meaningful if the
# things that must *not* pass are enumerated — an allow-only suite passes just as happily against a
# policy that allows everything.
package gitsaas.authz_test

import data.gitsaas.authz

# A well-formed request that the policy grants. Each deny test below mutates exactly one field of
# this, so a failure names the field responsible rather than leaving it to be guessed.
reader_request := {
	"tenant_id": "acme",
	"subject": {"id": "u-1", "roles": ["reader"], "tenant_id": "acme"},
	"action": "repo.read",
	"resource": {"type": "repository", "id": "repo-1"},
	"context": {},
}

# --- AC1: absence of an explicit allow is a denial ----------------------------------------------

# The empty input is the sharpest form of the invariant: nothing was asserted, so nothing is
# granted. A policy that errored here instead of denying would also fail this test, which is
# intended — an evaluation error must not be distinguishable from a denial to the caller.
test_deny_empty_input if {
	not authz.allow with input as {}
}

test_deny_unknown_action if {
	not authz.allow with input as object.union(reader_request, {"action": "repo.exfiltrate"})
}

test_deny_action_not_granted_to_role if {
	not authz.allow with input as object.union(reader_request, {"action": "repo.write"})
}

# The full role/action matrix, both directions.
#
# These exist because of a mutation test: widening the table so `reader` also granted "repo.admin"
# left the entire suite green. Every test above asserted what a role *can* do, and the one negative
# case happened to name the one action that stayed denied — so the suite could not tell a correct
# table from a dangerously wide one. The interesting property of a role is what it does not grant,
# and that has to be enumerated to be tested.
#
# `as_role` builds a request for one (role, action) pair against the standard repository resource.
as_role(role, action) := object.union(
	reader_request,
	{
		"subject": {"id": "u-matrix", "roles": [role], "tenant_id": "acme"},
		"action": action,
	},
)

# Every pair the table must NOT grant. Adding a grant to authz.rego without removing its row here
# fails this test, which is the point.
denied_pairs := [
	{"role": "reader", "action": "repo.write"},
	{"role": "reader", "action": "repo.admin"},
	{"role": "member", "action": "repo.admin"},
]

test_role_matrix_denies_everything_not_granted if {
	every pair in denied_pairs {
		not authz.allow with input as as_role(pair.role, pair.action)
	}
}

# And the complement, so the table cannot be fixed by narrowing it into uselessness — a policy that
# denied everything would satisfy the matrix above on its own.
granted_pairs := [
	{"role": "reader", "action": "repo.read"},
	{"role": "member", "action": "repo.read"},
	{"role": "member", "action": "repo.write"},
	{"role": "owner", "action": "repo.read"},
	{"role": "owner", "action": "repo.write"},
	{"role": "owner", "action": "repo.admin"},
]

test_role_matrix_grants_what_the_table_says if {
	every pair in granted_pairs {
		authz.allow with input as as_role(pair.role, pair.action)
	}
}

test_deny_subject_with_no_roles if {
	not authz.allow with input as object.union(
		reader_request,
		{"subject": {"id": "u-1", "roles": [], "tenant_id": "acme"}},
	)
}

test_deny_unknown_role if {
	not authz.allow with input as object.union(
		reader_request,
		{"subject": {"id": "u-1", "roles": ["auditor"], "tenant_id": "acme"}},
	)
}

# --- Invariant 1: every decision is tenant-scoped -----------------------------------------------

# The subject is a legitimate reader — in a different tenant. This is the case that matters most:
# holding the right role somewhere is not holding it here.
test_deny_subject_from_another_tenant if {
	not authz.allow with input as object.union(
		reader_request,
		{"subject": {"id": "u-1", "roles": ["reader"], "tenant_id": "globex"}},
	)
}

test_deny_missing_tenant if {
	not authz.allow with input as object.union(
		reader_request,
		{"tenant_id": "", "subject": {"id": "u-1", "roles": ["reader"], "tenant_id": ""}},
	)
}

# --- The action/resource pairing is enforced ----------------------------------------------------

# A grant for "repo.read" must not answer a question about a merge request. Without this the
# action vocabulary would be the only thing standing between a repository policy and every other
# resource kind that later reuses a verb.
test_deny_wrong_resource_type if {
	not authz.allow with input as object.union(
		reader_request,
		{"resource": {"type": "merge_request", "id": "mr-1"}},
	)
}

# `json.remove` rather than an object.union override, because object.union merges *recursively*:
# unioning in {"resource": {"id": "repo-1"}} keeps the original resource.type and the case under
# test never happens. Every other mutation here restates the whole nested object for that reason.
test_deny_missing_resource_type if {
	not authz.allow with input as json.remove(reader_request, ["resource/type"])
}

# --- What is actually granted -------------------------------------------------------------------

test_allow_reader_repo_read if {
	authz.allow with input as reader_request
}

test_allow_member_repo_write if {
	authz.allow with input as object.union(
		reader_request,
		{
			"subject": {"id": "u-2", "roles": ["member"], "tenant_id": "acme"},
			"action": "repo.write",
		},
	)
}

test_allow_owner_repo_admin if {
	authz.allow with input as object.union(
		reader_request,
		{
			"subject": {"id": "u-3", "roles": ["owner"], "tenant_id": "acme"},
			"action": "repo.admin",
		},
	)
}

# T-0013 / SPEC-0006 AC3: PAT lifecycle grants exist only through this PDP.
# Only tenant owners may administer credentials in this MVP policy vocabulary.
test_allow_owner_pat_lifecycle if {
	every action in {"identity.pat.issue", "identity.pat.list", "identity.pat.revoke"} {
		authz.allow with input as {
			"tenant_id": "acme",
			"subject": {"id": "u-owner", "roles": ["owner"], "tenant_id": "acme"},
			"action": action,
			"resource": {"type": "personal_access_token", "id": "u-target"},
			"context": {},
		}
	}
}

test_deny_member_pat_lifecycle if {
	every action in {"identity.pat.issue", "identity.pat.list", "identity.pat.revoke"} {
		not authz.allow with input as {
			"tenant_id": "acme",
			"subject": {"id": "u-member", "roles": ["member"], "tenant_id": "acme"},
			"action": action,
			"resource": {"type": "personal_access_token", "id": "u-target"},
			"context": {},
		}
	}
}

# One matching role among several is enough; holding an extra role must not revoke a grant.
test_allow_when_one_of_several_roles_grants if {
	authz.allow with input as object.union(
		reader_request,
		{"subject": {"id": "u-4", "roles": ["auditor", "reader"], "tenant_id": "acme"}},
	)
}

# --- The decision document the PDP actually queries ----------------------------------------------

# The Go PDP evaluates `data.gitsaas.authz.decision`, not `allow`. It must be total: if it were
# ever undefined the adapter would have to invent an answer, and the only safe invention is the one
# the policy should have made itself.
test_decision_is_defined_for_empty_input if {
	d := authz.decision with input as {}
	d.allow == false
	d.reason != ""
}

test_decision_mirrors_allow if {
	authz.decision.allow == true with input as reader_request
}

# Denial reasons must not vary with the cause. A reason that distinguished "no such role" from
# "wrong tenant" would let a caller map out roles and tenants by probing (see the contract's
# comment on DecideResponse.reason).
test_deny_reasons_are_indistinguishable if {
	wrong_tenant := authz.decision.reason with input as object.union(
		reader_request,
		{"subject": {"id": "u-1", "roles": ["reader"], "tenant_id": "globex"}},
	)
	no_role := authz.decision.reason with input as object.union(
		reader_request,
		{"subject": {"id": "u-1", "roles": [], "tenant_id": "acme"}},
	)
	wrong_tenant == no_role
}
