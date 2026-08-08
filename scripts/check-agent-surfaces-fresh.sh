#!/usr/bin/env bash
# Fitness function: this repo's agent surfaces match the canonical sources they are generated from.
# ADR-0037 decision 3.
#
# WHY ONLY THIS REPO: the manifest describes five repos, but four of them are submodules that a
# standalone governance CI run does not have. This is the same boundary `check-codegen-fresh.sh`
# documents in the super-repo — a consumer's generated tree can only be checked where the
# composition exists. The super-repo runs the same generator across all five; here we check the
# three surfaces that are actually present, because a gate that quietly skips is worse than no gate:
# the green check then stands as evidence of something nobody verified.
#
# What drift means: someone hand-edited AGENTS.md, CLAUDE.md, or opencode.json instead of editing
# canonical/agent-surfaces/ and regenerating. That is how five CLAUDE.md files came to disagree with
# invariant 7 after ADR-0033 rewrote it, and it is the whole reason ADR-0037 exists.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
report() { echo "AGENT SURFACE VIOLATION: $1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The generator lays repos out beneath an out-root; ours sits at <root>/governance.
mkdir -p "$tmp/governance"
if ! out=$(./scripts/gen-agent-surfaces.sh --scratch "$tmp" governance 2>&1); then
  report "generator failed:"
  while IFS= read -r line; do printf '          %s\n' "$line"; done <<<"$out"
  exit 1
fi

while IFS=$'\t' read -r _template dest; do
  case "$_template" in ''|\#*) continue ;; esac

  generated="$tmp/governance/$dest"
  if [ ! -f "$generated" ]; then
    report "$dest was not generated — canonical/agent-surfaces/repos/governance/files.tsv lists it"
    continue
  fi
  if [ ! -f "$dest" ]; then
    report "$dest is generated but missing from the tree — run scripts/gen-agent-surfaces.sh"
    continue
  fi
  if ! diff -u "$dest" "$generated" > "$tmp/diff" 2>&1; then
    report "$dest does not match canonical/agent-surfaces/ — edit canonical, not the output:"
    while IFS= read -r line; do printf '          %s\n' "$line"; done < "$tmp/diff"
  fi
done < canonical/agent-surfaces/repos/governance/files.tsv

if [ "$fail" -ne 0 ]; then
  echo
  echo "Regenerate with:  ./scripts/gen-agent-surfaces.sh .. governance"
  echo "(.. is the super-repo root when governance is checked out as a submodule.)"
  exit 1
fi

echo "agent surfaces: in sync with canonical/agent-surfaces/"
