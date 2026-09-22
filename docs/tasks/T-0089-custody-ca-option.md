# T-0089: The custody client can be given a CA, and refuses to guess

- **Status:** Todo
- **Phase / Epic:** first control-plane deployment (ADR-0104 carry)
- **Repo(s):** backend
- **Spec:** `../specs/SPEC-0071-custody-tls-trust.md` (AC1–AC7)
- **ADRs:** 0104 (Accepted 2026-09-22 — decisions 1, 2, 3), 0066, 0044/SPEC-0044 AC1, 0035
- **Owner:** unassigned

## Goal

Give `custody.Config` an explicit `CAFile`, wire it from `GITFROK_CUSTODY_CA_FILE`, and make every
way of getting it wrong a loud construction error instead of a quiet fallback to the system pool.

Nothing about signing, enrolment or transit changes. `validateAddress` is not touched: `https`
outside loopback stays mandatory, and the loopback-HTTP relaxation keeps its exact current scope.

## Acceptance criteria (test-first)

- [ ] AC1 `Config.CAFile` set → the client verifies a server chaining to that bundle; unset → it does
      not. Both directions, against a real TLS `httptest` server with a throwaway CA.
- [ ] AC2 The bundle is **appended** to the system pool, not substituted. A public-root certificate
      still verifies while `CAFile` is set.
- [ ] AC3 `NewOpenBao` still contacts nothing when `CAFile` is set (SPEC-0044 AC1).
- [ ] AC4 Absent, unreadable, and malformed `CAFile` are each a construction error naming the path —
      three cases, no fallback, no deferral to first call.
- [ ] AC5 Empty `CAFile` is byte-identical to today; every existing custody test passes unmodified.
- [ ] AC6 `CAFile` and `Client` both set is refused at construction.
- [ ] AC7 `cmd/controlplane-app` reads `GITFROK_CUSTODY_CA_FILE` into `Config.CAFile`; unset → empty.

## Tests to write first

- **unit (`modules/agent/internal/adapters/custody`)** — AC1 as one test asserting both directions;
  a separate test per AC4 case, each asserting the error mentions the path; AC6 as a construction
  refusal. AC1/AC4 must be written and **seen to fail** before the field exists, or they will be
  written to fit whatever gets built.
- **unit, pool composition (AC2)** — assert the resulting `RootCAs` subject count is the system
  pool's plus one, and that a public-root certificate still verifies. This is the test that
  distinguishes "appended" from "replaced"; an AC1-only suite passes on the broken implementation.
- **unit (AC3)** — construct against an address with no listener; assert nil error and no dial.
- **unit (`cmd/controlplane-app/custodyconfig_test.go`, AC7)** — beside the six variables already
  covered, including the unset case.
- **regression (AC5)** — the existing custody suite, unmodified. If a test needs changing to pass,
  that is a finding, not a fixup.

## Definition of Done

See `../process/definition-of-done.md`. Plus: `make verify` in `backend` green with `-race`, and one
commit in `backend` only (invariant 23) — the installer half is T-0090.

## Notes / open questions

**Do not reach for `SSL_CERT_FILE` or `SSL_CERT_DIR` if the tests get awkward.** ADR-0104 decision 3
rejected both, the first because Go uses it *instead of* the default file list and would silently drop
every public root. That refusal is the decision, not a preference.

**AC2's arithmetic depends on `x509.SystemCertPool()` being non-empty in a `FROM scratch` image
carrying one `ca-certificates.crt`.** SPEC-0071 records this as an assumption to be asserted rather
than trusted. If the pool comes back empty there, AC2 still holds — append is still append — but say
so in the exit record instead of adjusting the assertion until it passes.

**`Config.Client` stays.** It is the composition-root injection point the in-process wire tests use;
AC6 refuses only the *combination*, because two ways to specify one transport is a configuration
nobody can read off the composition.
