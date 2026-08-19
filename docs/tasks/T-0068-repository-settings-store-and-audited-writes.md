# T-0068: Repository settings on the registry record, and an audited write path

- **Status:** Not started
- **Phase / Epic:** 4 / EP-27 (Tier C)
- **Repo(s):** backend
- **Spec:** ../specs/SPEC-0057-repository-settings.md (AC1–AC9)
- **ADRs:** 0076, 0071, 0007, 0070, 0022, 0006
- **Owner:** unassigned

## Goal

One repository's share of SPEC-0057, split along the ADR-0027 boundary. The spec is the authority.

## Acceptance criteria (test-first)

- [ ] SPEC-0057 AC1–AC9 — as written in the spec.

## Tests to write first

- RED before implementation, per the spec's acceptance criteria.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.

## Notes / open questions

- **Archival is a label, not an enforcement.** AC7 is the executable form of ADR-0076 decision 1: an
  archived repository still lists, still reads, and is still writable. A read-only condition needs a
  cause from a two-member vocabulary and `readonly-cause` is a phase-wide pin.
- **The audit port is declared here, filled in `cmd/`.** Repository is a leaf at fan-out zero and
  stays one; importing the Audit context would invert the module graph for one call.
