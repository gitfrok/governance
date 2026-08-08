# ADR-0039: Vendor no third-party code — the surface pipeline is ours, and `governance` keeps GPL v2 by choice

- **Status:** Accepted
- **Date:** 2026-08-08
- **Deciders:** platform
- **Governs:** G7 process integrity — a dependency we carry is a dependency we own
- **Supersedes:** **ADR-0038** (`governance` is GPL v2 and vendors RDF)
- **Relates to:** **ADR-0037** (unchanged — this ADR removes the vendored tree it was implemented
  alongside, not the decision) · ADR-0006 (OPA) · ADR-0014 (Zoekt) · ADR-0009 (BYO CP/DP split) ·
  ADR-0027 (repo topology) · ADR-0001 (ADR SoT) · **Invariants:** 21

## Context

ADR-0038 licensed this repo GPL v2 so that [rfxn/rdf](https://github.com/rfxn/rdf) could be vendored
under `tools/rdf/`, and 245 files of it were. Two things about that have not aged well over the few
hours it existed.

**The vendored tree was never load-bearing.** ADR-0038 decision 2 said what it was for: the source
the agent personas would be derived from, a reference implementation, and the attribution that
derivation obliges. Only the third of those was ever real. The personas are ADR-0037 phase 1 and have
not been written. `scripts/gen-agent-surfaces.sh` was written from scratch and shares no code with
RDF — different data model (a TSV manifest, fragments, two textual expansions), different control
flow, different failure modes. `bin/rdf` is not run, not in CI, not referenced by any script here.
We were carrying 245 files, a licence obligation, an upstream pin to bump, and someone else's
security surface, in exchange for a citation.

**And it actively caused harm.** The vendored tree shipped upstream's own `CLAUDE.md` and its
generated `AGENTS.md`. Coding agents load nested instruction files for the directory they are working
in, so upstream's rules — a different commit protocol, "no Co-Authored-By", `~/.rdf/` paths that do
not exist here — became live instructions inside the repo that exists to state *our* rules. That was
caught and both files were dropped, but the shape of the problem is inherent: vendoring a framework
whose entire purpose is to instruct agents, into a repo whose entire purpose is to instruct agents,
puts two sets of instructions in one tree and hopes the right one wins.

What we actually took from RDF is an idea: author conventions once in a canonical source, generate
per-runtime surfaces from it, and gate the result against drift. Ideas are not copyrightable
expression, and this one is not even novel — it is what every code generator does, and it is what
`check-codegen-fresh.sh` has done for `contracts/` in this tree since T-0020. Reading a published
project and then writing your own implementation is not derivation.

That leaves the licence. ADR-0038 chose GPL v2 for one reason: it was the licence the vendored code
required. Remove the vendored code and the obligation goes with it. But the grant has already been
published — ADR-0038 merged, and every commit since carries a GPL v2 `LICENSE` in a public
repository. Retracting a published licence grant is messy, contested, and buys nothing.

## Decision

We will **vendor no third-party code in `governance`**, and we will **keep the GPL v2 `LICENSE` on
this repo as a deliberate choice rather than an obligation**.

1. **`tools/rdf/` is removed.** All 245 vendored files, the `UPSTREAM` pin, and every reference to
   them. Nothing in this repo depends on it.

2. **No third-party code is vendored into `governance`.** Not under `tools/`, not anywhere. If a
   future need is real, it is a dependency declared and pinned like any other, or it is an ADR — not
   a directory that appears in a feature PR. This is narrower than a general policy: it is about
   *this* repo, which every other repo defers to, and where a second set of anything is the problem
   invariant 21 exists to prevent.

3. **The surface pipeline is ours, and this is our flow, stated in our terms.**

   1. A rule is authored **once**, in `governance`, next to the invariant it implements.
   2. Every runtime's surface is **generated** from that source — no file is hand-written twice.
   3. Generation is **byte-deterministic**, so drift is a diff and a diff fails CI.
   4. Generated output is **committed and reviewed** like any other file. It is never gitignored,
      never "working files", never excluded from the record.
   5. Output crossing a repo boundary follows **ADR-0027's ordered workflow**; one commit never spans
      two submodules (invariant 23).

   Points 4 and 5 are where we deliberately diverge from the framework that prompted this: it
   excludes its generated governance from commits and assumes a single repo. Neither is available to
   us, and neither should be.

4. **`governance` stays GPL v2.** Not because anything obliges it — after decision 1 nothing does —
   but because the grant is already published and this repo links nothing, produces no binary, and
   ships to no customer, so the licence costs us nothing. `LICENSE` stays exactly as it is.

5. **The code repos' licence remains open, for the reason ADR-0038 gave.** That reasoning survives
   its superseding ADR and is restated here so it is not lost: GPL v2 *without* "or later" is
   incompatible with Apache-2.0, and ADR-0006 (OPA) and ADR-0014 (Zoekt) mandate Apache-2.0
   dependencies inside the binaries ADR-0009 distributes to BYO customers. `backend`, `bff`,
   `webfrontend`, and the super-repo therefore **must not** simply inherit this repo's licence. Their
   licence needs its own ADR, weighing GPL v3 / AGPL v3 (Apache-compatible; AGPL also closes the
   hosted-SaaS gap) against permissive and source-available options.

6. **ADR-0037 is untouched.** Its seven decisions stand exactly as Accepted. What changes is an
   implementation detail it never specified — whether a third-party tree sits in `tools/` — and the
   answer is now no.

## Consequences

**Positive.** 245 files, an upstream pin, a bump cadence, and someone else's security exposure leave
the tree, and nothing stops working, because nothing depended on them. The class of failure where a
vendored framework's instruction files compete with ours cannot recur, because there is no vendored
framework. The pipeline's provenance is simple to state: we wrote it. And the flow is now written
down in our own terms rather than as a citation of someone else's, which matters because two of its
five points are things that framework does the opposite of.

**Negative / costs.** We give up the reference implementation, so the next person extending the
generator has our script and this ADR rather than a worked example of the same pattern at a larger
scale. We keep a copyleft licence on this repo that nothing now requires, which is a small oddity
someone will ask about — decision 4 exists so the answer is written down. And superseding an ADR
within hours of merging it is not a good look; the honest reading is that ADR-0038 answered "may we
vendor this" without anyone asking the prior question, "do we need to".

**Follow-ups.**
- The code repos' licence (decision 5) is the open item, inherited from ADR-0038 and unchanged.
- ADR-0038 was merged with status `Proposed` and never flipped to `Accepted`, contrary to
  `docs/adr/README.md` step 3. It is marked `Superseded by ADR-0039` here, which makes the point
  moot, but the process gap is real and worth watching for on the next ADR.
- ADR-0037 phases 1 (agent personas) and 3 (modes, ceremony tiers) are unstarted. Phase 1 was the
  stated reason for vendoring; it will now be written from our own governance, which is what
  ADR-0037 decision 2 wanted anyway.

## Alternatives considered

- **Keep `tools/rdf/` and just be careful about instruction files** — rejected. The `CLAUDE.md`
  collision was caught by luck, not by a gate, and there is no gate available: any file that a
  future pin bump adds could be instruction-shaped. Carrying a hazard because we spotted it once is
  the pattern ADR-0034 and ADR-0036 were both written about.
- **Keep the vendored tree but prune it to what we derive from** — rejected because the honest answer
  to "what do we derive from" is nothing. The generator is independent and the personas are unwritten.
  A pruned tree would be zero files.
- **Remove the vendored code and revert the licence to none** — rejected. The GPL v2 grant is already
  published on a public repo; unpublishing a licence grant is contested and gains nothing, since the
  licence is free for a repo that links nothing and ships nothing.
- **Relicense `governance` permissively now** — rejected as unnecessary churn. It would be a second
  licence change in a day, and decision 5's open ADR is the right place to think about licensing
  across the whole tree rather than one repo at a time.
- **Write our own generator but keep citing RDF as its origin in the code comments** — partially
  adopted, and worth being precise about. This ADR names the influence plainly; what it removes is
  the implication, in `gen-agent-surfaces.sh` and the canonical README, that the method is on loan.
  It is not — points 4 and 5 of decision 3 are ours and are contrary to the original.
