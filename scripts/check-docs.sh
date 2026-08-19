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
#   4. every spec's status agrees with its own index row, and a spec whose every task is Done is not
#      still `Approved` — the lifecycle is Draft → Approved → Implemented
#      (docs/process/spec-driven-development.md)
#   5. every ADR's status agrees with its own index row
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
report() { echo "DOCS VIOLATION: $1"; fail=1; }

# --- 1. relative links resolve -----------------------------------------------------------------

# Collect the Markdown files once, NUL-delimited so a path with a space cannot split.
#
# canonical/agent-surfaces/ is pruned because those files are templates, not documents. Their links
# are relative to where the generated file lands, not to where the template sits, so resolving them
# from here is the wrong question. The generated output is a real file in this repo and is checked
# below like any other.
docs=()
while IFS= read -r -d '' f; do
  docs+=("$f")
done < <(find . -type f -name '*.md' \
  -not -path './.git/*' \
  -not -path './canonical/agent-surfaces/*' \
  -print0)

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

# --- 4. spec status agrees with the tasks that prove it ----------------------------------------

# WHY THIS EXISTS. On 2026-08-19 fifty-two specs were still marked `Approved` while every task that
# proved them was Done. Nothing was wrong with the work; the state had advanced in the task table and
# never in the specs, so this index answered "what may go RED" while reading like "what is built".
# The same session then wrote `Implemented` on four new specs, which made the inconsistency visible
# by accident rather than by a check — and a reader had to notice it.
#
# The lifecycle is Draft → Approved → Implemented (docs/process/spec-driven-development.md), so this
# gate is not a new rule. It is the existing one, asked mechanically, in the place where the answer
# stops depending on whether anybody looked.
#
# It checks two things: that a spec's own file and its index row say the same word, and that a spec
# whose every listed task is Done has left `Approved`. A spec with NO task is left alone — nothing in
# the task table can advance it, and inferring a status from silence is how a gate starts lying.
status_word() { sed -n 's/^- \*\*Status:\*\* *\**\([A-Za-z]*\).*/\1/p' "$1" | head -1; }

for spec_file in docs/specs/SPEC-*.md; do
  spec=$(basename "$spec_file" | cut -c1-9)
  file_status=$(status_word "$spec_file")
  row=$(grep -E "^\| $spec \|" docs/specs/README.md | head -1)
  if [ -z "$row" ]; then
    continue  # check 2 already reports a spec missing from its index
  fi
  index_status=$(printf '%s' "$row" | awk -F'|' '{print $4}' | sed 's/^ *//; s/[ (*].*//')
  if [ "$file_status" != "$index_status" ]; then
    report "$spec says '$file_status' in its own file and '$index_status' in docs/specs/README.md"
  fi

  tasks=$(printf '%s' "$row" | awk -F'|' '{print $5}' | grep -oE 'T-[0-9]+' || true)
  if [ -n "$tasks" ] && [ "$file_status" = "Approved" ]; then
    open=""
    for task in $tasks; do
      task_row=$(grep -E "^\| $task \|" docs/tasks/README.md | head -1)
      case "$task_row" in
        *"| Done"*) ;;
        *) open="$open $task" ;;
      esac
    done
    if [ -z "$open" ]; then
      report "$spec is still Approved, but every task proving it is Done ($(printf '%s' "$tasks" | tr '\n' ' ')) — the lifecycle ends at Implemented"
    fi
  fi
done

# --- 5. ADR status agrees with its index row ---------------------------------------------------

# Same class as check 4, for the documents ADR-0001 makes the Source of Truth. The index carries the
# status a reader sees first; a file that disagrees with it means one of the two is describing a
# decision nobody made. Superseded rows carry "Superseded by ADR-XXXX", so only the first word is
# compared — the pointer is prose for a human, not a state.
for adr_file in docs/adr/[0-9][0-9][0-9][0-9]-*.md; do
  number=$(basename "$adr_file" | cut -c1-4)
  case "$number" in
    0000) continue ;;  # the template is not a decision
  esac
  file_status=$(status_word "$adr_file")
  row=$(grep -E "^\| \[ADR-$number\]" docs/adr/README.md | head -1)
  if [ -z "$row" ]; then
    continue  # check 2 already reports an ADR missing from its index
  fi
  index_status=$(printf '%s' "$row" | awk -F'|' '{print $4}' | sed 's/^ *//; s/[ (*].*//')
  if [ "$file_status" != "$index_status" ]; then
    report "ADR-$number says '$file_status' in its own file and '$index_status' in docs/adr/README.md"
  fi
done

if [ "$fail" -ne 0 ]; then echo "docs: FAIL"; exit 1; fi
echo "docs: OK (${#docs[@]} files checked)"
