# SPEC-0072: A cluster's location is declared, never inherited

- **Status:** Implemented (2026-09-22)
- **Owner:** unassigned
- **Context(s):** deploy / infrastructure (`deploy/gcp`) — no application code, no Kubernetes object
- **ADRs:** 0106 (**Accepted 2026-09-22** — the consequence "no gate enforces it" is this spec's
  entire reason to exist; decisions 1 and 2 are the inputs), 0092 (the units and their boundaries),
  0011 (why NAT and the connector are not the lever), 0001 (governance is SoT)
- **Task(s):** T-0091 (super-repo)

## Problem / context

ADR-0106 decision 1 puts both production environments on zonal clusters and names the cost that
buys. Its Consequences section then concedes the weak point in plain terms:

> **Deleting a `location` line triples that environment's node bill**, and it looks like tidying […]
> **No gate enforces it**, which is the weakest part of this ADR and is recorded as a follow-up
> rather than claimed.

**The failure mode is an omission, not an error.** `var.location` defaults to `null` and resolves to
`var.region`, so a `gke/terragrunt.hcl` with no `location` line is valid HCL, plans without warning,
and applies successfully — into a regional cluster whose node pools create `min_nodes` nodes *per
zone*. Nothing fails. The plan output does not say "three times as many nodes"; it says
`location = "asia-southeast1"`, which reads like a correct region to anyone who does not already
know the multiplication. The bill arrives a month later.

That default is deliberate and must stay: `coalesce(var.location, var.region)` is what keeps the
module usable for a regional cluster without a second module. The gap is not in the module. **It is
that no artefact anywhere asserts a live environment made the choice at all.**

**What this spec must NOT do.** It must not assert that `location` equals any particular value. A
zone is a decision ADR-0106 decision 2 expects to be revisited when an availability requirement is
stated, and a gate pinning `asia-southeast1-a` would convert "restore regional deliberately" from a
one-line edit into a gate fight. The property under test is **explicitness**, not the value — the
same shape as `check-platform-kustomize.sh` AC10, which requires a `storageClassName` to be stated
and does not care which one.

## In scope

- A gate asserting every unit under `deploy/gcp/live/*/gke/` declares `location` explicitly.
- Its negative fixtures and its failability proof, wired into `make verify` beside the existing gates.

## Out of scope

- **Asserting any particular location value**, per the paragraph above.
- Machine types, node counts, disk sizes and storage classes. ADR-0106 decides those too, but each
  is a value whose wrong setting shows up as a plan diff a reviewer can read. `location` is the only
  one whose wrong setting is an *absent line*.
- The module's `coalesce` default, which stays.
- Any check against live GCP. This gate reads the tree; it must run offline and in CI with no
  credentials, like every other gate in `scripts/`.

## Acceptance criteria

- [x] **AC1** The gate fails when a `live/*/gke/terragrunt.hcl` has no `location` in its `inputs`.
      Asserted per unit, naming the unit — a gate reporting only "something is wrong" restates the
      bill rather than locating it.
- [x] **AC2** The gate passes for a unit declaring a **zone** (`asia-southeast1-a`) and equally for
      one declaring a **region** (`asia-southeast1`). Both are explicit; the gate has no opinion
      between them. **This is the criterion that keeps AC1 honest** — without it the obvious
      implementation is a grep for the current zone, which would pass today and refuse ADR-0106
      decision 2's own reversal path.
- [x] **AC3** A `location` present but commented out is a failure, not a pass. This is the exact
      shape the consequence describes: the line is visibly *there*, so a human diff reads as
      unchanged, while the parsed input is absent.
- [x] **AC4** The gate is proven failable: each negative fixture refused, **for its own stated
      reason**, read from the violation text and not from the exit status. A fixture whose refusal
      cannot be attributed to the rule under test is not evidence (T-0090's exit record, and the
      nine fixtures it found decorative).
- [x] **AC5** The two shipped units are **accepted** — a positive assertion in the same run, so the
      suite cannot pass by refusing everything.
- [x] **AC6** Wired into `make verify` in the super-repo; runs offline, no GCP credentials, no
      network.
- [x] **AC7** `deploy/gcp/README.md` states that the gate exists and what it does not assert, so the
      next person restoring regional knows the gate will not fight them.

## Assumptions to assert rather than trust

**That `location` is readable from the HCL without evaluating it.** The shipped units set it as a
literal, so a parse is enough. If a future unit computes it — from `env.hcl`, a dependency output or
a function — a textual check would report a false failure. **If that is found, say so in the exit
record and choose deliberately**, rather than loosening the assertion until it passes: either the
gate learns to evaluate, or computed locations become the thing the gate refuses. Both are
defensible; silently weakening AC1 is not.

**That `live/*/gke/` is the whole population.** Asserted by discovering the units rather than listing
them, so a third environment is covered on the day it is created and not on the day someone
remembers to add it.

## Non-goals worth stating

This gate does not make the zonal choice safe. A zone outage still takes both environments down
(ADR-0106's second consequence), and no gate can change that. It makes the choice **visible** — the
difference between an environment that decided and one that inherited.
