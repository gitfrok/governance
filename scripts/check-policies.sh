#!/usr/bin/env bash
# Governance fitness function: the policy bundle is loadable, tested, and deny-by-default.
#
# `policies/` is the whole of the system's authorization logic (ADR-0006, invariant 2): a rule that
# is not here does not exist, because no service is permitted an inline permission check. That makes
# this directory the highest-leverage thing in the repo to get wrong silently — a policy that fails
# to compile denies everything, and one that quietly loses its `default allow := false` permits
# everything. `docs/process/ci-gates.md` has marked "policy + tenant-isolation (Rego)" required in
# this repo since it was written; until T-0005 there was no such check and no policies to run it on.
#
# Checks:
#   1. `policies/` builds as an OPA bundle — the manifest parses, declares a revision, and its
#      roots actually cover the packages present (SPEC-0002 AC2)
#   2. `opa check --strict` compiles every module
#   3. `opa test` passes — the policy's own behavioural suite
#   4. every package defining `allow` evaluates to *false*, not undefined, for an empty input
#      (SPEC-0002 AC1)
#   5. none of the above is vacuous: a fixture carrying each specific defect must be REJECTED.
#      A gate that cannot fail is not a gate — the same discipline as check-contracts.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v opa >/dev/null || { echo "opa not installed: https://www.openpolicyagent.org/docs/latest/#running-opa"; exit 1; }

fail=0
report() { echo "POLICY VIOLATION: $1"; fail=1; }

# Indent captured output so it reads as evidence under its report line rather than as new
# top-level noise. Same helper as check-contracts.sh, kept identical on purpose.
indent() {
  while IFS= read -r line; do
    printf '          %s\n' "$line"
  done <<<"$1"
}

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

# --- 1. the bundle builds --------------------------------------------------------------------

# `opa build -b` is the honest form of "loads as a versioned OPA bundle". It parses .manifest,
# compiles every module, and — the part a hand-rolled check would miss — refuses a manifest whose
# roots do not cover the packages present. Roots are what keep one bundle from silently overwriting
# another's data when both are loaded, so a manifest that lies about them is a real defect.
if build_out=$(opa build -b policies -o "$workdir/bundle.tar.gz" 2>&1); then
  echo "  ok    opa build (policies/ is a valid bundle)"
else
  report "policies/ does not build as an OPA bundle:"
  indent "$build_out"
fi

# The revision is what a PEP keys its decision cache on (contracts/proto/policy/v1: policy_revision),
# so an empty one means every cached decision is keyed on nothing and survives a policy change.
# Parsed with opa rather than jq: opa is already a hard requirement here, and feeding the manifest
# in as input validates that it is well-formed JSON as a side effect.
if ! revision=$(opa eval --format raw --stdin-input 'input.revision' <policies/.manifest 2>&1); then
  report "policies/.manifest is not valid JSON:"
  indent "$revision"
elif [ -z "$revision" ]; then
  report "policies/.manifest declares no revision — decision caches would key on an empty string"
else
  echo "  ok    bundle revision: $revision"
fi

# --- 2. everything compiles under --strict -----------------------------------------------------

if check_out=$(opa check --strict policies 2>&1); then
  echo "  ok    opa check --strict (policies/)"
else
  report "opa check --strict failed on policies/:"
  indent "$check_out"
fi

# --- 3. the policy's own tests pass -------------------------------------------------------------

if test_out=$(opa test policies 2>&1); then
  echo "  ok    opa test (policies/)"
else
  report "opa test failed on policies/:"
  indent "$test_out"
fi

# --- 4. deny-by-default, evaluated rather than grepped -------------------------------------------

# The textual check — "does the file contain `default allow := false`" — would pass on a package
# that declares it in one file and overrides it in another, and would fail on a correct policy that
# spelled it differently. So this asks OPA instead: with an input that asserts nothing, what is
# `allow`?
#
# The answer must be exactly `false`. *Undefined* is not good enough and is the interesting failure:
# `not allow` succeeds for an undefined rule, so a policy missing its default looks safe under
# negation and hands the adapter an absent answer to interpret. ADR-0006 says the absence of an
# explicit allow is a denial; this asserts the policy says so itself.
deny_checked=0
while IFS= read -r -d '' module; do
  case "$module" in
    *_test.rego) continue ;;
  esac
  # Only packages that actually make an allow decision are in scope; a helper module has nothing
  # to default.
  grep -qE '^[[:space:]]*allow([[:space:]]|:=|=|\{|\.)' "$module" || continue

  pkg=$(grep -m1 -E '^package[[:space:]]+' "$module" | awk '{print $2}')
  if [ -z "$pkg" ]; then
    report "$module has no package declaration"
    continue
  fi

  deny_checked=$((deny_checked + 1))
  verdict=$(echo '{}' | opa eval -d policies --format raw --stdin-input "data.${pkg}.allow" 2>&1) || {
    report "could not evaluate data.${pkg}.allow:"
    indent "$verdict"
    continue
  }
  if [ "$verdict" = "false" ]; then
    echo "  ok    deny-by-default: data.${pkg}.allow is false for an empty input"
  elif [ -z "$verdict" ]; then
    report "data.${pkg}.allow is UNDEFINED for an empty input — it must be false (add 'default allow := false')"
  else
    report "data.${pkg}.allow is '$verdict' for an empty input — it must be false"
  fi
done < <(find policies -type f -name '*.rego' -print0)

# A policy tree with no allow rules at all would sail through check 4 without checking anything.
if [ "$deny_checked" -eq 0 ]; then
  report "no package in policies/ defines an allow rule — check 4 verified nothing"
fi

# --- 5. none of the above is vacuous -------------------------------------------------------------

# Each fixture carries exactly one defect and must be rejected by the check that exists to catch it.
# `opa check --strict` on the strict fixture, `opa test` on the failing-test fixture, and the
# empty-input evaluation on the fixture that omits its default.

if strict_out=$(opa check --strict scripts/testdata/policy-strict-violation 2>&1); then
  report "the strict fixture PASSED — opa check is not running with --strict"
  indent "$strict_out"
elif ! grep -q 'unused' <<<"$strict_out"; then
  # It failed, but not for the reason the fixture exists — a syntax error would "fail" too and
  # would quietly stop testing anything.
  report "the strict fixture failed, but not on the unused import:"
  indent "$strict_out"
else
  echo "  ok    strict fixture rejected (unused import)"
fi

if fixture_out=$(opa test scripts/testdata/policy-failing-test 2>&1); then
  report "the failing-test fixture PASSED — opa test is not evaluating assertions"
  indent "$fixture_out"
else
  echo "  ok    failing-test fixture rejected (assertions are evaluated)"
fi

open_verdict=$(echo '{}' | opa eval -d scripts/testdata/policy-no-default-deny --format raw \
  --stdin-input 'data.fixture.opendefault.allow' 2>&1 || true)
if [ "$open_verdict" = "false" ]; then
  report "the no-default-deny fixture evaluated to false — check 4 cannot distinguish a missing default"
elif [ -n "$open_verdict" ]; then
  report "the no-default-deny fixture evaluated to '$open_verdict', expected undefined"
else
  echo "  ok    no-default-deny fixture is undefined (check 4 can fail)"
fi

if [ "$fail" -ne 0 ]; then
  echo "policies: FAIL (see above) — ADR-0006, SPEC-0002, T-0005"
  exit 1
fi
echo "policies: OK"
