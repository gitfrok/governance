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

# --- 6. control-section records cannot carry an attested record (SPEC-0032 AC2) -----------------

# A pack's control sections are a compliance claim, and admitting an attested imported record makes
# that claim false to an auditor (ADR-0029 §6, SPEC-0031 AC2 — the criterion T-0018 AC19 owed
# forward). SPEC-0032 makes the exclusion a TYPE PROPERTY: the control-section record messages have
# no field capable of carrying an attested record, and attested history is representable only in the
# labelled appendix (AttestedAppendix). The check asks buf for the COMPILED descriptors of the five
# control-side messages rather than grepping the source: a field shows up in the descriptor whatever
# its name, type or spelling, and a proto that fails to compile fails this check loudly instead of
# passing by absence. --exclude-source-info keeps comments out of the image — prose is not what is
# under test. Imports are deliberately KEPT (unlike check 5): the records reference
# google.protobuf.Timestamp, and keeping imports is what makes the check bite if a control record
# type ever references the Provenance descriptor — the appendix's import then lands in the image
# and the marker scan finds it.
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

if [ "$fail" -ne 0 ]; then
  echo "contracts: FAIL (see above) — ADR-0032, T-0020"
  exit 1
fi
echo "contracts: OK"
