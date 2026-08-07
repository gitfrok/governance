#!/usr/bin/env bash
# Governance fitness function: the Source of Truth must be navigable and completely indexed.
#
# This repo is read by agents before they write code, and they follow its links. A dead link or a
# document missing from its index is not a cosmetic problem here — it is a decision that an agent
# will not find, and invariant 21 says decisions live nowhere else. Every other repo gates its
# source; this gates the thing they all defer to.
#
# Checks:
#   1. every relative Markdown link resolves to a file that exists
#   2. every ADR, spec and task file appears in its index, and every index row points at a file
#   3. no ADR number is used twice
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
report() { echo "DOCS VIOLATION: $1"; fail=1; }

# --- 1. relative links resolve -----------------------------------------------------------------

# Collect the Markdown files once, NUL-delimited so a path with a space cannot split.
docs=()
while IFS= read -r -d '' f; do
  docs+=("$f")
done < <(find . -type f -name '*.md' -not -path './.git/*' -print0)

for doc in "${docs[@]}"; do
  dir=$(dirname "$doc")
  # Pull the target out of every [text](target). -o gives one match per line.
  while IFS= read -r target; do
    # Skip external links, in-page anchors, and templates' placeholder targets.
    case "$target" in
      http://*|https://*|mailto:*|"#"*|"<"*) continue ;;
    esac
    # Strip any #anchor; a link to a heading still has to resolve to the file.
    path="${target%%#*}"
    [ -n "$path" ] || continue
    if [ ! -e "$dir/$path" ]; then
      report "$doc links to $target, which does not exist"
    fi
  done < <(grep -oE '\]\([^)]+\)' "$doc" | sed -E 's/^\]\(//; s/\)$//')
done

# --- 2. indexes are complete -------------------------------------------------------------------

# indexed <index-file> <glob-dir> <glob> <label>
# Fails if a file is missing from the index. The reverse direction — an index row naming a file
# that does not exist — is already covered by check 1, because every row is a Markdown link.
indexed() {
  local index="$1" dir="$2" glob="$3" label="$4"
  local f base
  for f in "$dir"/$glob; do
    [ -e "$f" ] || continue
    base=$(basename "$f")
    case "$base" in
      README.md|_template.md|0000-template.md) continue ;;
    esac
    if ! grep -qF "$base" "$index"; then
      report "$label $base is not listed in $index"
    fi
  done
}

indexed docs/adr/README.md   docs/adr   '[0-9][0-9][0-9][0-9]-*.md' ADR
indexed docs/plans/README.md docs/plans '*.md'                      plan

# Specs and tasks are indexed by id rather than filename, so match on the id.
indexed_by_id() { # indexed_by_id <index-file> <dir> <glob> <label>
  local index="$1" dir="$2" glob="$3" label="$4"
  local f id
  for f in "$dir"/$glob; do
    [ -e "$f" ] || continue
    id=$(basename "$f" | grep -oE '^[A-Z]+-[0-9]{4}') || continue
    if ! grep -qF "$id" "$index"; then
      report "$label $id is not listed in $index"
    fi
  done
}

indexed_by_id docs/specs/README.md docs/specs 'SPEC-*.md' spec
indexed_by_id docs/tasks/README.md docs/tasks 'T-*.md'    task

# --- 3. ADR numbers are unique -----------------------------------------------------------------

# ADR-0001 makes these the Source of Truth and immutable once Accepted; two files sharing a number
# means one of them cannot be cited unambiguously.
# `-printf` is a GNU extension that BSD find — and therefore macOS — does not have, so this line
# aborted the whole gate there with "find: -printf: unknown primary or operator". `sed` strips the
# directory instead, which is portable and needs no second process per file the way `-exec basename`
# would. T-0003 AC4 requires these scripts to work on macOS as well as Linux.
dupes=$(find docs/adr -maxdepth 1 -name '[0-9][0-9][0-9][0-9]-*.md' \
  | sed 's|.*/||' | cut -c1-4 | sort | uniq -d)
if [ -n "$dupes" ]; then
  while IFS= read -r n; do
    report "ADR number $n is used by more than one file"
  done <<< "$dupes"
fi

if [ "$fail" -ne 0 ]; then echo "docs: FAIL"; exit 1; fi
echo "docs: OK (${#docs[@]} files checked)"
