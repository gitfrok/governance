#!/usr/bin/env bash
# Governance fitness function: the shared surface must satisfy the schema policy it declares.
#
# contracts/ is the ONLY cross-context surface (ADR-0022) and all four consumers generate from it,
# so a bad shape here propagates everywhere before review can catch it. docs/process/ci-gates.md has
# marked "contract schema (additive / breaking-check)" a required check in four repos since it was
# written, and until T-0020 no such check existed anywhere — `buf` ran in no CI, and `buf lint` on
# contracts/ was red with 13 ENUM_VALUE_PREFIX violations (ADR-0032). This script is that check.
#
# Checks:
#   1. `buf lint` passes on contracts/ — the policy contracts/buf.yaml declares is the policy it meets
#   2. the gate is not vacuous: a fixture carrying the SAME policy plus one deliberate violation
#      must FAIL. A gate that cannot fail is not a gate (the T-0002/T-0009 pattern).
#   3. `buf breaking` passes against the baseline — no change to contracts/ breaks a v1 consumer
#   4. that gate is not vacuous either: an additive fixture must PASS while renumber, retype and
#      enum-rename fixtures must each FAIL on their specific rule. Both directions matter — a gate
#      that rejects everything is as useless as one that accepts everything, and only the pair shows
#      it distinguishes permitted evolution from wire corruption.
#   5. gitsaas.security.v1.Finding carries no triage field (SPEC-0027 AC7): triage is a resource
#      keyed by finding identity, and that shape — asserted against the COMPILED descriptor, not
#      grepped out of the source — is what makes "survives a re-scan" true by construction. The
#      paired fixture carries the defect and must be caught.
#   6. gitsaas.audit.v1's control-section record messages carry no field capable of holding an
#      attested imported record (SPEC-0032 AC2, inheriting T-0018 AC19 / SPEC-0011 AC14): no
#      provenance block, foreign handle, declared time, or import reference. Attested exclusion is
#      a TYPE PROPERTY of the schema — asserted against the COMPILED descriptor, exactly as check 5
#      does for triage — so the control claim cannot silently degrade at assembly time. The paired
#      fixture carries the defect and must be caught.
#   7. gitsaas.residency.v1 carries no tenant, actor or role field (SPEC-0043 AC6, ADR-0067): the
#      subject of a declaration is the verified principal on the call, never a message field — a
#      request field naming the tenant would be an unauthenticated routing claim (ADR-0045). The
#      absence is a TYPE PROPERTY of the package — asserted against the COMPILED descriptor, exactly
#      as checks 5 and 6 do — so the field cannot reappear as a convenience later. The paired
#      fixture carries the defect and must be caught.
#  16. gitsaas.repository.v1 carries no visibility, membership or policy field, and no delete verb
#      (SPEC-0057 AC11/AC12, ADR-0076): the accepted settings increment is name, description and
#      archival. Visibility and per-repository membership are authorization-model changes wearing a
#      form's clothing, branch protection and approval requirements are policy by PR-10, and
#      deletion is the one operation an operator cannot undo. A settings surface is where all four
#      arrive as the obvious next thing, so the absence is a TYPE PROPERTY. Paired with a fixture.
#  15. no gitsaas.release.v1 message carries an artifact (SPEC-0056 AC9, ADR-0075): the accepted
#      increment is tags and notes. An artifact field would arrive as "just a download URL" and
#      re-open signing, custody, retention and metering at once. Paired with a fixture.
#  14. gitsaas.policy.v1 carries no policy-authoring verb (SPEC-0055 AC2, ADR-0073): policies live
#      in governance/ and ADR-0001 makes governance the Source of Truth, so a write verb here is a
#      second source of truth for the same decisions. Paired with a fixture.
#  13. no gitsaas.ci.v1 message carries job output (SPEC-0054 AC8, ADR-0072): the ADR delivers
#      pipeline runs and defers log retention to its own decision. A log field arriving as a
#      convenience is how that deferral erodes, and it erodes quietly. Paired with a fixture.
#  12. gitsaas.repository.v1.CommitIdentity carries no platform principal (SPEC-0053 AC8): a
#      commit's author and committer are whatever the committer's git config said and git verifies
#      neither, so an actor_id or principal_id on that message would invite a consumer to render an
#      unverified string as an authenticated account — the line ADR-0029 already draws for an
#      imported record's declared_actor. Asserted against the COMPILED descriptor, and paired with
#      a fixture carrying the defect.
#   8. gitsaas.agent.v1.DesiredState carries BOTH trust bundles as distinct artifacts
#      (SPEC-0044 AC2 / SPEC-0045 AC2, Contracts touched): the CA trust bundle of ADR-0064
#      rides as ca_trust_bundle and the release trust bundle of ADR-0044/ADR-0065 rides as
#      release_trust_bundle — each on its own field with its own type, and neither bundle
#      type may carry the other's vocabulary (SPEC-0045's two-bundles note: never one field
#      or one type standing for both). All halves are TYPE PROPERTIES — asserted against the
#      COMPILED descriptor, exactly as checks 5 to 7 do. The paired fixtures carry the
#      defects — one bundle missing, and one bundle type carrying the other's vocabulary —
#      and must each be caught.
#   9. gitsaas.agent.v1.DesiredStateAck carries a payload-kind discriminator
#      (SPEC-0045's two-bundles note, extended to the ack path): the reconcile channel
#      delivers several desired-state artifacts whose generations are independent revision
#      spaces, so an ack that does not say WHICH artifact it answers cannot be attributed
#      to the right applied-state registry, and a forward-only GREATEST upsert would make
#      the pollution uncorrectable. The discriminator is a TYPE PROPERTY — asserted against
#      the COMPILED descriptor, exactly as checks 5 to 8 do. The paired fixture is an ack
#      with no discriminator and must be caught.
#  10. gitsaas.agent.v1.EnrolmentService carries the IssueEnrolmentToken operator door
#      (SPEC-0038 AC1, T-0030 lineage): the separately env-gated, PAT-verified surface
#      that mints the one-time token Enrol presents — with the domain's wire shape: a
#      lifetime-only request (tenant and actor are the verified principal on the call,
#      never fields, as the residency Declare door's check 7 demands of its package) and
#      a response carrying token_id, one_time_token, issued_at and expires_at — the token
#      record the domain returns, nothing more. Presence and shape are TYPE PROPERTIES —
#      asserted against the COMPILED descriptor, exactly as checks 5 to 9 do. The paired
#      fixture is a service with no RPC and must be caught.
#
# The baseline is the tip of main, overridable for local use. It is deliberately not a merge base:
# the question this asks is "does what I am about to merge break what is already released", and main
# is what is released.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v buf >/dev/null || { echo "buf not installed: https://buf.build/docs/installation"; exit 1; }

fail=0
report() { echo "CONTRACTS VIOLATION: $1"; fail=1; }

# Indent captured buf output so it reads as evidence under the report line rather than as new
# top-level noise. Parameter-expansion-free and shellcheck-clean (no `sed s///` on a variable).
indent() {
  while IFS= read -r line; do
    printf '          %s\n' "$line"
  done <<<"$1"
}

# --- 1. the real module -------------------------------------------------------------------------

if lint_out=$(buf lint contracts 2>&1); then
  echo "  ok    buf lint (contracts/)"
else
  report "buf lint failed on contracts/:"
  indent "$lint_out"
fi

# --- 2. the gate can fail -----------------------------------------------------------------------

# The fixture violates ENUM_VALUE_PREFIX under the same rule selection contracts/ uses. If this
# PASSES, either the policy stopped selecting that rule or lint is not running at all — both mean
# check 1 above proved nothing.
#
# --error-format=json because the assertion is on the *rule*, not on prose: buf's default output
# prints "should be prefixed with ..." and never names ENUM_VALUE_PREFIX, so matching the human
# message would silently pass if buf reworded it. The rule ID appears only in the JSON `type`.
fixture=scripts/testdata/lint-enum-prefix
if fixture_out=$(buf lint "$fixture" --error-format=json 2>&1); then
  report "the lint fixture $fixture PASSED — the gate is vacuous"
  if [ -n "$fixture_out" ]; then
    indent "$fixture_out"
  fi
elif ! grep -q 'ENUM_VALUE_PREFIX' <<<"$fixture_out"; then
  # It failed, but not for the reason the fixture exists. A syntax error would "fail" too, and
  # would quietly stop testing what this check is for.
  report "the lint fixture failed, but not on ENUM_VALUE_PREFIX:"
  indent "$fixture_out"
else
  echo "  ok    lint fixture rejected (ENUM_VALUE_PREFIX)"
fi

# --- 3. nothing breaks an existing v1 consumer --------------------------------------------------

# CI passes the remote-tracking ref explicitly. Locally, prefer origin/main and fall back to a local
# main, because a developer who has not fetched should get a clear instruction rather than a gate
# that quietly compares the branch against itself and always passes.
if [ -n "${CONTRACTS_BASELINE:-}" ]; then
  baseline="$CONTRACTS_BASELINE"
elif git rev-parse --verify --quiet origin/main >/dev/null; then
  baseline='.git#branch=origin/main,subdir=contracts'
elif git rev-parse --verify --quiet main >/dev/null; then
  baseline='.git#branch=main,subdir=contracts'
else
  echo "no baseline: neither origin/main nor main resolves. Run 'git fetch origin main', or set"
  echo "CONTRACTS_BASELINE (e.g. '.git#branch=origin/main,subdir=contracts')."
  exit 1
fi

if breaking_out=$(buf breaking contracts --against "$baseline" 2>&1); then
  echo "  ok    buf breaking (contracts/ vs $baseline)"
else
  report "buf breaking failed on contracts/ vs $baseline:"
  indent "$breaking_out"
fi

# --- 4. that gate can fail, and does not fail on everything --------------------------------------

base=scripts/testdata/breaking-base

# Additive must pass. If this fails, the gate blocks the evolution contracts/README.md explicitly
# permits, and people would start bumping to v2 for a new field.
if additive_out=$(buf breaking scripts/testdata/breaking-additive --against "$base" 2>&1); then
  echo "  ok    breaking fixture: additive field accepted"
else
  report "the additive fixture was REJECTED — the breaking gate is too strict:"
  indent "$additive_out"
fi

# The three mutations AC3 names, each with the rule buf actually reports for it. The rule IDs were
# read off buf 1.72.0 rather than guessed — a renumber, for instance, surfaces as FIELD_NO_DELETE
# (tag 2 is gone) and not as any "same number" rule. Asserting the ID rather than the prose is the
# same discipline as the lint fixture: buf's messages are not a stable contract.
#
# ENUM_VALUE_SAME_NAME is worth noticing: it is exactly the rule that would have rejected T-0020's
# own rename. Once this gate is live, ADR-0032's choice is enforced rather than merely recorded.
while IFS='|' read -r dir rule label; do
  [ -n "$dir" ] || continue
  if out=$(buf breaking "scripts/testdata/$dir" --against "$base" --error-format=json 2>&1); then
    report "the $dir fixture PASSED — the breaking gate is vacuous for: $label"
    if [ -n "$out" ]; then
      indent "$out"
    fi
  elif ! grep -q "$rule" <<<"$out"; then
    report "the $dir fixture failed, but not on $rule:"
    indent "$out"
  else
    echo "  ok    breaking fixture: $label rejected ($rule)"
  fi
done <<'FIXTURES'
breaking-renumber|FIELD_NO_DELETE|renumbered field
breaking-retype|FIELD_SAME_TYPE|retyped field
breaking-enum-rename|ENUM_VALUE_SAME_NAME|renamed enum value
FIXTURES

# --- 5. the finding message carries no triage field (SPEC-0027 AC7) ------------------------------

# Triage is a separate resource keyed by finding identity; the finding message must gain no triage
# field, and "survives a re-scan" holds by construction rather than by a migration step
# (SPEC-0026 AC3, SPEC-0027 AC7). The check asks buf for the COMPILED descriptor of the Finding
# message rather than grepping the source: a field shows up in the descriptor whatever its name,
# type or spelling, and a proto that fails to compile fails this check loudly instead of passing
# by absence. --exclude-source-info keeps comments out of the image — the real Finding's doc
# comment mentions triage precisely to say it has none, and prose is not what is under test.
if image_out=$(buf build contracts --type gitsaas.security.v1.Finding --exclude-imports \
  --exclude-source-info -o -#format=json 2>&1); then
  if grep -qi 'triage' <<<"$image_out"; then
    report "gitsaas.security.v1.Finding carries a triage field — triage is a separate resource keyed by finding identity (SPEC-0027 AC7)"
  else
    echo "  ok    Finding carries no triage field (SPEC-0027 AC7)"
  fi
else
  report "could not compile gitsaas.security.v1.Finding for the triage-separation check:"
  indent "$image_out"
fi

# The fixture is the one shape the real Finding must never grow: a triage field on the finding
# itself. The same descriptor question asked of it must find the marker — a check that cannot
# fail is not a gate (the T-0002/T-0009 pattern).
fixture=scripts/testdata/finding-triage-field
if fixture_image=$(buf build "$fixture" --type gitsaas.security.v1.Finding --exclude-imports \
  --exclude-source-info -o -#format=json 2>&1); then
  if grep -qi 'triage' <<<"$fixture_image"; then
    echo "  ok    triage-field fixture caught (the Finding descriptor check can fail)"
  else
    report "the triage-field fixture compiled with no triage marker in its descriptor — the check is vacuous"
  fi
else
  report "the triage-field fixture did not compile:"
  indent "$fixture_image"
fi

# --- 16. repository/v1 carries no policy field and no delete verb (SPEC-0057 AC11/AC12) -------

# ADR-0076 accepted name, description and archival only. The other three settings the prototype
# shows are not features that were skipped: "public" is a different authorization model, per-repository
# membership is a new one the PDP would have to learn everywhere repo.read is asked, and branch
# protection and approval requirements are policy by PR-10 — "enforced server-side and expressed as
# policy, not UI toggles". A settings page is precisely where that sentence erodes, by a checkbox
# appearing where a user would look for one rather than by anyone deciding to break it. Deletion is
# ADR-0076 decision 3, and the registry's migration already revoked DELETE from the application role.
if image_out=$(buf build contracts --path contracts/proto/repository/v1 \
  --exclude-source-info -o -#format=json 2>&1); then
  # Field names are matched EXACTLY. actor_roles is a verified principal attribute on every read
  # context and must keep working; a bare "roles" match would have flagged it and the check would
  # have been deleted rather than fixed.
  if grep -qE '"name": *"(visibility|public|private|member|members|branch_protection|protected_branch|protected_branches|required_approvals|approval_rule|approval_rules|merge_rule|merge_rules|permissions)"' <<<"$image_out"; then
    report "gitsaas.repository.v1 carries a visibility, membership or policy field — outside ADR-0076's accepted increment (SPEC-0057 AC11)"
  else
    echo "  ok    repository/v1 carries no visibility, membership or policy field (SPEC-0057 AC11, ADR-0076)"
  fi
  if grep -oE '"name": *"Delete[A-Za-z]*"' <<<"$image_out" | grep -q .; then
    report "gitsaas.repository.v1 carries a delete verb — repository deletion is ADR-0076's deferred decision (SPEC-0057 AC12)"
  else
    echo "  ok    repository/v1 carries no delete verb (SPEC-0057 AC12, ADR-0076)"
  fi
else
  report "could not compile gitsaas.repository.v1 for the settings check:"
  indent "$image_out"
fi

fixture=scripts/testdata/repository-settings-policy-field
if fixture_image=$(buf build "$fixture" --exclude-source-info -o -#format=json 2>&1); then
  if grep -qE '"name": *"visibility"' <<<"$fixture_image" &&
    grep -qE '"name": *"DeleteRepository"' <<<"$fixture_image"; then
    echo "  ok    repository-settings fixture caught (the settings check can fail)"
  else
    report "the repository-settings fixture compiled without visibility and DeleteRepository in its descriptor — the check is vacuous"
  fi
else
  report "the repository-settings fixture did not compile:"
  indent "$fixture_image"
fi

# --- 15. no release message carries an artifact (SPEC-0056 AC9, ADR-0075) ---------------------

# ADR-0075 accepted the tags-and-notes increment ONLY. The moment this platform serves a
# downloadable artifact it is in a customer's supply chain, and signing, custody, retention and
# metering are a larger decision than the feature looks. An artifact field would arrive as an
# obvious addition — "just a download URL" — which is exactly why the absence is asserted against
# the compiled descriptor rather than left to memory.
if image_out=$(buf build contracts --path contracts/proto/release/v1 \
  --exclude-source-info -o -#format=json 2>&1); then
  if grep -qiE '"name": *"(artifact|artifacts|asset|assets|download_url|attachment|attachments|file|files)"' <<<"$image_out"; then
    report "gitsaas.release.v1 carries an artifact field — artifacts are outside ADR-0075's accepted increment (SPEC-0056 AC9)"
  else
    echo "  ok    release/v1 carries no artifact (SPEC-0056 AC9, ADR-0075)"
  fi
else
  report "could not compile gitsaas.release.v1 for the artifact check:"
  indent "$image_out"
fi

fixture=scripts/testdata/release-artifact-field
if fixture_image=$(buf build "$fixture" --exclude-source-info -o -#format=json 2>&1); then
  if grep -qE '"name": *"download_url"' <<<"$fixture_image"; then
    echo "  ok    release-artifact fixture caught (the artifact check can fail)"
  else
    report "the release-artifact fixture compiled with no download_url in its descriptor — the check is vacuous"
  fi
else
  report "the release-artifact fixture did not compile:"
  indent "$fixture_image"
fi

# --- 14. PolicyDecisionPoint has no authoring verb (SPEC-0055 AC2, ADR-0073) ------------------

# ADR-0073 records that policy authoring is structurally absent, not missing: policies live in
# governance/ and ADR-0001 makes governance the Source of Truth, so a write verb here would be a
# second source of truth for the same decisions. It would also arrive as a convenience — a "just an
# upload endpoint" — long before anyone decided how a tenant policy composes with the platform
# bundle. The question is asked of the COMPILED descriptor, so a verb counts whatever its comment
# claims.
if image_out=$(buf build contracts --path contracts/proto/policy/v1 \
  --exclude-source-info -o -#format=json 2>&1); then
  if grep -oE '"name": *"(Put|Create|Update|Delete|Author|Set|Write)[A-Za-z]*"' <<<"$image_out" | grep -q .; then
    report "gitsaas.policy.v1 carries a policy-authoring verb — a per-tenant policy source is ADR-0073's deferred decision (SPEC-0055 AC2)"
  else
    echo "  ok    PolicyDecisionPoint has no authoring verb (SPEC-0055 AC2, ADR-0073)"
  fi
else
  report "could not compile gitsaas.policy.v1 for the authoring-verb check:"
  indent "$image_out"
fi

fixture=scripts/testdata/policy-authoring-rpc
if fixture_image=$(buf build "$fixture" --exclude-source-info -o -#format=json 2>&1); then
  if grep -qE '"name": *"PutPolicy"' <<<"$fixture_image"; then
    echo "  ok    policy-authoring fixture caught (the authoring-verb check can fail)"
  else
    report "the policy-authoring fixture compiled with no PutPolicy in its descriptor — the check is vacuous"
  fi
else
  report "the policy-authoring fixture did not compile:"
  indent "$fixture_image"
fi

# --- 13. no CI message carries job output (SPEC-0054 AC8, ADR-0072) ---------------------------

# ADR-0072 delivers pipeline RUNS and defers job LOGS to their own decision, covering capture,
# redaction, retention, access and residency. A log field arriving here as a convenience is exactly
# how that deferral erodes, and it would erode quietly — nobody reviews a new string field twice.
# Asked of the COMPILED descriptor so a field counts whatever its type or comment says.
# Unlike checks 5 and 12, this one does NOT pass --exclude-imports: CIJob references
# google.protobuf.Timestamp, and excluding imports makes the type uncompilable rather than smaller.
# Including them is harmless here because the grep names specific field names, and Timestamp's are
# seconds and nanos.
if image_out=$(buf build contracts --type gitsaas.ci.v1.CIJob \
  --exclude-source-info -o -#format=json 2>&1); then
  if grep -qiE '"name": *"(log|logs|output|stdout|stderr|log_url|log_ref)"' <<<"$image_out"; then
    report "gitsaas.ci.v1.CIJob carries a job-output field — retaining job output is ADR-0072's deferred decision, not a field (SPEC-0054 AC8)"
  else
    echo "  ok    CIJob carries no job output (SPEC-0054 AC8, ADR-0072)"
  fi
else
  report "could not compile gitsaas.ci.v1.CIJob for the job-output check:"
  indent "$image_out"
fi

fixture=scripts/testdata/cijob-output-field
if fixture_image=$(buf build "$fixture" --type gitsaas.ci.v1.CIJob --exclude-imports \
  --exclude-source-info -o -#format=json 2>&1); then
  if grep -qiE '"name": *"logs"' <<<"$fixture_image"; then
    echo "  ok    cijob-output fixture caught (the CIJob descriptor check can fail)"
  else
    report "the cijob-output fixture compiled with no logs field in its descriptor — the check is vacuous"
  fi
else
  report "the cijob-output fixture did not compile:"
  indent "$fixture_image"
fi

# --- 12. CommitIdentity carries no platform principal (SPEC-0053 AC8) --------------------------

# Blame and history answer "who touched this line", and the answer is git's, not the platform's.
# A field named actor_id or principal_id on CommitIdentity would let a consumer render an
# unverified string as an authenticated account. The question is asked of the COMPILED descriptor
# so a field counts whatever its type or comment says.
if image_out=$(buf build contracts --type gitsaas.repository.v1.CommitIdentity --exclude-imports \
  --exclude-source-info -o -#format=json 2>&1); then
  if grep -qiE '"name": *"(actor_id|principal_id|user_id|account_id)"' <<<"$image_out"; then
    report "gitsaas.repository.v1.CommitIdentity carries a platform principal field — a commit author is git's word, not an authenticated actor (SPEC-0053 AC8)"
  else
    echo "  ok    CommitIdentity carries no platform principal (SPEC-0053 AC8)"
  fi
else
  report "could not compile gitsaas.repository.v1.CommitIdentity for the identity-separation check:"
  indent "$image_out"
fi

fixture=scripts/testdata/commit-identity-actor-field
if fixture_image=$(buf build "$fixture" --type gitsaas.repository.v1.CommitIdentity --exclude-imports \
  --exclude-source-info -o -#format=json 2>&1); then
  if grep -qiE '"name": *"actor_id"' <<<"$fixture_image"; then
    echo "  ok    commit-identity fixture caught (the CommitIdentity descriptor check can fail)"
  else
    report "the commit-identity fixture compiled with no actor_id in its descriptor — the check is vacuous"
  fi
else
  report "the commit-identity fixture did not compile:"
  indent "$fixture_image"
fi

# --- 6. control-section records cannot carry an attested record (SPEC-0032 AC2) -----------------

# A pack's control sections are a compliance claim, and admitting an attested imported record makes
# that claim false to an auditor (ADR-0029 §6, SPEC-0031 AC2 — the criterion T-0018 AC19 owed
# forward). SPEC-0032 makes the exclusion a TYPE PROPERTY: the control-section record messages have
# no field capable of carrying an attested record, and attested history is representable only in the
# labelled appendix (AttestedAppendix). The check asks buf for the COMPILED descriptors of the six
# control-side messages rather than grepping the source: a field shows up in the descriptor whatever
# its name, type or spelling, and a proto that fails to compile fails this check loudly instead of
# passing by absence. --exclude-source-info keeps comments out of the image — prose is not what is
# under test. Imports are deliberately KEPT (unlike check 5): the records reference
# google.protobuf.Timestamp, and keeping imports is what makes the check bite if a control record
# type ever references the Provenance descriptor — the appendix's import then lands in the image
# and the marker scan finds it. T-0033 adds ResidencyRecord to the checked set: SPEC-0040 AC7's
# first-party-only residency section holds by the same type property, so its record message must
# satisfy the same marker scan.
#
# The marker list is the vocabulary of attested content in this codebase (ADR-0029 §2's provenance
# block fields): an import reference, a provenance block, a declared foreign handle or time, or
# anything else attested or foreign. The word "source" is deliberately absent — legitimate
# control-side fields may speak of sources — but every shape that could carry an attested record
# must name one of the markers to do so. The well-known Timestamp descriptor the image also carries
# has none of the markers.
attested_markers='attested|provenance|import_id|declared|foreign|history_imported'

if image_out=$(buf build contracts \
  --type gitsaas.audit.v1.ControlSectionRecord \
  --type gitsaas.audit.v1.ApprovalRecord \
  --type gitsaas.audit.v1.PolicyDecisionRecord \
  --type gitsaas.audit.v1.ScanGateRecord \
  --type gitsaas.audit.v1.AccessChangeRecord \
  --type gitsaas.audit.v1.ResidencyRecord \
  --exclude-source-info -o -#format=json 2>&1); then
  if grep -Eiq "$attested_markers" <<<"$image_out"; then
    report "gitsaas.audit.v1 control-section records carry an attested-content field — attested records are representable only in the labelled appendix (SPEC-0032 AC2, ADR-0029 §6)"
  else
    echo "  ok    control-section records carry no attested-content field (SPEC-0032 AC2)"
  fi
else
  report "could not compile gitsaas.audit.v1 control-section records for the attested-exclusion check:"
  indent "$image_out"
fi

# The fixture is the one shape the real control-section record must never grow: attested-import
# fields on ControlSectionRecord itself. The same descriptor question asked of it must find the
# markers — a check that cannot fail is not a gate (the T-0002/T-0009 pattern).
fixture=scripts/testdata/evidence-attested-field
if fixture_image=$(buf build "$fixture" --type gitsaas.audit.v1.ControlSectionRecord \
  --exclude-source-info -o -#format=json 2>&1); then
  if grep -Eiq "$attested_markers" <<<"$fixture_image"; then
    echo "  ok    attested-field fixture caught (the control-section descriptor check can fail)"
  else
    report "the attested-field fixture compiled with no attested marker in its descriptor — the check is vacuous"
  fi
else
  report "the attested-field fixture did not compile:"
  indent "$fixture_image"
fi

# --- 7. the residency surface carries no subject field (SPEC-0043 AC6, ADR-0067) ----------------

# The subject of a residency declaration is the verified principal on the call: tenant, actor and
# roles come from the request context the verification step populates (ADR-0045), never from the
# request body. So no message in gitsaas.residency.v1 may carry a tenant, actor or role field —
# a field naming the tenant would be an unauthenticated routing claim, and AC7's platform-operator
# path is answered by who the principal is, not by a field (ADR-0067). The check asks buf for the
# COMPILED descriptors of the package's messages rather than grepping the source: a field shows up
# in the descriptor whatever its name, type or spelling, and a proto that fails to compile fails
# this check loudly instead of passing by absence. --exclude-source-info keeps comments out of the
# image — the real messages' doc comments name the subject precisely to say it is carried nowhere
# on this wire, and prose is not what is under test. Imports are deliberately KEPT (as in check 6):
# the response references google.protobuf.Timestamp, whose descriptor carries no subject marker.
subject_markers='tenant|actor|role'

if image_out=$(buf build contracts \
  --type gitsaas.residency.v1.DeclareResidencyRequest \
  --type gitsaas.residency.v1.DeclareResidencyResponse \
  --exclude-source-info -o -#format=json 2>&1); then
  if grep -Eiq "$subject_markers" <<<"$image_out"; then
    report "gitsaas.residency.v1 carries a tenant, actor or role field — the subject is the verified principal on the call, never a message field (SPEC-0043 AC6, ADR-0067)"
  else
    echo "  ok    residency/v1 carries no tenant, actor or role field (SPEC-0043 AC6)"
  fi
else
  report "could not compile gitsaas.residency.v1 for the subject-exclusion check:"
  indent "$image_out"
fi

# The fixture is the one shape the real residency messages must never grow: a subject claim on the
# declaration request. The same descriptor question asked of it must find the marker — a check
# that cannot fail is not a gate (the T-0002/T-0009 pattern).
fixture=scripts/testdata/residency-subject-field
if fixture_image=$(buf build "$fixture" --type gitsaas.residency.v1.DeclareResidencyRequest \
  --exclude-imports --exclude-source-info -o -#format=json 2>&1); then
  if grep -Eiq "$subject_markers" <<<"$fixture_image"; then
    echo "  ok    subject-field fixture caught (the residency descriptor check can fail)"
  else
    report "the subject-field fixture compiled with no subject marker in its descriptor — the check is vacuous"
  fi
else
  report "the subject-field fixture did not compile:"
  indent "$fixture_image"
fi

# --- 8. DesiredState carries BOTH trust bundles as distinct artifacts ----------------------

# SPEC-0044 AC2 distributes the staged CA trust bundle — the agent-identity trust roots of
# ADR-0064 — as ca_trust_bundle; SPEC-0045 AC2 distributes the staged RELEASE trust bundle —
# the cosign release-signing keys of ADR-0044/ADR-0065 — as release_trust_bundle. They are
# DIFFERENT artifacts (SPEC-0045's two-bundles note): both ride the reconcile path as desired
# state, each on its own field with its own type and its own monotonic bundle revision, and
# neither bundle type may carry the other's vocabulary. All halves are TYPE PROPERTIES
# asserted against the COMPILED descriptor, exactly as checks 5 to 7 do — the presence of
# BOTH fields on DesiredState, and the vocabulary separation of the two bundle types.
# --exclude-source-info keeps comments out of the image: the real messages' doc comments
# name the other bundle precisely to say they are not it, and prose is not what is under
# test. Imports are KEPT on the DesiredState question (as in checks 6 and 7): the bundle
# descriptors it pulls in are exactly what the marker scans below then inspect on their own.

if image_out=$(buf build contracts --type gitsaas.agent.v1.DesiredState \
  --exclude-source-info -o -#format=json 2>&1); then
  if ! grep -q 'ca_trust_bundle' <<<"$image_out"; then
    report "gitsaas.agent.v1.DesiredState carries no ca_trust_bundle field — the staged CA trust bundle rides the reconcile path as desired state (SPEC-0044 AC2)"
  elif ! grep -q 'release_trust_bundle' <<<"$image_out"; then
    report "gitsaas.agent.v1.DesiredState carries no release_trust_bundle field — the staged release trust bundle rides the reconcile path on its OWN field, never the CA bundle's (SPEC-0045 AC2)"
  else
    echo "  ok    DesiredState carries both ca_trust_bundle and release_trust_bundle (SPEC-0044, SPEC-0045)"
  fi
else
  report "could not compile gitsaas.agent.v1.DesiredState for the two-bundles check:"
  indent "$image_out"
fi

# Vocabulary separation: the CA bundle type carries no release naming, and the release bundle
# type carries no CA-artifact vocabulary (ca_trust naming, certificate_pem roots, an issuance
# root). Imports are KEPT (as on the DesiredState question): the CA root carries a
# google.protobuf.Timestamp expiry the image must include, and that well-known descriptor
# carries none of the markers either way.
ca_bundle_markers='release'
release_bundle_markers='ca_trust|certificate_pem|issuance_root'

if ca_image=$(buf build contracts --type gitsaas.agent.v1.CATrustBundle \
  --exclude-source-info -o -#format=json 2>&1); then
  if grep -Eiq "$ca_bundle_markers" <<<"$ca_image"; then
    report "gitsaas.agent.v1.CATrustBundle carries release-trust-bundle vocabulary — the two trust bundles never share or imply one another's type (SPEC-0045's two-bundles note)"
  else
    echo "  ok    CATrustBundle carries no release vocabulary (SPEC-0044, SPEC-0045)"
  fi
else
  report "could not compile gitsaas.agent.v1.CATrustBundle for the two-bundles check:"
  indent "$ca_image"
fi

if release_image=$(buf build contracts --type gitsaas.agent.v1.ReleaseTrustBundle \
  --exclude-source-info -o -#format=json 2>&1); then
  if grep -Eiq "$release_bundle_markers" <<<"$release_image"; then
    report "gitsaas.agent.v1.ReleaseTrustBundle carries CA-trust-bundle vocabulary — the release trust bundle is SPEC-0045's different artifact, with its own type"
  else
    echo "  ok    ReleaseTrustBundle carries no CA vocabulary (SPEC-0045)"
  fi
else
  report "could not compile gitsaas.agent.v1.ReleaseTrustBundle for the two-bundles check:"
  indent "$release_image"
fi

# The first fixture is the shape the real DesiredState must never degrade to: only ONE of the
# two bundles present, the release trust content left to ride the CA bundle's field. The same
# descriptor question asked of it must miss the release field — a check that cannot fail is
# not a gate (the T-0002/T-0009 pattern).
fixture=scripts/testdata/release-bundle-missing-field
if fixture_image=$(buf build "$fixture" --type gitsaas.agent.v1.DesiredState --exclude-imports \
  --exclude-source-info -o -#format=json 2>&1); then
  if ! grep -q 'release_trust_bundle' <<<"$fixture_image"; then
    echo "  ok    missing-release-field fixture caught (the two-bundles presence check can fail)"
  else
    report "the missing-release-field fixture compiled WITH a release_trust_bundle field — the presence check is vacuous"
  fi
else
  report "the missing-release-field fixture did not compile:"
  indent "$fixture_image"
fi

# The second fixture is the other shape the real bundle must never grow: a ReleaseTrustBundle
# carrying CA-artifact vocabulary. The same vocabulary question asked of it must find the
# marker — both failure modes of the two-bundles note are caught.
fixture=scripts/testdata/release-bundle-ca-vocabulary
if fixture_image=$(buf build "$fixture" --type gitsaas.agent.v1.ReleaseTrustBundle --exclude-imports \
  --exclude-source-info -o -#format=json 2>&1); then
  if grep -Eiq "$release_bundle_markers" <<<"$fixture_image"; then
    echo "  ok    CA-vocabulary fixture caught (the release-bundle descriptor check can fail)"
  else
    report "the CA-vocabulary fixture compiled with no CA marker in its descriptor — the check is vacuous"
  fi
else
  report "the CA-vocabulary fixture did not compile:"
  indent "$fixture_image"
fi

# --- 9. DesiredStateAck carries a payload-kind discriminator (SPEC-0045 two-bundles note) ----

# The reconcile channel delivers several desired-state artifacts — the CA trust bundle of
# SPEC-0044 and the release trust bundle of SPEC-0045 — whose generations are INDEPENDENT
# revision spaces (both start at 1). An ack that does not say which artifact it answers
# cannot be attributed: the control plane would record a CA bundle ack's generation into
# the release bundle's applied registry, and the registry's forward-only GREATEST upsert
# makes that pollution uncorrectable. So the ack carries a payload-kind discriminator — a
# TYPE PROPERTY asserted against the COMPILED descriptor, exactly as checks 5 to 8 do.
# --exclude-source-info keeps comments out of the image — prose is not what is under test.

if image_out=$(buf build contracts --type gitsaas.agent.v1.DesiredStateAck --exclude-imports \
  --exclude-source-info -o -#format=json 2>&1); then
  if ! grep -q 'kind' <<<"$image_out"; then
    report "gitsaas.agent.v1.DesiredStateAck carries no payload-kind discriminator — an ack must say WHICH desired-state artifact it answers, or its generation cannot be attributed to the right applied-state registry (SPEC-0045's two-bundles note, extended to the ack path)"
  else
    echo "  ok    DesiredStateAck carries a payload-kind discriminator (SPEC-0045)"
  fi
else
  report "could not compile gitsaas.agent.v1.DesiredStateAck for the ack-discriminator check:"
  indent "$image_out"
fi

# The fixture is the shape the real DesiredStateAck must never degrade back to: an ack with
# generation only and no discriminator. The same descriptor question asked of it must miss
# the kind field — a check that cannot fail is not a gate (the T-0002/T-0009 pattern).
fixture=scripts/testdata/desired-state-ack-no-kind
if fixture_image=$(buf build "$fixture" --type gitsaas.agent.v1.DesiredStateAck --exclude-imports \
  --exclude-source-info -o -#format=json 2>&1); then
  if ! grep -q 'kind' <<<"$fixture_image"; then
    echo "  ok    no-kind ack fixture caught (the ack-discriminator check can fail)"
  else
    report "the no-kind ack fixture compiled WITH a kind field — the ack-discriminator check is vacuous"
  fi
else
  report "the no-kind ack fixture did not compile:"
  indent "$fixture_image"
fi

# --- 10. EnrolmentService carries the IssueEnrolmentToken operator door -----------------

# SPEC-0038 AC1 mints the one-time token a data plane presents as Enrol.one_time_token,
# but until this door existed IssueEnrolmentToken was reachable only from tests: no
# shipped binary exposed an operator path to mint a token. The door mirrors the residency
# Declare door (SPEC-0043, ADR-0063): a separately env-gated admin surface whose caller
# is PAT-verified before any policy decision, and whose tenant and actor are the verified
# principal on the call — never request fields (ADR-0045). Presence of the service, its
# RPC and the domain's wire shape — a lifetime-only request, a response carrying the
# token record (token_id, one_time_token, issued_at, expires_at) — are TYPE PROPERTIES
# asserted against the COMPILED descriptor, exactly as checks 5 to 9 do.
# --exclude-source-info keeps comments out of the image — prose is not what is under
# test. Imports are KEPT: the request references google.protobuf.Duration and the
# response google.protobuf.Timestamp, whose well-known descriptors carry none of the
# shape markers.

if image_out=$(buf build contracts --type gitsaas.agent.v1.EnrolmentService \
  --exclude-source-info -o -#format=json 2>&1); then
  if ! grep -q '"IssueEnrolmentToken"' <<<"$image_out"; then
    report "gitsaas.agent.v1.EnrolmentService carries no IssueEnrolmentToken RPC — the operator door that mints the one-time token Enrol presents must exist (SPEC-0038 AC1, T-0030)"
  elif ! grep -q 'IssueEnrolmentTokenRequest' <<<"$image_out" || ! grep -q 'IssueEnrolmentTokenResponse' <<<"$image_out"; then
    report "gitsaas.agent.v1.EnrolmentService.IssueEnrolmentToken's input or output is not IssueEnrolmentTokenRequest/IssueEnrolmentTokenResponse — the door's shape is the domain's, not an ad-hoc pair (SPEC-0038 AC1)"
  elif ! grep -q 'lifetime' <<<"$image_out" || ! grep -q 'token_id' <<<"$image_out" \
    || ! grep -q 'one_time_token' <<<"$image_out" || ! grep -q 'issued_at' <<<"$image_out" \
    || ! grep -q 'expires_at' <<<"$image_out"; then
    report "the IssueEnrolmentToken request/response drifted from the domain's wire shape — lifetime in; token_id, one_time_token, issued_at, expires_at out (SPEC-0038 AC1/AC2)"
  else
    echo "  ok    EnrolmentService carries IssueEnrolmentToken with the domain's shape (SPEC-0038, T-0030)"
  fi
else
  report "could not compile gitsaas.agent.v1.EnrolmentService for the enrolment-door check:"
  indent "$image_out"
fi

# The fixture is the shape the real door must never degrade back to: an EnrolmentService
# with NO RPC — a service that compiles but mints nothing. The same descriptor question
# asked of it must miss the RPC — a check that cannot fail is not a gate (the
# T-0002/T-0009 pattern).
fixture=scripts/testdata/enrolment-service-no-rpc
if fixture_image=$(buf build "$fixture" --type gitsaas.agent.v1.EnrolmentService --exclude-imports \
  --exclude-source-info -o -#format=json 2>&1); then
  if ! grep -q '"IssueEnrolmentToken"' <<<"$fixture_image"; then
    echo "  ok    no-rpc enrolment-service fixture caught (the enrolment-door check can fail)"
  else
    report "the no-rpc enrolment-service fixture compiled WITH the IssueEnrolmentToken RPC — the enrolment-door check is vacuous"
  fi
else
  report "the no-rpc enrolment-service fixture did not compile:"
  indent "$fixture_image"
fi

if [ "$fail" -ne 0 ]; then
  echo "contracts: FAIL (see above) — ADR-0032, T-0020"
  exit 1
fi
echo "contracts: OK"