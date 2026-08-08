#!/usr/bin/env bash
# SPEC-0013 acceptance criteria, as tests. Each case builds a throwaway repo, installs the hook the
# way dispatch-worktree.sh installs it, stages a known set of files, and asserts what `git commit`
# does — the hook's actual invocation path, not the script called by hand.
#
# AC8 (the shared extraction leaves the ceremony gate's 13 cases passing) is covered by
# test-ceremony-tier.sh rather than duplicated here.
set -euo pipefail
cd "$(dirname "$0")/.."

HOOK="$PWD/scripts/dispatch-pre-commit.sh"
LIB="$PWD/scripts/lib-submodule-scope.sh"
HELPER="$PWD/canonical/agent-surfaces/shared/dispatch-worktree.sh"
for f in "$HOOK" "$LIB"; do [ -f "$f" ] || { echo "missing: $f" >&2; exit 4; }; done

pass=0
fail=0

check() {
  local name=$1 want=$2 got=$3 log=$4
  if [ "$got" -eq "$want" ]; then
    printf '  ok    %s\n' "$name"; pass=$((pass + 1))
  else
    printf '  FAIL  %s — expected rc=%s, got rc=%s\n' "$name" "$want" "$got"
    [ -f "$log" ] && sed 's/^/          /' "$log"
    fail=$((fail + 1))
  fi
}

# new_repo — a repo with the hook installed exactly as the helper installs it: a shim in the hooks
# dir that execs the script from the worktree root. Anything less would test a different code path.
new_repo() {
  local d
  d=$(mktemp -d)
  git init -q -b main "$d"
  git -C "$d" config user.email t@t
  git -C "$d" config user.name t
  mkdir -p "$d/scripts"
  cp "$HOOK" "$d/scripts/dispatch-pre-commit.sh"
  cp "$LIB" "$d/scripts/lib-submodule-scope.sh"
  chmod +x "$d/scripts/dispatch-pre-commit.sh"
  local hooks
  hooks=$(git -C "$d" rev-parse --git-path hooks)
  mkdir -p "$d/$hooks"
  # Single-quoted on purpose: the shim must expand at hook time, not now.
  # shellcheck disable=SC2016
  printf '#!/usr/bin/env bash\nexec "$(git rev-parse --show-toplevel)/scripts/dispatch-pre-commit.sh" "$@"\n' > "$d/$hooks/pre-commit"
  chmod +x "$d/$hooks/pre-commit"
  # Commit the harness's own copies before any scope exists, so they are not staged by the cases
  # below. Without this the hook correctly rejects scripts/ as out of scope and the failure looks
  # like the hook's rather than the fixture's — which is exactly what it did on first run.
  git -C "$d" add -A
  git -C "$d" commit -qm harness >/dev/null 2>&1
  echo "$d"
}

scope() { printf 'repo:   %s\npaths:  %s\n' "$2" "$3" > "$1/.git/dispatch-scope"; }

echo "SPEC-0013 acceptance criteria:"

# AC1 — a staged file matching a glob commits.
d=$(new_repo); scope "$d" backend 'src/** *_test.go'
mkdir -p "$d/src"; echo x > "$d/src/a.go"; git -C "$d" add -A
rc=0; git -C "$d" commit -qm t >"$d/.log" 2>&1 || rc=$?
check "AC1 in-scope file commits" 0 "$rc" "$d/.log"; rm -rf "$d"

# AC2 — a staged file matching nothing is rejected, and the message names it and the scope.
d=$(new_repo); scope "$d" backend 'src/**'
mkdir -p "$d/src" "$d/other"; echo x > "$d/src/a.go"; echo y > "$d/other/b.go"; git -C "$d" add -A
rc=0; git -C "$d" commit -qm t >"$d/.log" 2>&1 || rc=$?
check "AC2 out-of-scope file rejected" 1 "$rc" "$d/.log"
if grep -q 'other/b.go' "$d/.log" && grep -q 'src/\*\*' "$d/.log"; then
  printf '  ok    %s\n' "AC2 message names the file and the scope"; pass=$((pass + 1))
else
  printf '  FAIL  %s\n' "AC2 message names the file and the scope"; sed 's/^/          /' "$d/.log"; fail=$((fail + 1))
fi
rm -rf "$d"

# AC3 — no declaration is inert, and says so.
d=$(new_repo)
echo x > "$d/anything.go"; git -C "$d" add -A
rc=0; git -C "$d" commit -qm t >"$d/.log" 2>&1 || rc=$?
check "AC3 no scope commits" 0 "$rc" "$d/.log"
if grep -q 'hook is inert' "$d/.log"; then
  printf '  ok    %s\n' "AC3 inert hook says so rather than passing silently"; pass=$((pass + 1))
else
  printf '  FAIL  %s\n' "AC3 inert hook says so rather than passing silently"; sed 's/^/          /' "$d/.log"; fail=$((fail + 1))
fi
rm -rf "$d"

# AC4 — spanning two submodules is refused, via the shared detection.
d=$(new_repo); scope "$d" super-repo '**'
printf '[submodule "backend"]\n\tpath = backend\n\turl = ../backend.git\n[submodule "bff"]\n\tpath = bff\n\turl = ../bff.git\n' > "$d/.gitmodules"
mkdir -p "$d/backend" "$d/bff"; echo a > "$d/backend/a"; echo b > "$d/bff/b"; git -C "$d" add -A
rc=0; git -C "$d" commit -qm t >"$d/.log" 2>&1 || rc=$?
check "AC4 spanning two submodules rejected" 1 "$rc" "$d/.log"
if grep -q 'invariant 23' "$d/.log"; then
  printf '  ok    %s\n' "AC4 cites invariant 23"; pass=$((pass + 1))
else
  printf '  FAIL  %s\n' "AC4 cites invariant 23"; sed 's/^/          /' "$d/.log"; fail=$((fail + 1))
fi
rm -rf "$d"

# AC5 — the helper refuses a target that is not a submodule, and names the valid ones.
d=$(mktemp -d)
printf '[submodule "backend"]\n\tpath = backend\n\turl = ../backend.git\n' > "$d/.gitmodules"
rc=0; (cd "$d" && bash "$HELPER" nosuchrepo br 'x/**') >"$d/.log" 2>&1 || rc=$?
check "AC5 helper refuses a non-submodule target" 4 "$rc" "$d/.log"
if grep -q 'valid targets: backend' "$d/.log"; then
  printf '  ok    %s\n' "AC5 names the valid targets"; pass=$((pass + 1))
else
  printf '  FAIL  %s\n' "AC5 names the valid targets"; sed 's/^/          /' "$d/.log"; fail=$((fail + 1))
fi
rm -rf "$d"

# AC5b — an unscoped worktree is the thing this avoids, so no globs is a usage error.
d=$(mktemp -d)
printf '[submodule "backend"]\n\tpath = backend\n\turl = ../backend.git\n' > "$d/.gitmodules"
rc=0; (cd "$d" && bash "$HELPER" backend br) >"$d/.log" 2>&1 || rc=$?
check "AC5 helper refuses a worktree with no scope" 2 "$rc" "$d/.log"; rm -rf "$d"

# AC7 — the scope lives in the gitdir and never appears in git status.
d=$(new_repo); scope "$d" backend 'src/**'
if [ -z "$(git -C "$d" status --porcelain)" ]; then
  printf '  ok    %s\n' "AC7 scope file is not visible to git status"; pass=$((pass + 1))
else
  printf '  FAIL  %s — git status is not clean after writing the scope\n' "AC7 scope file is not visible to git status"
  git -C "$d" status --porcelain | sed 's/^/          /'; fail=$((fail + 1))
fi
rm -rf "$d"

echo
if [ "$fail" -ne 0 ]; then
  echo "dispatch scope: $fail failing, $pass passing"
  exit 1
fi
echo "dispatch scope: $pass passing"
