# T-0040: Agent-CA custody — KMS signing, staged trust-bundle rotation, runbook

- **Status:** Todo
- **Phase / Epic:** 3.1 / EP-21 (agent-CA custody and rotation)
- **Repo(s):** backend; plus the runbook entry in the super-repo (`deploy/MVP-RUNBOOK.md`) — the
  runbook change is recorded under this task's repo list and lands as its own super-repo commit,
  one commit per submodule, the same split prior tasks used for the runbook
- **Spec:** docs/specs/SPEC-0044-agent-ca-custody-rotation.md (Approved 2026-08-15 — RED may begin)
- **ADRs:** 0064, 0060, 0056, 0044, 0057
- **Owner:** unassigned

## Goal

Move PR-20's identity root off development custody: in a production posture the CA issues and rotates
agent certificates through a narrow platform-secrets/KMS custody interface and holds key references,
never key material; rotation is a staged trust bundle with a dual-validate window that requires no
fleet re-enrolment; and the dev CA is test-only, unreachable from the production composition root
(ADR-0064). Also lands the runbook entry ADR-0064's consequences name — the rotation procedure,
alongside the clock-skew symptom entry owed since T-0030.

## Acceptance criteria (test-first)

SPEC-0044 AC1–AC4:
- [ ] AC1: the CA signs through custody-held keys — the production composition root cannot construct
      a CA from a file path or an env var, fitness-asserted; the private key never exists on disk or
      in the environment.
- [ ] AC2: CA rotation is a staged trust bundle with a dual-validate window — new key beside the old,
      both validate during the overlap, new certificates chain to the new key, and the old root is
      removed only after every issued certificate predates its removal; no fleet re-enrolment, and a
      data plane that cannot present a valid certificate still recovers only by re-enrolment
      (ADR-0060 unchanged).
- [ ] AC3: the dev CA is test-only and unreachable from the production composition root —
      fitness-asserted, so the in-process signer the suites use cannot silently become the production
      signer.
- [ ] AC4: the runbook covers the rotation procedure — stage, overlap, remove, with the removal
      precondition named — and cross-references the clock-skew symptom entry (a skewed customer
      cluster presents as a network fault; T-0030's recorded limit).

## Tests to write first

Per SPEC-0044 § Test plan:
- KMS-fake integration tests: the custody interface exercised against a fake provider in CI, never
  the production one; the issuance path proven to hold references, not material (AC1).
- dual-validate window rotation tests: stage → overlap (old and new both validate) → new issuance →
  old-root removal ordering, including mid-window restart and a certificate that outlives a premature
  removal attempt (AC2).
- fitness tests for both posture assertions (AC1, AC3).
- runbook: existence and cross-links resolve — checked by the docs gate once authored under the
  implementing task (AC4).

## Definition of Done

See `../process/definition-of-done.md`. `full` ceremony — the change touches secrets posture; no
lower tier is available (SPEC-0012).

Gate matrix (per repo):
- backend: `gofmt` / `go build` / `go vet`, `internal/` boundary + architecture fitness, policy +
  tenant-isolation, `go test -race`.
- super-repo (runbook commit only): `make verify` plus the codegen/surfaces/policy checks; one
  commit, documentation only, no code.

## Notes / open questions

Rotation cadence and overlap length are per-environment configuration, not compiled in.
Trust-bundle staging is assumed to ride the existing reconcile path; if the channel lacks a field,
that additive `agent/v1` change happens first under its own governance PR (SPEC-0044 Contracts
touched). Choosing a concrete KMS provider stays a deployment concern, out of scope; general
platform-wide tenant-secret custody stays open on ADR-0057's own track — the custody interface stays
narrow enough that a future general platform-secrets ADR can absorb it (ADR-0064 decision 2).
