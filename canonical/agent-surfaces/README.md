# canonical/agent-surfaces — the source the agent-facing files are generated from

ADR-0037. Sixteen files across five repos tell AI agents how to work here:

| Repo | Surfaces |
|------|----------|
| super-repo | `AGENTS.md`, `CLAUDE.md`, `opencode.json`, `.cursor/rules/agdd.mdc` |
| governance | `AGENTS.md`, `CLAUDE.md`, `opencode.json` |
| backend | `AGENTS.md`, `CLAUDE.md`, `opencode.json` |
| bff | `AGENTS.md`, `CLAUDE.md`, `opencode.json` |
| webfrontend | `AGENTS.md`, `CLAUDE.md`, `opencode.json` |

They used to be hand-written, which meant the same rule was restated up to five times and nothing
checked that the restatements agreed. They did not: when invariant 7 was rewritten after T-0007 and
ADR-0033, five `CLAUDE.md` files kept saying the old thing. Now the rule is written once here and
every copy is generated.

## Layout

```
manifest.tsv                     repo → where it sits → how it reaches governance
fragments/<name>.md              prose shared by more than one repo
repos/<repo>/files.tsv           template → destination, relative to that repo's root
repos/<repo>/<template>          the repo's own copy, with {{...}} expansions
```

## The two expansions

`{{include:<name>}}` pulls in `fragments/<name>.md`. It must be the entire line — a fragment is a
block, not a word — and it is expanded one level deep. A fragment that includes another fragment
reads fine and composes badly: "which file did this line come from" is exactly the question this
directory exists to keep answerable.

`{{GOV}}` becomes the path from that repo's root to `governance` — `governance` from the super-repo,
`../governance` from the three code repos, `.` from here. It is what lets one fragment serve repos
that sit at different depths.

## Changing a rule

1. Edit the fragment if the rule is shared, or the repo's template if it is not.
2. `scripts/gen-agent-surfaces.sh <super-repo-root>` — writes every repo's surfaces.
   Add repo names to limit it: `scripts/gen-agent-surfaces.sh .. governance backend`.
3. Commit governance's own output here. **A surface in another repo is that repo's commit** —
   invariant 23, one commit never spans two submodules. Follow ADR-0027's ordered workflow:
   governance PR first, then each consumer, then the super-repo pointer bump.

`scripts/check-agent-surfaces-fresh.sh` fails CI if this repo's three surfaces do not match. The
other four are checked in the super-repo, where the composition actually exists — the same boundary
`check-codegen-fresh.sh` documents for generated protobuf code.

## What is shared and what is not

Shared today: the four-bullet `CLAUDE.md` body used by all three code repos, and their
`opencode.json` instruction list. Those were byte-identical five times over and are now written once.

Not shared: `AGENTS.md` bodies, and everything in the super-repo and governance templates. Those are
genuinely per-repo — `AGENTS.md` is where a repo says what *it* owns — and forcing them into
fragments would trade real duplication for fake abstraction. They live here for the gate, not for
deduplication. When a rule does start repeating, move it into `fragments/` then.

## Method, not runtime

The canonical-first, adapter-delivered, drift-gated shape is RDF's (`tools/rdf/`, ADR-0038):
read from canonical, write to output, never modify canonical. We do not run `bin/rdf` — the
generator here is ours and so is every word it emits. RDF supplies the pattern and the licence
obligation that comes with deriving from it.
