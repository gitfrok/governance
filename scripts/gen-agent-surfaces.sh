#!/usr/bin/env bash
# Render the agent-facing surfaces from canonical sources. ADR-0037.
#
# WHY THIS EXISTS: sixteen files across five repos (AGENTS.md, CLAUDE.md, opencode.json, and the
# super-repo's .cursor rule) restate the same rules in different voices for different runtimes, and
# nothing checked that they agreed. When invariant 7 was rewritten after T-0007 and ADR-0033, five
# CLAUDE.md files kept whatever they said before. The rule is now written once, in
# canonical/agent-surfaces/, and every runtime's copy is generated from it.
#
# The contract (ADR-0039 decision 3): read from canonical, write to output, never modify canonical.
# Generation is byte-deterministic, so drift is a diff and a diff fails CI, and the output is
# committed and reviewed like any other file rather than gitignored.
#
# Usage:
#   scripts/gen-agent-surfaces.sh [--scratch] <out-root> [repo ...]
#
# <out-root> is the SUPER-REPO ROOT — every path in the manifest is relative to it, and the script
# refuses anything without a .gitmodules unless --scratch says otherwise. Relative paths resolve
# against your current directory, not this repo's. Naming repos limits the run to those;
# with none, every repo in the manifest is rendered. A repo whose submodule is not checked out is
# skipped with a warning rather than failing the run: the manifest is canonical, the working tree is
# not.
#
# --scratch says the out-root is a throwaway directory, not a composition, so that skip does not
# apply and every named repo is rendered. The freshness check uses it; nothing else should.
set -euo pipefail

# Resolve the out-root against the CALLER's directory, before this script cd's to the repo root.
# Doing it after means a relative path is silently reinterpreted against governance/ — running
# `./governance/scripts/gen-agent-surfaces.sh . super-repo` from the super-repo then writes the
# super-repo's four surfaces on top of governance's own three. That is not hypothetical; it is what
# happened the first time it was run from the composition.
_caller_pwd=$PWD
cd "$(dirname "$0")/.."

CANON="canonical/agent-surfaces"
FRAGMENTS="$CANON/fragments"

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }

scratch=0
[ $# -ge 1 ] || { usage >&2; exit 2; }
case "$1" in
  -h|--help|help) usage; exit 0 ;;
  --scratch)      scratch=1; shift ;;
esac

[ $# -ge 1 ] || { usage >&2; exit 2; }
out_root=$1
shift
case "$out_root" in /*) ;; *) out_root="$_caller_pwd/$out_root" ;; esac
[ -d "$out_root" ] || { echo "gen-agent-surfaces: no such directory: $out_root" >&2; exit 4; }
out_root=$(cd "$out_root" && pwd)

[ -f "$CANON/manifest.tsv" ] || { echo "gen-agent-surfaces: missing $CANON/manifest.tsv" >&2; exit 4; }

# Every path in the manifest is relative to the SUPER-REPO root, so an out-root that is not one
# silently means something else: "governance" resolves to a subdirectory that does not exist, and
# "." — the super-repo's own row — resolves to whatever directory was passed. Pointing this at a
# submodule root is how the super-repo's surfaces landed on top of governance's own.
if [ "$scratch" -eq 0 ] && [ ! -f "$out_root/.gitmodules" ]; then
  echo "gen-agent-surfaces: $out_root is not the super-repo root (no .gitmodules)." >&2
  echo "  The manifest's paths are relative to it. Pass the super-repo root, or --scratch to" >&2
  echo "  render into a throwaway directory." >&2
  exit 4
fi

# render <template> <gov> — expand {{include:NAME}} and {{GOV}} on stdout.
#
# Includes are expanded one level deep on purpose. A fragment that includes another fragment reads
# fine and composes badly: the second-order question "which file does this line actually come from"
# is exactly the one this whole exercise exists to keep answerable.
#
# {{GOV}} is always written with a following slash — `{{GOV}}/docs/...`. For governance itself the
# manifest says ".", and expanding that literally gives `./docs/...`, which works and reads like a
# typo. So for that one repo the slash is consumed too and the path comes out bare.
render() {
  local template=$1 gov=$2 line name frag
  local from='{{GOV}}/' to="$gov/"
  [ "$gov" = "." ] && to=''

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *'{{include:'*'}}'*)
        name=${line#*\{\{include:}
        name=${name%%\}\}*}
        frag="$FRAGMENTS/$name.md"
        if [ ! -f "$frag" ]; then
          echo "gen-agent-surfaces: $template references a fragment that does not exist: $name" >&2
          return 4
        fi
        # A fragment is a block, not a word: anything else on the line would be silently dropped.
        if [ "$line" != "{{include:$name}}" ]; then
          echo "gen-agent-surfaces: $template line must be exactly '{{include:$name}}': $line" >&2
          return 4
        fi
        sed -e "s|${from}|${to}|g" -e "s|{{GOV}}|$gov|g" "$frag"
        ;;
      *)
        line=${line//"$from"/"$to"}
        printf '%s\n' "${line//\{\{GOV\}\}/$gov}"
        ;;
    esac
  done < "$template"
}

wanted=("$@")
want() {
  local r=$1 w
  [ ${#wanted[@]} -eq 0 ] && return 0
  for w in "${wanted[@]}"; do [ "$w" = "$r" ] && return 0; done
  return 1
}

written=0
skipped=0
while IFS=$'\t' read -r repo path gov; do
  case "$repo" in ''|\#*) continue ;; esac
  want "$repo" || continue

  files="$CANON/repos/$repo/files.tsv"
  [ -f "$files" ] || { echo "gen-agent-surfaces: missing $files" >&2; exit 4; }

  # "." is how the manifest says "this repo is the out-root itself".
  repo_root=$out_root
  [ "$path" = "." ] || repo_root="$out_root/$path"

  # Refuse to write into a submodule that is not checked out. Without this the generator happily
  # creates backend/AGENTS.md inside an empty gitlink mount point, which git reports as a *deleted
  # submodule* rather than as new files — so the damage does not look like damage. Found by running
  # it: `git submodule update --init` had only been run for governance.
  if [ "$scratch" -eq 0 ] && [ "$path" != "." ] && [ ! -e "$repo_root/.git" ]; then
    echo "gen-agent-surfaces: skipping $repo — $repo_root is not a checked-out repo" >&2
    skipped=$((skipped + 1))
    continue
  fi

  while IFS=$'\t' read -r template dest; do
    case "$template" in ''|\#*) continue ;; esac

    # A files.tsv row naming shared/<file> reads one template that every repo renders. {{GOV}} is
    # what makes that work across repos at different depths — without it a shared template could
    # only hold text with no paths in it, which is most of nothing.
    case "$template" in
      shared/*) src="$CANON/$template" ;;
      *)        src="$CANON/repos/$repo/$template" ;;
    esac
    [ -f "$src" ] || { echo "gen-agent-surfaces: missing template $src" >&2; exit 4; }

    target="$repo_root/$dest"
    mkdir -p "$(dirname "$target")"
    render "$src" "$gov" > "$target"
    written=$((written + 1))
  done < "$files"
done < "$CANON/manifest.tsv"

echo "gen-agent-surfaces: wrote $written file(s) under $out_root"
if [ "$skipped" -ne 0 ]; then
  echo "gen-agent-surfaces: skipped $skipped repo(s) that are not checked out —"
  echo "  run 'git submodule update --init' from the super-repo to render them too."
fi
