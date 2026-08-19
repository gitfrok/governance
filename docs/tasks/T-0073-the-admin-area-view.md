# T-0073: The admin area view — a dated report, and a door instead of a trail

- **Status:** Not started
- **Phase / Epic:** 4 / EP-27 (Tier C)
- **Repo(s):** webfrontend
- **Spec:** ../specs/SPEC-0058-admin-area.md (AC12–AC19)
- **ADRs:** 0077, 0069, 0070, 0033 (the grant flow this links into)
- **Owner:** unassigned

## Goal

The browser half of SPEC-0058. The spec is the authority.

## Acceptance criteria (test-first)

- [ ] SPEC-0058 AC12–AC19 — as written in the spec.

## Tests to write first

- RED before implementation, per the spec's acceptance criteria.

## Notes / open questions

- **The age is the most prominent field.** A fleet panel that renders status without saying when the
  plane last said so misrepresents an outbound-only architecture as a live console.
- **No members panel and no `Last active`.** The first has no port behind it; the second is presence
  telemetry this product has declined to collect. Both are held by the copy enumeration.

## Definition of Done

See ../process/definition-of-done.md. `full` ceremony.
