# T-0040: Agent-CA custody — OpenBao deployment, KMS signing, staged CA-trust-bundle rotation, runbook

- **Status:** Todo
- **Phase / Epic:** 3.1 / EP-21 (agent-CA custody and rotation)
- **Repo(s):** backend (custody interface, CA wiring, rotation); super-repo (the OpenBao deployment
  under `deploy/`, its image pin, and the runbook entry in `deploy/MVP-RUNBOOK.md`) — one commit per
  repo, the same split prior tasks used for the runbook
- **Spec:** docs/specs/SPEC-0044-agent-ca-custody-rotation.md (Approved 2026-08-15, amended 2026-08-15 — RED may begin)
- **ADRs:** 0064, 0066 (provider, deployment, unseal, availability contract), 0034/0035 (image pin form), 0060, 0056, 0044, 0057
- **Owner:** unassigned

## Goal

Move PR-20's identity root off development custody: in a production posture the CA issues and rotates
agent certificates through a narrow platform-secrets/KMS custody interface and holds key references,
never key material; rotation is a staged CA trust bundle with a dual-validate window that requires no
fleet re-enrolment; and the dev CA is test-only, unreachable from the production composition root
(ADR-0064). Also lands the runbook entry ADR-0064's consequences name — the rotation procedure,
alongside the clock-skew symptom entry owed since T-0030.

## Acceptance criteria (test-first)

SPEC-0044 AC1–AC5:
- [ ] AC1: the CA signs through custody-held keys — the production composition root cannot construct
      a CA from a file path or an env var, fitness-asserted; the private key never exists on disk or
      in the environment.
- [ ] AC2: CA rotation is a staged CA trust bundle with a dual-validate window — new key beside the old,
      both validate during the overlap, new certificates chain to the new key, and the old root is
      removed only after every issued certificate predates its removal; no fleet re-enrolment, and a
      data plane that cannot present a valid certificate still recovers only by re-enrolment
      (ADR-0060 unchanged).
- [ ] AC3: the dev CA is test-only and unreachable from the production composition root —
      fitness-asserted, so the in-process signer the suites use cannot silently become the production
      signer.
- [ ] AC4: the runbook covers the rotation procedure — stage, overlap, remove, with the removal
      precondition named — plus quorum unseal after a cold restart (share custody, out-of-band
      distribution, order of operations), seal/custody outage (issuance stops; already-issued
      certificates stay valid until expiry), and the enrolment-mid-flight case SPEC-0042 AC6 decides;
      and cross-references the clock-skew symptom entry (a skewed customer cluster presents as a
      network fault; T-0030's recorded limit).
- [ ] AC5: the custody service is deployed and pinned, not assumed — OpenBao control-plane-side only,
      three-node Raft, Kubernetes auth with no static credential in chart values or environment,
      image pinned per ADR-0034. A deployment check asserts node count, credential absence, and that
      no data-plane chart references the custody service at all (ADR-0066 decisions 5–7).

## Tests to write first

Per SPEC-0044 § Test plan:
- KMS-fake integration tests: the custody interface exercised against a fake provider in CI, never
  the production one; the issuance path proven to hold references, not material (AC1).
- dual-validate window rotation tests: stage → overlap (old and new both validate) → new issuance →
  old-root removal ordering, including mid-window restart and a certificate that outlives a premature
  removal attempt (AC2).
- fitness tests for both posture assertions (AC1, AC3).
- deployment assertions (AC5): rendered manifests for node count and control-plane-side placement,
  image-pin conformance, no static credential in values or environment, and a data-plane chart render
  proving the custody service is absent from it.
- custody-unavailable test: signer refusing — already-issued certificates still validate, and
  enrolment behaves as SPEC-0042 AC6 specifies (shared surface with T-0036; neither proves it alone).
- runbook: existence and cross-links resolve — rotation, unseal, seal outage and the clock-skew entry
  must all resolve, checked by the docs gate once authored under this task (AC4).

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony — the change touches secrets posture; no
lower tier is available (SPEC-0012).

Gate matrix (per repo):
- backend: `gofmt` / `go build` / `go vet`, `internal/` boundary + architecture fitness, policy +
  tenant-isolation, `go test -race`.
- super-repo (deployment + runbook): `make verify` plus the codegen/surfaces/policy checks, the
  image-pin check over the new custody image, and the AC5 deployment assertions; one commit.

## Notes / open questions

**Order within this task: deploy the custody service before swapping the composition root.** AC1's
fitness test forbids a disk or env key, and the only other signer is the dev CA AC3 makes
unreachable — so the CA has nowhere to sign until AC5's OpenBao is up. The staging is: deploy and
unseal, wire Kubernetes auth, create the non-exportable transit key, swap the issuer, then land the
fitness tests.

The bundle this task rotates is the **CA trust bundle** (agent identity roots). T-0041 rotates the
**release trust bundle** (cosign release-signing keys) — different artifact, different reason, same
reconcile path. Neither task's tests may stand in for the other's; if one staging mechanism ends up
serving both, say so in the exit record and name the dependency it creates.

Rotation cadence and overlap length are per-environment configuration, not compiled in.
CA-trust-bundle staging is assumed to ride the existing reconcile path; if the channel lacks a field,
that additive `agent/v1` change happens first under its own governance PR (SPEC-0044 Contracts
touched). The KMS provider is settled by ADR-0066 (OpenBao transit engine, Shamir unseal,
Kubernetes auth) and deploying it is AC5 of this task; general platform-wide tenant-secret custody
stays open on ADR-0057's own track — the custody interface stays narrow enough that a future
general platform-secrets ADR can absorb it (ADR-0064 decision 2).
