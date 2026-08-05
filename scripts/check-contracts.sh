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
#
# `buf breaking` is deliberately absent: its baseline is post-rename main, so it is wired in the
# follow-up PR, once main carries the renamed enums. See T-0020 AC3.
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

if [ "$fail" -ne 0 ]; then
  echo "contracts: FAIL (see above) — ADR-0032, T-0020"
  exit 1
fi
echo "contracts: OK"
