# ADR-0038: License `governance` under GPL v2 and vendor RDF into it — and do not extend GPL v2 to the code repos yet

- **Status:** Superseded by ADR-0039
- **Date:** 2026-08-08
- **Deciders:** platform
- **Governs:** G7 process integrity — ADR-0037 phase 2 cannot start while the licence of the tree it
  writes into is undefined
- **Relates to:** **ADR-0037** (answers its deferred decision 4 — *refined, not superseded*) ·
  ADR-0027 (repo topology) · ADR-0006 (OPA) · ADR-0014 (Zoekt) · ADR-0009 (BYO CP/DP split) ·
  ADR-0017 (agent) · ADR-0001 (ADR SoT) · **Invariants:** 21, 22 ·
  **Upstream:** [rfxn/rdf](https://github.com/rfxn/rdf) (GPL v2)

## Context

ADR-0037 decided to generate the sixteen agent surfaces from this repo using RDF's canonical-first
method, and consumed RDF as an external pinned tool rather than vendoring it. It said why:

> RDF is **GPL v2** and neither this repo nor the super-repo currently carries a `LICENSE` file.
> Vendoring `canonical/` prose or `lib/*.sh` would raise a derivative-work question we have not
> answered […] **Vendoring requires its own ADR.**

That deferral has a cost ADR-0037 named as a consequence and which is now the blocker: an external
`rdf generate` that breaks is a blocked PR, upstream sets its own cadence, and phase 2's freshness
gate would depend on a binary that is not in the tree. Vendoring removes all three. The only thing
standing in the way is that nothing in this tree states a licence.

Two questions are tangled together and must be separated, because the answer differs:

1. **May GPL v2 material live in `governance`?** This repo is markdown, shell scripts, protobuf
   contracts, and Rego. It links nothing and ships in no binary.
2. **May GPL v2 apply to `backend`, `bff`, `webfrontend`?** These link a dependency tree that our
   own ADRs mandate, and much of it is **Apache-2.0**: OPA (ADR-0006), Zoekt (ADR-0014), and most of
   the Go ecosystem around them.

Question 2 has a real answer and it is not the convenient one. **GPL v2 without the "or later" clause
is incompatible with Apache-2.0** — the FSF's long-standing position, on the grounds that Apache
2.0's patent-termination and indemnification terms are restrictions GPL v2 §6 does not permit. RDF is
GPL v2 *only* (`LICENSE` is the plain Version 2, June 1991 text; no "or, at your option, any later
version"). So licensing `backend` GPL v2 would put us in conflict with ADR-0006 and ADR-0014 on the
day we shipped a binary. GPL **v3** or **AGPL v3** are compatible with Apache-2.0 and would not have
this problem — but they are also not what RDF is under, and picking one is a product decision about
copyleft reach, not a tooling decision.

The distribution question matters too, and is separate from the compatibility one. GPL v2 is a
*distribution* copyleft with no network clause: operating the SaaS is not distribution, so a
hosted-only product would trigger nothing. **We are not hosted-only.** ADR-0009's BYO data plane runs
on customer infrastructure and ADR-0017's agent is a binary we ship to them. Both are distribution.
Any GPL-v2 component inside them would carry source-availability obligations to those customers.

## Decision

We will **license `governance` under GNU GPL v2 and vendor RDF into it**, and we will **not** extend
GPL v2 to `backend`, `bff`, or `webfrontend` on the strength of this ADR.

1. **`governance` is GPL v2.** A verbatim GPL v2 `LICENSE` is added at the root of this repo. This is
   the repo that will hold RDF-derived material, and it is the one where GPL v2 costs nothing: it
   links no libraries, produces no binary, and ships to no customer.

2. **Vendoring RDF-derived material into `governance` is permitted.** It lands under `tools/rdf/`,
   with upstream's `LICENSE` and copyright headers preserved verbatim, a `tools/rdf/UPSTREAM` file
   recording the exact upstream commit vendored, and no modifications outside clearly-marked local
   patches. This is the standard obligation set for GPL v2 redistribution, not an extra ceremony.

3. **Vendored upstream is pinned by commit and bumped deliberately.** Same discipline as invariant 25
   for submodule pointers: `tools/rdf/UPSTREAM` names a commit, and moving it is a reviewed PR that
   states what changed. Vendoring is not a licence to drift silently.

4. **The code repos stay unlicensed by this ADR, and that is deliberate, not an oversight.**
   `backend`, `bff`, and `webfrontend` link Apache-2.0 dependencies that ADR-0006 and ADR-0014
   require. GPL v2 *only* is incompatible with Apache-2.0, so applying it there would put the tree in
   conflict with two Accepted ADRs. **Their licence is an open decision requiring its own ADR**,
   which must weigh at minimum: GPL v3 or AGPL v3 (Apache-compatible, and AGPL closes the network
   gap), a permissive licence, or a source-available licence — against ADR-0009's BYO distribution,
   where whatever we pick is what customers receive.

5. **No GPL-v2 material crosses into a distributed artifact.** Nothing under `tools/rdf/` may be
   imported, embedded, or copied into `backend`, `bff`, `webfrontend`, the ADR-0017 agent, or any
   shipped image. It is build-time-and-authoring-time tooling for this repo. The generated agent
   surfaces are our own prose, not RDF's — RDF supplies the pipeline, not the content. If a future
   change wants RDF code inside a shipped artifact, decision 4's ADR must land first.

6. **ADR-0037 is refined, not superseded.** Its decision 4 chose "external tool, not vendored"
   *because* the licence was unanswered. The licence is now answered for the one repo that matters,
   so vendoring is permitted and phase 2 may proceed. Every other decision in ADR-0037 stands
   unchanged — including decision 2 (no `.rdf/governance/` scaffolding) and decision 3 (generated
   output is committed and gated).

## Consequences

**Positive.** ADR-0037 phase 2 is unblocked with the tooling in-tree, so the freshness gate depends
on a vendored, pinned generator rather than on whatever version of RDF a developer or CI runner
happens to have installed — which is the same reasoning ADR-0034 applied to image pins. Upstream
cadence stops being able to break our CI. The one repo that gains a copyleft obligation is the one
with no linked dependencies and no shipped artifact, so the obligation is close to free. And the
compatibility landmine under the code repos is now written down in the SoT instead of waiting to be
discovered by whoever first adds a `LICENSE` to `backend`.

**Negative / costs.** The tree now has a mixed and partly-undefined licence state: `governance` is
GPL v2, three code repos and the super-repo are unlicensed, which is legally the *most* restrictive
default and is not a state to leave sitting. Decision 5's "no GPL material in shipped artifacts"
boundary is enforced by review, not by a check — invariant 22's dependency direction already
prevents the import path (nothing may import governance internals; only `contracts/` is shared), but
`tools/rdf/` is prose and shell that a copy-paste could move without tripping any gate. Vendoring
also means we now carry someone else's code: bumping `tools/rdf/UPSTREAM` is a real review burden,
and a security issue upstream is our security issue.

**Follow-ups.**
- **The code repos' licence is the open item this ADR creates.** It needs its own ADR and it should
  not sit for long; GPL v3 / AGPL v3 / permissive / source-available against ADR-0009's BYO
  distribution is the trade to make explicitly.
- The super-repo also has no `LICENSE`. It holds pins and scripts, not product code, so it is a
  smaller question — but it is the same question and should ride along with the one above.
- A fitness function asserting no `tools/rdf/` path is referenced from a code repo would turn
  decision 5 from a review rule into a checked one. Cheap, and worth doing when phase 2 lands.

## Alternatives considered

- **License the whole tree GPL v2, matching RDF** — rejected on a concrete conflict, not on taste.
  GPL v2 *only* is incompatible with Apache-2.0, and ADR-0006 (OPA) and ADR-0014 (Zoekt) mandate
  Apache-2.0 dependencies in the very binaries that ADR-0009 distributes to BYO customers. This would
  create a licence conflict at ship time and put us at odds with two Accepted ADRs.
- **License the whole tree GPL v3 or AGPL v3** — not rejected, deferred. Both are Apache-2.0
  compatible and AGPL v3 additionally closes the hosted-SaaS gap that GPL v2 leaves open. Either may
  well be the right answer for the code repos, but it is a product decision about how far copyleft
  reaches into a commercial BYO offering, and it should be decided on that basis rather than inherited
  from a tooling dependency's licence.
- **Keep RDF external, as ADR-0037 decided** — rejected, having now paid the cost it predicted. The
  generator being outside the tree means CI depends on an unpinned third-party install; ADR-0034
  already established that a dependency whose exact version is not fixed is a defect waiting for a
  bad day.
- **Rewrite RDF's generator ourselves to dodge the licence entirely** — rejected as cost, same as
  ADR-0037's alternative of the same name. Clean-rooming a few hundred lines of shell to avoid a
  copyleft obligation on a repo that ships nothing is effort spent on the wrong problem.
- **Vendor RDF without licensing this repo at all** — rejected. Redistributing GPL v2 material inside
  an unlicensed repo is precisely the thing GPL v2 §2 does not allow, and "we did not mean to
  redistribute" is not a defence once it is in a public tree.
