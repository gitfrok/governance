#!/usr/bin/env bash
# SPEC-0013 open question 1, as tests: the CI-side scope check, which runs on what was pushed rather
# than on what the author chose to run. Same harness shape as the other two suites — a throwaway
# repo per case, a real diff, assert the exit code.
set -euo pipefail
cd "$(dirname "$0")/.."

GATE="$PWD/scripts/check-dispatch-scope.sh"
[ -x "$GATE" ] || { echo "missing or not executable: $GATE" >&2; exit 4; }

pass=0
fail=0

# case <name> <expected-rc> <pr-body> <base-files...> -- <changed-files...>
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
    for f in "${base[@]}"; do
      mkdir -p "$(dirname "$f")"
      # .gitmodules must be real config — filler makes `git config -f` exit 1, which is how the
      # ceremony suite's AC2 spent its whole life asserting a crash instead of detecting a span.
      if [ "$f" = ".gitmodules" ]; then
        printf '[submodule "backend"]\n\tpath = backend\n\turl = ../backend.git\n[submodule "bff"]\n\tpath = bff\n\turl = ../bff.git\n' > "$f"
      else
        echo base > "$f"
      fi
    done
    echo seed > .seed
    git add -A; git commit -qm base
    git update-ref refs/remotes/origin/main HEAD
    for f in "${changed[@]}"; do mkdir -p "$(dirname "$f")"; echo changed > "$f"; done
    git add -A; git commit -qm change
  ) >/dev/null 2>&1

  # The gate needs its library beside it, exactly as the generated layout places them.
  mkdir -p "$tmp/scripts"
  cp "$GATE" "$tmp/scripts/"
  cp "$PWD/scripts/lib-submodule-scope.sh" "$tmp/scripts/"

  local got=0
  PR_BODY="$body" SCOPE_BASE=origin/main bash -c "cd '$tmp' && ./scripts/check-dispatch-scope.sh" >"$tmp/.out" 2>&1 || got=$?

  if [ "$got" -eq "$want" ]; then
    printf '  ok    %s\n' "$name"; pass=$((pass + 1))
  else
    printf '  FAIL  %s — expected rc=%s, got rc=%s\n' "$name" "$want" "$got"
    sed 's/^/          /' "$tmp/.out"; fail=$((fail + 1))
  fi
  rm -rf "$tmp"
}

echo "SPEC-0013 CI-side scope checks:"

# The gap this closes: invariant 23 is checked with no declaration at all, on every PR. The ceremony
# gate only reaches its span check inside the `bugfix` branch, so a `full`-tier PR spanning two
# submodules passed CI unchecked.
case_run "invariant 23 caught with no declaration at all" 1 "an ordinary PR body" \
  .gitmodules backend/a bff/b -- backend/a bff/b
case_run "invariant 23 caught even at Ceremony: full" 1 "Ceremony: full" \
  .gitmodules backend/a bff/b -- backend/a bff/b
case_run "one submodule is fine" 0 "no declaration here" \
  .gitmodules backend/a -- backend/a

# Path scope, only when declared.
case_run "declared scope, in-scope file passes" 0 "Scope: backend modules/**" \
  .gitmodules backend/modules/x.go -- backend/modules/x.go
case_run "declared scope, out-of-scope file rejected" 1 "Scope: backend modules/**" \
  .gitmodules backend/modules/x.go backend/other/y.go -- backend/modules/x.go backend/other/y.go
case_run "declared repo disagreeing with the diff is rejected" 1 "Scope: bff **" \
  .gitmodules backend/a -- backend/a
case_run "Scope with no glob is a usage error" 1 "Scope: backend" \
  .gitmodules backend/a -- backend/a

# No declaration means the path half is inert — and must say so.
tmp=$(mktemp -d)
(
  cd "$tmp"; git init -q -b main .; git config user.email t@t; git config user.name t
  echo x > a.md; git add -A; git commit -qm base; git update-ref refs/remotes/origin/main HEAD
  echo y > b.md; git add -A; git commit -qm change
) >/dev/null 2>&1
mkdir -p "$tmp/scripts"; cp "$GATE" "$PWD/scripts/lib-submodule-scope.sh" "$tmp/scripts/"
PR_BODY="nothing declared" SCOPE_BASE=origin/main bash -c "cd '$tmp' && ./scripts/check-dispatch-scope.sh" >"$tmp/.out" 2>&1 || true
if grep -q 'path scope not' "$tmp/.out"; then
  printf '  ok    %s\n' "undeclared path scope says it is not checked"; pass=$((pass + 1))
else
  printf '  FAIL  %s\n' "undeclared path scope says it is not checked"; sed 's/^/          /' "$tmp/.out"; fail=$((fail + 1))
fi
rm -rf "$tmp"

# An undeterminable diff fails rather than passing, same as every other gate here.
tmp=$(mktemp -d)
(cd "$tmp"; git init -q -b main .; git config user.email t@t; git config user.name t; echo x > a; git add -A; git commit -qm base) >/dev/null 2>&1
mkdir -p "$tmp/scripts"; cp "$GATE" "$PWD/scripts/lib-submodule-scope.sh" "$tmp/scripts/"
got=0
PR_BODY="" SCOPE_BASE=refs/heads/nope bash -c "cd '$tmp' && ./scripts/check-dispatch-scope.sh" >/dev/null 2>&1 || got=$?
if [ "$got" -eq 3 ]; then printf '  ok    %s\n' "missing base ref exits 3"; pass=$((pass+1));
else printf '  FAIL  %s — expected rc=3, got rc=%s\n' "missing base ref exits 3" "$got"; fail=$((fail+1)); fi
rm -rf "$tmp"

echo
if [ "$fail" -ne 0 ]; then
  echo "dispatch scope (CI): $fail failing, $pass passing"
  exit 1
fi
echo "dispatch scope (CI): $pass passing"
