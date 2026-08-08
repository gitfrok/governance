#!/usr/bin/env bash
# SPEC-0012 acceptance criteria, as tests. Each case builds a throwaway git repo, makes a diff with
# a known shape, and asserts what check-ceremony-tier.sh does with it.
#
# Why a real repo per case rather than stubbing git: the gate's whole job is to read a diff, and a
# stub would let it pass against a diff shape that git never actually produces. These are cheap —
# an empty repo and two commits.
set -euo pipefail
cd "$(dirname "$0")/.."

GATE="$PWD/scripts/check-ceremony-tier.sh"
[ -x "$GATE" ] || { echo "missing or not executable: $GATE" >&2; exit 4; }

pass=0
fail=0

# case <name> <expected-rc> <ceremony-body> <base-files...> -- <changed-files...>
#
# Files before `--` exist in the base commit; files after it are added or modified on the branch.
# A file in both is modified; a file only after is added.
case_run() {
  local name=$1 want=$2 body=$3; shift 3
  local base=() changed=() seen=0 f
  for f in "$@"; do
    if [ "$f" = "--" ]; then seen=1; continue; fi
    if [ "$seen" -eq 0 ]; then base+=("$f"); else changed+=("$f"); fi
  done

  local tmp
  tmp=$(mktemp -d)
  (
    cd "$tmp"
    git init -q -b main .
    git config user.email t@t; git config user.name t
    mkdir -p .git/no-hooks; git config core.hooksPath .git/no-hooks
    for f in "${base[@]}"; do mkdir -p "$(dirname "$f")"; echo base > "$f"; done
    echo seed > .seed
    git add -A; git commit -qm base
    # The gate diffs against origin/main; a local ref of that name is indistinguishable to it.
    git update-ref refs/remotes/origin/main HEAD
    for f in "${changed[@]}"; do mkdir -p "$(dirname "$f")"; echo changed > "$f"; done
    git add -A; git commit -qm change
  ) >/dev/null 2>&1

  local got=0
  PR_BODY="$body" CEREMONY_BASE=origin/main bash -c "cd '$tmp' && '$GATE'" >"$tmp/.out" 2>&1 || got=$?
  rm -rf "$tmp/.git"

  if [ "$got" -eq "$want" ]; then
    printf '  ok    %s\n' "$name"
    pass=$((pass + 1))
  else
    printf '  FAIL  %s — expected rc=%s, got rc=%s\n' "$name" "$want" "$got"
    sed 's/^/          /' "$tmp/.out"
    fail=$((fail + 1))
  fi
  rm -rf "$tmp"
}

echo "SPEC-0012 acceptance criteria:"

# AC1 — quick may not move non-test source.
case_run "AC1 quick + source file rejected" 1 "Ceremony: quick" \
  src/thing.go -- src/thing.go
case_run "AC1 quick + docs accepted" 0 "Ceremony: quick" \
  README.md -- README.md
case_run "AC1 quick + test-only refactor accepted" 0 "Ceremony: quick" \
  src/thing_test.go -- src/thing_test.go

# AC2 — bugfix may not span two submodules (composition only).
case_run "AC2 bugfix spanning two submodules rejected" 1 "Ceremony: bugfix" \
  .gitmodules backend/a_test.go bff/b.go -- backend/a_test.go bff/b.go

# AC3 — the security floor no tier crosses.
case_run "AC3 quick + policies/ rejected" 1 "Ceremony: quick" \
  policies/x.rego -- policies/x.rego
case_run "AC3 bugfix + contracts/ rejected" 1 "Ceremony: bugfix" \
  contracts/v1/a.proto x_test.go -- contracts/v1/a.proto x_test.go
case_run "AC3 quick + a tenant-scoped path rejected" 1 "Ceremony: quick" \
  docs/tenant-notes.md -- docs/tenant-notes.md

# AC4 — absence is never a waiver, and full checks nothing because it waives nothing.
case_run "AC4 no Ceremony line is full and passes" 0 "just a normal PR body" \
  src/thing.go -- src/thing.go
case_run "AC4 explicit full passes with source changes" 0 "Ceremony: full" \
  src/thing.go -- src/thing.go

# AC5 — a bugfix without a test has waived the spec for nothing.
case_run "AC5 bugfix without a test rejected" 1 "Ceremony: bugfix" \
  src/thing.go -- src/thing.go
case_run "AC5 bugfix with a test accepted" 0 "Ceremony: bugfix" \
  src/thing.go src/thing_test.go -- src/thing.go src/thing_test.go

# AC6 — an undeterminable diff fails rather than passing. case_run always sets up origin/main, so
# this one is built by hand with a base ref that genuinely does not resolve.
tmp=$(mktemp -d)
(
  cd "$tmp"; git init -q -b main .; git config user.email t@t; git config user.name t
  echo x > a.md; git add -A; git commit -qm base
) >/dev/null 2>&1
got=0
PR_BODY="Ceremony: quick" CEREMONY_BASE=refs/heads/nope bash -c "cd '$tmp' && '$GATE'" >/dev/null 2>&1 || got=$?
if [ "$got" -eq 3 ]; then printf '  ok    %s\n' "AC6 missing base ref exits 3"; pass=$((pass+1));
else printf '  FAIL  %s — expected rc=3, got rc=%s\n' "AC6 missing base ref exits 3" "$got"; fail=$((fail+1)); fi
rm -rf "$tmp"

# An unrecognised tier is a mistake, not a silent full.
case_run "unknown tier rejected" 1 "Ceremony: cheap" \
  README.md -- README.md

echo
if [ "$fail" -ne 0 ]; then
  echo "ceremony gate: $fail failing, $pass passing"
  exit 1
fi
echo "ceremony gate: $pass passing"
