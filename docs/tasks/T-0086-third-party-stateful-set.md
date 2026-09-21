# T-0086: Install the third-party stateful set

- **Status:** Todo — **blocked-by ADR-0099 acceptance** (Proposed 2026-09-22; SPEC-0069 is `Draft`).
  Not lane-blocked: every criterion is provable by rendering.
- **Phase / Epic:** first control-plane deployment. **No epic yet** — filing one is part of
  scheduling this, as it was for T-0084.
- **Repo(s):** **super-repo** (`deploy/k8s/platform/`, `deploy/gcp/**` for the backups unit,
  `scripts/check-platform-kustomize.sh`) **and governance** (teaching
  `check-custody-service.sh`'s assertions a production path is a super-repo change, but SPEC-0069's
  status transition is governance). Two repos, two commits (invariant 23).
- **Spec:** docs/specs/SPEC-0069-third-party-stateful-set.md (**Draft**)
- **ADRs:** 0099 (Proposed), 0093, 0096, 0066, 0092, 0033/0050, 0052, 0034/0098
- **Owner:** unassigned

## Goal

Give the six third-party components a production install, so the control-plane installer's required
inputs exist. **This is the last structural blocker between the tree and a login** — and meeting it
still will not produce one, for reasons in SPEC-0069 open question 4.

## Acceptance criteria (test-first)

SPEC-0069's twelve, carried rather than paraphrased. The ordering below is the ordering to build in:

- [ ] AC11 the gate, with a negative fixture per assertion — **first**, as in T-0084
- [ ] AC2 StatefulSets with volumeClaimTemplates; Zitadel exempt as stateless
- [ ] AC3 replica counts exactly as ADR-0099 decision 4 states them
- [ ] AC4 no authored Secret, no secretGenerator, credentials by reference
- [ ] AC5 nothing publicly reachable in either overlay
- [ ] AC1 the two overlays render the right components, OpenBao and Zitadel control-plane-only
- [ ] AC7 OpenBao's gated properties carried, and the gate taught the production path
- [ ] AC8 OpenBao on TLS; no loopback proxy, no ALLOW_LOOPBACK_HTTP under deploy/k8s
- [ ] AC9 the CNPG Cluster declares a backup target, and its absence fails
- [ ] AC6 digest pins resolving to versions.env, NOT RUN where unpublished
- [ ] AC10 explicit block-backed storage classes
- [ ] AC12 deterministic renders

## Tests to write first

1. **`scripts/check-platform-kustomize.sh` with fixtures** under `scripts/testdata/`: a `Deployment`
   carrying a PVC (AC2), a scaled-down replica count (AC3), a `secretGenerator` and a literal
   credential (AC4), a `LoadBalancer` Service (AC5), and a CNPG `Cluster` with no `backup` stanza
   (AC9). Each exits non-zero; the shipped tree exits zero.
2. **Render assertions parsed as YAML**, never grepped — T-0084's gate had three false positives
   from substring matching, including its own comment tripping its own grep.
3. **Determinism** (AC12).
4. **AC7 last**, because it changes an existing gate: `check-custody-service.sh` currently hardcodes
   the dev path, so teaching it a second one risks a list that silently matches nothing and passes.
   Prove the new assertion fails on a mutated production manifest before trusting it.

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony.

Gate matrix (super-repo): `make verify` including the new gate and its fixtures;
`check-custody-service.sh` green against **both** paths; `check-shell-portability.sh`;
`check-controlplane-kustomize.sh` unaffected. Governance: `check-docs.sh` for the status transition.

## Notes / open questions

**Blocked on a decision, not a lane.** ADR-0099 adopts an operator, amends ADR-0092 decision 5 to
provision a GCS backup bucket, and fixes six replica counts. Each is the owner's to confirm, and
building against a Proposed shape risks rework on all six components.

**What this task must not do.** It must not promote `deploy/dev` — five of the six are `Deployment`
plus ReadWriteOnce there, a shape that cannot roll and that would fail on its first upgrade looking
like a storage fault. It must not author a Secret. It must not put a `LoadBalancer` in either overlay.
And it must not leave `check-custody-service.sh` proving properties about a Minikube file while
production runs a different one.

**The ordering nobody has written down.** Postgres and Zitadel care about upgrade order relative to
each other and to the control-plane app; ADR-0099 records that nothing states it. This task does not
settle it, and whoever first upgrades production will discover it if it is still unwritten.

**After this, the remaining path to a login is short and entirely non-structural:** publish the
first-party images (ADR-0098's workflow, which needs its GitHub environment), create seven
credentials, unseal OpenBao with a human quorum, then apply the control-plane overlay.
