# T-0033: Residency pinning and its evidence-pack section

- **Status:** Todo
- **Phase / Epic:** 3 / EP-17 (residency and evidence)
- **Repo(s):** governance (pack-contract addition, ADR-0027 order), then backend
- **Spec:** docs/specs/SPEC-0040-residency-pinning-evidence.md (Draft — Approved before RED)
- **ADRs:** 0009, 0010, 0029, 0055
- **Owner:** unassigned

## Goal
Make residency provable: a declared cloud/region enforced on placement, contradictions visible, and
a pack section that answers "where was this tenant's work during the range" with honest gaps.

## Acceptance criteria (test-first)
SPEC-0040 AC1–AC8. The ones that decide whether this is evidence or decoration:
- [ ] AC5: an interval with no placement reports renders as a gap, never as compliance.
- [ ] AC7: a customer's own attestation about their cluster can reach the attested appendix only,
      never a control section — a customer must not attest their own compliance into the record.
- [ ] AC6: a declaration change inside the range shows as a change with its effective time.

## Tests to write first
- unit: declared-vs-observed contradiction detection inside the window; gap rendering for a silent
  interval.
- contract: the additive pack section against `buf breaking`.
- integration: pack assembled while a data plane is offline — assembles, with the gap.
- policy-isolation: no tenant-B placement fact in a tenant-A pack, including through shared infra.

## Definition of Done
See `../process/definition-of-done.md`. `full` ceremony — evidence and tenancy.

## Notes / open questions
Changing a tenant's declared residency (migration) is undesigned: today it renders as a change with
no mechanism to move existing data. Say so in the exit record rather than letting the section imply
migration is supported.
