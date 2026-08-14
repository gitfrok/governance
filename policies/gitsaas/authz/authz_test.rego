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
	{"role": "reader", "action": "merge_request.open"},
	{"role": "reader", "action": "repository.branch_protection.manage"},
	{"role": "member", "action": "repository.branch_protection.manage"},
	# An import writes history the platform did not witness, and mapping a foreign
	# handle is what could make that history read as ours (SPEC-0011 AC10). Neither
	# belongs to a role that merely pushes code.
	{"role": "member", "action": "repository.import"},
	{"role": "member", "action": "repository.import.revoke"},
	{"role": "member", "action": "repository.import.map_actor"},
	{"role": "reader", "action": "repository.import"},
	{"role": "reader", "action": "repository.import.read"},
	{"role": "reader", "action": "repository.import.revoke"},
	{"role": "reader", "action": "repository.import.map_actor"},
	# A reader reads text, not every large object the repository references.
	{"role": "reader", "action": "repo.lfs.read"},
	{"role": "reader", "action": "repo.lfs.write"},
	# Feeding scanner output into the findings plane, and reading its findings,
	# are not implied by reading a repository's text (SPEC-0025, T-0022).
	{"role": "reader", "action": "findings.ingest"},
	{"role": "reader", "action": "findings.read"},
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
	{"role": "member", "action": "merge_request.open"},
	{"role": "owner", "action": "repo.read"},
	{"role": "owner", "action": "repo.write"},
	{"role": "owner", "action": "repo.admin"},
	{"role": "owner", "action": "merge_request.open"},
	{"role": "owner", "action": "repository.branch_protection.manage"},
	{"role": "owner", "action": "repository.import"},
	{"role": "owner", "action": "repo.lfs.read"},
	{"role": "owner", "action": "repo.lfs.write"},
	{"role": "member", "action": "repo.lfs.read"},
	{"role": "member", "action": "repo.lfs.write"},
	{"role": "member", "action": "findings.ingest"},
	{"role": "member", "action": "findings.read"},
	{"role": "owner", "action": "findings.ingest"},
	{"role": "owner", "action": "findings.read"},
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

# T-0017 / SPEC-0020: members who may write a repository may trigger and
# cancel its CI jobs. Readers receive neither grant; the CI PEP still binds the
# tenant, repository/job and verified actor context before it asks the PDP.
test_allow_member_ci_lifecycle if {
	every pair in [
		{"action": "ci.run", "resource_type": "repository", "resource_id": "repo-1"},
		{"action": "ci.cancel", "resource_type": "ci_job", "resource_id": "job-1"},
	] {
		authz.allow with input as {
			"tenant_id": "acme",
			"subject": {"id": "u-member", "roles": ["member"], "tenant_id": "acme"},
			"action": pair.action,
			"resource": {"type": pair.resource_type, "id": pair.resource_id},
			"context": {},
		}
	}
}

test_deny_reader_ci_lifecycle if {
	every pair in [
		{"action": "ci.run", "resource_type": "repository", "resource_id": "repo-1"},
		{"action": "ci.cancel", "resource_type": "ci_job", "resource_id": "job-1"},
	] {
		not authz.allow with input as {
			"tenant_id": "acme",
			"subject": {"id": "u-reader", "roles": ["reader"], "tenant_id": "acme"},
			"action": pair.action,
			"resource": {"type": pair.resource_type, "id": pair.resource_id},
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

# --- T-0016: Merge request actions ------------------------------------------------

# merge_request.review and merge_request.merge target a merge_request resource, not a
# repository, so they need their own request shape rather than the reader_request base.
mr_subject(role) := {"id": "u-mr", "roles": [role], "tenant_id": "acme"}

test_allow_member_merge_request_review if {
	authz.allow with input as {
		"tenant_id": "acme",
		"subject": mr_subject("member"),
		"action": "merge_request.review",
		"resource": {"type": "merge_request", "id": "mr-1"},
		"context": {},
	}
}

test_allow_owner_merge_request_review if {
	authz.allow with input as {
		"tenant_id": "acme",
		"subject": mr_subject("owner"),
		"action": "merge_request.review",
		"resource": {"type": "merge_request", "id": "mr-1"},
		"context": {},
	}
}

test_deny_reader_merge_request_review if {
	not authz.allow with input as {
		"tenant_id": "acme",
		"subject": mr_subject("reader"),
		"action": "merge_request.review",
		"resource": {"type": "merge_request", "id": "mr-1"},
		"context": {},
	}
}

test_allow_merge_with_sufficient_approvals if {
	authz.allow with input as {
		"tenant_id": "acme",
		"subject": mr_subject("member"),
		"action": "merge_request.merge",
		"resource": {"type": "merge_request", "id": "mr-1"},
		"context": {"valid_approvals": "2", "required_approvals": "1"},
	}
}

test_deny_merge_without_sufficient_approvals if {
	not authz.allow with input as {
		"tenant_id": "acme",
		"subject": mr_subject("member"),
		"action": "merge_request.merge",
		"resource": {"type": "merge_request", "id": "mr-1"},
		"context": {"valid_approvals": "0", "required_approvals": "1"},
	}
}

# A merge with no approval context at all is denied — the caller cannot omit the
# check by leaving context empty (SPEC-0019 AC5).
test_deny_merge_with_no_approval_context if {
	not authz.allow with input as {
		"tenant_id": "acme",
		"subject": mr_subject("member"),
		"action": "merge_request.merge",
		"resource": {"type": "merge_request", "id": "mr-1"},
		"context": {},
	}
}

# --- T-0016: Protected branches ---------------------------------------------------

# A direct push to a protected branch is denied regardless of role (SPEC-0019 AC2).
test_deny_direct_push_to_protected_branch if {
	not authz.allow with input as {
		"tenant_id": "acme",
		"subject": {"id": "u-1", "roles": ["owner"], "tenant_id": "acme"},
		"action": "repo.write",
		"resource": {"type": "repository", "id": "repo-1"},
		"context": {"operation": "direct_push", "protected": "true"},
	}
}

# A direct push to an unprotected branch is still governed by the role table.
test_allow_direct_push_to_unprotected_branch if {
	authz.allow with input as {
		"tenant_id": "acme",
		"subject": {"id": "u-2", "roles": ["member"], "tenant_id": "acme"},
		"action": "repo.write",
		"resource": {"type": "repository", "id": "repo-1"},
		"context": {"operation": "direct_push", "protected": "false"},
	}
}

# A merge path (non-direct-push) to a protected branch is not blocked by the
# direct-push denial; it lives or dies by the merge_request.merge rule instead.
test_deny_direct_push_does_not_block_merge_action if {
	authz.allow with input as {
		"tenant_id": "acme",
		"subject": {"id": "u-2", "roles": ["member"], "tenant_id": "acme"},
		"action": "repo.write",
		"resource": {"type": "repository", "id": "repo-1"},
		"context": {"operation": "merge", "protected": "true"},
	}
}

# --- SPEC-0011 AC10/AC15: import authorization ---------------------------------------------------

# An import is asked about a repository; the import-scoped actions are asked about
# an import. Pinning each action to one resource kind is what keeps "read this
# import" from being answered by a grant meant for something else.
import_request(role, action, resource_type) := {
	"tenant_id": "acme",
	"subject": {"id": "u-imp", "roles": [role], "tenant_id": "acme"},
	"action": action,
	"resource": {"type": resource_type, "id": "import-1"},
	"context": {},
}

test_allow_owner_starts_an_import if {
	authz.allow with input as import_request("owner", "repository.import", "repository")
}

test_allow_owner_maps_a_declared_actor if {
	authz.allow with input as import_request("owner", "repository.import.map_actor", "import")
}

test_allow_owner_revokes_an_import if {
	authz.allow with input as import_request("owner", "repository.import.revoke", "import")
}

# A member reads imported history — it is repository content — and does nothing else with it.
test_allow_member_reads_imported_history if {
	authz.allow with input as import_request("member", "repository.import.read", "import")
}

test_deny_member_maps_a_declared_actor if {
	not authz.allow with input as import_request("member", "repository.import.map_actor", "import")
}

test_deny_member_starts_an_import if {
	not authz.allow with input as import_request("member", "repository.import", "repository")
}

# The resource kind is load-bearing: an import action asked about a repository is
# not the same question, and must not be answered by the repository grant.
test_deny_import_action_asked_about_the_wrong_resource if {
	not authz.allow with input as import_request("owner", "repository.import.map_actor", "repository")
}

test_deny_import_start_asked_about_an_import if {
	not authz.allow with input as import_request("owner", "repository.import", "import")
}

# Holding owner in another tenant does not authorize an import here (invariant 1).
test_deny_import_from_another_tenant if {
	not authz.allow with input as object.union(
		import_request("owner", "repository.import", "repository"),
		{"subject": {"id": "u-imp", "roles": ["owner"], "tenant_id": "globex"}},
	)
}

# --- SPEC-0023 AC3: LFS is its own permission ----------------------------------------------------

# The point of a separate action: holding repo.read does not carry the right to
# pull every large object the repository references.
test_deny_lfs_read_is_not_implied_by_repo_read if {
	not authz.allow with input as object.union(
		reader_request,
		{"action": "repo.lfs.read"},
	)
}

test_deny_lfs_write_is_not_implied_by_repo_write if {
	not authz.allow with input as {
		"tenant_id": "acme",
		"subject": {"id": "u-1", "roles": ["reader"], "tenant_id": "acme"},
		"action": "repo.lfs.write",
		"resource": {"type": "repository", "id": "repo-1"},
		"context": {},
	}
}

# And an LFS action asked about the wrong resource kind is not answered by the
# repository grant either.
test_deny_lfs_action_asked_about_an_import if {
	not authz.allow with input as {
		"tenant_id": "acme",
		"subject": {"id": "u-1", "roles": ["member"], "tenant_id": "acme"},
		"action": "repo.lfs.read",
		"resource": {"type": "import", "id": "import-1"},
		"context": {},
	}
}

# --- T-0022 / SPEC-0025: findings ingest and read -----------------------------------------------

# findings.ingest is asked about a repository; findings.read is asked about
# either a repository (listing) or the finding itself (GetFinding). The deny
# cases outnumber the allow cases on purpose: widening the findings grants is
# the mutation this suite must catch.
findings_request(role, action, resource_type) := {
	"tenant_id": "acme",
	"subject": {"id": "u-find", "roles": [role], "tenant_id": "acme"},
	"action": action,
	"resource": {"type": resource_type, "id": "finding-1"},
	"context": {},
}

test_allow_member_ingests_scan_results if {
	authz.allow with input as findings_request("member", "findings.ingest", "repository")
}

test_allow_owner_ingests_scan_results if {
	authz.allow with input as findings_request("owner", "findings.ingest", "repository")
}

# Reading covers both resource kinds the SPEC names: listing is asked about
# the repository, reading one finding is asked about the finding.
test_allow_member_reads_findings_on_both_resource_kinds if {
	every resource_type in ["repository", "finding"] {
		authz.allow with input as findings_request("member", "findings.read", resource_type)
	}
}

test_allow_owner_reads_findings_on_both_resource_kinds if {
	every resource_type in ["repository", "finding"] {
		authz.allow with input as findings_request("owner", "findings.read", resource_type)
	}
}

# A reader reads repository text; the findings plane is its own permission.
test_deny_reader_ingests_scan_results if {
	not authz.allow with input as findings_request("reader", "findings.ingest", "repository")
}

test_deny_reader_reads_findings if {
	every resource_type in ["repository", "finding"] {
		not authz.allow with input as findings_request("reader", "findings.read", resource_type)
	}
}

# Ingest is pinned to the repository kind: asking it about a finding is not
# the same question and must not be answered by the repository grant.
test_deny_ingest_asked_about_a_finding if {
	not authz.allow with input as findings_request("owner", "findings.ingest", "finding")
}

# A findings action asked about an unrelated resource kind is denied, whatever
# the role — the action/resource pinning is load-bearing here as everywhere.
test_deny_findings_read_asked_about_an_import if {
	not authz.allow with input as findings_request("owner", "findings.read", "import")
}

test_deny_findings_ingest_asked_about_a_merge_request if {
	not authz.allow with input as findings_request("member", "findings.ingest", "merge_request")
}

# Holding member in another tenant does not authorize an ingest here
# (invariant 1), and the denial does not say why (SPEC-0001).
test_deny_ingest_from_another_tenant if {
	not authz.allow with input as object.union(
		findings_request("member", "findings.ingest", "repository"),
		{"subject": {"id": "u-find", "roles": ["member"], "tenant_id": "globex"}},
	)
}

test_deny_finding_read_from_another_tenant if {
	not authz.allow with input as object.union(
		findings_request("owner", "findings.read", "finding"),
		{"subject": {"id": "u-find", "roles": ["owner"], "tenant_id": "globex"}},
	)
}

# repo.read must not carry findings access: the grant tables are the whole of
# the system's authorization logic, and this pins that the two surfaces
# stay separable.
test_deny_findings_read_is_not_implied_by_repo_read if {
	not authz.allow with input as object.union(
		reader_request,
		{"action": "findings.read", "resource": {"type": "finding", "id": "finding-1"}},
	)
}
