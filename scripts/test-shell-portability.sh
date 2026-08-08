#!/usr/bin/env bash
# SPEC-0014, as tests. Same harness shape as the other three suites: a throwaway repo per case, a
# real tracked script, assert the exit code — and here, sometimes, assert what the output did or did
# not say, because two of the acceptance criteria are about the gate refusing to lie rather than
# about it finding something.
#
# THE FIXTURES LIVE IN testdata/portability/*.sh.txt AND NOT IN THIS FILE, and the reason is the
# whole design being tested. This suite is a tracked *.sh, so the gate audits it; fixtures written
# inline meant the gate reported fifteen violations against its own test suite. That is the third
# time the same shape has been paid for — SPEC-0013's `Scope:` parser enforced the example inside its
# own PR body, the pattern list had to leave the gate for a `.tsv` for the same reason, and now this.
# The rule that keeps falling out: KEEP THE LITERALS OUT OF EVERY FILE THE GATE READS. `.sh.txt` is
# not matched by `*.sh`, so nothing self-matches and no file needs exempting.
#
# The inline version passed locally and failed on the first CI run, because the file was still
# untracked when it was run by hand and `git ls-files` therefore could not see it.
#
# EVERY CASE BELOW WAS CONFIRMED FAILING BEFORE IT WAS TRUSTED. SPEC-0013's twenty tests all passed
# while a live defect made them meaningless — the fixtures happened to expand to exactly the file
# under test — and the lesson recorded there was that a fixture which cannot distinguish the
# mechanism from the outcome is not testing the mechanism. Each detection case was re-run with its
# pattern deleted from the list and confirmed to stop firing.
#
# ONE CONTROL CANNOT RUN HERE, and saying so is the point of this paragraph. The *passing* side of
# the part-3 environment assertion needs a real BSD userland at /usr/bin, and a stub anywhere else
# is rejected by the same path check it would be trying to satisfy. Faking it would mean weakening
# the assertion to make its own test pass. The macOS lane is that control, and it is the only thing
# that can be.
#
# shellcheck disable=SC2016
# The bash stub below is shell source held as data; single quotes are the point, since `$1` and `$@`
# must reach the stub as literal text rather than being expanded by this suite first. Same
# suppression, same reason, as test-dispatch-scope-ci.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

GATE="$PWD/scripts/check-shell-portability.sh"
FLAGS="$PWD/scripts/portability-flags.tsv"
FIXTURES="$PWD/scripts/testdata/portability"
[ -x "$GATE" ] || { echo "missing or not executable: $GATE" >&2; exit 4; }
[ -f "$FLAGS" ] || { echo "missing: $FLAGS" >&2; exit 4; }
[ -d "$FIXTURES" ] || { echo "missing: $FIXTURES" >&2; exit 4; }

pass=0
fail=0

# case_run <name> <expected-rc> <env-string> <fixture> [must-contain] [must-not-contain]
#
# fixture names a file in testdata/portability/, without the .sh.txt suffix; it is installed into
# the throwaway repo as scripts/probe.sh. env-string is a space-separated list of KEY=VALUE, "" for
# none.
case_run() {
  local name=$1 want=$2 envs=$3 fixture=$4 want_out=${5:-} unwant_out=${6:-}
  local src="$FIXTURES/$fixture.sh.txt"
  [ -f "$src" ] || { printf '  FAIL  %s — no such fixture: %s\n' "$name" "$src"; fail=$((fail + 1)); return; }

  local tmp
  tmp=$(mktemp -d)
  mkdir -p "$tmp/scripts"
  cp "$GATE" "$tmp/scripts/check-shell-portability.sh"
  cp "$FLAGS" "$tmp/scripts/portability-flags.tsv"
  cp "$src" "$tmp/scripts/probe.sh"
  (
    cd "$tmp"
    git init -q -b main .
    git config user.email t@t; git config user.name t
    git add -A
    git commit -qm base
  ) >/dev/null 2>&1

  local got=0
  # shellcheck disable=SC2086
  env $envs bash -c "cd '$tmp' && ./scripts/check-shell-portability.sh" >"$tmp/.out" 2>&1 || got=$?

  local ok=1 why=""
  [ "$got" -eq "$want" ] || { ok=0; why="expected rc=$want, got rc=$got"; }
  if [ "$ok" -eq 1 ] && [ -n "$want_out" ] && ! grep -qF "$want_out" "$tmp/.out"; then
    ok=0; why="output did not contain: $want_out"
  fi
  if [ "$ok" -eq 1 ] && [ -n "$unwant_out" ] && grep -qF "$unwant_out" "$tmp/.out"; then
    ok=0; why="output should not have contained: $unwant_out"
  fi

  if [ "$ok" -eq 1 ]; then
    printf '  ok    %s\n' "$name"; pass=$((pass + 1))
  else
    printf '  FAIL  %s — %s\n' "$name" "$why"
    sed 's/^/          /' "$tmp/.out"; fail=$((fail + 1))
  fi
  rm -rf "$tmp"
}

echo "SPEC-0014 shell portability gate:"

# --- part 1: parse (AC1) ------------------------------------------------------------------------
case_run "a clean script passes" 0 "" clean

# An unterminated `if`, not a malformed `[`. The first draft used `[ -z "$x" ; then`, which looks
# broken and is not: `[` is a command, so a missing `]` is a runtime failure that `bash -n` correctly
# says nothing about. That case asserted a syntax error that did not exist and passed the gate —
# caught by running it, which is the only way it could have been.
case_run "a syntax error is caught by the parse half" 1 "" syntax-error "does not parse"

# --- part 2: the codified audit (AC4, AC5) ------------------------------------------------------
#
# NEITHER THE CASE NAMES NOR THE ASSERTIONS SPELL THE CONSTRUCTS OUT, for the same reason the
# fixtures moved to testdata: this file is audited, and a case named after the flag it tests is a
# flag in a tracked script. So each case asserts against the *explanation* column of the pattern
# list rather than its label. That the assertions still bind is what the "confirmed failing first"
# note above is for.
case_run "a GNU find predicate is a finding" 1 "" gnu-find-predicate "GNU findutils only"
case_run "a GNU stat format flag is a finding" 1 "" gnu-stat-format "BSD stat spells it"
case_run "in-place editing with no backup suffix is a finding" 1 "" inplace-no-suffix "explicit backup suffix"
case_run "in-place editing with the BSD empty suffix is clean" 0 "" inplace-bsd-suffix
case_run "an associative array declaration is a finding" 1 "" declare-assoc "Associative arrays are"
case_run "bash 4 case conversion is a finding" 1 "" case-conversion "case conversion"

# The comment policy, both directions. A gate that can be silenced with a `#` is not a gate; a gate
# that cannot tell documentation from code reports its own explanatory text.
case_run "a whole-line comment naming a GNU flag is documentation, not code" 0 "" comment-documents-a-flag
case_run "a trailing inline comment cannot silence a finding" 1 "" inline-comment-cannot-silence "GNU findutils only"

# --- the waiver, and its limits -----------------------------------------------------------------
case_run "a same-line waiver with a reason is honoured and printed" 0 "" waiver-same-line "portability: waived"
case_run "a waiver on the line above is honoured" 0 "" waiver-line-above "portability: waived"
case_run "a waiver with no reason does not waive" 1 "" waiver-without-reason "GNU findutils only"
case_run "a waiver two lines above does not reach" 1 "" waiver-too-far "GNU findutils only"

# --- part 3: the environment assertion (AC2, AC3) -----------------------------------------------
# These are the reason the gate is worth anything on a runner that ships Homebrew. Both are hard
# failures; neither is a skip.
case_run "strict mode rejects a bash that is not 3.2" 1 "PORTABILITY_STRICT=1" clean "is not 3.2"
case_run "strict mode rejects a GNU userland" 1 "PORTABILITY_STRICT=1" clean "is the GNU implementation"

# Half of the positive control, and the only half reachable without Darwin: prove the version
# assertion *accepts* 3.2 rather than merely always failing. On Linux the userland half still fails,
# as it must, so this asserts rc=1 with the bash complaint absent. On the macOS lane the whole
# assertion passes for real, which is the other half.
stub=$(mktemp -d)
printf '#!/bin/sh\nif [ "$1" = "--version" ]; then echo "GNU bash, version 3.2.57(1)-release (test-stub)"; exit 0; fi\nexec /bin/bash "$@"\n' > "$stub/bash32"
chmod +x "$stub/bash32"
if [ "$(uname -s)" = "Darwin" ]; then
  # Here the real assertion passes, so the stub would only prove that a stub works. Skipped, and
  # said out loud: an unrun case and a passing one must not look alike in a log.
  echo "  --    strict mode accepts 3.2 — not run on Darwin, where the unstubbed assertion is the control"
else
  case_run "strict mode accepts 3.2 — the version assertion is not a blanket refusal" 1 \
    "PORTABILITY_STRICT=1 PORTABILITY_BASH=$stub/bash32" clean \
    "is the GNU implementation" "is not 3.2"
fi
rm -rf "$stub"

case_run "non-strict names the assertion it is not making" 0 "PORTABILITY_STRICT=0" clean \
  "userland assertion not applicable"

# --- operational failure modes ------------------------------------------------------------------
# A gate that cannot find its own contract must not pass. Exit 3 is "could not establish", which the
# other suites use for the same shape of failure.
case_run "a missing pattern list is exit 3, not a pass" 3 "PORTABILITY_FLAGS=/nonexistent/flags.tsv" clean

echo
echo "portability: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
