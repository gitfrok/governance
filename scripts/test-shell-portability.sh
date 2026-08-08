#!/usr/bin/env bash
# SPEC-0014, as tests. Same harness shape as the other three suites: a throwaway repo per case, a
# real tracked script, assert the exit code — and here, sometimes, assert what the output did or did
# not say, because two of the acceptance criteria are about the gate refusing to lie rather than
# about it finding something.
#
# EVERY CASE BELOW WAS CONFIRMED FAILING BEFORE IT WAS TRUSTED. SPEC-0013's twenty tests all passed
# while a live defect made them meaningless — the fixtures happened to expand to exactly the file
# under test — and the lesson recorded there was that a fixture which cannot distinguish the
# mechanism from the outcome is not testing the mechanism. So each detection case was run once with
# its pattern removed from the list, and each waiver case once with the waiver support stubbed out.
#
# ONE CONTROL CANNOT RUN HERE, and saying so is the point of this paragraph. The *passing* side of
# the part-3 environment assertion needs a real BSD userland at /usr/bin, and a stub anywhere else
# is rejected by the same path check it would be trying to satisfy. Faking it would mean weakening
# the assertion to make its own test pass. The macOS lane is that control, and it is the only thing
# that can be.
#
# shellcheck disable=SC2016
# The fixtures are shell source held as data. Single quotes are the point: `${x,,}` and `$(stat …)`
# must reach the gate as the literal text a real script would contain, not as something this suite
# expanded first. Same suppression, same reason, as test-dispatch-scope-ci.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

GATE="$PWD/scripts/check-shell-portability.sh"
FLAGS="$PWD/scripts/portability-flags.tsv"
[ -x "$GATE" ] || { echo "missing or not executable: $GATE" >&2; exit 4; }
[ -f "$FLAGS" ] || { echo "missing: $FLAGS" >&2; exit 4; }

pass=0
fail=0

# case_run <name> <expected-rc> <env-string> <probe-script-content> [must-contain] [must-not-contain]
#
# env-string is a space-separated list of KEY=VALUE applied to the run; "" for none.
case_run() {
  local name=$1 want=$2 envs=$3 content=$4 want_out=${5:-} unwant_out=${6:-}

  local tmp
  tmp=$(mktemp -d)
  mkdir -p "$tmp/scripts"
  cp "$GATE" "$tmp/scripts/check-shell-portability.sh"
  cp "$FLAGS" "$tmp/scripts/portability-flags.tsv"
  printf '%s\n' "$content" > "$tmp/scripts/probe.sh"
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
case_run "a clean script passes" 0 "" \
  '#!/usr/bin/env bash
echo hello'

# An unterminated `if`, not a malformed `[`. `[ -z "$x" ;` looks broken and is not: `[` is a command,
# so a missing `]` is a runtime failure that `bash -n` correctly says nothing about. The first draft
# of this case asserted a syntax error that was not one and passed the gate — caught by running it.
case_run "a syntax error is caught by the parse half" 1 "" \
  '#!/usr/bin/env bash
if [ -z "$x" ]; then
  echo no' \
  "does not parse"

# --- part 2: the codified audit (AC4, AC5) ------------------------------------------------------
case_run "find -printf is a finding" 1 "" \
  '#!/usr/bin/env bash
find . -name "*.md" -printf "%f\n"' \
  "find -printf"

case_run "stat -c is a finding" 1 "" \
  '#!/usr/bin/env bash
sz=$(stat -c %s "$1")
echo "$sz"' \
  "stat -c"

case_run "sed -i without an argument is a finding" 1 "" \
  '#!/usr/bin/env bash
sed -i s/a/b/ file' \
  "sed -i"

case_run "sed -i with the BSD empty suffix is clean" 0 "" \
  "#!/usr/bin/env bash
sed -i '' s/a/b/ file"

case_run "declare -A is a finding" 1 "" \
  '#!/usr/bin/env bash
declare -A m
m[a]=b' \
  "declare -A"

case_run "\${var,,} is a finding" 1 "" \
  '#!/usr/bin/env bash
x=ABC
echo "${x,,}"' \
  '${var,,}'

# The comment policy, both directions. A gate that can be silenced with a `#` is not a gate; a gate
# that cannot tell documentation from code reports its own explanatory text, which is how SPEC-0013's
# scope parser came to enforce the example inside its own PR body.
case_run "a whole-line comment naming a GNU flag is documentation, not code" 0 "" \
  '#!/usr/bin/env bash
# Never use find -printf here: it is GNU-only.
find . -name "*.md"'

case_run "a trailing inline comment cannot silence a finding" 1 "" \
  '#!/usr/bin/env bash
find . -printf "%f\n"  # this comment does not make it portable' \
  "find -printf"

# --- the waiver, and its limits -----------------------------------------------------------------
case_run "a same-line waiver with a reason is honoured and printed" 0 "" \
  '#!/usr/bin/env bash
if out=$(stat -c %s "$1" 2>/dev/null); then echo "$out"; fi  # portability-ok: probed, fallback below' \
  "portability: waived"

case_run "a waiver on the line above is honoured" 0 "" \
  '#!/usr/bin/env bash
# portability-ok: probed inside a conditional, portable fallback follows
if out=$(stat -c %s "$1" 2>/dev/null); then echo "$out"; fi' \
  "portability: waived"

case_run "a waiver with no reason does not waive" 1 "" \
  '#!/usr/bin/env bash
find . -printf "%f\n"  # portability-ok:' \
  "find -printf"

case_run "a waiver two lines above does not reach" 1 "" \
  '#!/usr/bin/env bash
# portability-ok: too far away to bind
echo unrelated
find . -printf "%f\n"' \
  "find -printf"

# --- part 3: the environment assertion (AC2, AC3) -----------------------------------------------
# These are the reason the gate is worth anything on a runner that ships Homebrew. Both are hard
# failures; neither is a skip.
case_run "strict mode rejects a bash that is not 3.2" 1 "PORTABILITY_STRICT=1" \
  '#!/usr/bin/env bash
echo hello' \
  "is not 3.2"

case_run "strict mode rejects a GNU userland" 1 "PORTABILITY_STRICT=1" \
  '#!/usr/bin/env bash
echo hello' \
  "is the GNU implementation"

# Half of the positive control, and the only half reachable without Darwin: prove the version
# assertion *accepts* 3.2 rather than merely always failing. The userland half still fails here, as
# it must on Linux, so the case asserts rc=1 with the bash complaint absent.
stub=$(mktemp -d)
printf '#!/bin/sh\nif [ "$1" = "--version" ]; then echo "GNU bash, version 3.2.57(1)-release (x86_64-apple-darwin)"; exit 0; fi\nexec /bin/bash "$@"\n' > "$stub/bash32"
chmod +x "$stub/bash32"
case_run "strict mode accepts 3.2 — the version assertion is not a blanket refusal" 1 \
  "PORTABILITY_STRICT=1 PORTABILITY_BASH=$stub/bash32" \
  '#!/usr/bin/env bash
echo hello' \
  "is the GNU implementation" "is not 3.2"
rm -rf "$stub"

case_run "non-strict names the assertion it is not making" 0 "PORTABILITY_STRICT=0" \
  '#!/usr/bin/env bash
echo hello' \
  "userland assertion not applicable"

# --- operational failure modes ------------------------------------------------------------------
# A gate that cannot find its own contract must not pass. Exit 3 is "could not establish", which the
# other suites use for the same shape of failure.
case_run "a missing pattern list is exit 3, not a pass" 3 "PORTABILITY_FLAGS=/nonexistent/flags.tsv" \
  '#!/usr/bin/env bash
echo hello'

echo
echo "portability: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
