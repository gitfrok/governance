#!/usr/bin/env bash
# Render the agent-facing surfaces from canonical sources. ADR-0037.
#
# WHY THIS EXISTS: sixteen files across five repos (AGENTS.md, CLAUDE.md, opencode.json, and the
# super-repo's .cursor rule) restate the same rules in different voices for different runtimes, and
# nothing checked that they agreed. When invariant 7 was rewritten after T-0007 and ADR-0033, five
# CLAUDE.md files kept whatever they said before. The rule is now written once, in
# canonical/agent-surfaces/, and every runtime's copy is generated from it.
#
# The contract is RDF's (tools/rdf/, ADR-0038): read from canonical, write to output, never modify
# canonical. What RDF supplies is the method; the content is ours.
#
# Usage:
#   scripts/gen-agent-surfaces.sh [--scratch] <out-root> [repo ...]
#
# <out-root> is the directory the repos sit under — the super-repo root in a full composition, or a
# scratch directory when you only want to look at the output. Naming repos limits the run to those;
# with none, every repo in the manifest is rendered. A repo whose submodule is not checked out is
# skipped with a warning rather than failing the run: the manifest is canonical, the working tree is
# not.
#
# --scratch says the out-root is a throwaway directory, not a composition, so that skip does not
# apply and every named repo is rendered. The freshness check uses it; nothing else should.
set -euo pipefail
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
[ -d "$out_root" ] || { echo "gen-agent-surfaces: no such directory: $out_root" >&2; exit 4; }
out_root=$(cd "$out_root" && pwd)

[ -f "$CANON/manifest.tsv" ] || { echo "gen-agent-surfaces: missing $CANON/manifest.tsv" >&2; exit 4; }

# render <template> <gov> — expand {{include:NAME}} and {{GOV}} on stdout.
#
# Includes are expanded one level deep on purpose. A fragment that includes another fragment reads
# fine and composes badly: the second-order question "which file does this line actually come from"
# is exactly the one this whole exercise exists to keep answerable.
render() {
  local template=$1 gov=$2 line name frag

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
        sed "s|{{GOV}}|$gov|g" "$frag"
        ;;
      *)
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

    src="$CANON/repos/$repo/$template"
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
