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
	# A summary is an aggregate over findings; it can never be wider than the
	# list it summarizes (SPEC-0026 AC6, SPEC-0027 AC4, T-0023). The matrix
	# resource is a repository — exactly the kind findings.summary.read is
	# asked about — so this row catches a widening to reader for the right
	# reason. findings.triage is deliberately NOT here: the matrix resource
	# is the wrong kind for it, a denial would hold for the wrong reason, and
	# the dedicated section below tests it with the finding kind instead.
	{"role": "reader", "action": "findings.summary.read"},
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
	# Dashboard summaries are granted exactly as widely as findings.read
	# (SPEC-0026 AC6); the matrix repository resource is the kind the action
	# is asked about, so these rows are meaningful in both directions.
	{"role": "member", "action": "findings.summary.read"},
	{"role": "owner", "action": "findings.summary.read"},
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

# --- T-0023 / SPEC-0026 / SPEC-0027: triage and dashboard summary --------------------------------

# findings.triage is asked about the finding the record is keyed to; a triage
# decision is a control action an auditor may later read (PR-17), so the deny
# cases outnumber the allow cases on purpose — the mutation this section must
# catch is granting a reader any write on the findings plane, or letting a
# repository grant answer a finding-keyed question.
triage_request(role, action, resource_type) := {
	"tenant_id": "acme",
	"subject": {"id": "u-triage", "roles": [role], "tenant_id": "acme"},
	"action": action,
	"resource": {"type": resource_type, "id": "finding-1"},
	"context": {},
}

test_allow_owner_and_member_triage_a_finding if {
	every role in ["owner", "member"] {
		authz.allow with input as triage_request(role, "findings.triage", "finding")
	}
}

# A reader reads repository text; triage is a decision on a finding, and a
# role that may not read findings cannot record decisions on them
# (SPEC-0026 AC3/AC4).
test_deny_reader_triages_a_finding if {
	not authz.allow with input as triage_request("reader", "findings.triage", "finding")
}

# Triage is pinned to the finding kind: asking it about the repository the
# finding sits in is not the same question and must not be answered by the
# repository grant — even for an owner.
test_deny_triage_asked_about_a_repository if {
	not authz.allow with input as triage_request("owner", "findings.triage", "repository")
}

test_deny_triage_asked_about_an_import if {
	not authz.allow with input as triage_request("owner", "findings.triage", "import")
}

# Holding member in another tenant does not authorize a triage transition
# here (invariant 1); the denial is as coarse as every other (SPEC-0001).
test_deny_triage_from_another_tenant if {
	not authz.allow with input as object.union(
		triage_request("member", "findings.triage", "finding"),
		{"subject": {"id": "u-triage", "roles": ["member"], "tenant_id": "globex"}},
	)
}

# No roles means no triage: a denial creates no triage record, no event and
# no audit entry (SPEC-0027 AC5).
test_deny_triage_with_no_roles if {
	not authz.allow with input as object.union(
		triage_request("member", "findings.triage", "finding"),
		{"subject": {"id": "u-triage", "roles": [], "tenant_id": "acme"}},
	)
}

# findings.summary.read is asked about a repository, exactly as SPEC-0027's
# table pins it. Counts and facets are aggregates over findings, so the
# summary can never be wider than findings.read: reader is denied here
# because it is denied there (SPEC-0026 AC6, SPEC-0027 AC4).
summary_request(role, action, resource_type) := {
	"tenant_id": "acme",
	"subject": {"id": "u-summary", "roles": [role], "tenant_id": "acme"},
	"action": action,
	"resource": {"type": resource_type, "id": "repo-1"},
	"context": {},
}

test_allow_owner_and_member_read_findings_summary if {
	every role in ["owner", "member"] {
		authz.allow with input as summary_request(role, "findings.summary.read", "repository")
	}
}

test_deny_reader_reads_findings_summary if {
	not authz.allow with input as summary_request("reader", "findings.summary.read", "repository")
}

# The resource kind is load-bearing: a summary asked about a finding, a
# tenant, or an unrelated kind is not the per-repository question the grant
# answers. An org-wide summary decomposes into per-repository decisions
# server-side; no tenant-kind question exists for this action.
test_deny_summary_read_asked_about_a_finding if {
	not authz.allow with input as summary_request("owner", "findings.summary.read", "finding")
}

test_deny_summary_read_asked_about_a_tenant if {
	not authz.allow with input as summary_request("owner", "findings.summary.read", "tenant")
}

test_deny_summary_read_asked_about_an_import if {
	not authz.allow with input as summary_request("member", "findings.summary.read", "import")
}

test_deny_summary_read_from_another_tenant if {
	not authz.allow with input as object.union(
		summary_request("owner", "findings.summary.read", "repository"),
		{"subject": {"id": "u-summary", "roles": ["owner"], "tenant_id": "globex"}},
	)
}

# Triage and summary denials are as indistinguishable as every other denial:
# a cross-tenant triage and a reader's summary request receive the same
# reason, so probing the PDP cannot separate the causes (SPEC-0001).
test_deny_triage_reasons_are_indistinguishable if {
	cross_tenant := authz.decision.reason with input as object.union(
		triage_request("member", "findings.triage", "finding"),
		{"subject": {"id": "u-triage", "roles": ["member"], "tenant_id": "globex"}},
	)
	reader_summary := authz.decision.reason with input as summary_request("reader", "findings.summary.read", "repository")
	cross_tenant == reader_summary
}

# --- T-0028 / SPEC-0034 / SPEC-0035: code search ------------------------------------------------

# search.query is asked about the tenant: the query is tenant-scoped and the
# searchable repository set is server-derived, so no repository appears in the
# question (SPEC-0035 AC2). search.read and search.index.status.read are asked
# about a repository — the per-repository re-check that binds a revocation to
# the next query (SPEC-0034 AC6). The deny cases outnumber the allow cases on
# purpose: the leak this surface must not create is an existence hint, and
# every denial below is one it could have given.
search_request(role, action, resource_type, resource_id) := {
	"tenant_id": "acme",
	"subject": {"id": "u-search", "roles": [role], "tenant_id": "acme"},
	"action": action,
	"resource": {"type": resource_type, "id": resource_id},
	"context": {},
}

# Every role that reads a repository may search: a search result is repository
# text, and the index never serves what repo.read does not (SPEC-0034/0035).
test_allow_every_role_queries_search if {
	every role in ["owner", "member", "reader"] {
		authz.allow with input as search_request(role, "search.query", "tenant", "acme")
	}
}

test_allow_every_role_reads_search_results if {
	every role in ["owner", "member", "reader"] {
		authz.allow with input as search_request(role, "search.read", "repository", "repo-1")
	}
}

test_allow_every_role_reads_index_status if {
	every role in ["owner", "member", "reader"] {
		authz.allow with input as search_request(role, "search.index.status.read", "repository", "repo-1")
	}
}

# Holding owner in another tenant does not authorize a query here
# (invariant 1). A cross-tenant query, cursor or result is impossible
# (SPEC-0034 AC8), and the denial says nothing about why.
test_deny_search_query_from_another_tenant if {
	not authz.allow with input as object.union(
		search_request("owner", "search.query", "tenant", "acme"),
		{"subject": {"id": "u-search", "roles": ["owner"], "tenant_id": "globex"}},
	)
}

test_deny_search_read_from_another_tenant if {
	not authz.allow with input as object.union(
		search_request("reader", "search.read", "repository", "repo-1"),
		{"subject": {"id": "u-search", "roles": ["reader"], "tenant_id": "globex"}},
	)
}

# Index status of a repository in another tenant must be no more discoverable
# than the repository itself: the status read is denied like everything else,
# and GetIndexStatus reports nothing for it (SPEC-0035 AC6).
test_deny_index_status_read_from_another_tenant if {
	not authz.allow with input as object.union(
		search_request("owner", "search.index.status.read", "repository", "repo-1"),
		{"subject": {"id": "u-search", "roles": ["owner"], "tenant_id": "globex"}},
	)
}

# The resource kind is load-bearing for every search action. A query asked
# about a repository is not the tenant-scoped question the grant answers, and
# a per-repository read asked about the tenant is not answered either —
# conflating the two would let one grant serve both surfaces.
test_deny_search_query_asked_about_a_repository if {
	not authz.allow with input as search_request("owner", "search.query", "repository", "repo-1")
}

test_deny_search_read_asked_about_a_tenant if {
	not authz.allow with input as search_request("owner", "search.read", "tenant", "acme")
}

test_deny_index_status_read_asked_about_a_finding if {
	not authz.allow with input as search_request("owner", "search.index.status.read", "finding", "finding-1")
}

test_deny_search_read_asked_about_an_import if {
	not authz.allow with input as search_request("member", "search.read", "import", "import-1")
}

# No roles means no search, on every action: a principal cannot reach the
# index at all, so neither a result nor a freshness record can leak
# existence to it.
test_deny_search_with_no_roles if {
	every action in {"search.query", "search.read", "search.index.status.read"} {
		not authz.allow with input as object.union(
			search_request("reader", action, "repository", "repo-1"),
			{"subject": {"id": "u-search", "roles": [], "tenant_id": "acme"}},
		)
	}
}

# Search denials are as indistinguishable as every other denial: a cross-tenant
# query and a roleless query receive the same reason, so probing the PDP
# cannot separate "wrong tenant" from "no such role" (SPEC-0001).
test_deny_search_reasons_are_indistinguishable if {
	cross_tenant := authz.decision.reason with input as object.union(
		search_request("owner", "search.read", "repository", "repo-1"),
		{"subject": {"id": "u-search", "roles": ["owner"], "tenant_id": "globex"}},
	)
	no_role := authz.decision.reason with input as object.union(
		search_request("reader", "search.read", "repository", "repo-1"),
		{"subject": {"id": "u-search", "roles": [], "tenant_id": "acme"}},
	)
	cross_tenant == no_role
}

# --- T-0024 / SPEC-0028: findings on a merge request -------------------------------------------

# Reading a merge request's introduced findings reuses findings.read, asked
# about the merge request itself: the repository, the head revision and the
# attribution status are server-derived context, never caller claims
# (SPEC-0028). No new action enters the vocabulary, so the deny cases below
# pin that the extension widens the resource set of findings.read and
# nothing else — the mutation this section must catch is one that lets a
# repository grant, a review grant, or a reader answer a merge-request-keyed
# findings question.
mr_findings_request(role) := {
	"tenant_id": "acme",
	"subject": {"id": "u-mrf", "roles": [role], "tenant_id": "acme"},
	"action": "findings.read",
	"resource": {"type": "merge_request", "id": "mr-1"},
	"context": {},
}

test_allow_owner_and_member_read_merge_request_findings if {
	every role in ["owner", "member"] {
		authz.allow with input as mr_findings_request(role)
	}
}

# A reader reads repository text; the findings plane is its own permission,
# and asking findings.read about a merge request changes nothing about that
# (SPEC-0025, SPEC-0028 AC8).
test_deny_reader_reads_merge_request_findings if {
	not authz.allow with input as mr_findings_request("reader")
}

# Holding no roles at all denies the merge-request-keyed read like every
# other question: a caller without read on the merge request or its
# repository sees nothing, coarsely (SPEC-0028 AC8).
test_deny_merge_request_findings_with_no_roles if {
	not authz.allow with input as object.union(
		mr_findings_request("member"),
		{"subject": {"id": "u-mrf", "roles": [], "tenant_id": "acme"}},
	)
}

# Holding member in another tenant does not authorize the read here
# (invariant 1); the denial is as coarse as every other (SPEC-0001).
test_deny_merge_request_findings_from_another_tenant if {
	not authz.allow with input as object.union(
		mr_findings_request("member"),
		{"subject": {"id": "u-mrf", "roles": ["member"], "tenant_id": "globex"}},
	)
}

# The extension widens findings.read's resource set only. Ingest stays
# pinned to the repository kind (tested above), and triage and summary stay
# pinned to finding and repository respectively: asking either about a
# merge request is not the question those grants answer.
test_deny_triage_asked_about_a_merge_request if {
	not authz.allow with input as triage_request("owner", "findings.triage", "merge_request")
}

test_deny_summary_read_asked_about_a_merge_request if {
	not authz.allow with input as summary_request("owner", "findings.summary.read", "merge_request")
}

# A review grant on the same merge request is not a findings grant: the
# role table is the whole of the authorization logic, and holding
# merge_request.review must not be re-readable as findings.read.
test_deny_merge_request_findings_is_not_implied_by_repo_read if {
	not authz.allow with input as object.union(
		reader_request,
		{"action": "findings.read", "resource": {"type": "merge_request", "id": "mr-1"}},
	)
}

# Merge-request-keyed findings denials are as indistinguishable as every
# other denial: a cross-tenant read and a reader's read receive the same
# reason, so probing the PDP cannot separate the causes (SPEC-0001).
test_deny_merge_request_findings_reasons_are_indistinguishable if {
	cross_tenant := authz.decision.reason with input as object.union(
		mr_findings_request("member"),
		{"subject": {"id": "u-mrf", "roles": ["member"], "tenant_id": "globex"}},
	)
	reader_mr := authz.decision.reason with input as mr_findings_request("reader")
	cross_tenant == reader_mr
}

# --- T-0025 / SPEC-0029 / SPEC-0030: security merge gate on attributed findings -----------------

# merge_gate_request builds a merge_request.merge request that already satisfies
# the SPEC-0019 approval gate (2 of 1 required) and engages the security findings
# gate (findings_gate="true"). The caller merges in the findings facts under test,
# so a failure names the findings dimension responsible. With approvals already
# sufficient, any denial below is attributable to the security gate itself.
merge_gate_request(findings_context) := object.union(
	{
		"tenant_id": "acme",
		"subject": {"id": "u-sec", "roles": ["member"], "tenant_id": "acme"},
		"action": "merge_request.merge",
		"resource": {"type": "merge_request", "id": "mr-1"},
		"context": {"valid_approvals": "2", "required_approvals": "1", "findings_gate": "true"},
	},
	{"context": findings_context},
)

# Severity-threshold boundary (threshold is HIGH). Below the threshold an
# attributed finding does not block...
test_allow_merge_below_severity_threshold if {
	every sev in ["LOW", "MEDIUM"] {
		authz.allow with input as merge_gate_request({"findings_highest_severity": sev})
	}
}

# ...a gate engaged with a clean scan (no attributed findings) does not block...
test_allow_merge_findings_gate_with_no_attributed_findings if {
	authz.allow with input as merge_gate_request({"findings_highest_severity": "NONE"})
}

# ...and AT or ABOVE the threshold it blocks (SPEC-0029 AC3). HIGH is the
# boundary itself: it must deny, and CRITICAL above it must deny too.
test_deny_merge_at_severity_threshold if {
	not authz.allow with input as merge_gate_request({"findings_highest_severity": "HIGH"})
}

test_deny_merge_above_severity_threshold if {
	not authz.allow with input as merge_gate_request({"findings_highest_severity": "CRITICAL"})
}

# The block is attributable to the security gate, not to approvals: approvals are
# sufficient, so only the findings breach can explain the denial (SPEC-0029 AC3).
test_deny_merge_approvals_sufficient_but_findings_breach if {
	not authz.allow with input as merge_gate_request({"findings_highest_severity": "HIGH"})
}

# ACCEPT/FALSE_POSITIVE triage exemption (SPEC-0029 AC4): a breach covered by the
# relied-upon triage records does not block...
test_allow_merge_triage_exempts_a_breach if {
	authz.allow with input as merge_gate_request({
		"findings_highest_severity": "HIGH",
		"relied_upon_triage_ids": "triage-1",
	})
}

# ...and the decision records WHICH triage record it relied on.
test_decision_records_relied_upon_triage if {
	d := authz.decision with input as merge_gate_request({
		"findings_highest_severity": "HIGH",
		"relied_upon_triage_ids": "triage-1,triage-2",
	})
	d.allow == true
	d.relied_upon_triage == ["triage-1", "triage-2"]
}

# Without an exemption the decision records no relied-upon triage.
test_decision_relied_upon_triage_empty_without_exemption if {
	d := authz.decision with input as merge_gate_request({"findings_highest_severity": "MEDIUM"})
	d.relied_upon_triage == []
}

# Fail CLOSED (SPEC-0029 AC9, SPEC-0030 AC4): the gate engaged but its facts did
# not assemble. A missing findings_highest_severity...
test_deny_merge_findings_gate_missing_facts if {
	not authz.allow with input as merge_gate_request({})
}

# ...and a malformed one (not in the severity vocabulary) are both denials,
# never a fail-open default.
test_deny_merge_findings_gate_malformed_severity if {
	not authz.allow with input as merge_gate_request({"findings_highest_severity": "NOT_A_SEVERITY"})
}

# Composition with the approval gate (SPEC-0029 AC5): neither replaces the other.
# Findings clear, but no approvals -> still denied by the approval rule.
test_deny_merge_findings_clear_but_insufficient_approvals if {
	not authz.allow with input as {
		"tenant_id": "acme",
		"subject": {"id": "u-sec", "roles": ["member"], "tenant_id": "acme"},
		"action": "merge_request.merge",
		"resource": {"type": "merge_request", "id": "mr-1"},
		"context": {
			"valid_approvals": "0",
			"required_approvals": "1",
			"findings_gate": "true",
			"findings_highest_severity": "NONE",
		},
	}
}

# An imported approval never satisfies the requirement (ADR-0029 §4, SPEC-0029
# AC6): valid_approvals counts FIRST-PARTY approvals only, so a merge whose only
# approval is imported presents valid_approvals=0 and is denied. This is the
# structural proof — no context fact makes an imported approval count.
test_deny_merge_whose_only_approval_is_imported if {
	not authz.allow with input as {
		"tenant_id": "acme",
		"subject": {"id": "u-sec", "roles": ["member"], "tenant_id": "acme"},
		"action": "merge_request.merge",
		"resource": {"type": "merge_request", "id": "mr-1"},
		"context": {"valid_approvals": "0", "required_approvals": "1"},
	}
}

# No findings gate engaged: the SPEC-0019 approval behaviour is unchanged
# (backward compatibility — the security gate only applies when engaged).
test_allow_merge_without_findings_gate_unchanged if {
	authz.allow with input as {
		"tenant_id": "acme",
		"subject": {"id": "u-sec", "roles": ["member"], "tenant_id": "acme"},
		"action": "merge_request.merge",
		"resource": {"type": "merge_request", "id": "mr-1"},
		"context": {"valid_approvals": "1", "required_approvals": "1"},
	}
}

# Holding member in another tenant does not authorize the merge here
# (invariant 1); the denial is as coarse as every other (SPEC-0001).
test_deny_merge_gate_from_another_tenant if {
	not authz.allow with input as object.union(
		merge_gate_request({"findings_highest_severity": "MEDIUM"}),
		{"subject": {"id": "u-sec", "roles": ["member"], "tenant_id": "globex"}},
	)
}

# Security-gate denials are as indistinguishable as every other denial: a
# threshold breach and a fail-closed missing-fact receive the same reason.
test_deny_merge_gate_reasons_are_indistinguishable if {
	breach := authz.decision.reason with input as merge_gate_request({"findings_highest_severity": "HIGH"})
	fail_closed := authz.decision.reason with input as merge_gate_request({})
	breach == fail_closed
}

# --- T-0025 / SPEC-0030: policy dry-run and decision-read vocabulary ----------------------------

# policy.dryrun is asked about the tenant; policy.decision.read is asked about
# the decision record. Both are owner-only; the deny cases outnumber the allow
# cases on purpose — the mutation this section must catch is widening either to
# member or reader, or letting a repository grant answer a policy question.
policy_request(role, action, resource_type) := {
	"tenant_id": "acme",
	"subject": {"id": "u-policy", "roles": [role], "tenant_id": "acme"},
	"action": action,
	"resource": {"type": resource_type, "id": "acme"},
	"context": {},
}

test_allow_owner_policy_dryrun if {
	authz.allow with input as policy_request("owner", "policy.dryrun", "tenant")
}

test_allow_owner_policy_decision_read if {
	authz.allow with input as policy_request("owner", "policy.decision.read", "decision")
}

# Neither grant extends to member or reader (least privilege): a role that merges
# code has not thereby been granted the surface that dry-runs or audits the rules.
test_deny_member_and_reader_policy_actions if {
	every pair in [
		{"role": "member", "action": "policy.dryrun", "resource_type": "tenant"},
		{"role": "member", "action": "policy.decision.read", "resource_type": "decision"},
		{"role": "reader", "action": "policy.dryrun", "resource_type": "tenant"},
		{"role": "reader", "action": "policy.decision.read", "resource_type": "decision"},
	] {
		not authz.allow with input as policy_request(pair.role, pair.action, pair.resource_type)
	}
}

# The resource kind is load-bearing: a dry-run asked about a repository, or a
# decision read asked about a tenant, is not the question those grants answer —
# even for an owner.
test_deny_policy_dryrun_asked_about_a_repository if {
	not authz.allow with input as policy_request("owner", "policy.dryrun", "repository")
}

test_deny_policy_decision_read_asked_about_a_tenant if {
	not authz.allow with input as policy_request("owner", "policy.decision.read", "tenant")
}

test_deny_policy_decision_read_asked_about_a_merge_request if {
	not authz.allow with input as policy_request("owner", "policy.decision.read", "merge_request")
}

# Holding owner in another tenant does not authorize a dry-run here
# (invariant 1); the denial is as coarse as every other (SPEC-0001).
test_deny_policy_dryrun_from_another_tenant if {
	not authz.allow with input as object.union(
		policy_request("owner", "policy.dryrun", "tenant"),
		{"subject": {"id": "u-policy", "roles": ["owner"], "tenant_id": "globex"}},
	)
}

# No roles means no policy surface at all.
test_deny_policy_actions_with_no_roles if {
	every pair in [
		{"action": "policy.dryrun", "resource_type": "tenant"},
		{"action": "policy.decision.read", "resource_type": "decision"},
	] {
		not authz.allow with input as object.union(
			policy_request("owner", pair.action, pair.resource_type),
			{"subject": {"id": "u-policy", "roles": [], "tenant_id": "acme"}},
		)
	}
}

# Policy denials are as indistinguishable as every other denial: a reader's
# decision-read and a cross-tenant dry-run receive the same reason.
test_deny_policy_reasons_are_indistinguishable if {
	reader := authz.decision.reason with input as policy_request("reader", "policy.decision.read", "decision")
	cross_tenant := authz.decision.reason with input as object.union(
		policy_request("owner", "policy.dryrun", "tenant"),
		{"subject": {"id": "u-policy", "roles": ["owner"], "tenant_id": "globex"}},
	)
	reader == cross_tenant
}

# --- T-0026 / SPEC-0031 / SPEC-0032: evidence pack vocabulary -----------------------------------

# evidence.pack.generate is asked about the tenant (range bounds and repository
# scope travel as server-derived context, SPEC-0032); evidence.pack.read is
# asked about the pack itself. Both are owner-only in this vocabulary: a pack
# is the compliance owner's dated export of the tenant's control history
# (PR-17), and reading one is what T-0027's SPEC-0033 auditor grants will
# later gate — so the deny cases outnumber the allow cases on purpose. The
# mutations this section must catch are widening either action to member or
# reader, or letting a repository, import, decision or findings grant answer a
# pack question.
evidence_request(role, action, resource_type) := {
	"tenant_id": "acme",
	"subject": {"id": "u-evidence", "roles": [role], "tenant_id": "acme"},
	"action": action,
	"resource": {"type": resource_type, "id": "pack-1"},
	"context": {},
}

test_allow_owner_generates_an_evidence_pack if {
	authz.allow with input as evidence_request("owner", "evidence.pack.generate", "tenant")
}

test_allow_owner_reads_an_evidence_pack if {
	authz.allow with input as evidence_request("owner", "evidence.pack.read", "evidence_pack")
}

# Neither grant extends to member or reader (least privilege): a role that
# merges code has not thereby been granted the surface that exports its
# control evidence, nor the surface that reads a pack an auditor will later
# be granted scoped access to (SPEC-0031 AC5, SPEC-0033).
test_deny_member_and_reader_evidence_actions if {
	every pair in [
		{"role": "member", "action": "evidence.pack.generate", "resource_type": "tenant"},
		{"role": "member", "action": "evidence.pack.read", "resource_type": "evidence_pack"},
		{"role": "reader", "action": "evidence.pack.generate", "resource_type": "tenant"},
		{"role": "reader", "action": "evidence.pack.read", "resource_type": "evidence_pack"},
	] {
		not authz.allow with input as evidence_request(pair.role, pair.action, pair.resource_type)
	}
}

# The resource kind is load-bearing: a generation asked about a repository, or
# a pack read asked about a tenant, is not the question those grants answer —
# even for an owner.
test_deny_evidence_generate_asked_about_a_repository if {
	not authz.allow with input as evidence_request("owner", "evidence.pack.generate", "repository")
}

test_deny_evidence_read_asked_about_a_tenant if {
	not authz.allow with input as evidence_request("owner", "evidence.pack.read", "tenant")
}

test_deny_evidence_read_asked_about_a_repository if {
	not authz.allow with input as evidence_request("owner", "evidence.pack.read", "repository")
}

# An import grant and a policy-decision grant are not pack grants: the action
# vocabulary and the resource pinning together keep SPEC-0011's import surface
# and SPEC-0030's decision surface from being re-readable as evidence access.
test_deny_evidence_read_asked_about_an_import if {
	not authz.allow with input as evidence_request("owner", "evidence.pack.read", "import")
}

test_deny_evidence_read_asked_about_a_decision if {
	not authz.allow with input as evidence_request("owner", "evidence.pack.read", "decision")
}

# Holding owner in another tenant does not authorize a pack here
# (invariant 1): a pack can never span two tenants (SPEC-0031 AC6), and the
# denial is as coarse as every other (SPEC-0001).
test_deny_evidence_generate_from_another_tenant if {
	not authz.allow with input as object.union(
		evidence_request("owner", "evidence.pack.generate", "tenant"),
		{"subject": {"id": "u-evidence", "roles": ["owner"], "tenant_id": "globex"}},
	)
}

test_deny_evidence_read_from_another_tenant if {
	not authz.allow with input as object.union(
		evidence_request("owner", "evidence.pack.read", "evidence_pack"),
		{"subject": {"id": "u-evidence", "roles": ["owner"], "tenant_id": "globex"}},
	)
}

# No roles means no evidence surface at all: a principal without roles cannot
# request a pack nor read one, so neither a generation nor a retrieval can
# leak control history to it.
test_deny_evidence_actions_with_no_roles if {
	every pair in [
		{"action": "evidence.pack.generate", "resource_type": "tenant"},
		{"action": "evidence.pack.read", "resource_type": "evidence_pack"},
	] {
		not authz.allow with input as object.union(
			evidence_request("owner", pair.action, pair.resource_type),
			{"subject": {"id": "u-evidence", "roles": [], "tenant_id": "acme"}},
		)
	}
}

# repo.read must not carry evidence access: pinning that the repository grant
# and the pack surface stay separable, exactly as findings.read is.
test_deny_evidence_read_is_not_implied_by_repo_read if {
	not authz.allow with input as object.union(
		reader_request,
		{"action": "evidence.pack.read", "resource": {"type": "evidence_pack", "id": "pack-1"}},
	)
}

# Evidence denials are as indistinguishable as every other denial: a member's
# read and a cross-tenant generation receive the same reason, so probing the
# PDP cannot separate the causes (SPEC-0001).
test_deny_evidence_reasons_are_indistinguishable if {
	member_read := authz.decision.reason with input as evidence_request("member", "evidence.pack.read", "evidence_pack")
	cross_tenant := authz.decision.reason with input as object.union(
		evidence_request("owner", "evidence.pack.generate", "tenant"),
		{"subject": {"id": "u-evidence", "roles": ["owner"], "tenant_id": "globex"}},
	)
	member_read == cross_tenant
}

# --- T-0027 / SPEC-0033: scoped, read-only, time-boxed auditor grants ---------------------------

# An auditor reads a pack under a GRANT, not a role: the grant's validity — ID,
# state, tenant, expiry, range bounds, named packs — arrives as decision-time
# context facts the PEP supplies fresh on every request (SPEC-0033 AC7). Each
# deny test below mutates exactly one of those facts, so a failure names the
# dimension responsible. The deny cases outnumber the allow case on purpose:
# the mutation this section must catch is any rule that lets a revoked, expired,
# out-of-scope or cross-tenant grant answer a pack read, or that lets the
# auditor principal reach a repository or a write path.
auditor_grant_context := {
	"auditor_grant_id": "grant-1",
	"auditor_grant_state": "ACTIVE",
	"auditor_grant_tenant": "acme",
	"auditor_grant_expires_at": "2026-09-01T00:00:00Z",
	"auditor_grant_range_from": "2026-01-01T00:00:00Z",
	"auditor_grant_range_to": "2026-06-30T23:59:59Z",
	"auditor_grant_packs": "pack-1,pack-2",
	"pack_range_from": "2026-02-01T00:00:00Z",
	"pack_range_to": "2026-03-31T23:59:59Z",
	"decision_time": "2026-08-14T12:00:00Z",
}

auditor_pack_request(context) := {
	"tenant_id": "acme",
	"subject": {"id": "u-auditor", "roles": ["auditor"], "tenant_id": "acme"},
	"action": "evidence.pack.read",
	"resource": {"type": "evidence_pack", "id": "pack-1"},
	"context": context,
}

# The one thing an auditor principal may do: read a named pack, inside the
# grant's range, before its expiry, in the grant's tenant (SPEC-0033 AC1/AC5).
test_allow_auditor_reads_pack_under_valid_grant if {
	authz.allow with input as auditor_pack_request(auditor_grant_context)
}

# A second named pack reads too; the grant names it.
test_allow_auditor_reads_every_named_pack if {
	authz.allow with input as object.union(
		auditor_pack_request(auditor_grant_context),
		{"resource": {"type": "evidence_pack", "id": "pack-2"}},
	)
}

# The owner's pack read is unchanged: the role path needs no grant context, and
# the grant rule extends the same action rather than replacing it (SPEC-0033).
test_allow_owner_pack_read_is_unaffected_by_the_grant_rule if {
	authz.allow with input as evidence_request("owner", "evidence.pack.read", "evidence_pack")
}

# Expiry is a decision-time comparison, not a timer contract: once decision_time
# reaches the expiry the read is denied — without any operator action
# (SPEC-0033 AC3).
test_deny_auditor_pack_read_at_expiry if {
	not authz.allow with input as auditor_pack_request(
		object.union(auditor_grant_context, {"decision_time": "2026-09-01T00:00:00Z"}),
	)
}

test_deny_auditor_pack_read_after_expiry if {
	not authz.allow with input as auditor_pack_request(
		object.union(auditor_grant_context, {"decision_time": "2026-09-02T12:00:00Z"}),
	)
}

# The server-rendered EXPIRED state is a denial too, whichever fact lands first.
test_deny_auditor_pack_read_with_expired_state if {
	not authz.allow with input as auditor_pack_request(
		object.union(auditor_grant_context, {"auditor_grant_state": "EXPIRED"}),
	)
}

# Revocation is immediate (SPEC-0033 AC7): the state arrives fresh at decision
# time, so a revoked grant fails this decision — no cache cycle, no token.
test_deny_auditor_pack_read_with_revoked_grant if {
	not authz.allow with input as auditor_pack_request(
		object.union(auditor_grant_context, {"auditor_grant_state": "REVOKED"}),
	)
}

# A pack the grant does not name is out of scope, whatever its range
# (SPEC-0033 AC6).
test_deny_auditor_pack_read_of_unnamed_pack if {
	not authz.allow with input as object.union(
		auditor_pack_request(auditor_grant_context),
		{"resource": {"type": "evidence_pack", "id": "pack-3"}},
	)
}

# A pack whose range escapes the grant's range is out of scope, even when
# named: the grant's bounds are a conjunct, not a suggestion.
test_deny_auditor_pack_read_with_out_of_scope_range if {
	not authz.allow with input as auditor_pack_request(
		object.union(auditor_grant_context, {"pack_range_to": "2026-07-31T23:59:59Z"}),
	)
}

test_deny_auditor_pack_read_with_out_of_scope_range_start if {
	not authz.allow with input as auditor_pack_request(
		object.union(auditor_grant_context, {"pack_range_from": "2025-12-01T00:00:00Z"}),
	)
}

# Grant absent: no facts assembled means fail closed (SPEC-0033 non-functional).
test_deny_auditor_pack_read_with_no_grant if {
	not authz.allow with input as auditor_pack_request({})
}

# Fail CLOSED on malformed facts: a missing decision_time or an unparseable
# expiry is a denial, never a fail-open default.
test_deny_auditor_pack_read_with_missing_decision_time if {
	not authz.allow with input as auditor_pack_request(
		json.remove(auditor_grant_context, ["decision_time"]),
	)
}

test_deny_auditor_pack_read_with_malformed_expiry if {
	not authz.allow with input as auditor_pack_request(
		object.union(auditor_grant_context, {"auditor_grant_expires_at": "not-an-instant"}),
	)
}

# A grant issued for another tenant authorizes nothing here (invariant 1),
# even when every other fact is valid.
test_deny_auditor_pack_read_with_grant_for_another_tenant if {
	not authz.allow with input as auditor_pack_request(
		object.union(auditor_grant_context, {"auditor_grant_tenant": "globex"}),
	)
}

# Holding the auditor role in another tenant is not holding it here.
test_deny_auditor_pack_read_from_another_tenant_subject if {
	not authz.allow with input as object.union(
		auditor_pack_request(auditor_grant_context),
		{"subject": {"id": "u-auditor", "roles": ["auditor"], "tenant_id": "globex"}},
	)
}

# The grant confers NO repository read (SPEC-0033 AC1): the coarse denial is
# the proof, and it is the same denial as every other.
test_deny_auditor_repo_read if {
	not authz.allow with input as {
		"tenant_id": "acme",
		"subject": {"id": "u-auditor", "roles": ["auditor"], "tenant_id": "acme"},
		"action": "repo.read",
		"resource": {"type": "repository", "id": "repo-1"},
		"context": {},
	}
}

# The grant is read-only (SPEC-0033 AC2): every write path — repository,
# triage, import, pack generation, grant management itself — is denied for an
# auditor principal. Each pair asks the action about the resource kind it is
# pinned to, so every denial holds for the right reason.
test_deny_auditor_every_write_path if {
	every pair in [
		{"action": "repo.write", "resource_type": "repository"},
		{"action": "merge_request.open", "resource_type": "repository"},
		{"action": "findings.ingest", "resource_type": "repository"},
		{"action": "findings.triage", "resource_type": "finding"},
		{"action": "repository.import", "resource_type": "repository"},
		{"action": "evidence.pack.generate", "resource_type": "tenant"},
		{"action": "auditor.grant.manage", "resource_type": "tenant"},
	] {
		not authz.allow with input as {
			"tenant_id": "acme",
			"subject": {"id": "u-auditor", "roles": ["auditor"], "tenant_id": "acme"},
			"action": pair.action,
			"resource": {"type": pair.resource_type, "id": "acme"},
			"context": {},
		}
	}
}

# A valid grant changes nothing about the write paths: grant facts ride on
# evidence.pack.read decisions only, and cannot widen any other question.
test_deny_auditor_writes_even_with_grant_context if {
	not authz.allow with input as {
		"tenant_id": "acme",
		"subject": {"id": "u-auditor", "roles": ["auditor"], "tenant_id": "acme"},
		"action": "auditor.grant.manage",
		"resource": {"type": "tenant", "id": "acme"},
		"context": auditor_grant_context,
	}
}

# auditor.grant.manage is asked about the tenant; the resource kind is
# load-bearing, even for an owner.
test_deny_grant_manage_asked_about_a_repository if {
	not authz.allow with input as {
		"tenant_id": "acme",
		"subject": {"id": "u-owner", "roles": ["owner"], "tenant_id": "acme"},
		"action": "auditor.grant.manage",
		"resource": {"type": "repository", "id": "repo-1"},
		"context": {},
	}
}

# Grant management is owner-only: issuing, revoking and listing grants is the
# act that widens an auditor's scope, and only the tenant's accountable role
# may make it (SPEC-0033 AC8 — no self-extension).
test_allow_owner_manages_auditor_grants if {
	authz.allow with input as {
		"tenant_id": "acme",
		"subject": {"id": "u-owner", "roles": ["owner"], "tenant_id": "acme"},
		"action": "auditor.grant.manage",
		"resource": {"type": "tenant", "id": "acme"},
		"context": {},
	}
}

test_deny_non_owner_grant_management if {
	every role in ["member", "reader", "auditor"] {
		not authz.allow with input as {
			"tenant_id": "acme",
			"subject": {"id": "u-nonowner", "roles": [role], "tenant_id": "acme"},
			"action": "auditor.grant.manage",
			"resource": {"type": "tenant", "id": "acme"},
			"context": {},
		}
	}
}

test_deny_grant_management_from_another_tenant if {
	not authz.allow with input as {
		"tenant_id": "acme",
		"subject": {"id": "u-owner", "roles": ["owner"], "tenant_id": "globex"},
		"action": "auditor.grant.manage",
		"resource": {"type": "tenant", "id": "acme"},
		"context": {},
	}
}

# Auditor denials are as indistinguishable as every other denial (SPEC-0001,
# SPEC-0033 AC6): a revoked grant, an absent grant, an out-of-scope pack and a
# repository read all receive the same reason, so probing the PDP cannot
# separate "grant existed but was revoked" from "no such grant" — the very
# distinction that would enumerate grants.
test_deny_auditor_reasons_are_indistinguishable if {
	revoked := authz.decision.reason with input as auditor_pack_request(
		object.union(auditor_grant_context, {"auditor_grant_state": "REVOKED"}),
	)
	absent := authz.decision.reason with input as auditor_pack_request({})
	unnamed_pack := authz.decision.reason with input as object.union(
		auditor_pack_request(auditor_grant_context),
		{"resource": {"type": "evidence_pack", "id": "pack-3"}},
	)
	repo_read := authz.decision.reason with input as {
		"tenant_id": "acme",
		"subject": {"id": "u-auditor", "roles": ["auditor"], "tenant_id": "acme"},
		"action": "repo.read",
		"resource": {"type": "repository", "id": "repo-1"},
		"context": {},
	}
	revoked == absent
	absent == unnamed_pack
	unnamed_pack == repo_read
}

# --- T-0030 / SPEC-0038: agent enrolment and data-plane operator actions -----------------------

# The control-plane operator surface asks the PDP about four actions (invariant
# 2): enrolment-token issue/revoke are asked about the enrolment token, and
# dataplane revoke/read are asked about the data-plane registry record. All
# four are owner-only: token issuance mints a data-plane certificate and
# revocation is what makes a revoked certificate stop connecting (SPEC-0038
# AC5), so the deny cases outnumber the allow cases on purpose — the mutation
# this section must catch is widening any of them to member or reader, or
# letting a repository, PAT, or evidence grant answer an agent question.
agent_request(role, action, resource_type) := {
	"tenant_id": "acme",
	"subject": {"id": "u-agent", "roles": [role], "tenant_id": "acme"},
	"action": action,
	"resource": {"type": resource_type, "id": "dp-1"},
	"context": {},
}

# The owner administers the whole agent lifecycle: issuing and revoking
# enrolment tokens, revoking a data plane, and reading the registry states
# AC8's operator visibility is about.
test_allow_owner_agent_enrolment_token_lifecycle if {
	every action in {"agent.enrolment_token.issue", "agent.enrolment_token.revoke"} {
		authz.allow with input as agent_request("owner", action, "enrolment_token")
	}
}

test_allow_owner_agent_dataplane_lifecycle if {
	every action in {"agent.dataplane.revoke", "agent.dataplane.read"} {
		authz.allow with input as agent_request("owner", action, "data_plane")
	}
}

# No grant extends to member or reader (least privilege): a role that pushes
# code or reads text has not thereby been granted the surface that mints or
# revokes machine identity (SPEC-0038 AC5), nor the registry the operator
# reads (SPEC-0038 AC8).
test_deny_member_and_reader_agent_actions if {
	every pair in [
		{"role": "member", "action": "agent.enrolment_token.issue", "resource_type": "enrolment_token"},
		{"role": "member", "action": "agent.enrolment_token.revoke", "resource_type": "enrolment_token"},
		{"role": "member", "action": "agent.dataplane.revoke", "resource_type": "data_plane"},
		{"role": "member", "action": "agent.dataplane.read", "resource_type": "data_plane"},
		{"role": "reader", "action": "agent.enrolment_token.issue", "resource_type": "enrolment_token"},
		{"role": "reader", "action": "agent.enrolment_token.revoke", "resource_type": "enrolment_token"},
		{"role": "reader", "action": "agent.dataplane.revoke", "resource_type": "data_plane"},
		{"role": "reader", "action": "agent.dataplane.read", "resource_type": "data_plane"},
	] {
		not authz.allow with input as agent_request(pair.role, pair.action, pair.resource_type)
	}
}

# The auditor principal reaches nothing of the agent surface either: the grant
# rule reads evidence packs and nothing else (SPEC-0033 AC1/AC2).
test_deny_auditor_agent_actions if {
	every pair in [
		{"action": "agent.enrolment_token.issue", "resource_type": "enrolment_token"},
		{"action": "agent.dataplane.revoke", "resource_type": "data_plane"},
		{"action": "agent.dataplane.read", "resource_type": "data_plane"},
	] {
		not authz.allow with input as {
			"tenant_id": "acme",
			"subject": {"id": "u-auditor", "roles": ["auditor"], "tenant_id": "acme"},
			"action": pair.action,
			"resource": {"type": pair.resource_type, "id": "dp-1"},
			"context": {},
		}
	}
}

# The resource kind is load-bearing: a token issue asked about the tenant, or
# a dataplane read asked about a repository, is not the question those grants
# answer — even for an owner.
test_deny_token_issue_asked_about_a_tenant if {
	not authz.allow with input as agent_request("owner", "agent.enrolment_token.issue", "tenant")
}

test_deny_token_revoke_asked_about_a_personal_access_token if {
	not authz.allow with input as agent_request("owner", "agent.enrolment_token.revoke", "personal_access_token")
}

test_deny_dataplane_revoke_asked_about_a_repository if {
	not authz.allow with input as agent_request("owner", "agent.dataplane.revoke", "repository")
}

test_deny_dataplane_read_asked_about_a_tenant if {
	not authz.allow with input as agent_request("owner", "agent.dataplane.read", "tenant")
}

# Holding owner in another tenant does not authorize an enrolment act here
# (invariant 1); a data plane's certificate is tenant-bound (SPEC-0038 AC3,
# AC9), and the denial is as coarse as every other (SPEC-0001).
test_deny_agent_actions_from_another_tenant if {
	every pair in [
		{"action": "agent.enrolment_token.issue", "resource_type": "enrolment_token"},
		{"action": "agent.dataplane.revoke", "resource_type": "data_plane"},
	] {
		not authz.allow with input as object.union(
			agent_request("owner", pair.action, pair.resource_type),
			{"subject": {"id": "u-agent", "roles": ["owner"], "tenant_id": "globex"}},
		)
	}
}

# No roles means no agent surface at all: a principal without roles can mint
# no token and read no registry state.
test_deny_agent_actions_with_no_roles if {
	every pair in [
		{"action": "agent.enrolment_token.issue", "resource_type": "enrolment_token"},
		{"action": "agent.dataplane.read", "resource_type": "data_plane"},
	] {
		not authz.allow with input as object.union(
			agent_request("owner", pair.action, pair.resource_type),
			{"subject": {"id": "u-agent", "roles": [], "tenant_id": "acme"}},
		)
	}
}

# repo.read must not carry agent access: a reader's repository grant cannot
# be re-read as a dataplane registry read.
test_deny_dataplane_read_is_not_implied_by_repo_read if {
	not authz.allow with input as object.union(
		reader_request,
		{"action": "agent.dataplane.read", "resource": {"type": "data_plane", "id": "dp-1"}},
	)
}

# Agent denials are as indistinguishable as every other denial: a member's
# token issue and a cross-tenant dataplane revoke receive the same reason,
# so probing the PDP cannot separate the causes (SPEC-0001).
test_deny_agent_reasons_are_indistinguishable if {
	member_issue := authz.decision.reason with input as agent_request("member", "agent.enrolment_token.issue", "enrolment_token")
	cross_tenant := authz.decision.reason with input as object.union(
		agent_request("owner", "agent.dataplane.revoke", "data_plane"),
		{"subject": {"id": "u-agent", "roles": ["owner"], "tenant_id": "globex"}},
	)
	member_issue == cross_tenant
}

# --- T-0033 / SPEC-0040: residency declaration is an owner-only control-plane act ---------------

# The residency declaration is control-plane state (SPEC-0040 AC1): setting it
# is asked about the tenant, with the cloud and region it sets carried as
# server-derived context.
residency_request(role, resource_type) := {
	"tenant_id": "acme",
	"subject": {"id": "u-residency", "roles": [role], "tenant_id": "acme"},
	"action": "residency.declaration.set",
	"resource": {"type": resource_type, "id": "acme"},
	"context": {"cloud": "gke", "region": "europe-west1"},
}

# The owner sets the tenant's residency declaration.
test_allow_owner_residency_declaration_set if {
	authz.allow with input as residency_request("owner", "tenant")
}

# No grant extends to member, reader or the auditor principal: a role that
# pushes code, reads text or audits evidence has not thereby been granted the
# surface that moves where the tenant's data must live (SPEC-0040 AC1, AC7 —
# the same principal the declaration must never be self-serviceable by is the
# customer itself).
test_deny_member_reader_auditor_residency_declaration_set if {
	every role in {"member", "reader", "auditor"} {
		not authz.allow with input as residency_request(role, "tenant")
	}
}

# The resource kind is load-bearing: a declaration asked about a repository or
# a data plane is not the question this grant answers — even for an owner.
test_deny_residency_declaration_set_asked_about_a_repository if {
	not authz.allow with input as residency_request("owner", "repository")
}

test_deny_residency_declaration_set_asked_about_a_data_plane if {
	not authz.allow with input as residency_request("owner", "data_plane")
}

# Holding owner in another tenant does not authorize a declaration here
# (invariant 1), and a principal without roles sets nothing.
test_deny_residency_declaration_set_from_another_tenant if {
	not authz.allow with input as object.union(
		residency_request("owner", "tenant"),
		{"subject": {"id": "u-residency", "roles": ["owner"], "tenant_id": "globex"}},
	)
}

test_deny_residency_declaration_set_with_no_roles if {
	not authz.allow with input as object.union(
		residency_request("owner", "tenant"),
		{"subject": {"id": "u-residency", "roles": [], "tenant_id": "acme"}},
	)
}

# Denials stay coarse: a member's declaration attempt and a cross-tenant one
# receive the same reason, so probing the PDP cannot separate the causes
# (SPEC-0001).
test_deny_residency_reasons_are_indistinguishable if {
	member_set := authz.decision.reason with input as residency_request("member", "tenant")
	cross_tenant := authz.decision.reason with input as object.union(
		residency_request("owner", "tenant"),
		{"subject": {"id": "u-residency", "roles": ["owner"], "tenant_id": "globex"}},
	)
	member_set == cross_tenant
}

# --- T-0034 / SPEC-0041: the fair-use usage view is a tenant-scoped read -------------------------

# The usage view is the tenant's own commercial state (PR-23): the counters
# and envelope conditions the control plane derives from received telemetry.
# It is a read granted to owner and member, asked about the tenant.
usage_request(role, resource_type) := {
	"tenant_id": "acme",
	"subject": {"id": "u-usage", "roles": [role], "tenant_id": "acme"},
	"action": "usage.view.read",
	"resource": {"type": resource_type, "id": "acme"},
	"context": {},
}

# Owner and member read the usage view; the roles whose work the usage
# describes see it before an envelope is reached (PR-23, SPEC-0041 AC4).
test_allow_owner_and_member_usage_view_read if {
	every role in {"owner", "member"} {
		authz.allow with input as usage_request(role, "tenant")
	}
}

# Reader and auditor do not: a role granted to read repository text or to
# read evidence under a grant has not thereby been granted the tenant's
# metering (least privilege).
test_deny_reader_and_auditor_usage_view_read if {
	every role in {"reader", "auditor"} {
		not authz.allow with input as usage_request(role, "tenant")
	}
}

# The resource kind is load-bearing: a usage view read asked about a
# repository or a data plane is not the question this grant answers — even
# for an owner.
test_deny_usage_view_read_asked_about_a_repository if {
	not authz.allow with input as usage_request("owner", "repository")
}

test_deny_usage_view_read_asked_about_a_data_plane if {
	not authz.allow with input as usage_request("owner", "data_plane")
}

# Holding member in another tenant does not authorize a usage view read here
# (invariant 1): usage is tenant-bound metering state.
test_deny_usage_view_read_from_another_tenant if {
	not authz.allow with input as object.union(
		usage_request("member", "tenant"),
		{"subject": {"id": "u-usage", "roles": ["member"], "tenant_id": "globex"}},
	)
}

# --- T-0038 / SPEC-0043 AC7 / ADR-0067: a tenant-scoped platform operator may declare -----------

# A verified platform_operator principal — the ADR-0046 binding shape, reused
# without a new role — declares for the tenant it is bound to, beside the
# owner grant which stands unchanged (ADR-0067 decision 1). The request shape
# is the T-0033 section's residency_request: no tenant claim travels in it
# beyond the decision's scope, and the subject's tenant is the binding's.
test_allow_platform_operator_residency_declaration_set if {
	authz.allow with input as residency_request("platform_operator", "tenant")
}

# The owner grant is unchanged by AC7: owner still declares on its own
# tenant, and the platform-operator rule adds nothing to, and takes nothing
# from, the table grant (ADR-0067 decision 1, tested both directions).
test_allow_owner_residency_declaration_set_still_granted if {
	authz.allow with input as residency_request("owner", "tenant")
}

# Every tenant role that is not owner stays denied under AC7: the platform
# operator sits BESIDE the owner, not above the membership roles. member,
# reader and auditor keep the T-0033 denials; platform_operator is the only
# addition (ADR-0067 decision 5).
test_deny_every_non_owner_tenant_role_residency_declaration_set if {
	every role in {"member", "reader", "auditor"} {
		not authz.allow with input as residency_request(role, "tenant")
	}
}

# Denied on tenant mismatch: the grant holds only where the principal's
# tenant equals the tenant the declaration is about (ADR-0046 decision 2,
# ADR-0067 decision 2). There is no cross-tenant path — a binding to one
# tenant is not a binding to another, whatever the request asks about.
test_deny_platform_operator_residency_declaration_set_on_another_tenant if {
	not authz.allow with input as object.union(
		residency_request("platform_operator", "tenant"),
		{"subject": {"id": "u-residency", "roles": ["platform_operator"], "tenant_id": "globex"}},
	)
}

# Denied on any resource kind but the tenant: the declaration is tenant
# state, and asking about a repository or a data plane is not the question
# the grant answers (ADR-0067 decision 5).
test_deny_platform_operator_residency_declaration_set_asked_about_a_repository if {
	not authz.allow with input as residency_request("platform_operator", "repository")
}

test_deny_platform_operator_residency_declaration_set_asked_about_a_data_plane if {
	not authz.allow with input as residency_request("platform_operator", "data_plane")
}

# The role stays narrow (ADR-0046 decision 4, ADR-0067 decision 4): holding
# platform_operator grants the declaration action and nothing else — no
# repository read or write, no tenant administration surface, no credential
# issuance, no policy authoring, no evidence or metering read. The role has
# no entry in the role table, and these denials are what that buys.
platform_operator_probe(action, resource_type) := {
	"tenant_id": "acme",
	"subject": {"id": "u-platform-operator", "roles": ["platform_operator"], "tenant_id": "acme"},
	"action": action,
	"resource": {"type": resource_type, "id": "probed"},
	"context": {},
}

test_deny_platform_operator_everything_but_the_declaration if {
	not authz.allow with input as platform_operator_probe("repo.read", "repository")
	not authz.allow with input as platform_operator_probe("repo.write", "repository")
	not authz.allow with input as platform_operator_probe("repo.admin", "repository")
	not authz.allow with input as platform_operator_probe("repository.import", "repository")
	not authz.allow with input as platform_operator_probe("identity.pat.issue", "personal_access_token")
	not authz.allow with input as platform_operator_probe("policy.dryrun", "tenant")
	not authz.allow with input as platform_operator_probe("policy.decision.read", "decision")
	not authz.allow with input as platform_operator_probe("evidence.pack.generate", "tenant")
	not authz.allow with input as platform_operator_probe("auditor.grant.manage", "tenant")
	not authz.allow with input as platform_operator_probe("agent.dataplane.read", "data_plane")
	not authz.allow with input as platform_operator_probe("usage.view.read", "tenant")
	not authz.allow with input as platform_operator_probe("search.query", "tenant")
}

# Denials stay coarse under AC7 too: a platform operator refused on tenant
# mismatch and a member refused on role receive the same reason, so probing
# the PDP cannot separate the causes (SPEC-0001, ADR-0067).
test_deny_platform_operator_reasons_are_indistinguishable if {
	member_set := authz.decision.reason with input as residency_request("member", "tenant")
	cross_tenant := authz.decision.reason with input as object.union(
		residency_request("platform_operator", "tenant"),
		{"subject": {"id": "u-residency", "roles": ["platform_operator"], "tenant_id": "globex"}},
	)
	member_set == cross_tenant
}

# ---------------------------------------------------------------------------
# The role vocabulary is closed  (SPEC-0058 AC5, ADR-0077 decision 2)
# ---------------------------------------------------------------------------
# ADR-0077 exists because an admin area is where privilege accumulates. Its
# second decision is that "admin" is not a new authorization primitive: an admin
# area asks the PDP the same way every other surface does, and never acquires a
# role that means "allowed everywhere".
#
# That decision is only expressible here. A UI cannot hold it, a contract cannot
# hold it, and a review will not catch it — an `admin` key in the table below
# would arrive looking like the obvious way to let the admin area work, and every
# existing test would stay green, because each of them asserts what a role CAN
# do. This is the same failure the denied_pairs matrix above was written for.
#
# So the vocabulary itself is pinned. Adding a role to authz.rego fails this
# test, which forces the decision back to an ADR rather than a diff.
test_role_vocabulary_is_exactly_the_three_tenant_roles if {
	object.keys(authz.role_actions) == {"owner", "member", "reader"}
}

# The admin area's fleet read is an EXISTING action, and only the owner has it.
# If a future surface needs a wider reader, that is a role decision, and this
# test is where it becomes visible.
#
# The request names the `data_plane` resource rather than the repository one that
# `as_role` builds: action_resource pins each action to the resource kind it may
# be asked about, so asking `agent.dataplane.read` about a repository is refused
# for that reason instead of the one under test.
fleet_request(role) := {
	"tenant_id": "acme",
	"subject": {"id": "u-fleet", "roles": [role], "tenant_id": "acme"},
	"action": "agent.dataplane.read",
	"resource": {"type": "data_plane", "id": "dp-1"},
	"context": {},
}

test_fleet_read_is_owner_only if {
	authz.allow with input as fleet_request("owner")
	not authz.allow with input as fleet_request("member")
	not authz.allow with input as fleet_request("reader")
}
