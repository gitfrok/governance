# ADR-0040: Apache-2.0 across the whole tree

- **Status:** Proposed
- **Date:** 2026-08-08
- **Deciders:** platform
- **Governs:** G7 process integrity — four of five repos shipped with no licence at all, which is the
  most restrictive default there is
- **Relates to:** **ADR-0039** (answers its decision 5 and reverses its decision 4 — *refined, not
  superseded*) · ADR-0038 (superseded; its Apache-2.0 incompatibility finding is what made this
  necessary) · ADR-0006 (OPA) · ADR-0014 (Zoekt) · ADR-0009 (BYO CP/DP split) · ADR-0017 (agent) ·
  ADR-0013 (Helm + operator) · **Invariants:** 21

## Context

The tree has been in a mixed and partly-undefined licence state since ADR-0038: `governance` under
GPL v2, and `backend`, `bff`, `webfrontend`, and the super-repo carrying **no `LICENSE` at all** —
which is not "permissive by default" but the opposite, since without a grant nobody has permission
to do anything with the code. ADR-0039 decision 5 left that open deliberately and called it out:

> `backend`, `bff`, `webfrontend`, and the super-repo therefore **must not** simply inherit this
> repo's licence. Their licence needs its own ADR.

This is that ADR, and the reason it could not simply say "GPL v2 everywhere" is ADR-0038's finding,
which survives both of its own supersessions: **GPL v2 without the "or later" clause is incompatible
with Apache-2.0.** ADR-0006 mandates OPA and ADR-0014 mandates Zoekt, both Apache-2.0, inside
binaries that ADR-0009 and ADR-0013 distribute to BYO customers. Distribution is what triggers a
copyleft obligation, and we distribute.

Two facts make relicensing available rather than merely desirable:

1. **The tree is entirely first-party.** ADR-0039 removed the vendored third-party code and forbade
   vendoring any more into `governance`. There is no longer an external licence dictating ours.
2. **Copyright is held by the project.** Every commit in `governance` is authored by Pichate Insuwan
   or WebEnable Asia. Relicensing requires the agreement of everyone holding copyright in the tree,
   and here that is one party.

GPL v2 on `governance` was never an obligation in the first place. ADR-0039 decision 4 says so
plainly — it kept the licence "as a deliberate choice rather than an obligation", because the grant
was already published and cost that repo nothing. A choice is exactly the kind of thing a later ADR
may revisit.

## Decision

We will **license every repository in the tree under the Apache License, Version 2.0.**

1. **All five repos carry a verbatim Apache-2.0 `LICENSE`** — `governance`, `backend`, `bff`,
   `webfrontend`, and the super-repo. Copyright line: `Copyright 2026 WebEnable Asia`. Each lands as
   its own commit in its own repo (invariant 23), in ADR-0027's order.

2. **`governance` moves from GPL v2 to Apache-2.0**, reversing ADR-0039 decision 4. Its GPL v2
   grant on commits already published is **not** withdrawn and cannot be: anyone who received those
   commits keeps GPL v2 rights to them forever. Relicensing binds this version onward. That is the
   normal shape of a relicence and it is worth stating rather than implying.

3. **Apache-2.0 rather than the alternatives, for reasons specific to what we ship.** It is
   compatible with every dependency our own ADRs mandate, which is the constraint that killed GPL v2.
   Its **express patent grant** (§3) matters for software we hand to customers to run themselves —
   GPL v2 has only an implied grant, and MIT has none at all. And §4's requirement to carry the
   licence and state changes gives attribution without the redistribution burden a copyleft licence
   places on a BYO installation.

4. **This is a permissive licence and we are choosing that knowingly.** A BYO customer — or a
   competitor — may fork this code, modify it, and redistribute it commercially without contributing
   anything back or publishing their changes. AGPL v3 would have prevented that and would also have
   closed the hosted-SaaS gap. We are not choosing it. Consequences below states what that costs, so
   that nobody later reads this ADR as though the trade were invisible.

5. **`LICENSE` is not a generated surface.** ADR-0037's pipeline generates the agent surfaces, and
   five byte-identical `LICENSE` files look like an obvious candidate. They are not. A licence has to
   be verbatim and self-contained, and a generated one invites exactly the question a licence must
   never raise — whether the text was modified in transit. It also cannot carry the "GENERATED"
   banner every other generated file carries, because that banner would itself be a modification.
   Five hand-placed identical files is the correct answer here.

6. **ADR-0039 is refined, not superseded.** Its decisions 1, 2, 3, and 6 stand unchanged — no
   vendored third-party code, the pipeline is ours, and the five-point flow. Only decision 4 (keep
   GPL v2) is reversed and decision 5 (code repos' licence open) is answered.

## Consequences

**Positive.** Every repo has a licence, so the question "what may I do with this" has an answer for
the first time — including for the BYO customers ADR-0009 and ADR-0013 hand a data plane to. The
Apache-2.0/GPL-v2 conflict that ADR-0038 identified is gone rather than contained, so nothing about
adding an Apache-2.0 dependency needs a licence review. One licence across five repos ends the mixed
state ADR-0039 called "not a state to leave sitting". And the express patent grant protects both
directions: contributors grant patent rights, and anyone bringing patent litigation over the code
loses their grant.

**Negative / costs.** We give up all copyleft. A BYO customer may take the data plane, improve it,
and ship a competing product without returning anything, and Apache-2.0 gives us no recourse — this
is the deliberate choice in decision 4, not an oversight. `governance`'s existing GPL v2 grant also
cannot be recalled, so a fork taken from any commit before this one carries copyleft terms while
everything after it does not; that is a confusing but harmless state, and it is the reason the ADR
records exactly when the change happened. Anyone who chose to depend on this project *because* it was
GPL v2 loses that guarantee.

**Follow-ups.**
- ADR-0013 packages Helm charts and an operator, and ADR-0035 signs first-party images. Whether the
  distributed artifacts need a `NOTICE` file or an SBOM listing third-party licences is a separate
  question this ADR does not answer. Apache-2.0 §4(d) only requires propagating a `NOTICE` if one
  exists, and we are deliberately not creating one.
- Existing source files carry no licence headers. Apache-2.0 does not require them, and adding them
  to every file is churn; if a distribution requirement later argues for it, that is its own change.

## Alternatives considered

- **AGPL v3** — rejected on the instruction to use Apache-2.0, and the trade is worth recording. It
  is Apache-2.0-compatible, so it would have solved ADR-0038's conflict just as well, and it is the
  only option here that closes the hosted-SaaS gap: a competitor running our code as a service would
  owe source to their users. It is also the option most likely to deter enterprise adoption and BYO
  installs, which is the market ADR-0009 exists to serve.
- **GPL v3** — rejected. Apache-compatible and copyleft, but it carries the copyleft cost into every
  BYO installation without AGPL's network protection, which is the worst of both for this product.
- **MIT** — rejected in favour of Apache-2.0 on one specific point: no patent grant. For software
  distributed to customers who will run it on their own infrastructure, an express grant is worth the
  extra length.
- **Keep `governance` GPL v2 and license only the code repos Apache-2.0** — rejected. It is
  defensible in law, since `governance` links nothing, but it leaves a copyleft island in the repo
  every other repo defers to and guarantees a recurring "wait, which licence applies here" question.
  ADR-0039 kept GPL v2 as a choice; the reason for that choice was inertia, and inertia is not a
  reason to keep two licences.
- **Do nothing** — rejected. Four of five repos with no licence is the status quo, and it means no
  BYO customer has permission to run what ADR-0009 promises them.
